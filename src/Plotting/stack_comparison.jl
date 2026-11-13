"""
    stack_comparison(data::BinnedHist, groups, colors, band::UncertaintyBand;
                     data_errors=:poisson) -> ROOTPlots.Comparison

Numerical data/MC comparison (no rendering): stack components from the nominal
histograms of `groups` (vector of [`SampleTemplates`](@ref), bottom to top)
with fill `colors`, the observed visible bins of `data`, and `band` as the
prediction uncertainty (main panel: prediction ± band; ratio panel:
`1 ± band / prediction`; data points: `data / prediction`).

`data_errors`: `:poisson` (Garwood intervals, integer counts; see
[`poisson_errors`](@ref)), `:sumw2` (`sqrt(Σw²)` for weighted data), or a
`(low, high)` tuple of vectors.

Negative group bins (from signed weights) cannot be stacked; they are drawn as
zero. The band magnitudes are those of `band` (computed from the unclamped
templates); the band is centred on the drawn stack.
"""
function stack_comparison(data::BinnedHist, groups::AbstractVector{SampleTemplates},
                          colors::AbstractVector{<:AbstractString}, band::UncertaintyBand;
                          data_errors=:poisson)
    length(groups) == length(colors) || throw(ArgumentError("one colour per group is needed"))
    edges = data.edges
    all(g -> g.nominal.edges == edges, groups) && band.edges == edges ||
        throw(ArgumentError("data, groups and band must share the bin edges"))
    components = [Component(g.name, Hist1D(edges, max.(g.nominal.sumw, 0.0), g.nominal.sumw2), String(c))
                  for (g, c) in zip(groups, colors)]
    lo, hi = data_error_vectors(data, data_errors)
    observed = Hist1D(edges, data.sumw, data.sumw2)
    return comparison(observed, components; data_errors=BinErrors(lo, hi),
                      prediction_errors=BinErrors(band.low, band.high), uncertainty_label=band.label)
end

function data_error_vectors(data::BinnedHist, mode)
    mode === :poisson && return poisson_errors(data.sumw)
    mode === :sumw2 && return (sqrt.(data.sumw2), sqrt.(data.sumw2))
    mode isa Tuple && length(mode) == 2 && return (Float64.(mode[1]), Float64.(mode[2]))
    throw(ArgumentError("data_errors must be :poisson, :sumw2 or a (low, high) tuple"))
end
