"""
    hist_scale(h::BinnedHist, c::Real) -> BinnedHist

Histogram scaled by the constant `c`: `Σw` is multiplied by `c` and `Σw²`
by `c²` (e.g. a `σ L / Σw_gen` normalisation or a normalisation variation).
"""
function hist_scale(h::BinnedHist, c::Real)
    isfinite(c) || throw(ArgumentError("scale factor must be finite"))
    k = Float64(c)
    return BinnedHist(copy(h.edges), k .* h.sumw, k^2 .* h.sumw2)
end
