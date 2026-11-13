"""
    selection_context(raw::Dict{String,Any}, sel, collections) -> KernelContext

Kernel context over the columns `raw` (jagged columns as flat content plus
one offsets vector per collection, checked to agree), with empty object
buffers for `sel.object_names`. Errors if a collection in `collections` has
no column.
"""
function selection_context(raw::AbstractDict, sel::CompiledSelection, collections; objs = nothing, memo = nothing, n = nothing)
    names = Symbol[]; vals = Any[]
    offs = Dict{String,Vector{Int}}()
    # NamedTuple field order is part of KernelContext's concrete type.
    # Use the same order for a schema regardless of Dict insertion history.
    for k in sort!(collect(keys(raw)))
        v = raw[k]
        if v isa Jagged
            coll = first(split(k, '_'))
            if haskey(offs, coll)
                (offs[coll] === v.offsets || offs[coll] == v.offsets) || error("columns of collection $coll have inconsistent offsets ($k)")
            else
                offs[coll] = v.offsets
            end
            push!(names, Symbol(k)); push!(vals, v.content)
        else
            push!(names, Symbol(k)); push!(vals, v)
        end
    end
    for c in collections
        haskey(offs, c) || error("no column read for collection $c")
    end
    # Prefix cuts can reference event-local jagged helpers without using any
    # selected object. Make every available jagged collection's offsets visible.
    oc = sort!(collect(keys(offs)))
    cols = NamedTuple{Tuple(names)}(Tuple(vals))
    offt = NamedTuple{Tuple(Symbol.(oc))}(Tuple(offs[c] for c in oc))
    buffers = objs === nothing ?
        NamedTuple{Tuple(Symbol.(sel.object_names))}(Tuple(Int[] for _ in sel.object_names)) : objs
    ctx = KernelContext(cols, offt, buffers)
    isempty(sel.variable_nodes) && return ctx
    if memo === nothing
        # In an empty schema callers must supply n; normal select_events does.
        count = n === nothing ? (isempty(raw) ? 0 :
            (first(values(raw)) isa Jagged ? length(first(values(raw)).offsets) - 1 : length(first(values(raw))))) : n
        memo = VariableMemoRegistry(count, length(sel.variable_nodes), sel.memoize_max_bytes)
    end
    return _memo_context(ctx, sel, memo)
end
