module StreamingFixtures
using Cascade, TOML, JSON3
using Cascade.IO, Cascade.Config, Cascade.Pipeline, Cascade.Histograms
include(joinpath(@__DIR__, "../reduced/fixtures.jl"))
export setup_stream, rewrite, json, STEPS_STREAM, groups, entries, assert_stores
const rewrite = ReducedFixtures.rewrite
const json = ReducedFixtures.json
const STEPS_STREAM = ReducedFixtures.STEPS_REDUCED
function setup_stream(dir; zero_file = false, theory = true, data = false, window = 2, shard = 2, target = 1000)
    p = ReducedFixtures.setup(dir; zero_file, theory, data)
    raw = TOML.parsefile(p)
    raw["reduced_skim"] = Dict("mode" => "streaming", "streaming" => Dict("window_events" => window,
        "target_shard_events" => shard, "target_shard_payload_bytes" => target))
    return rewrite(p, raw)
end
function groups(bundle)
    m = json(joinpath(bundle, "manifest.json"))
    [read_reduced_group(joinpath(bundle, r.path)) for r in m.groups]
end
function entries(g)
    all = Int64[]
    for r in g["shards"]
        s = ReducedShardSource(joinpath(g["bundle_root"], r["path"]))
        try; append!(all, read_columns(s,["cascade_source_entry"])["cascade_source_entry"])
        finally; close_source(s); end
    end
    return all
end
function assert_stores(a, b; atol = 0.0)
    x = read_store(a); y = read_store(b)
    Set(keys(x)) == Set(keys(y)) || return false
    all(x[k].edges == y[k].edges && all(isapprox.(getfield(x[k],f),getfield(y[k],f);rtol=0.,atol)) for k in keys(x) for f in (:sumw,:sumw2))
end
end
