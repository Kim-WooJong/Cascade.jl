using Test, TOML, JSON3, Cascade
using Cascade.Config, Cascade.IO, Cascade.Histograms, Cascade.Pipeline
const BP = Cascade.Pipeline
function batch_fixture(dir; invalid = false)
    for i in 1:2
        w = i == 1 ? [4., -1.] : [2., -1.]
        v = i == 1 ? [[2., 1.], [2., 1.]] : [[0., 1.], [0., 1.]]
        invalid && i == 2 && (v = [[NaN, 1.], [0., 1.]])
        write_column_file(joinpath(dir, "f$i.cols"), Dict("x" => [.25, 1.25],
            "genWeight" => w, "V" => Jagged(v)); meta = Dict("gen_weight_sum" => i == 1 ? -3. : -1.))
    end
    raw = Dict{String,Any}("analysis" => Dict("name" => "batch", "lumi_pb" => 4.),
        "batch" => Dict("workers" => 2, "threads" => 1),
        "samples" => [Dict("name" => "mc", "kind" => "mc", "format" => "cols", "xsec_pb" => 1., "files" => [joinpath(dir, "f*.cols")]),
            Dict("name" => "data", "kind" => "data", "format" => "cols", "files" => [joinpath(dir, "f1.cols")])],
        "weights" => Dict("mc" => ["genWeight"]),
        "histograms" => [Dict("name" => "x", "values" => ["x"], "edges" => [0., 1., 2.])],
        "hooks" => Dict("correct" => "Cascade.Systematics.apply_corrections"),
        "corrections" => Dict("flat" => [Dict("name" => "sf", "nominal" => -1., "up" => -1.1, "down" => -.9)]),
        "theory_weights" => [Dict("name" => "scale", "branch" => "V", "family" => "scale", "normalization" => "relative",
            "reduction" => "envelope", "indices" => [1, 2], "expected_length" => 2, "samples" => ["mc"], "convention" => "synthetic cancellation")],
        "fit" => Dict("channels" => [Dict("region" => "signal", "variable" => "x")], "signal" => ["mc"],
            "asimov" => true, "impacts" => false, "profile_interval" => false, "staterror" => false))
    # Keep fit bins positive despite signed Runs and signed event weights.
    raw["histograms"][1]["edges"] = [0., 2.]
    p = joinpath(dir, "analysis.toml"); open(io -> TOML.print(io, raw), p, "w")
    return p
end
function batch_compare(a, b)
    for rel in ("merge/histograms_raw.json", "merge/histograms.json", "systematics/templates.json")
        x = read_store(joinpath(a, rel)); y = read_store(joinpath(b, rel))
        @test Set(keys(x)) == Set(keys(y))
        @test x.meta == y.meta
        for k in keys(x), field in (:edges, :sumw, :sumw2)
            @test reinterpret(UInt64, getfield(x[k], field)) == reinterpret(UInt64, getfield(y[k], field))
        end
    end
    for rel in ("merge/samples.json", "fit/workspace.json")
        @test JSON3.read(read(joinpath(a, rel), String)) == JSON3.read(read(joinpath(b, rel), String))
    end
    @test read(joinpath(a, "merge/yields.tsv")) == read(joinpath(b, "merge/yields.tsv"))
end
