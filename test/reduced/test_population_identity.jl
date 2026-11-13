module TestReducedPopulationIdentity
using Test, Cascade, TOML
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..ReducedFixtures
@testset "canonical inode ownership raw hardlinks and offline derivatives" begin
    @test population_identity(Dict("device"=>"7","inode"=>"19","realpath"=>"/a")) == population_identity(Dict("device"=>7,"inode"=>19,"realpath"=>"/b"))
    @test population_identity(Dict("inode"=>"0","realpath"=>"/a/../same")) == population_identity(Dict("realpath"=>"/same"))
    @test_throws Exception population_identity(Dict("inode"=>"0"))
    mktempdir() do dir
        p=setup(dir;theory=false); a=joinpath(dir,"input/a.cols"); b=joinpath(dir,"input/b.cols")
        hardlink(a,b); raw=TOML.parsefile(p); raw["samples"][1]["files"]=[a,b]; rewrite(p,raw)
        @test stat(a).inode==stat(b).inode
        @test_throws Exception run_pipeline(RunOptions(p;workdir=joinpath(dir,"serial-bad"),steps=[:skim]))
        @test !isfile(joinpath(dir,"serial-bad/skim/signal.json"))
        @test_throws Exception reduce_analysis(RunOptions(p);output_dir=joinpath(dir,"export-bad"))
        @test !ispath(joinpath(dir,"export-bad"))
        @test_throws Exception batch_plan(RunOptions(p;workdir=joinpath(dir,"batch-bad")))
        @test !ispath(joinpath(dir,"batch-bad"))
        @test Cascade.Audit.audit_inputs(load_analysis(p))["status"]=="fail"
        bundles=String[]
        for (name,file) in (("a",a),("b",b))
            r=deepcopy(raw); r["samples"][1]["files"]=[file]
            q=rewrite(joinpath(dir,name*".toml"),r); dest=joinpath(dir,"bundle-"*name)
            reduce_analysis(RunOptions(q);output_dir=dest); push!(bundles,dest)
        end
        c=joinpath(dir,"input/c.cols"); cp(a,c)
        @test validate_source_populations("cols",[a,c])===nothing
        r=deepcopy(raw); r["samples"][1]["files"]=[a,c]
        q=rewrite(joinpath(dir,"distinct.toml"),r); distinct=joinpath(dir,"distinct")
        reduce_analysis(RunOptions(q);output_dir=distinct)
        firstmeta=read_reduced_metadata(joinpath(bundles[1],"signal/00000001.root"))
        secondmeta=read_reduced_metadata(joinpath(bundles[2],"signal/00000001.root"))
        @test firstmeta["population"]["realpath"]!=secondmeta["population"]["realpath"]
        @test population_identity(firstmeta["population"])==population_identity(secondmeta["population"])
        rm(joinpath(dir,"input");recursive=true) # Disposable fixture originals only.
        combined=TOML.parsefile(joinpath(bundles[1],"analysis.toml"))
        combined["samples"][1]["files"]=[joinpath(x,"signal/00000001.root") for x in bundles]
        q=rewrite(joinpath(dir,"combined.toml"),combined)
        @test_throws Exception run_pipeline(RunOptions(q;workdir=joinpath(dir,"offline-bad"),steps=[:skim]))
        @test_throws Exception validate_source_populations("reduced_rntuple",combined["samples"][1]["files"])
        work=joinpath(dir,"distinct-batch")
        batch_plan(RunOptions(joinpath(distinct,"analysis.toml");workdir=work))
        @test batch_run(work;workers=2)["complete"]
        result=batch_merge(work)
        @test json(joinpath(result,"merge/samples.json")).samples.signal.gen_weight_sum==40.
    end
end
end
