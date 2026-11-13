"""
    HistogramStore()

Mapping `HistKey -> BinnedHist` plus free-form `meta` (e.g. normalisation
factors, provenance).
"""
struct HistogramStore
    hists::Dict{HistKey,BinnedHist}
    meta::Dict{String,Any}
end

HistogramStore() = HistogramStore(Dict{HistKey,BinnedHist}(), Dict{String,Any}())

"""
    hist!(store, key::HistKey, edges) -> BinnedHist

Return the histogram at `key`, creating an empty one with `edges` if missing.
"""
function hist!(store::HistogramStore, key::HistKey, edges::AbstractVector{<:Real})
    h = get(store.hists, key, nothing)
    if h === nothing
        h = BinnedHist(edges)
        store.hists[key] = h
    end
    return h
end

Base.getindex(s::HistogramStore, k::HistKey) = s.hists[k]
Base.getindex(s::HistogramStore, region, sample, variation, variable) = s.hists[HistKey(region, sample, variation, variable)]
Base.haskey(s::HistogramStore, k::HistKey) = haskey(s.hists, k)
Base.keys(s::HistogramStore) = sort!(collect(keys(s.hists)))
Base.length(s::HistogramStore) = length(s.hists)

"""
    store_axis(store, axis::Symbol) -> Vector{String}

Sorted distinct values of `:region`, `:sample`, `:variation` or `:variable`.
"""
store_axis(s::HistogramStore, axis::Symbol) = sort!(unique([getfield(k, axis) for k in keys(s.hists)]))
