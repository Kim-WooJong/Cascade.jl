"""
    binned_hist(edges, sumw, sumw2; underflow=(0.0, 0.0), overflow=(0.0, 0.0),
                fold_underflow=true, fold_overflow=true) -> BinnedHist

Validated, copied [`BinnedHist`](@ref) (the `Cascade.Histograms` type) from plain
arrays: the input contract of `Cascade.Plotting`.

- `edges`: `n + 1` finite, strictly increasing bin edges (bins `[low, high)`).
- `sumw`, `sumw2`: sum of weights and of squared weights of the `n` bins;
  negative `sumw` (signed generator weights) are allowed, `sumw2 >= 0`.
- `underflow`, `overflow`: optional `(Σw, Σw²)` of the flow bins. A
  `BinnedHist` has no flow bins (the histogram store drops underflow and fills
  overflow into the last bin), so a flow pair is added to the first / last bin
  when `fold_underflow` / `fold_overflow` is true and dropped otherwise.

All arrays are copied; the result never aliases caller data.
"""
function binned_hist(edges::AbstractVector{<:Real}, sumw::AbstractVector{<:Real}, sumw2::AbstractVector{<:Real};
                     underflow=(0.0, 0.0), overflow=(0.0, 0.0), fold_underflow::Bool=true, fold_overflow::Bool=true)
    e, w, v = Vector{Float64}(edges), Vector{Float64}(sumw), Vector{Float64}(sumw2)
    length(e) >= 2 || throw(ArgumentError("a histogram needs at least two bin edges"))
    length(w) == length(e) - 1 == length(v) ||
        throw(ArgumentError("expected n + 1 edges and n values of sumw and sumw2"))
    all(isfinite, e) && all(diff(e) .> 0) ||
        throw(ArgumentError("bin edges must be finite and strictly increasing"))
    all(isfinite, w) && all(isfinite, v) || throw(ArgumentError("bin contents must be finite"))
    all(>=(0), v) || throw(ArgumentError("sumw2 must be non-negative"))
    uf, of = flow_pair(underflow), flow_pair(overflow)
    if fold_underflow
        w[1] += uf[1]; v[1] += uf[2]
    end
    if fold_overflow
        w[end] += of[1]; v[end] += of[2]
    end
    return BinnedHist(e, w, v)
end

"""Validate one `(Σw, Σw²)` flow pair."""
function flow_pair(flow)
    length(flow) == 2 && all(x -> x isa Real && isfinite(x), flow) && flow[2] >= 0 ||
        throw(ArgumentError("a flow bin must be a finite (Σw, Σw²) pair with Σw² >= 0"))
    return (Float64(flow[1]), Float64(flow[2]))
end
