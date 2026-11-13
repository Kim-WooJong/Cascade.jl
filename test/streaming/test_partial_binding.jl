module TestStreamingPartialBinding
using Test, Cascade, TOML, JSON3
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..StreamingFixtures
const setup=(dir;kwargs...)->setup_stream(dir;window=1,shard=1,kwargs...)
const STEPS_REDUCED=STEPS_STREAM
const compare_stores=assert_stores
binding_error(f) = try f(); false catch e; occursin("reduced skim input binding changed",sprint(showerror,e)) && occursin("rerun skim",sprint(showerror,e)) end
pinning_error(f) = try f(); false catch e; occursin("reduced analysis rejects custom hooks or replaced built-in readers",sprint(showerror,e)) end
@testset "persisted reduced skim is bound before every downstream partial reuse" begin
    mktempdir() do dir
        bundles=String[]
        for (name,factor) in (("a",1f0),("b",2f0))
            input=joinpath(dir,name); mkpath(input)
            p=setup(input;zero_file=true,theory=false); raw=TOML.parsefile(p)
            raw["plot"]=Dict("prefit"=>false,"postfit"=>false,"cutflow"=>false,"impacts"=>false,"tables"=>true)
            raw["theory_weights"]=[Dict("name"=>"PDF","branch"=>"LHEPdfWeight","family"=>"pdf","normalization"=>"central",
                "central_index"=>1,"indices"=>[2,3],"expected_length"=>3,"samples"=>["signal"],"reduction"=>"replica_std",
                "cl_scale"=>1.,"pdf_template_model"=>"rank_one","convention"=>"synthetic binding fixture")]
            rewrite(p,raw)
            f=joinpath(input,"input/a.cols"); cols,meta,_=read_column_file(f)
            cols["genWeight"] .*= factor; meta["gen_weight_sum"]=factor==1f0 ? 20.0 : 25.0
            write_column_file(f,cols;meta)
            bundle=joinpath(dir,"bundle-"*name); reduce_analysis(RunOptions(p);output_dir=bundle); push!(bundles,bundle)
        end
        q=rewrite(joinpath(dir,"active.toml"),TOML.parsefile(joinpath(bundles[1],"analysis.toml")))
        work=joinpath(dir,"work"); steps=vcat(STEPS_REDUCED,[:fit,:plot])
        run_pipeline(RunOptions(q;max_files=1,workdir=work,steps))
        for step in (:select,:correct,:histogram,:merge,:systematics,:fit,:plot)
            @test run_pipeline(RunOptions(q;max_files=1,workdir=work,steps=[step])) isa Dict
        end
        @test binding_error(() -> run_pipeline(RunOptions(q;workdir=work,steps=[:merge]))) # max_files changed.
        before=read(joinpath(work,"merge/histograms.json"))
        rewrite(q,TOML.parsefile(joinpath(bundles[2],"analysis.toml")))
        rm(bundles[1];recursive=true) # Disposable derivative A is now unavailable too.
        for step in (:select,:correct,:histogram,:merge,:systematics,:fit,:plot)
            @test binding_error(() -> run_pipeline(RunOptions(q;max_files=1,workdir=work,steps=[step])))
            @test read(joinpath(work,"merge/histograms.json"))==before
            cfg=load_analysis(q); ctx=StepContext(cfg,work,step,cfg.samples,RunOptions(q;max_files=1,workdir=work,steps=[step]))
            @test binding_error(() -> run_step(step,ctx))
        end
        @test Cascade.Pipeline.main(["run",q,"--from","select","--max-files","1","--workdir",work])==1
        @test Cascade.Pipeline.main(["run",q,"--only","merge","--max-files","1","--workdir",work])==1
        run_pipeline(RunOptions(q;max_files=1,workdir=work,steps)) # Full run refreshes skim first.
        @test read(joinpath(work,"merge/histograms.json"))!=before
        direct=joinpath(dir,"direct-b"); run_pipeline(RunOptions(q;max_files=1,workdir=direct,steps))
        for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
            @test compare_stores(joinpath(work,rel),joinpath(direct,rel))
        end
        manifestpath=joinpath(bundles[2],"manifest.json"); saved=read(manifestpath)
        manifest=Cascade.Pipeline._jsdict(JSON3.read(String(copy(saved))))
        delete!(manifest,"id"); manifest["note"]="valid metadata changed at unchanged paths"
        manifest["id"]=Cascade.Pipeline.batch_hash(manifest); write(manifestpath,JSON3.write(manifest))
        @test read_reduced_metadata(joinpath(bundles[2],"signal/00000001.source.json"))["retained_nevents"]==3
        @test binding_error(() -> run_pipeline(RunOptions(q;max_files=1,workdir=work,steps=[:merge])))
        write(manifestpath,saved)
        @test run_pipeline(RunOptions(q;max_files=1,workdir=work,steps=[:merge])) isa Dict
        raw=TOML.parsefile(q)
        unused=deepcopy(raw["samples"][1]); unused["name"]="unused"; unused["files"]=[joinpath(dir,"missing-unselected.root")]
        push!(raw["samples"],unused); rewrite(q,raw)
        @test run_pipeline(RunOptions(q;samples=["signal"],max_files=1,workdir=work,steps=[:merge])) isa Dict
        raw["histograms"][1]["edges"]=[0.,35.,100.]; rewrite(q,raw)
        @test run_pipeline(RunOptions(q;samples=["signal"],max_files=1,workdir=work,steps=[:histogram,:merge,:systematics])) isa Dict
        cfg=load_analysis(q); selected=[sample_by_name(cfg,"signal")]
        ctx=StepContext(cfg,work,:correct,selected,RunOptions(q;samples=["signal"],max_files=1,workdir=work,steps=[:correct]))
        register_hook!(:correct,identity;id="unverified")
        try
            @test pinning_error(() -> run_step(:correct,ctx))
        finally
            empty!(Cascade.Pipeline.HOOKS)
        end
        register_source_format!("reduced_rntuple",p -> ReducedRNTupleSource(p))
        try
            @test pinning_error(() -> run_step(:correct,ctx))
        finally
            register_source_format!("reduced_rntuple",ReducedRNTupleSource)
        end
        raw["theory_weights"][1]["cl_scale"]=2.; rewrite(q,raw)
        @test run_pipeline(RunOptions(q;samples=["signal"],max_files=1,workdir=work,steps=[:systematics])) isa Dict
        converted=deepcopy(raw); converted["samples"][1]["format"]="cols"
        converted["samples"][1]["files"]=[joinpath(dir,"b/input/a.cols")]; rewrite(q,converted)
        @test binding_error(() -> run_pipeline(RunOptions(q;samples=["signal"],max_files=1,workdir=work,steps=[:merge])))
        rewrite(q,raw)
        batchwork=joinpath(dir,"selected-batch")
        manifest=batch_plan(RunOptions(q;samples=["signal"],max_files=1,workdir=batchwork))
        @test length(manifest["tasks"])==3
        @test !batch_status(batchwork)["complete"]
    end
end
end
