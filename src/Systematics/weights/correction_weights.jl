"""
    correction_weights(cfg, sample, source_path, table; spec = parse_corrections(cfg))
        -> Dict{String,Vector{Float64}}

Weight columns of the kept events of one chunk: `"nominal"` and
`"<name>Up"`/`"<name>Down"` for every varied `[corrections]` term (see
`combine_weights`) plus the expression variations of the selection
(`w:<name>Up/Down` table columns, applied on top of the corrected nominal).
Data samples get the base weight only. `source_path` (format
`sample.format`) is opened only if an event weight needs a branch.
"""
function correction_weights(cfg::AnalysisConfig, sample::SampleConfig, source_path::AbstractString,
                            table::EventTable; spec::CorrectionsSpec = parse_corrections(cfg), source = nothing)
    base = Vector{Float64}(table["weight"])
    is_mc(sample) || return Dict{String,Vector{Float64}}("nominal" => base)
    n = nrows(table)
    index = output_column_index(cfg)
    terms = WeightFactors[]
    reader = BranchReader(sample.format, source_path, n == 0 ? Int[] : Vector{Int}(table["entry"]); options = get(sample.raw, "source", Dict()), source)
    try
        for t in spec.object_sfs
            c = cached_correctionset(t.set)[t.correction]
            bound = bind_inputs(t.inputs, t.systematic, c; label = "object_sf '$(t.name)' ($(t.correction))")
            push!(terms, object_factors(t, c, bound, table, index))
        end
        for t in spec.event_weights
            c = cached_correctionset(t.set)[t.correction]
            bound = bind_inputs(t.inputs, t.systematic, c; label = "event_weight '$(t.name)' ($(t.correction))")
            push!(terms, event_factors(t, c, bound, table, index, cfg, reader))
        end
        for t in spec.trigger_ors
            push!(terms, trigger_or_factors(t, table, index))
        end
    finally
        close(reader)
    end
    for t in spec.flat
        push!(terms, flat_factors(t, n))
    end
    out = combine_weights(base, terms)
    for name in table.order
        startswith(name, "w:") || continue
        label = name[3:end]
        haskey(out, label) && throw(ArgumentError("weight variation '$label' defined twice"))
        out[label] = out["nominal"] .* table[name]
    end
    return out
end
