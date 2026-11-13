module TestStreamingFit
using Test, Cascade, TOML, JSON3
using Cascade.IO, Cascade.Pipeline, Cascade.Config
using ..StreamingFixtures
const setup=setup_stream
const STEPS_REDUCED=STEPS_STREAM
const compare_stores=assert_stores
@testset "reduced fit inputs closure and current overlap provenance" begin
    mktempdir() do dir
        p=setup(dir;theory=false); raw=TOML.parsefile(p)
        cols,_,_=read_column_file(joinpath(dir,"input/a.cols"))
        write_column_file(joinpath(dir,"observed.cols"),cols)
        push!(raw["samples"],Dict("name"=>"observed","kind"=>"data","format"=>"cols","files"=>[joinpath(dir,"observed.cols")]))
        raw["fit"]=Dict("poi"=>"mu","signal"=>["signal"],"profile_interval"=>false,"impacts"=>false,"channels"=>[Dict("name"=>"c","region"=>"signal","variable"=>"pt")])
        rewrite(p,raw)
        steps=vcat(STEPS_REDUCED,[:fit])
        original=joinpath(dir,"original"); run_pipeline(RunOptions(p;workdir=original,steps))
        bundle=joinpath(dir,"bundle"); reduce_analysis(RunOptions(p);output_dir=bundle)
        rp=joinpath(bundle,"analysis.toml"); reduced=joinpath(dir,"reduced")
        run_pipeline(RunOptions(rp;workdir=reduced,steps))
        a=json(joinpath(original,"fit/result.json")); b=json(joinpath(reduced,"fit/result.json"))
        for key in ("status","converged","nll","poi_value","poi_error","parameters","covariance","channels","workspace")
            @test a[key]==b[key]
        end
        @test compare_stores(joinpath(original,"systematics/templates.json"),joinpath(reduced,"systematics/templates.json"))
        # A second identical current channel must be rejected, not accepted using
        # copied/stale original overlap evidence. Zero weights do not hide overlap.
        rr=TOML.parsefile(rp)
        push!(rr["fit"]["channels"],Dict("name"=>"duplicate","region"=>"signal","variable"=>"pt"))
        rewrite(rp,rr)
        @test_throws Exception run_pipeline(RunOptions(rp;workdir=joinpath(dir,"overlap"),steps))
    end
end
end
