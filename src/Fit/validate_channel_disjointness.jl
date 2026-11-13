"""
    validate_channel_disjointness(store::HistogramStore, fc::FitConfig) -> nothing

Reject overlapping observed fit channels before constructing an independent
Poisson likelihood. Only active channels and the data samples used by the fit
are checked. Multi-channel stores with observed histograms require exact
selection provenance; histogram integrals cannot establish disjointness.
Single-channel, synthetic Asimov and data-free stores retain their existing
behavior. An Asimov bypass is not evidence of physical channel independence.
"""
function validate_channel_disjointness(store::HistogramStore, fc::FitConfig)
    fc.asimov && return nothing
    length(fc.channels) <= 1 && return nothing
    data = [d for d in fc.data if any(ch -> haskey(store, HistKey(ch.region, d, NOMINAL, ch.variable)), fc.channels)]
    isempty(data) && return nothing
    p = get(store.meta, "fit_channel_provenance", nothing)
    missing() = throw(ArgumentError("multi-channel observed fit requires complete selected-event overlap provenance; rerun merge from selection tables"))
    p isa AbstractDict && get(p, "version", 0) == 1 || missing()
    channels = get(p, "channels", Any[])
    records = get(p, "samples", Dict())
    for ch in fc.channels
        idx = findfirst(c -> c["name"] == ch.name && c["region"] == ch.region && c["variable"] == ch.variable, channels)
        idx === nothing && missing()
        for d in data
            key = HistKey(ch.region, d, NOMINAL, ch.variable)
            haskey(store, key) || continue
            channels[idx]["edges"] == store[key].edges || missing()
        end
    end
    for d in data
        haskey(records, d) || missing()
        record = records[d]
        counts = get(record, "channel_events", Dict())
        for ch in fc.channels
            haskey(counts, ch.name) || missing()
        end
        pairs = get(record, "overlaps", Any[])
        for i in eachindex(fc.channels), j in (i + 1):length(fc.channels)
            left, right = fc.channels[i].name, fc.channels[j].name
            idx = findfirst(pair -> (pair["left"] == left && pair["right"] == right) ||
                                   (pair["left"] == right && pair["right"] == left), pairs)
            idx === nothing && missing()
            n = Int(pairs[idx]["n"])
            n >= 0 || missing()
            n == 0 || throw(ArgumentError("fit channels '$left' and '$right' overlap in $n selected data event(s) of sample '$d'; define disjoint region expr masks or fit only one channel"))
        end
    end
    return nothing
end
