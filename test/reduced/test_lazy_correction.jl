module TestReducedLazyCorrection
using Test, Cascade, TOML, JSON3
using Cascade.IO, Cascade.Pipeline
using ..ReducedFixtures
@testset "lazy correction-only scalar dependency is retained" begin
    mktempdir() do dir
        p=setup(dir;theory=false); file=joinpath(dir,"input/a.cols")
        cols,meta,_=read_column_file(file); cols["pileupOnly"]=Float32[1.,2.,3.,4.]
        write_column_file(file,cols;meta)
        payload=Dict("schema_version"=>2,"corrections"=>[Dict("name"=>"identity","description"=>"synthetic","version"=>1,
            "inputs"=>[Dict("name"=>"x","type"=>"real")],"output"=>Dict("name"=>"w","type"=>"real"),
            "data"=>Dict("nodetype"=>"formula","expression"=>"x","parser"=>"TFormula","variables"=>["x"]))])
        cp=joinpath(dir,"correction.json"); write(cp,JSON3.write(payload))
        raw=TOML.parsefile(p)
        raw["hooks"]=Dict("correct"=>"Cascade.Systematics.apply_corrections")
        raw["corrections"]=Dict("sets"=>Dict("test"=>cp),"event_weight"=>[Dict("name"=>"pu","set"=>"test","correction"=>"identity","inputs"=>Dict("x"=>"pileupOnly"))])
        rewrite(p,raw)
        original=joinpath(dir,"original"); run_pipeline(RunOptions(p;workdir=original,steps=STEPS_REDUCED))
        bundle=joinpath(dir,"bundle"); reduce_analysis(RunOptions(p);output_dir=bundle)
        s=open_source("reduced_rntuple",joinpath(bundle,"signal/00000001.root"))
        @test read_columns(s,["pileupOnly"])["pileupOnly"]==Float32[1,2,3]; close_source(s)
        reduced=joinpath(dir,"reduced"); run_pipeline(RunOptions(joinpath(bundle,"analysis.toml");workdir=reduced,steps=STEPS_REDUCED))
        @test compare_stores(joinpath(original,"merge/histograms.json"),joinpath(reduced,"merge/histograms.json"))
        raw["reduced_skim"]=Dict("drop"=>["pileupOnly"]); rewrite(p,raw)
        @test_throws Exception reduce_analysis(RunOptions(p);output_dir=joinpath(dir,"bad"))
        @test !ispath(joinpath(dir,"bad"))
    end
end
end
