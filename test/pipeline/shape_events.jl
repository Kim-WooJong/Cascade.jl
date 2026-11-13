"""
Jet-energy inputs for shape-systematics tests: adds to `synthetic_events` output
the columns used by JES/JER/MET variations (Jet_mass, Jet_genJetIdx, GenJet_*,
Rho_fixedGridRhoFastjetAll, event, PuppiMET_*).
"""
module ShapeEvents
using Random
using Cascade.IO

export add_shape_columns!

function add_shape_columns!(rng::AbstractRNG, c::Dict{String,Any}; first_event::Integer = 1)
    jpt = c["Jet_pt"]; jeta = c["Jet_eta"]; jphi = c["Jet_phi"]
    n = length(jpt)
    mass = Vector{Float32}[]; gidx = Vector{Int16}[]
    gpt = Vector{Float32}[]; geta = Vector{Float32}[]; gphi = Vector{Float32}[]
    for i in 1:n
        m = Float32[]; gi = Int16[]; gp = Float32[]; ge = Float32[]; gf = Float32[]
        for (p, e, f) in zip(jpt[i], jeta[i], jphi[i])
            push!(m, Float32(p * (0.05 + 0.15 * rand(rng))))
            r = rand(rng)
            if r < 0.6          # close gen jet (mostly matched; some fail the 3 sigma cut)
                push!(gp, Float32(p * (1 + 0.12 * randn(rng)))); push!(ge, e + Float32(0.05 * randn(rng)))
                push!(gf, f + Float32(0.05 * randn(rng))); push!(gi, Int16(length(gp) - 1))
            elseif r < 0.7      # gen jet too far in deltaR
                push!(gp, Float32(p)); push!(ge, e + 0.5f0); push!(gf, f); push!(gi, Int16(length(gp) - 1))
            else
                push!(gi, Int16(-1))
            end
        end
        for _ in 1:rand(rng, 0:2)   # unmatched gen jets
            push!(gp, Float32(10 + 100 * rand(rng))); push!(ge, Float32(-3 + 6 * rand(rng)))
            push!(gf, Float32(-π + 2π * rand(rng)))
        end
        push!(mass, m); push!(gidx, gi); push!(gpt, gp); push!(geta, ge); push!(gphi, gf)
    end
    c["Jet_mass"] = Jagged(mass)
    c["Jet_genJetIdx"] = Jagged(gidx)
    c["GenJet_pt"] = Jagged(gpt); c["GenJet_eta"] = Jagged(geta); c["GenJet_phi"] = Jagged(gphi)
    c["Rho_fixedGridRhoFastjetAll"] = Float32[5 + 30 * rand(rng) for _ in 1:n]
    c["event"] = UInt64[first_event + i - 1 for i in 1:n]
    c["PuppiMET_pt"] = Float32[rand(rng) < 0.1 ? 20.0f0 : Float32(5 + 120 * rand(rng)) for _ in 1:n]
    c["PuppiMET_phi"] = Float32[Float32(-π + 2π * rand(rng)) for _ in 1:n]
    return c
end
end
