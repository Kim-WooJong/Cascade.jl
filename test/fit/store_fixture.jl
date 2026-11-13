# Synthetic histogram store and [fit] section shared by the store-fit tests.
import Cascade
using Cascade.Histograms: HistogramStore, HistKey, BinnedHist
using Cascade.Config: SampleConfig

const FIX_EDGES = [0.0, 1.0, 2.0, 3.0]
const FIX_SIG1 = [20.0, 40.0, 60.0]
const FIX_SIG2 = [10.0, 10.0, 20.0]
const FIX_BKG = [100.0, 50.0, 20.0]

fixture_samples() = [SampleConfig(n, k, String[], "cols", k === :mc ? 1.0 : NaN, 1.0, "", g, Dict{String,Any}())
                     for (n, k, g) in (("sig1", :mc, "signal"), ("sig2", :mc, "signal"), ("bkg", :mc, "bkg"),
                                       ("data", :data, "data"))]

"Store with region SR / variable x: two signal samples (group signal), one background, data = mu*S + B."
function fixture_store(; mu = 1.3, data = nothing)
    st = HistogramStore()
    add!(s, v, w, w2) = (st.hists[HistKey("SR", s, v, "x")] = BinnedHist(copy(FIX_EDGES), Float64.(w), Float64.(w2)))
    add!("sig1", "nominal", FIX_SIG1, 0.04 .* FIX_SIG1)
    add!("sig1", "jesUp", FIX_SIG1 .* [1.05, 1.0, 0.95], 0.04 .* FIX_SIG1)
    add!("sig1", "jesDown", FIX_SIG1 .* [0.96, 1.0, 1.04], 0.04 .* FIX_SIG1)
    add!("sig2", "nominal", FIX_SIG2, 0.09 .* FIX_SIG2)                     # no jes: contributes its nominal
    add!("bkg", "nominal", FIX_BKG, 0.01 .* FIX_BKG)
    add!("bkg", "shapeUp", FIX_BKG .* [0.9, 1.0, 1.1], 0.01 .* FIX_BKG)    # one-sided: mirrored
    add!("bkg", "flatUp", FIX_BKG, 0.01 .* FIX_BKG)                       # identical to nominal: dropped
    d = data === nothing ? mu .* (FIX_SIG1 .+ FIX_SIG2) .+ FIX_BKG : data
    add!("data", "nominal", d, d)
    st.hists[HistKey("CR", "bkg", "nominal", "x")] = BinnedHist(copy(FIX_EDGES), [1.0, 1, 1], [1.0, 1, 1])
    return st
end

fixture_section(; kw...) = merge(Dict{String,Any}(
    "poi" => "mu_sig", "signal" => ["signal"], "channels" => [Dict("region" => "SR", "variable" => "x")],
    "normsys" => [Dict("name" => "lumi", "size" => 0.02, "samples" => ["all"]),
                  Dict("name" => "bkg_norm", "hi" => 1.1, "lo" => 0.9, "samples" => ["bkg"], "placeholder" => true)]),
    Dict{String,Any}(String(k) => v for (k, v) in kw))

"Plain Dict/Vector copy of parsed JSON (as the pipeline reads fit/result.json)."
plainjson(x::JSON3.Object) = Dict{String,Any}(String(k) => plainjson(v) for (k, v) in pairs(x))
plainjson(x::JSON3.Array) = Any[plainjson(v) for v in x]
plainjson(x) = x
