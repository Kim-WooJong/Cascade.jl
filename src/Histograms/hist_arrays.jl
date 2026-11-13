"""
    hist_arrays(h::BinnedHist) -> (edges, sumw, sumw2)

Plain arrays for conversion to other histogram types, e.g.
`ROOTPlots.Hist1D(hist_arrays(h)...)`.
"""
hist_arrays(h::BinnedHist) = (h.edges, h.sumw, h.sumw2)
