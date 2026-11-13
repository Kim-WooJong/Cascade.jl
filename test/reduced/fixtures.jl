module ReducedFixtures
using Cascade, TOML, JSON3
using Cascade.IO, Cascade.Config, Cascade.Pipeline
export setup, rewrite, json, STEPS_REDUCED, compare_stores
const STEPS_REDUCED = [:skim, :select, :correct, :histogram, :merge, :systematics]
json(p) = JSON3.read(read(p, String))
function rewrite(path, raw)
    open(io -> TOML.print(io, raw), path, "w")
    return path
end
function setup(dir; zero_file = false, theory = true, data = false)
    input = joinpath(dir, "input"); mkpath(input)
    cols = Dict{String,Any}("Jet_pt" => Jagged(Float32[29,31,40,10], [0,1,2,3,4]),
        "nJet" => UInt32[1,1,1,1], "genWeight" => Float32[2,-1,3,4],
        "event" => UInt64[2^53+1,2^53+2,typemax(UInt64),9], "run" => UInt32[1,1,1,1],
        "luminosityBlock" => UInt32[1,2,2,1], "PSWeight" => Jagged([Float32[1.2,.8] for _ in 1:4]),
        "LHEPdfWeight" => Jagged([Float64[1.,1.01,.99] for _ in 1:4]),
        "LHEScaleWeight" => Jagged([Float32[1.,.9,1.1] for _ in 1:4]))
    write_column_file(joinpath(input, "a.cols"), cols; meta = Dict("gen_weight_sum" => 20.0))
    if zero_file
        z = Dict{String,Any}(k => c isa Jagged ? Jagged([collect(c[4])]) : c[4:4] for (k,c) in cols)
        write_column_file(joinpath(input, "b.cols"), z; meta = Dict("gen_weight_sum" => 5.0))
    end
    raw = Dict{String,Any}("analysis" => Dict("name" => "reduced_fixture", "lumi_pb" => 100.),
        "reduced_skim" => Dict("mode" => "legacy_eager"),
        "samples" => [Dict("name" => "signal", "kind" => data ? "data" : "mc", "format" => "cols", "files" => [joinpath(input,"*.cols")], "xsec_pb" => 2.)],
        "objects" => [Dict("name" => "jets", "collection" => "Jet", "cut" => "pt > 30")],
        "cuts" => [Dict("name" => "jet", "expr" => "length(jets) > 0")],
        "regions" => [Dict("name" => "signal", "after" => "jet")],
        "weights" => Dict("mc" => ["genWeight"], "data" => ["1.0"]),
        "histograms" => [Dict("name" => "pt", "edges" => [0.,100.], "values" => ["jets.pt[1]"])],
        "shape_variations" => [Dict("name" => "Scale", "kind" => "scale", "collection" => "Jet", "fields" => ["pt"], "up" => "1.1", "down" => "0.9")])
    if theory && !data
        raw["theory_weights"] = [Dict("name" => "ISR", "family" => "ps", "branch" => "PSWeight", "samples" => ["signal"],
            "indices" => [1,2], "expected_length" => 2, "normalization" => "relative", "reduction" => "pair", "convention" => "synthetic fixture")]
    end
    return rewrite(joinpath(dir,"analysis.toml"), raw)
end
function compare_stores(a,b)
    using_h = Cascade.Histograms
    x=using_h.read_store(a); y=using_h.read_store(b)
    Set(keys(x)) == Set(keys(y)) || return false
    return all(reinterpret(UInt64,getfield(x[k],f)) == reinterpret(UInt64,getfield(y[k],f)) for k in keys(x) for f in (:edges,:sumw,:sumw2))
end
end
