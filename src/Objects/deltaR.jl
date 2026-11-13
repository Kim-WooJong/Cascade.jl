"""
    deltaR(eta1, phi1, eta2, phi2)

Distance in the eta-phi plane, with the phi difference wrapped to [-pi, pi):
`hypot(eta1 - eta2, mod(phi1 - phi2 + pi, 2pi) - pi)`. Arithmetic is done in the
argument precision (Float32 for NanoAOD), as in the reference analysis.
"""
@inline function deltaR(eta1, phi1, eta2, phi2)
    dphi = mod(phi1 - phi2 + π, 2π) - π
    return hypot(eta1 - eta2, dphi)
end
