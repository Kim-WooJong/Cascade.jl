module TestStreamIntegrity
using Test, Cascade, TOML, JSON3, SHA
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..StreamingFixtures
@testset "complete logical groups corruption ownership and stale partial mapping" begin
mktempdir() do dir
    p=setup_stream(dir;zero_file=true,shard=1)
    a=joinpath(dir,"A"); reduce_analysis(RunOptions(p);output_dir=a)
    paths=[joinpath(a,r.path) for r in json(joinpath(a,"manifest.json")).groups]
    g=read_reduced_group(paths[1]); @test length(g["shards"])==3
    root=joinpath(a,g["shards"][2]["path"]); side=root*".cascade.json"
    bytes=read(side); write(side,vcat(bytes,UInt8[0x20]))
    @test_throws ErrorException read_reduced_group(paths[1])
    @test_throws ErrorException batch_plan(RunOptions(joinpath(a,"analysis.toml");workdir=joinpath(dir,"bad")))
    @test !ispath(joinpath(dir,"bad")); write(side,bytes)
    renamed=root*".temporarily-missing"; mv(root,renamed)
    @test_throws ErrorException read_reduced_group(paths[1]); mv(renamed,root)
    @test_throws ErrorException validate_source_populations("reduced_rntuple_group",[paths[1],paths[1]])
    copydir=joinpath(dir,"copy"); cp(a,copydir)
    @test_throws ErrorException validate_source_populations("reduced_rntuple_group",[paths[1],joinpath(copydir,relpath(paths[1],a))])
    # Structural conflicts are rejected even with updated consistency checksums.
    manifestpath=joinpath(a,"manifest.json"); originalmanifest=read(manifestpath); descriptorbytes=read(paths[1])
    for mutate in (x->reverse!(x["shards"]), x->(x["shards"][2]["source_begin"]+=1),
        x->(x["shards"][2]["source_begin"]-=1), x->push!(x["shards"],deepcopy(x["shards"][1])),
        x->(x["shards"][2]["retained_begin"]+=1), x->(x["normalization"]["status"]="missing"))
        x=JSON3.read(String(copy(descriptorbytes)),Dict{String,Any}); mutate(x); write(paths[1],JSON3.write(x))
        m=JSON3.read(String(copy(originalmanifest)),Dict{String,Any}); m["groups"][1]["sha256"]=bytes2hex(open(sha256,paths[1])); pop!(m,"id"); m["id"]=Cascade.Pipeline.batch_hash(m); write(manifestpath,JSON3.write(m))
        @test_throws Exception read_reduced_group(paths[1])
    end
    write(paths[1],descriptorbytes); write(manifestpath,originalmanifest)
    analysis=joinpath(a,"analysis.toml"); work=joinpath(dir,"work")
    run_pipeline(RunOptions(analysis;workdir=work,steps=STEPS_STREAM,max_files=1))
    @test_throws ErrorException run_pipeline(RunOptions(analysis;workdir=work,steps=[:merge],max_files=0))
    b=joinpath(dir,"B"); reduce_analysis(RunOptions(p);output_dir=b)
    cfg=TOML.parsefile(analysis); cfg["samples"][1]["files"]=TOML.parsefile(joinpath(b,"analysis.toml"))["samples"][1]["files"]
    switched=joinpath(dir,"switched.toml"); rewrite(switched,cfg)
    for stage in (:select,:correct,:histogram,:merge,:systematics,:fit,:plot)
        @test_throws ErrorException run_pipeline(RunOptions(switched;workdir=work,steps=[stage],max_files=1))
    end
    run_pipeline(RunOptions(switched;workdir=work,steps=STEPS_STREAM,max_files=1))
    @test json(joinpath(work,"merge/samples.json")).samples.signal.gen_weight_sum==20.
end
end
end
