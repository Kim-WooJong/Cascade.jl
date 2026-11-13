module TestReducedGeneratedSubset
using Test, Cascade, TOML
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..ReducedFixtures
@testset "every published subset has valid generated config without silent pruning" begin
    mktempdir() do dir
        p=setup(dir;theory=false); base=TOML.parsefile(p)
        other=deepcopy(base["samples"][1]); other["name"]="other"; push!(base["samples"],other)
        rewrite(p,base)
        valid=joinpath(dir,"valid-subset")
        reduce_analysis(RunOptions(p;samples=["signal"]);output_dir=valid)
        cfg=load_analysis(joinpath(valid,"analysis.toml"))
        @test [s.name for s in cfg.samples]==["signal"]
        @test Cascade.Pipeline.validate_reduced_inputs(cfg)===nothing
        @test Cascade.Pipeline.validate_reduced_export(joinpath(valid,"analysis.toml"),valid,valid)===nothing
        @test !ispath(joinpath(valid,"analysis_output")) # Validation never writes through final workdir.
        generated=joinpath(valid,"analysis.toml"); bytes=read(generated)
        open(generated,"a") do io; write(io,"\n# accidental generated-config byte drift\n"); end
        @test_throws Exception Cascade.Pipeline.validate_reduced_export(generated,valid,valid)
        write(generated,bytes)
        cases=Dict{String,Any}[]
        theory=deepcopy(base)
        theory["theory_weights"]=[Dict("name"=>"ISR","family"=>"ps","branch"=>"PSWeight","samples"=>["other"],
            "indices"=>[1,2],"expected_length"=>2,"normalization"=>"relative","reduction"=>"pair","convention"=>"synthetic subset test")]
        push!(cases,theory)
        shape=deepcopy(base); shape["shape_variations"][1]["samples"]=["other"]; push!(cases,shape)
        for declaration in (Dict("signal"=>["other"]),Dict("signal"=>["signal"],"data"=>["other"]),
                    Dict("signal"=>["combined"],"groups"=>Dict("combined"=>["signal","other"])))
            raw=deepcopy(base)
            fit=Dict{String,Any}(declaration)
            fit["channels"]=[Dict("region"=>"signal","variable"=>"pt")]
            raw["fit"]=fit; push!(cases,raw)
        end
        for (i,raw) in enumerate(cases)
            rewrite(p,raw); load_analysis(p)
            dest=joinpath(dir,"rejected-$i")
            @test_throws Exception reduce_analysis(RunOptions(p;samples=["signal"]);output_dir=dest)
            @test !ispath(dest)
        end
        # A full-sample declaration accepted by Config but invalid for Fit must
        # still fail fresh generated validation, never publish an unusable TOML.
        invalid=deepcopy(base)
        invalid["fit"]=Dict("signal"=>["missing_group"],"channels"=>[Dict("region"=>"signal","variable"=>"pt")])
        rewrite(p,invalid); load_analysis(p)
        dest=joinpath(dir,"invalid-fit-full")
        @test_throws Exception reduce_analysis(RunOptions(p);output_dir=dest)
        @test !ispath(dest)
        @test !ispath(joinpath(dest,"analysis_output"))
    end
end
end
