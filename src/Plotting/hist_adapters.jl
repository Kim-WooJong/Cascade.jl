"""
    to_hist1d(h::BinnedHist) -> ROOTPlots.Hist1D
    binned_hist(h::ROOTPlots.Hist1D; fold_underflow=true, fold_overflow=true) -> BinnedHist

Adapters between [`BinnedHist`](@ref) and ROOTPlots `Hist1D`. Edges, `Σw` and
`Σw²` are carried over unchanged (copied). A `BinnedHist` has no flow bins, so
`to_hist1d` gives empty flow bins and `binned_hist` folds the `Hist1D` flow
bins into the first / last bin (or drops them, see [`binned_hist`](@ref)).
ROOTPlots' optional fill bookkeeping (entries, moments) is not kept.
"""
to_hist1d(h::BinnedHist) = Hist1D(copy(h.edges), copy(h.sumw), copy(h.sumw2))

binned_hist(h::Hist1D; fold_underflow::Bool=true, fold_overflow::Bool=true) =
    binned_hist(h.edges, h.sumw, h.sumw2; underflow=h.underflow, overflow=h.overflow, fold_underflow, fold_overflow)
