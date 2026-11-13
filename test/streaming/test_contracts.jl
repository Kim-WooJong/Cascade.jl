module TestStreamingContracts
using Test, Cascade, TOML
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..StreamingFixtures
@testset "streaming signed true-zero missing normalization and scientific subset guards" begin
    for value in (nothing,-20.,0.)
        mktempdir() do dir
            p=setup_stream(dir;theory=false,window=1,shard=1)
            file=joinpath(dir,"input/a.cols"); cols,meta,_=read_column_file(file)
            value===nothing ? delete!(meta,"gen_weight_sum") : (meta["gen_weight_sum"]=value)
            write_column_file(file,cols;meta); bundle=joinpath(dir,"bundle")
            if value===nothing
                @test_throws Exception reduce_analysis(RunOptions(p);output_dir=bundle)
                @test !ispath(bundle)
            else
                reduce_analysis(RunOptions(p);output_dir=bundle)
                g=only(groups(bundle)); @test g["normalization"]["value"]==value
                @test g["normalization"]["status"]=="available"
                if value==0.
                    @test_throws Exception run_pipeline(RunOptions(joinpath(bundle,"analysis.toml");workdir=joinpath(dir,"work"),steps=STEPS_STREAM))
                end
            end
        end
    end
    mktempdir() do dir
        p=setup_stream(dir;theory=false); raw=TOML.parsefile(p)
        second=deepcopy(raw["samples"][1]); second["name"]="other"; push!(raw["samples"],second)
        for (i,modifier) in enumerate((:theory,:shape,:fit))
            r=deepcopy(raw)
            if modifier==:theory
                r["theory_weights"]=[Dict("name"=>"other-theory","family"=>"ps","branch"=>"PSWeight","samples"=>["other"],"indices"=>[1,2],"expected_length"=>2,"normalization"=>"relative","reduction"=>"pair","convention"=>"synthetic")]
            elseif modifier==:shape
                r["shape_variations"][1]["samples"]=["other"]
            else
                r["fit"]=Dict("signal"=>["signal"],"channels"=>[Dict("region"=>"signal","variable"=>"pt")],"asimov"=>true)
            end
            rewrite(p,r); out=joinpath(dir,"subset"*string(i))
            @test_throws Exception reduce_analysis(RunOptions(p;samples=["signal"]);output_dir=out)
            @test !ispath(out)
        end
        # Explicit cross-sample original sharing remains allowed for the full config.
        rewrite(p,raw); out=joinpath(dir,"shared"); reduce_analysis(RunOptions(p);output_dir=out)
        @test length(groups(out))==2
        @test population_identity(groups(out)[1]["population"])==population_identity(groups(out)[2]["population"])
    end
end
end
