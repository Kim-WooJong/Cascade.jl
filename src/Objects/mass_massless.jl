"""
    mass_massless(pt1, eta1, phi1, pt2, eta2, phi2) -> Float64

Invariant mass of two massless objects, `m^2 = 2 pt1 pt2 (cosh(deta) - cos(dphi))`.
The product is evaluated in the argument precision and the square root in
Float64 (`sqrt(max(m2, 0.0))`), matching the reference ttbar e-mu code.
"""
@inline function mass_massless(pt1, eta1, phi1, pt2, eta2, phi2)
    return sqrt(max(2pt1 * pt2 * (cosh(eta1 - eta2) - cos(phi1 - phi2)), 0.0))
end
