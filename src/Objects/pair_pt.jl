"""
    pair_pt(pt1, phi1, pt2, phi2) -> Float64

Magnitude of the vector sum of two transverse momenta. Arithmetic is Float64;
the inputs use the same momentum units and azimuths are in radians.
"""
@inline function pair_pt(pt1, phi1, pt2, phi2)
    p1, p2 = Float64(pt1), Float64(pt2)
    a, b = Float64(phi1), Float64(phi2)
    return hypot(p1 * cos(a) + p2 * cos(b), p1 * sin(a) + p2 * sin(b))
end
