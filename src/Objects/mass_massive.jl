"""
    mass_massive(pt1, eta1, phi1, m1, pt2, eta2, phi2, m2) -> Float64

Invariant mass of two objects specified by transverse momentum, pseudorapidity,
azimuth and rest mass. All arithmetic is Float64. Nonnegative momenta and
masses are required. A rapidity-based, rationalized expression avoids the
large energy-minus-momentum cancellation of a Cartesian four-vector sum.
`mass_massless` is intentionally a separate, unchanged precision contract.
"""
@inline function mass_massive(pt1, eta1, phi1, m1, pt2, eta2, phi2, m2)
    p1, p2 = Float64(pt1), Float64(pt2)
    a, b = Float64(m1), Float64(m2)
    (p1 >= 0 && p2 >= 0 && a >= 0 && b >= 0) ||
        throw(DomainError((p1, a, p2, b), "transverse momenta and masses must be nonnegative"))
    t1, t2 = hypot(p1, a), hypot(p2, b)
    y1 = t1 == 0 ? 0.0 : asinh((p1 / t1) * sinh(Float64(eta1)))
    y2 = t2 == 0 ? 0.0 : asinh((p2 / t2) * sinh(Float64(eta2)))
    denom = t1 * t2 + p1 * p2
    gap = denom == 0 ? 0.0 : (a^2 * (p2^2 + b^2) + b^2 * p1^2) / denom
    m2pair = a^2 + b^2 + 2gap + 4t1 * t2 * sinh((y1 - y2) / 2)^2 +
             4p1 * p2 * sin((Float64(phi1) - Float64(phi2)) / 2)^2
    return sqrt(max(m2pair, 0.0))
end
