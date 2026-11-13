"""
    fill_store!(store, sample, hists, values, regions, weights) -> store

Fill histograms of one sample.

- `hists::Vector{HistogramConfig}` (edges, region restriction);
- `values[h.name]`: vector of value columns (one per fill expression, NaN = skip);
- `regions`: `region name => Bool mask` over events;
- `weights`: `variation label => weight column`.

Events are processed in order and, within an event, value columns in order, so
the floating-point accumulation order equals an event-loop implementation.
"""
function fill_store!(store::HistogramStore, sample::AbstractString, hists::AbstractVector{HistogramConfig},
                     values::AbstractDict, regions::AbstractVector{<:Pair}, weights::AbstractVector{<:Pair})
    for (rname, mask) in regions, h in hists
        (isempty(h.regions) || rname in h.regions) || continue
        cols = values[h.name]
        for (vname, w) in weights
            target = hist!(store, HistKey(rname, sample, vname, h.name), h.edges)
            _fill_columns!(target, mask, cols, w)
        end
    end
    return store
end

function _fill_columns!(h::BinnedHist, mask::AbstractVector{Bool}, cols::AbstractVector, w::AbstractVector{Float64})
    for i in eachindex(mask)
        mask[i] || continue
        for c in cols
            fill_bin!(h, c[i], w[i])
        end
    end
    return h
end
