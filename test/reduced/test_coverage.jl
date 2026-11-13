module TestReducedCoverage
using Test, Cascade, TOML
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..ReducedFixtures
@testset "prefilter certified LS coverage survives data reduction" begin
    mktempdir() do dir
        p=setup(dir;data=true,theory=false); raw=TOML.parsefile(p)
        golden=joinpath(dir,"golden.json"); write(golden,"{\"1\":[[1,2]]}")
        lumi=joinpath(dir,"lumi.json"); write(lumi,"{\"1\":{\"1\":3.0,\"2\":7.0}}")
        file=joinpath(dir,"input/a.cols"); cols,meta,_=read_column_file(file)
        cols["R"]=pop!(cols,"run"); cols["L"]=pop!(cols,"luminosityBlock"); write_column_file(file,cols;meta)
        raw["data_quality"]=Dict("golden_json"=>golden,"run_branch"=>"R","lumi_branch"=>"L")
        raw["luminosity"]=Dict("mode"=>"certified","file"=>lumi,"unit"=>"pb^-1","assume_complete_lumisections"=>true)
        rewrite(p,raw)
        bundle=joinpath(dir,"bundle"); reduce_analysis(RunOptions(p);output_dir=bundle)
        src=open_source("reduced_rntuple",joinpath(bundle,"signal/00000001.root"))
        @test read_columns(src,["L"])["L"]==UInt32[2,2]
        @test src.meta["certified_observed_lumisections"]==[[1,1],[1,2]]; close_source(src)
        out=joinpath(dir,"run")
        run_pipeline(RunOptions(joinpath(bundle,"analysis.toml");workdir=out,steps=STEPS_REDUCED))
        info=json(joinpath(out,"merge/samples.json"))
        @test info.lumi_pb==10.
        @test info.luminosity.certified_observed_lumisection_count==2
        @test info.luminosity.exposure_status=="assumed_complete_observed_lumisections"
    end
end
end
