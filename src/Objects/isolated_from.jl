"""
    isolated_from(eta, phi, other_eta, other_phi, others, dr) -> Bool

True if `deltaR(eta, phi, other_eta[k], other_phi[k]) > dr` for every flat index
`k` in `others` (overlap removal). The candidate is the first argument pair,
which fixes the floating-point evaluation order.
"""
@inline function isolated_from(eta, phi, other_eta::AbstractVector, other_phi::AbstractVector,
                               others::AbstractVector{Int}, dr::Real)
    for k in others
        deltaR(eta, phi, other_eta[k], other_phi[k]) > dr || return false
    end
    return true
end
