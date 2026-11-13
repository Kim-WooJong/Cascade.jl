module TestSampleMetadata
using Test,TOML,JSON3
using Cascade.IO,Cascade.Pipeline,Cascade.Histograms
@testset "Declared sample metadata survives merge without changing weights" begin
    mktempdir() do dir
        input=joinpath(dir,"sample.cols")
        write_column_file(input,Dict("genWeight"=>[2.,-1.],"x"=>[0.5,1.5]);meta=Dict("gen_weight_sum"=>3.))
        raw=Dict{String,Any}("analysis"=>Dict("name"=>"metadata","lumi_pb"=>6.),
            "samples"=>[Dict{String,Any}("name"=>"signal","kind"=>"mc","format"=>"cols","files"=>[input],"xsec_pb"=>2.,"branching_ratio"=>0.5,
                "metadata"=>Dict("dataset"=>"/Primary/Processed/NANOAODSIM","provenance"=>"test production"))],
            "weights"=>Dict("mc"=>["genWeight"]),"histograms"=>[Dict("name"=>"x","edges"=>[0.,1.,2.],"values"=>["x"])])
        config=joinpath(dir,"analysis.toml");open(io->TOML.print(io,raw),config,"w")
        workdir=joinpath(dir,"out");steps=[:skim,:select,:correct,:histogram,:merge]
        run_pipeline(RunOptions(config;workdir,steps))
        old=read_store(joinpath(workdir,"merge","histograms.json"))
        info=JSON3.read(read(joinpath(workdir,"merge","samples.json"),String))["samples"]["signal"]
        @test info["metadata"]["dataset"]==raw["samples"][1]["metadata"]["dataset"]
        @test info["norm"]==2.
        @test old["signal","signal",NOMINAL,"x"].sumw==[4.,-2.]
        raw["samples"][1]["metadata"]["provenance"]="documented update"
        open(io->TOML.print(io,raw),config,"w")
        summary=run_pipeline(RunOptions(config;workdir,steps))
        @test summary[:skim]["run"]==0
        @test summary[:select]["run"]==0
        @test summary[:correct]["run"]==0
        @test summary[:histogram]["run"]==0
        @test summary[:merge]["run"]==1
        new=read_store(joinpath(workdir,"merge","histograms.json"))
        @test new["signal","signal",NOMINAL,"x"]==old["signal","signal",NOMINAL,"x"]
        info=JSON3.read(read(joinpath(workdir,"merge","samples.json"),String))["samples"]["signal"]
        @test info["metadata"]["provenance"]=="documented update"
    end
end
end
