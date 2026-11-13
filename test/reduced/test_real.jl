module TestReducedReal
using Test, Cascade, TOML, JSON3
using Cascade.IO, Cascade.Config, Cascade.Pipeline, Cascade.Histograms
if get(ENV,"CASCADE_REDUCED_REAL","0")=="1"
@testset "bounded actual data MC standalone RNTuple and fresh batch parity" begin
    area=ENV["CASCADE_REDUCED_AREA"]; ispath(area) && error("real validation area must be unused"); mkpath(area)
    project=normpath(joinpath(@__DIR__,"../.."))
    base=load_analysis(joinpath(project,"analyses/ttbar_emu/analysis.toml");profile="theory_example")
    raw=deepcopy(base.raw)
    raw["reduced_skim"]=Dict("mode"=>"legacy_eager")
    raw["samples"]=[s for s in raw["samples"] if s["name"] in ("TTto2L2Nu","MuonEG")]
    raw["data_quality"]["golden_json"]=base.data_quality.golden_json
    raw["fit"]=Dict("poi"=>"mu_ttbar","signal"=>["ttbar"],"channels"=>[Dict("region"=>"emu_ge1j","variable"=>"njet")],"asimov"=>true)
    for h in raw["histograms"]
        h["name"]=="njet" || continue
        delete!(h,"range"); pop!(h,"linspace",nothing); h["edges"]=[0.,100.]
    end
    p=joinpath(area,"analysis.toml"); open(io->TOML.print(io,raw),p,"w")
    original=joinpath(area,"original"); steps=[:skim,:select,:correct,:histogram,:merge,:systematics,:fit]
    run_pipeline(RunOptions(p;max_files=1,workdir=original,steps))
    bundle=joinpath(area,"bundle"); manifest=reduce_analysis(RunOptions(p;max_files=1);output_dir=bundle)
    @test length(manifest["files"])==2
    retained=Dict{String,Int}(); original_counts=Dict{String,Int}(); comparisons=0
    for record in manifest["files"]
        reduced=open_source("reduced_rntuple",joinpath(bundle,record["path"]))
        meta=reduced.meta; name=record["sample"]
        sample=sample_by_name(load_analysis(p),name)
        source=open_source(sample.format,meta["source_signature"]["path"];options=get(sample.raw,"source",Dict()))
        try
            @test nevents(source)==meta["original_nevents"]
            @test gen_weight_sum(source)==gen_weight_sum(reduced)
            entries=read_columns(reduced,["cascade_source_entry"])["cascade_source_entry"]
            @test issorted(entries)
            names=setdiff(column_names(reduced),["cascade_source_entry"])
            a=read_columns(source,names); b=read_columns(reduced,names)
            for branch in names
                x=a[branch]; y=b[branch]
                if x isa Jagged
                    @test eltype(x.content)==eltype(y.content)
                    @test length(y.offsets)==length(entries)+1
                    for (row,e) in enumerate(entries)
                        @test reinterpret(UInt8,collect(x[e]))==reinterpret(UInt8,collect(y[row]))
                        comparisons+=1
                    end
                else
                    @test eltype(x)==eltype(y)
                    @test reinterpret(UInt8,x[entries])==reinterpret(UInt8,y)
                    comparisons+=length(entries)
                end
            end
            retained[name]=nevents(reduced); original_counts[name]=nevents(source)
        finally
            close_source(source); close_source(reduced)
        end
    end
    rp=joinpath(bundle,"analysis.toml"); reduced=joinpath(area,"reduced")
    run_pipeline(RunOptions(rp;workdir=reduced,steps))
    bins=0
    for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
        a=read_store(joinpath(original,rel)); b=read_store(joinpath(reduced,rel))
        @test Set(keys(a))==Set(keys(b))
        for k in keys(a), field in (:edges,:sumw,:sumw2)
            @test reinterpret(UInt64,getfield(a[k],field))==reinterpret(UInt64,getfield(b[k],field))
            field==:sumw && (bins+=length(a[k].sumw))
        end
    end
    for name in keys(retained)
        a=JSON3.read(read(joinpath(original,"merge/samples.json"),String)).samples[Symbol(name)]
        b=JSON3.read(read(joinpath(reduced,"merge/samples.json"),String)).samples[Symbol(name)]
        @test a.gen_weight_sum==b.gen_weight_sum; @test a.norm==b.norm; @test a.regions==b.regions
        @test b.original_sources[1].original_cutflows.nominal==a.cutflow
    end
    a=JSON3.read(read(joinpath(original,"fit/result.json"),String)); b=JSON3.read(read(joinpath(reduced,"fit/result.json"),String))
    for key in ("poi_value","poi_error","nll","parameters","workspace")
        @test a[key]==b[key]
    end
    work=joinpath(area,"batch"); batch_plan(RunOptions(rp;workdir=work))
    @test batch_run(work;workers=2)["complete"]
    result=batch_merge(work;steps=[:merge,:systematics,:fit])
    for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
        a=read_store(joinpath(reduced,rel)); b=read_store(joinpath(result,rel))
        @test Set(keys(a))==Set(keys(b))
        for k in keys(a), field in (:edges,:sumw,:sumw2)
            @test reinterpret(UInt64,getfield(a[k],field))==reinterpret(UInt64,getfield(b[k],field))
        end
    end
    a=JSON3.read(read(joinpath(result,"fit/result.json"),String))
    serial_fit=JSON3.read(read(joinpath(reduced,"fit/result.json"),String))
    @test a.poi_value==serial_fit.poi_value; @test a.nll==serial_fit.nll
    summary=Dict("files"=>2,"original_events"=>original_counts,"retained_events"=>retained,"raw_branch_event_comparisons"=>comparisons,
        "histogram_bins_compared"=>bins,"scope"=>"bounded data+MC; configured lumi retained; actual exposure unknown; Asimov technical fit")
    write(joinpath(area,"summary.json"),JSON3.write(summary)); println(JSON3.write(summary))
end
end
end
