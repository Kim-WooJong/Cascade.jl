module TestStreamScience
using Test, Cascade, TOML, JSON3
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..StreamingFixtures
@testset "streaming original certified LS exposure appears once not retained luminosity" begin
mktempdir() do dir
    p=setup_stream(dir;data=true,theory=false,shard=1,window=1)
    raw=TOML.parsefile(p); delete!(raw,"shape_variations")
    golden=joinpath(dir,"golden.json"); write(golden,"{\"1\":[[1,2]]}")
    lumi=joinpath(dir,"lumi.json"); write(lumi,"{\"1\":{\"1\":3.0,\"2\":7.0}}")
    raw["data_quality"]=Dict("golden_json"=>golden)
    raw["luminosity"]=Dict("mode"=>"certified","file"=>lumi,"unit"=>"pb^-1","assume_complete_lumisections"=>true)
    rewrite(p,raw); out=joinpath(dir,"bundle"); reduce_analysis(RunOptions(p);output_dir=out)
    g=only(groups(out)); @test entries(g)==[2,3]
    @test g["certified_observed_lumisections"]==[[1,1],[1,2]]
    @test g["metrics"]["max_window_events"]==1
    work=joinpath(dir,"work"); run_pipeline(RunOptions(joinpath(out,"analysis.toml");workdir=work,steps=STEPS_STREAM))
    info=json(joinpath(work,"merge/samples.json")); @test info.lumi_pb==10.
    @test length(info.samples.signal.original_sources)==1
    @test info.samples.signal.cutflow.n==[2,2]
    @test g["original_cutflows"]["nominal"]["n"]==[4,2]
end
end
@testset "borrowed lazy scalar and absolute theory reference use local window rows" begin
mktempdir() do dir
    p=setup_stream(dir;window=1,shard=1,theory=false)
    file=joinpath(dir,"input/a.cols"); cols,meta,_=read_column_file(file)
    cols["pileupOnly"]=Float32[1,2,3,4]; cols["referenceOnly"]=Float64[2,4,8,16]
    cols["absoluteVector"]=Jagged([Float64[2x,3x] for x in [2,4,8,16]])
    write_column_file(file,cols;meta)
    payload=Dict("schema_version"=>2,"corrections"=>[Dict("name"=>"identity","description"=>"synthetic","version"=>1,
        "inputs"=>[Dict("name"=>"x","type"=>"real")],"output"=>Dict("name"=>"w","type"=>"real"),
        "data"=>Dict("nodetype"=>"formula","expression"=>"x","parser"=>"TFormula","variables"=>["x"]))])
    cp=joinpath(dir,"correction.json"); write(cp,JSON3.write(payload))
    raw=TOML.parsefile(p); raw["hooks"]=Dict("correct"=>"Cascade.Systematics.apply_corrections")
    raw["corrections"]=Dict("sets"=>Dict("test"=>cp),"event_weight"=>[Dict("name"=>"pu","set"=>"test","correction"=>"identity","inputs"=>Dict("x"=>"pileupOnly"))])
    raw["theory_weights"]=[Dict("name"=>"absolute","family"=>"ps","branch"=>"absoluteVector","reference_branch"=>"referenceOnly","samples"=>["signal"],
        "indices"=>[1,2],"expected_length"=>2,"normalization"=>"absolute","reduction"=>"pair","convention"=>"synthetic")]
    rewrite(p,raw); original=joinpath(dir,"original"); run_pipeline(RunOptions(p;workdir=original,steps=STEPS_STREAM))
    bundle=joinpath(dir,"bundle"); reduce_analysis(RunOptions(p);output_dir=bundle)
    g=only(groups(bundle)); @test entries(g)==[1,2,3]
    @test all(d["name"] in [x["name"] for x in g["columns"]] for d in [Dict("name"=>"pileupOnly"),Dict("name"=>"referenceOnly"),Dict("name"=>"absoluteVector")])
    rm(joinpath(dir,"input");recursive=true)
    work=joinpath(dir,"work"); run_pipeline(RunOptions(joinpath(bundle,"analysis.toml");workdir=work,steps=STEPS_STREAM))
    for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
        @test assert_stores(joinpath(original,rel),joinpath(work,rel))
    end
end
end
end
