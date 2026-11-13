"""
    filter_store(store; region = nothing, sample = nothing, variation = nothing, variable = nothing)

New store sharing the histograms whose key matches every given value (a value
may be a string or a collection of strings).
"""
function filter_store(store::HistogramStore; region = nothing, sample = nothing, variation = nothing,
                      variable = nothing)
    ok(v, want) = want === nothing || (want isa AbstractString ? v == want : v in want)
    out = HistogramStore(Dict{HistKey,BinnedHist}(), copy(store.meta))
    for (k, h) in store.hists
        ok(k.region, region) && ok(k.sample, sample) && ok(k.variation, variation) && ok(k.variable, variable) &&
            (out.hists[k] = h)
    end
    return out
end
