module TestFitRegionOverlapPipeline
using Test, TOML, JSON3
using Cascade.Config, Cascade.IO, Cascade.Histograms, Cascade.Pipeline

@testset "pipeline disjoint categories and overlap protection" begin
    mktempdir() do dir
        for sample in ("sig", "data")
            write_column_file(joinpath(dir, sample * ".cols"),
                Dict("Jet_pt" => Jagged([[0.5], [1.5], [2.5], [3.5]]), "genWeight" => ones(4));
                meta = Dict{String,Any}("gen_weight_sum" => 4.))
        end
        raw = Dict{String,Any}(
            "analysis" => Dict("name" => "categories", "lumi_pb" => 4.),
            "samples" => [Dict("name" => "sig", "kind" => "mc", "xsec_pb" => 1., "format" => "cols", "files" => [joinpath(dir, "sig.cols")]),
                          Dict("name" => "data", "kind" => "data", "format" => "cols", "files" => [joinpath(dir, "data.cols")])],
            "weights" => Dict("mc" => ["genWeight"]),
            "objects" => [Dict("name" => "jets", "collection" => "Jet", "cut" => "pt > 0")],
            "variables" => Dict("x" => "jets.pt[1]"),
            "cuts" => [Dict("name" => "one_jet", "expr" => "length(jets) == 1"),
                       Dict("name" => "positive", "expr" => "x > 0")],
            "regions" => [Dict("name" => "low", "after" => "positive", "expr" => "x < 2"),
                          Dict("name" => "high", "after" => "positive", "expr" => "x >= 2"),
                          Dict("name" => "inclusive", "after" => "positive")],
            "histograms" => [Dict("name" => "x", "edges" => [0., 5.], "values" => ["x"])],
            "shape_variations" => [Dict("name" => "Scale", "collection" => "Jet", "kind" => "scale",
                                        "fields" => ["pt"], "up" => "2.0", "down" => "0.5")],
            "fit" => Dict("signal" => ["sig"], "channels" => [Dict("name" => "low", "region" => "low", "variable" => "x"),
                                                                  Dict("name" => "high", "region" => "high", "variable" => "x")],
                          "staterror" => false, "histosys" => false, "impacts" => false, "profile_interval" => false))
        path = joinpath(dir, "analysis.toml")
        open(io -> TOML.print(io, raw), path, "w")
        workdir = joinpath(dir, "out")
        steps = [:skim, :select, :correct, :histogram, :merge, :systematics, :fit]
        run_pipeline(RunOptions(path; workdir, steps))
        store = read_store(joinpath(workdir, "merge", "histograms.json"))
        @test integral(store["low", "data", NOMINAL, "x"]) == 2.
        @test integral(store["high", "data", NOMINAL, "x"]) == 2.
        @test integral(store["inclusive", "data", NOMINAL, "x"]) == 4.
        @test haskey(store.meta, "fit_channel_provenance")
        info = JSON3.read(read(joinpath(workdir, "merge", "samples.json"), String))
        @test info["samples"]["data"]["regions"]["low"]["n"] == 2
        @test info["samples"]["data"]["regions"]["high"]["n"] == 2
        @test info["samples"]["sig"]["shape"]["ScaleUp"]["regions"]["low"]["n"] == 1
        @test info["samples"]["sig"]["shape"]["ScaleUp"]["regions"]["high"]["n"] == 3
        @test info["samples"]["sig"]["shape"]["ScaleDown"]["regions"]["low"]["n"] == 4
        @test info["samples"]["sig"]["shape"]["ScaleDown"]["regions"]["high"]["n"] == 0
        @test integral(store["low", "sig", "ScaleUp", "x"]) == 1.
        @test integral(store["low", "sig", "ScaleDown", "x"]) == 4.
        report = JSON3.read(read(joinpath(workdir, "fit", "result.json"), String))
        @test report["status"] == "ok"
        @test report["poi_value"] ≈ 1. atol = 1e-6
        cached = run_pipeline(RunOptions(path; workdir, steps))
        @test all(v["run"] == 0 for v in values(cached))

        # A fit-only change must invalidate the overlap provenance without
        # requiring selection to rerun. The inclusive histogram was legal above.
        raw["fit"]["channels"][2]["region"] = "inclusive"
        open(io -> TOML.print(io, raw), path, "w")
        sm = run_pipeline(RunOptions(path; workdir, steps = steps[1:end-1]))
        @test sm[:select]["run"] == 0
        @test sm[:merge]["run"] == 1
        err = try run_pipeline(RunOptions(path; workdir, steps = [:fit])); nothing catch e; e end
        @test err isa ArgumentError
        @test occursin("overlap in 2 selected data event", sprint(showerror, err))
    end
end
end
