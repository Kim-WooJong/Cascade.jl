"""
    total_yield(h::BinnedHist) -> (sumw=..., sumw2=...)

Integrated `Σw` and `Σw²` of all bins. The statistical uncertainty of the
yield is `sqrt(sumw2)`.
"""
total_yield(h::BinnedHist) = (sumw=sum(h.sumw), sumw2=sum(h.sumw2))
