"""
    merge_store!(dest::HistogramStore, src::HistogramStore) -> dest

Add every histogram of `src` into `dest` (edges must agree). Merging chunk
stores in a fixed chunk order makes the result independent of scheduling.
"""
function merge_store!(dest::HistogramStore, src::HistogramStore)
    merge_theory_extraction!(dest,src)
    for k in keys(src)
        h = src.hists[k]
        d = hist!(dest, k, h.edges)
        d.edges == h.edges || throw(ArgumentError("bin edges differ for $k"))
        d.sumw .+= h.sumw
        d.sumw2 .+= h.sumw2
    end
    return dest
end
