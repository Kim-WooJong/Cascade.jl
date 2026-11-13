"""
Synthetic NanoAOD-like events and an in-memory event source for selection
tests (shared by the selection and pipeline tests).
"""
module SyntheticEvents
using Random
using Cascade.IO
import Cascade.IO: nevents, column_names, read_columns, gen_weight_sum, source_signature

export MemorySource, synthetic_events, HLT_PATHS

struct MemorySource <: AbstractEventSource
    cols::Dict{String,Any}
    n::Int
end
nevents(s::MemorySource) = s.n
column_names(s::MemorySource) = collect(keys(s.cols))
read_columns(s::MemorySource, names::AbstractVector{<:AbstractString}; needed = nothing) =
    Dict{String,Any}(String(n) => s.cols[n] for n in names)
gen_weight_sum(s::MemorySource) = haskey(s.cols, "genWeight") ? sum(Float64, s.cols["genWeight"]) : 0.0
source_signature(s::MemorySource) = Dict{String,Any}("memory" => s.n)

const HLT_PATHS = ["HLT_Mu8_TrkIsoVVL_Ele23_CaloIdL_TrackIdL_IsoVL_DZ",
                   "HLT_Mu23_TrkIsoVVL_Ele12_CaloIdL_TrackIdL_IsoVL", "HLT_IsoMu24", "HLT_Ele32_WPTight_Gsf"]

pick(rng, special, lo, hi) = rand(rng) < 0.15 ? Float32(rand(rng, special)) : Float32(lo + (hi - lo) * rand(rng))

"""
    synthetic_events(rng, n; runs) -> Dict{String,Any}

Random events with many values on selection boundaries (pt 35/10/30, |eta| 2.4,
ECAL gap, iso 0.15, jetId bits, dR ~ 0.4), lepton-rich so most cuts are exercised.
"""
function synthetic_events(rng::AbstractRNG, n::Integer; runs = [356309, 356400, 356615, 356000, 357000])
    c = Dict{String,Any}()
    ne = [rand(rng, 0:3) for _ in 1:n]; nm = [rand(rng, 0:3) for _ in 1:n]; nj = [rand(rng, 0:6) for _ in 1:n]
    lists(f, ns) = [Float32[f() for _ in 1:k] for k in ns]
    c["Electron_pt"] = Jagged(lists(() -> pick(rng, [35.0, 10.0, 35.00001], 5, 120), ne))
    c["Electron_eta"] = Jagged(lists(() -> pick(rng, [2.4, -2.4, 1.444, 1.5, -1.566], -2.6, 2.6), ne))
    c["Electron_phi"] = Jagged(lists(() -> pick(rng, [0.0, π, -π], -π, π), ne))
    c["Electron_deltaEtaSC"] = Jagged(lists(() -> pick(rng, [0.0, 0.05], -0.1, 0.1), ne))
    c["Electron_charge"] = Jagged([Int32[rand(rng, (-1, 1)) for _ in 1:k] for k in ne])
    c["Electron_cutBased"] = Jagged([UInt8[rand(rng, 0:4) for _ in 1:k] for k in ne])
    c["Muon_pt"] = Jagged(lists(() -> pick(rng, [35.0, 10.0], 5, 120), nm))
    c["Muon_eta"] = Jagged(lists(() -> pick(rng, [2.4, -2.4], -2.6, 2.6), nm))
    c["Muon_phi"] = Jagged(lists(() -> pick(rng, [0.0, 3.0], -π, π), nm))
    c["Muon_charge"] = Jagged([Int32[rand(rng, (-1, 1)) for _ in 1:k] for k in nm])
    c["Muon_tightId"] = Jagged([Bool[rand(rng) < 0.8 for _ in 1:k] for k in nm])
    c["Muon_pfRelIso04_all"] = Jagged(lists(() -> pick(rng, [0.15], 0, 0.3), nm))
    c["Jet_pt"] = Jagged(lists(() -> pick(rng, [30.0, 30.00001, 60.0], 15, 300), nj))
    c["Jet_eta"] = Jagged(lists(() -> pick(rng, [2.4, 0.0], -3, 3), nj))
    c["Jet_phi"] = Jagged(lists(() -> pick(rng, [0.0, 0.3, 0.4], -π, π), nj))
    c["Jet_jetId"] = Jagged([UInt8[rand(rng, (0, 2, 4, 6)) for _ in 1:k] for k in nj])
    for p in HLT_PATHS
        c[p] = [rand(rng) < 0.5 for _ in 1:n]
    end
    c["genWeight"] = Float32[rand(rng, (-1, 1)) * (100 + 50 * rand(rng)) for _ in 1:n]
    c["run"] = UInt32[rand(rng, runs) for _ in 1:n]
    c["luminosityBlock"] = UInt32[rand(rng, 1:400) for _ in 1:n]
    return c
end
end
