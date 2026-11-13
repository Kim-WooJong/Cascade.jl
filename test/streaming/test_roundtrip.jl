module TestStreamRoundtrip
using Test, Cascade, TOML
using Cascade.IO, Cascade.Config, Cascade.Pipeline, Cascade.Histograms
using ..StreamingFixtures
@testset "automatic window-independent rollover original denominator and offline fresh batch" begin
mktempdir() do dir
    p=setup_stream(dir;zero_file=true)
    raw=TOML.parsefile(p); pop!(raw["reduced_skim"],"mode"); rewrite(p,raw)
    original=joinpath(dir,"original"); run_pipeline(RunOptions(p;workdir=original,steps=STEPS_STREAM))
    bundle=joinpath(dir,"bundle"); m=reduce_analysis(RunOptions(p);output_dir=bundle)
    @test m["schema"]==2; @test length(m["groups"])==2
    gs=groups(bundle); a,b=gs
    @test entries(a)==[1,2,3]; @test entries(b)==Int[]
    @test [r["nevents"] for r in a["shards"]]==[2,1]
    @test [r["nevents"] for r in b["shards"]]==[0]
    @test [g["normalization"]["value"] for g in gs]==[20.,5.]
    @test a["original_cutflows"]["nominal"]["sumw"]==[8.,2.]
    @test a["metrics"]["max_window_events"]==2
    @test a["metrics"]["max_shard_events"]==2
    @test all(!haskey(r,"normalization") for g in gs for r in g["shards"])
    s=ReducedShardSource(joinpath(bundle,a["shards"][1]["path"]))
    @test_throws ErrorException gen_weight_sum(s)
    @test read_columns(s,["event"])["event"]==UInt64[2^53+1,2^53+2]
    close_source(s)
    raw["reduced_skim"]["streaming"]["window_events"]=1; rewrite(p,raw)
    other=joinpath(dir,"other"); reduce_analysis(RunOptions(p);output_dir=other)
    @test entries(first(groups(other)))==[1,2,3]
    @test [r["nevents"] for r in first(groups(other))["shards"]]==[2,1]
    @test first(groups(other))["original_cutflows"]==a["original_cutflows"]
    rm(joinpath(dir,"input");recursive=true) # Disposable synthetic inputs only.
    analysis=joinpath(bundle,"analysis.toml"); work=joinpath(dir,"work")
    run_pipeline(RunOptions(analysis;workdir=work,steps=STEPS_STREAM))
    info=json(joinpath(work,"merge/samples.json")).samples.signal
    @test info.gen_weight_sum==25.; @test info.norm==8.
    @test info.nfiles==2; @test info.physical_nfiles==3
    @test length(info.original_sources)==2
    @test info.cutflow.n==[3,2]
    for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
        @test assert_stores(joinpath(original,rel),joinpath(work,rel))
    end
    for stage in (:select,:correct,:histogram,:merge,:systematics,:fit,:plot)
        @test haskey(run_pipeline(RunOptions(analysis;workdir=work,steps=[stage])),stage)
    end
    batch=joinpath(dir,"batch"); plan=batch_plan(RunOptions(analysis;workdir=batch,max_files=1))
    task=first(plan["tasks"]); group=first(plan["skims"]["signal"]["groups"])
    cfg=load_analysis(analysis); scope=Dict("entry"=>task["entry"],"group"=>group)
    ctx=StepContext(cfg,work,:select,cfg.samples,RunOptions(analysis;workdir=work),scope)
    @test_throws ErrorException run_step(:merge,ctx)
    @test length(plan["tasks"])==2; @test length(plan["skims"]["signal"]["groups"])==1
    @test batch_run(batch;workers=2)["complete"]
    result=batch_merge(batch)
    @test json(joinpath(result,"merge/samples.json")).samples.signal.gen_weight_sum==20.
    one=joinpath(dir,"one"); run_pipeline(RunOptions(analysis;max_files=1,workdir=one,steps=STEPS_STREAM))
    for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
        @test assert_stores(joinpath(one,rel),joinpath(result,rel))
    end
end
end
end
