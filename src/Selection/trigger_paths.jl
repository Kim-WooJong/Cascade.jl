"""
    trigger_paths(t::TriggerConfig, kind::Symbol, stream::AbstractString) -> Vector{String}

HLT branches needed to evaluate the `trigger` builtin for a sample: the groups
of its stream and of all higher-priority streams (data) or the `mc` groups.
"""
function trigger_paths(t::TriggerConfig, kind::Symbol, stream::AbstractString)
    groups = String[]
    if kind === :mc
        append!(groups, t.mc)
    else
        k = findfirst(==(stream), t.priority)
        k === nothing && throw(ArgumentError("stream '$stream' not in triggers.priority"))
        for s in t.priority[1:k]
            append!(groups, t.streams[s])
        end
    end
    return unique!(reduce(vcat, (t.groups[g] for g in groups); init = String[]))
end
