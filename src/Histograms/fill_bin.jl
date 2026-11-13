"""
    fill_bin!(h::BinnedHist, x, w) -> h

Fill value `x` with weight `w`. Underflow (`x < edges[1]`) is dropped,
overflow goes into the last bin, `NaN` means "no value" and is skipped.
Bin lookup is `min(searchsortedlast(edges, x), nbins)`, comparing `x` in its own
precision against the Float64 edges.
"""
@inline function fill_bin!(h::BinnedHist, x::Real, w::Real)
    isnan(x) && return h
    x < h.edges[1] && return h
    k = min(searchsortedlast(h.edges, x), length(h.sumw))
    @inbounds h.sumw[k] += w
    @inbounds h.sumw2[k] += w^2
    return h
end
