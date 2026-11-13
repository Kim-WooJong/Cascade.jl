"""
    hist_sum(a::BinnedHist, b::BinnedHist) -> BinnedHist

Bin-wise sum of two histograms with identical edges: `Σw` and `Σw²` add
(independent samples). Returns a new histogram; the inputs are not modified.
"""
function hist_sum(a::BinnedHist, b::BinnedHist)
    a.edges == b.edges || throw(ArgumentError("bin edges disagree"))
    return BinnedHist(copy(a.edges), a.sumw .+ b.sumw, a.sumw2 .+ b.sumw2)
end
