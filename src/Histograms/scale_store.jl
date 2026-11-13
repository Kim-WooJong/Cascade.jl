"""
    scale_store!(store, factor; sample = nothing) -> store

Multiply `sumw` by `factor` and `sumw2` by `factor^2` (all histograms, or only
those of `sample`).
"""
function scale_store!(store::HistogramStore, factor::Real; sample = nothing)
    c = Float64(factor)
    for (k, h) in store.hists
        (sample === nothing || k.sample == sample) || continue
        h.sumw .*= c
        h.sumw2 .*= c^2
    end
    return store
end
