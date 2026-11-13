module TestStreamingShapeClosure
using Test, Random, TOML, Cascade
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..StreamingFixtures
using ..StreamingFixtures.ReducedFixtures: STEPS_REDUCED, compare_stores
include(joinpath(@__DIR__,"../selection/synthetic_events.jl"))
include(joinpath(@__DIR__,"../pipeline/shape_events.jl"))
using .SyntheticEvents, .ShapeEvents
@testset "nominal JER JES MET cleaning sorting and earliest-region union" begin
    mktempdir() do dir
        src=normpath(joinpath(@__DIR__,"../../analyses/shape_test"))
        for f in readdir(src); cp(joinpath(src,f),joinpath(dir,f)); end
        p=joinpath(dir,"analysis.toml"); raw=TOML.parsefile(p)
        raw["reduced_skim"]=Dict("mode"=>"streaming","streaming"=>Dict("window_events"=>7,"target_shard_events"=>3,"target_shard_payload_bytes"=>20000))
        raw["samples"]=raw["samples"][1:1]
        for shape in raw["shape_variations"]
            shape["kind"]=="jer" && (shape["nominal"]=true)
        end
        rewrite(p,raw)
        rng=MersenneTwister(921); cols=add_shape_columns!(rng,synthetic_events(rng,120))
        write_column_file(joinpath(dir,"inputs/sigA/a.cols"),cols;meta=Dict("gen_weight_sum"=>200.))
        original=joinpath(dir,"original"); run_pipeline(RunOptions(p;workdir=original,steps=STEPS_REDUCED))
        bundle=joinpath(dir,"bundle"); reduce_analysis(RunOptions(p);output_dir=bundle)
        g=only(groups(bundle))
        mapping=entries(g)
        s=ReducedShardSource(joinpath(bundle,g["shards"][1]["path"]))
        localmapping=read_columns(s,["cascade_source_entry"])["cascade_source_entry"]
        @test issorted(mapping); @test length(mapping)<120
        skim=json(joinpath(original,"skim/sigA.json")); chunk=String(skim.files[1].chunk)
        nominalpath=Cascade.Pipeline.chunk_path(original,:select,"sigA",chunk,".cols")
        selectionmeta=Cascade.Pipeline.read_meta(nominalpath)
        @test g["original_cutflows"]["nominal"]==selectionmeta["cutflow"]
        unionentries=Int.(Cascade.Selection.read_event_table(nominalpath)["entry"])
        for label in selectionmeta["shape"]
            table=Cascade.Selection.read_event_table(Cascade.Pipeline.shape_chunk_path(original,:select,"sigA",chunk,label,".cols"))
            append!(unionentries,Int.(table["entry"]))
            @test g["original_cutflows"][label]==selectionmeta["shape_cutflows"][label]
        end
        @test mapping==sort!(unique!(unionentries))
        needed=read_columns(s,["Jet_pt","GenJet_pt","Rho_fixedGridRhoFastjetAll","event"])
        for (row,e) in enumerate(localmapping)
            @test isequal(needed["Jet_pt"][row],cols["Jet_pt"][e])
            @test isequal(needed["GenJet_pt"][row],cols["GenJet_pt"][e])
            @test needed["event"][row]==cols["event"][e]
        end
        close_source(s)
        reduced=joinpath(dir,"reduced"); run_pipeline(RunOptions(joinpath(bundle,"analysis.toml");workdir=reduced,steps=STEPS_REDUCED))
        for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
            @test assert_stores(joinpath(original,rel),joinpath(reduced,rel);atol=1e-9)

        end
    end
end
end
