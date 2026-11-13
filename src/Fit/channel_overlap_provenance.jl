"""
    channel_overlap_provenance(table::EventTable, cfg::AnalysisConfig) -> Dict

Exact per-entry overlap counts for the active `[fit]` channels in a nominal
data table. Membership requires the actual region mask and at least one value
accepted by `fill_bin!`: NaN and underflow are excluded, overflow is folded.
Weights (including zero) do not affect membership. Returns mergeable metadata,
not event identifiers. Independent source entries are the unit of identity;
this does not deduplicate physical events repeated across files or samples.
"""
function channel_overlap_provenance(table::EventTable, cfg::AnalysisConfig)
    fc = fit_config(cfg)
    fc === nothing && throw(ArgumentError("channel overlap provenance requires a [fit] section"))
    String(get(table.meta, "kind", "")) == "data" ||
        throw(ArgumentError("channel overlap provenance requires nominal data"))
    String(get(table.meta, "variation", "nominal")) == "nominal" ||
        throw(ArgumentError("channel overlap provenance requires nominal data"))
    regions = region_masks(table)
    descriptions = Any[]
    masks = BitVector[]
    for ch in fc.channels
        hi = findfirst(h -> h.name == ch.variable, cfg.histograms)
        hi === nothing && throw(ArgumentError("fit channel $(ch.name): unknown histogram $(ch.variable)"))
        h = cfg.histograms[hi]
        haskey(regions, ch.region) || throw(ArgumentError("fit channel $(ch.name): unknown region $(ch.region)"))
        (isempty(h.regions) || ch.region in h.regions) ||
            throw(ArgumentError("fit channel $(ch.name): histogram $(h.name) is not filled in region $(ch.region)"))
        cols = get(table.meta["hist_columns"], h.name, nothing)
        cols === nothing && throw(ArgumentError("fit channel $(ch.name): missing histogram columns"))
        mask = falses(length(table["entry"]))
        for col in cols
            values = table[String(col)]
            for i in eachindex(mask)
                mask[i] |= regions[ch.region][i] && !isnan(values[i]) && values[i] >= first(h.edges)
            end
        end
        push!(masks, mask)
        push!(descriptions, Dict("name" => ch.name, "region" => ch.region, "variable" => ch.variable,
                                 "edges" => copy(h.edges)))
    end
    pairs = Any[Dict("left" => fc.channels[i].name, "right" => fc.channels[j].name,
                      "n" => count(masks[i] .& masks[j]))
                for i in eachindex(masks) for j in (i + 1):length(masks)]
    sample = String(get(table.meta, "sample", ""))
    isempty(sample) && throw(ArgumentError("channel overlap provenance requires a sample name"))
    record = Dict{String,Any}("channel_events" => Dict(ch.name => count(mask) for (ch, mask) in zip(fc.channels, masks)),
                              "overlaps" => pairs)
    return Dict{String,Any}("version" => 1, "channels" => descriptions,
                            "samples" => Dict{String,Any}(sample => record))
end
