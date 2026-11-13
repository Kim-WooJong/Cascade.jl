module TestParallelColumnsActual
using Test, Cascade, TOML, JSON3, SHA, UnROOT
struct TestNonMmapStream <: UnROOT.AbstractSourceStream end
using Cascade.Config, Cascade.IO, Cascade.Selection
const I=Cascade.IO
function samebits(a,b)
    typeof(a)==typeof(b) || return false
    a isa Jagged && return samebits(a.content,b.content) && samebits(a.offsets,b.offsets)
    a isa AbstractVector && return axes(a)==axes(b) && collect(reinterpret(UInt8,a))==collect(reinterpret(UInt8,b))
    return isequal(a,b)
end
if get(ENV,"CASCADE_PARALLEL_REAL","0")=="1"
@testset "actual primitive/jagged masks, ownership and nominal selection" begin
    root=normpath(joinpath(@__DIR__,"../.."))
    cfg=load_analysis(joinpath(root,"analyses/ttbar_emu/analysis.toml");profile="baseline")
    dq=cfg.data_quality
    lm=load_lumimask(dq.golden_json;run_min=dq.run_min,run_max=dq.run_max)
    paths=[("TTto2L2Nu",ENV["CASCADE_PARALLEL_MC"],32853), ("MuonEG",ENV["CASCADE_PARALLEL_DATA"],104057)]
    for (name,path,n) in paths
        src=NanoAODSource(path); sample=sample_by_name(cfg,name); sel=compile_selection(cfg,sample.kind)
        try
            @test nevents(src)==n
            @test isempty(I.column_read_eligibility(src))
            @test I.column_source_identity(src)!==nothing
            lmask=is_data(sample) ? lm : nothing
            baseline,needed=read_selection_columns(sel,src;stream=sample.stream,lumimask=lmask)
            ref,cf=select_events(sel,baseline,n;sample=name)
            for width in (1,2,4,4,4)
                diagnostics=Dict{String,Any}()
                with_column_readers(src;readers=width,diagnostics) do scope
                    raw,mask=read_selection_columns(sel,src;stream=sample.stream,lumimask=lmask,reader_scope=scope)
                    @test isequal(mask,needed)
                    @test Set(keys(raw))==Set(keys(baseline))
                    @test all(samebits(raw[k],baseline[k]) for k in keys(raw))
                    if scope!==nothing
                        @test all(s.file !== src.file && s.file.fobj !== src.file.fobj for s in scope.slots[2:end])
                        @test all((s.tree,s.runs_tree,s.gen_sumw)==(src.tree,src.runs_tree,src.gen_sumw) for s in scope.slots)
                    end
                    table,flow=select_events(sel,raw,n;sample=name)
                    @test table.order==ref.order
                    @test all(samebits(table[k],ref[k]) for k in table.order)
                    @test isequal(cutflow_dict(flow),cutflow_dict(cf))
                end
                @test diagnostics["extra_opens"]==diagnostics["extra_closes"]
                @test diagnostics["effective_readers"]==width
                width==1 && @test diagnostics["extra_opens"]==0
                println(JSON3.write(Dict("sample"=>name,"width"=>width,"diagnostics"=>diagnostics)))
            end
            names=["Muon_pt","Muon_eta","Electron_pt","Electron_eta","Muon_pt"]
            for mask in (trues(n),falses(n),[isodd(i) for i in 1:n])
                expected=read_columns(src,names;needed=mask)
                d=Dict{String,Any}()
                with_column_readers(src;readers=4,diagnostics=d) do scope
                    jobs=I.column_read_jobs(src,names,mask,scope.diagnostics)
                    @test length(jobs)==4
                    @test jobs[1][2]===jobs[2][2]
                    @test jobs[3][2]===jobs[4][2]
                    @test d["counter_reads"]==2
                    got=read_parallel_columns(scope,names;needed=mask)
                    @test collect(keys(got))==collect(keys(expected))
                    @test all(samebits(got[k],expected[k]) for k in keys(got))
                    @test d["extra_opens"]==3
                    again=read_parallel_columns(scope,names;needed=.!mask)
                    serial=read_columns(src,names;needed=.!mask)
                    @test all(samebits(again[k],serial[k]) for k in keys(serial))
                    @test d["extra_opens"]==3
                end
                @test d["extra_closes"]==3
            end
            d=Dict{String,Any}()
            with_column_readers(src;readers=4,diagnostics=d) do scope
                @test isempty(read_parallel_columns(scope,String[]))
                @test samebits(read_parallel_columns(scope,["event"])["event"],read_columns(src,["event"])["event"])
                @test d["extra_opens"]==0
                @test_throws ArgumentError read_parallel_columns(scope,["Muon_pt","Muon_eta"];needed=[true])
                @test d["extra_opens"]==0
                @test_throws Exception read_parallel_columns(scope,["event","missing_column"])
                @test scope.active==0
            end
            @test d["extra_opens"]==d["extra_closes"]
            # Replacing any built-in registry disables the path before opening.
            saved=I.SOURCE_FORMATS["nanoaod"]
            try
                I.SOURCE_FORMATS["nanoaod"]=p->NanoAODSource(p)
                d=Dict{String,Any}()
                @test with_column_readers(s->s===nothing,src;readers=4,diagnostics=d)
                @test d["fallback"]=="replaced_readers" && d["extra_opens"]==0
            finally
                I.SOURCE_FORMATS["nanoaod"]=saved
            end
            for wrapper in (EventWindowSource(src,1:1,Dict()), LazyEventSource("nanoaod",path))
                d=Dict{String,Any}()
                @test with_column_readers(s->s===nothing,wrapper;readers=4,diagnostics=d)
                @test d["extra_opens"]==0 && d["fallback"]=="unsupported_source"
            end
            f=src.file
            args=map(fieldnames(typeof(f))) do field
                field===:fobj ? TestNonMmapStream() : getfield(f,field)
            end
            other=NanoAODSource(path,UnROOT.ROOTFile(args...),src.tree,src.runs_tree,src.gen_sumw)
            d=Dict{String,Any}()
            @test with_column_readers(s->s===nothing,other;readers=4,diagnostics=d)
            @test d["fallback"]=="non_mmap_source" && d["extra_opens"]==0
            @test nevents(src)==n # Borrower never closes its original.
        finally
            close_source(src)
        end
    end
    # Rename replacement with identical ROOT bytes still has another mapped inode.
    mktempdir() do dir
        path=joinpath(dir,"source.root"); cp(ENV["CASCADE_PARALLEL_MC"],path)
        src=NanoAODSource(path)
        try
            expected=I.column_source_identity(src)
            mv(path,path*".old"); cp(path*".old",path)
            @test_throws ErrorException I.column_source_identity(src;expected)
            @test_throws ErrorException I.open_column_reader(src,expected)
            # Rebind only the current path metadata while retaining the old
            # mapping: the clone must still reject its different mapped inode.
            rebound=I.column_source_identity(src)
            @test rebound.mapping==expected.mapping && rebound.path!=expected.path
            @test_throws ErrorException I.open_column_reader(src,rebound)
        finally
            close_source(src)
        end
    end
end
end
end
