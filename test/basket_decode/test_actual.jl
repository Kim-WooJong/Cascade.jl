samebits(a,b) = typeof(a)==typeof(b) && (a isa Jagged ? samebits(a.content,b.content)&&samebits(a.offsets,b.offsets) : axes(a)==axes(b)&&collect(reinterpret(UInt8,a))==collect(reinterpret(UInt8,b)))
@testset "native detached baskets and nominal selection" begin
    root=normpath(joinpath(@__DIR__,"../.."))
    cfg=load_analysis(joinpath(root,"analyses/ttbar_emu/analysis.toml");profile="baseline")
    dq=cfg.data_quality; lm=load_lumimask(dq.golden_json;run_min=dq.run_min,run_max=dq.run_max)
    for (name,path,n) in (("TTto2L2Nu",ENV["CASCADE_PARALLEL_MC"],32853),("MuonEG",ENV["CASCADE_PARALLEL_DATA"],104057))
        src=NanoAODSource(path); s=sample_by_name(cfg,name); sel=compile_selection(cfg,s.kind)
        try
            lmask=is_data(s) ? lm : nothing
            baseline,needed=read_selection_columns(sel,src;stream=s.stream,lumimask=lmask)
            ref,cf=select_events(sel,baseline,n;sample=name)
            @test nevents(src)==n
            @test_throws ArgumentError run_selection(sel,src;decode_threads=4,column_readers=true)
            @test_throws ArgumentError run_selection(sel,src;decode_threads=true)
            for width in (1,4,8,16,16,16)
                d=Dict{String,Any}()
                with_decode_pipeline(src;threads=width,diagnostics=d) do scope
                    raw,mask=read_selection_columns(sel,src;stream=s.stream,lumimask=lmask,decode_scope=scope)
                    @test isequal(mask,needed)
                    @test Set(keys(raw))==Set(keys(baseline))
                    for k in keys(raw); @test samebits(raw[k],baseline[k]); end
                    table,flow=select_events(sel,raw,n;sample=name)
                    @test table.order==ref.order
                    for k in table.order; @test samebits(table[k],ref[k]); end
                    @test isequal(cutflow_dict(flow),cutflow_dict(cf))
                end
                @test d["extra_opens"]==d["extra_closes"]==0
                @test d["workers_joined"]
                if width>1
                    @test d["phases"]==2
                    @test isempty(d["phase_fallbacks"])
                    @test d["basket_requests"]>0
                    @test d["queue_jobs_highwater"]<=32
                    @test d["queue_bytes_highwater"]<=64*1024^2
                    @test d["effective_actors"]<=min(width,Threads.nthreads())
                    @test d["max_active_decoders"]>1 # default compute pool, not a serialized main pool
                else
                    @test d["phases"]==0 && d["decoder_workers"]==0
                    @test !haskey(d,"dependency_contract")
                end
                println(JSON3.write(Dict("sample"=>name,"width"=>width,"execution"=>d)))
            end
            names=["event","Muon_pt","Muon_eta","Electron_pt","Electron_eta","Muon_pt"]
            for mask in (trues(n),falses(n),[isodd(i) for i in 1:n])
                d=Dict{String,Any}()
                with_decode_pipeline(src;threads=16,diagnostics=d) do scope
                    for needed in (mask,.!mask)
                        expected=read_columns(src,names;needed)
                        got=read_decoded_columns(scope,names;needed)
                        @test collect(keys(got))==collect(keys(expected))
                        for k in keys(got); @test samebits(got[k],expected[k]); end
                    end
                    @test isempty(read_decoded_columns(scope,String[]))
                    @test_throws ArgumentError read_decoded_columns(scope,names;needed=[true])
                    @test_throws Exception read_decoded_columns(scope,["event","missing_column"])
                end
                @test d["workers_joined"]
            end
            @test_throws ErrorException with_decode_pipeline(scope->read_decoded_columns(scope,["Muon_pt"]),src;threads=4,queue_bytes=1)
            # Detached jobs cannot contain ROOTFile/LazyBranch or source metadata.
            phase,reason=I.prepare_nanoaod_decode(src,["event","Muon_pt"],nothing,Dict{String,Any}("counter_reads"=>0);max_bytes=64*1024^2)
            @test isempty(reason)
            @test all(src.file[string(src.tree,"/",p.name)] isa UnROOT.TBranch for p in phase.plans)
            @test all(I.decode_interpretation_supported(src.file[string(src.tree,"/",p.name)],p.T,p.J) for p in phase.plans)
            @test !I.decode_interpretation_supported(src.file[string(src.tree,"/event")],Vector{Float32},UnROOT.Offsetjagg)
            desc=first(phase.descriptors); p=phase.plans[desc.branch]
            job=(key=desc.key,bytes=UnROOT.read_seek_nb(src.file.fobj,desc.pos,desc.compressed),blocks=desc.blocks,T=p.T,J=p.J,entries=desc.hi-desc.lo+1)
            @test keys(job)==(:key,:bytes,:blocks,:T,:J,:entries)
            expected=I.decode_prepared_basket(job)
            # The independent checksum rejects payload corruption, despite unchecked
            # return codes in the upstream wrapper.
            if !isempty(job.blocks)
                corrupt=copy(job.bytes); corrupt[end] ⊻= 0x01
                @test_throws ErrorException I.decode_prepared_basket(merge(job,(bytes=corrupt,)))
                bad=copy(job.bytes); bad[4:6].=0xff
                @test_throws ErrorException I.validate_decode_blocks(bad,job.key.fObjlen)
            end
            saved=I.SOURCE_FORMATS["nanoaod"]
            try
                I.SOURCE_FORMATS["nanoaod"]=p->NanoAODSource(p)
                d=Dict{String,Any}()
                @test with_decode_pipeline(x->x===nothing,src;threads=16,diagnostics=d)
                @test d["fallback"]=="replaced_readers"
            finally
                I.SOURCE_FORMATS["nanoaod"]=saved
            end
            for wrapper in (EventWindowSource(src,1:1,Dict()),LazyEventSource("nanoaod",path))
                d=Dict{String,Any}()
                @test with_decode_pipeline(x->x===nothing,wrapper;threads=16,diagnostics=d)
                @test d["fallback"]=="unsupported_source"
            end
            @test nevents(src)==n
        finally
            close_source(src)
        end
    end
end

@testset "mapped pathname rejects replacement before initial binding" begin
    mktempdir() do dir
        path=joinpath(dir,"borrowed.root");cp(ENV["CASCADE_PARALLEL_MC"],path)
        src=NanoAODSource(path)
        try
            binding=I.decode_source_identity(src)
            @test binding !== nothing
            @test binding.mapped_path==realpath(path)
            mv(path,path*".old");cp(path*".old",path)
            @test_throws ErrorException I.decode_source_identity(src)
            @test_throws ErrorException I.decode_source_identity(src;expected=binding)
        finally
            close_source(src)
        end
    end
end
