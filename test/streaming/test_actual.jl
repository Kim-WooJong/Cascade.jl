module TestStreamingActual
using Test, Cascade, TOML, JSON3
using Cascade.IO, Cascade.Config, Cascade.Pipeline, Cascade.Histograms
if get(ENV,"CASCADE_STREAM_REAL","0")=="1"
@testset "bounded actual data MC original-window typed closure and deterministic grouped batch" begin
    area=ENV["CASCADE_STREAM_AREA"]; ispath(area) && error("actual area exists"); mkpath(area)
    project=normpath(joinpath(@__DIR__,"../.."))
    base=load_analysis(joinpath(project,"analyses/ttbar_emu/analysis.toml");profile="theory_example")
    raw=deepcopy(base.raw)
    raw["reduced_skim"]=Dict("mode"=>"streaming","streaming"=>Dict("window_events"=>5000,"target_shard_events"=>300,"target_shard_payload_bytes"=>32000000))
    raw["samples"]=[s for s in raw["samples"] if s["name"] in ("TTto2L2Nu","MuonEG")]
    raw["data_quality"]["golden_json"]=base.data_quality.golden_json
    raw["fit"]=Dict("poi"=>"mu_ttbar","signal"=>["ttbar"],"channels"=>[Dict("region"=>"emu_ge1j","variable"=>"njet")],"asimov"=>true)
    for h in raw["histograms"]
        h["name"]=="njet" || continue
        delete!(h,"range"); pop!(h,"linspace",nothing); h["edges"]=[0.,100.]
    end
    p=joinpath(area,"analysis.toml"); open(io->TOML.print(io,raw),p,"w")
    steps=[:skim,:select,:correct,:histogram,:merge,:systematics,:fit]
    original=joinpath(area,"original"); run_pipeline(RunOptions(p;max_files=1,workdir=original,steps))
    bundle=joinpath(area,"bundle"); m=reduce_analysis(RunOptions(p;max_files=1);output_dir=bundle)
    @test length(m["groups"])==2
    counts=Dict{String,Int}(); retained=Dict{String,Int}(); comparisons=0; physical=0
    for record in m["groups"]
        group=read_reduced_group(joinpath(bundle,record["path"])); name=record["sample"]
        sample=sample_by_name(load_analysis(p),name)
        source=open_source(sample.format,group["source_signature"]["path"];options=get(sample.raw,"source",Dict()))
        try
            @test nevents(source)==group["original_nevents"]
            @test gen_weight_sum(source)==(sample.kind==:mc ? group["normalization"]["value"] : 0.)
            counts[name]=nevents(source); retained[name]=group["retained_nevents"]
            names=[d["name"] for d in group["columns"] if d["name"]!="cascade_source_entry"]
            # This bounded original-reader reference is independent of the export window reader.
            reference=read_columns(source,names)
            original_skim=JSON3.read(read(joinpath(original,"skim",name*".json"),String))
            chunk=String(original_skim.files[1].chunk)
            selected=Cascade.Pipeline.chunk_path(original,:select,name,chunk,".cols")
            original_meta=Cascade.Pipeline.read_meta(selected)
            expected_entries=Int64.(Cascade.Selection.read_event_table(selected)["entry"])
            for label in get(original_meta,"shape",String[])
                varied=Cascade.Selection.read_event_table(Cascade.Pipeline.shape_chunk_path(original,:select,name,chunk,label,".cols"))
                append!(expected_entries,Int64.(varied["entry"]))
                @test group["original_cutflows"][label]==original_meta["shape_cutflows"][label]
            end
            sort!(unique!(expected_entries)); actual_entries=Int64[]
            for shard in group["shards"]
                physical+=1; r=ReducedShardSource(joinpath(bundle,shard["path"]))
                try
                    es=read_columns(r,["cascade_source_entry"])["cascade_source_entry"]; values=read_columns(r,names)
                    @test issorted(es); append!(actual_entries,es)
                    for name in names
                        x=reference[name]; y=values[name]
                        if x isa Jagged
                            @test eltype(x.content)==eltype(y.content)
                            for (row,e) in enumerate(es)
                                @test reinterpret(UInt8,collect(x[e]))==reinterpret(UInt8,collect(y[row])); comparisons+=1
                            end
                        else
                            @test eltype(x)==eltype(y)
                            @test reinterpret(UInt8,x[es])==reinterpret(UInt8,y); comparisons+=length(es)
                        end
                    end
                finally; close_source(r); end
            end
            @test actual_entries==expected_entries
        finally; close_source(source); end
    end
    rp=joinpath(bundle,"analysis.toml"); reduced=joinpath(area,"reduced")
    run_pipeline(RunOptions(rp;workdir=reduced,steps))
    maxabs=0.; maxscaled=0.; bins=0
    # Predefined bound: 64 eps * log2(N) * contribution-scale upper bound.
    n=sum(values(counts)); multiplier=64eps(Float64)*max(1,ceil(log2(n)))
    for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
        a=read_store(joinpath(original,rel)); b=read_store(joinpath(reduced,rel)); @test Set(keys(a))==Set(keys(b))
        for k in keys(a)
            @test a[k].edges==b[k].edges
            for field in (:sumw,:sumw2)
                x=getfield(a[k],field); y=getfield(b[k],field)
                for i in eachindex(x)
                    scale=field==:sumw ? max(1.,sqrt(n*max(a[k].sumw2[i],b[k].sumw2[i]))) : max(1.,abs(x[i]),abs(y[i]))
                    difference=abs(x[i]-y[i]); maxabs=max(maxabs,difference); maxscaled=max(maxscaled,difference/scale)
                    @test difference<=multiplier*scale
                end
            end
            bins+=length(a[k].sumw)
        end
    end
    for name in keys(counts)
        a=JSON3.read(read(joinpath(original,"merge/samples.json"),String)).samples[Symbol(name)]
        b=JSON3.read(read(joinpath(reduced,"merge/samples.json"),String)).samples[Symbol(name)]
        @test a.gen_weight_sum==b.gen_weight_sum; @test a.norm==b.norm
        @test a.cutflow==b.original_sources[1].original_cutflows.nominal
        for region in keys(a.regions), key in ("n","sumw","yield")
            haskey(a.regions[region],key) || continue
            @test isapprox(a.regions[region][key],b.regions[region][key];rtol=1e-11,atol=1e-9)
        end
    end
    fit_a=JSON3.read(read(joinpath(original,"fit/result.json"),String)); fit_b=JSON3.read(read(joinpath(reduced,"fit/result.json"),String))
    for key in ("poi_value","poi_error","nll")
        @test isapprox(fit_a[key],fit_b[key];rtol=1e-9,atol=1e-8)
    end
    batch=joinpath(area,"batch"); batch_plan(RunOptions(rp;workdir=batch)); @test batch_run(batch;workers=2)["complete"]
    result=batch_merge(batch;steps=[:merge,:systematics,:fit])
    for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
        a=read_store(joinpath(reduced,rel)); b=read_store(joinpath(result,rel)); @test Set(keys(a))==Set(keys(b))
        @test all(reinterpret(UInt64,getfield(a[k],f))==reinterpret(UInt64,getfield(b[k],f)) for k in keys(a) for f in (:edges,:sumw,:sumw2))
    end
    @test JSON3.read(read(joinpath(result,"fit/result.json"),String)).poi_value==fit_b.poi_value
    summary=Dict("original_events"=>counts,"retained_events"=>retained,"physical_shards"=>physical,
        "raw_branch_event_comparisons"=>comparisons,"histogram_bins_compared"=>bins,
        "max_hist_absolute_difference"=>maxabs,"max_contribution_scaled_difference"=>maxscaled,"predefined_scaled_bound"=>multiplier,
        "fit_differences"=>Dict(k=>abs(fit_a[k]-fit_b[k]) for k in ("poi_value","poi_error","nll")),
        "scope"=>"bounded actual data MC; exposure unknown; configured1210pb^-1; technical Asimov fit; no repartition bit-equality promise")
    write(joinpath(area,"summary.json"),JSON3.write(summary)); println(JSON3.write(summary))
end
end
end
