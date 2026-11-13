"""
    trigger_column(cols, t::TriggerConfig, kind, stream) -> Vector{Bool}

Per-event trigger decision with primary-dataset overlap removal. A group fires
if any of its paths fires. MC: any `t.mc` group fires. Data in stream `S`: a
group of `S` fires and no group of a stream before `S` in `t.priority` fires,
so every collision event is counted in exactly one primary dataset.
"""
function trigger_column(cols::AbstractDict, t::TriggerConfig, kind::Symbol, stream::AbstractString)
    fired(g) = reduce((a, p) -> a .| Vector{Bool}(cols[p]), t.groups[g]; init = falses(_nev(cols, t.groups[g])))
    if kind === :mc
        isempty(t.mc) && throw(ArgumentError("trigger builtin used but triggers.mc is empty"))
        return Vector{Bool}(reduce(.|, (fired(g) for g in t.mc)))
    end
    k = findfirst(==(stream), t.priority)
    k === nothing && throw(ArgumentError("stream '$stream' not in triggers.priority"))
    pass = reduce(.|, (fired(g) for g in t.streams[stream]))
    for s in t.priority[1:k-1], g in t.streams[s]
        pass = pass .& .!fired(g)
    end
    return Vector{Bool}(pass)
end

_nev(cols, paths) = isempty(paths) ? throw(ArgumentError("empty trigger group")) : length(cols[first(paths)])
