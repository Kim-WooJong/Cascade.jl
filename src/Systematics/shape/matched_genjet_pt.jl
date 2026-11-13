"""
    matched_genjet_pt(idx, gen_pt, gen_eta, gen_phi, gen_offsets, i, eta, phi, pt, jer, max_dr, nsigma) -> Float64

Generator-jet pt for the hybrid JER method, or `-1.0` if the jet is not
matched. `idx` is the 0-based NanoAOD `genJetIdx` of the jet in event `i`
(GenJet flat content `gen_*` with offsets `gen_offsets`); the match requires
`deltaR(jet, genjet) < max_dr` (in the column precision) and
`|pt - genpt| < nsigma * jer * pt`.
"""
@inline function matched_genjet_pt(idx::Integer, gen_pt, gen_eta, gen_phi, gen_offsets::Vector{Int}, i::Int,
                                   eta, phi, pt::Float64, jer::Float64, max_dr::Float64, nsigma::Float64)
    idx < 0 && return -1.0
    k = gen_offsets[i] + Int(idx) + 1
    k <= gen_offsets[i+1] || return -1.0
    deltaR(eta, phi, gen_eta[k], gen_phi[k]) < max_dr || return -1.0
    g = Float64(gen_pt[k])
    abs(pt - g) < nsigma * jer * pt || return -1.0
    return g
end
