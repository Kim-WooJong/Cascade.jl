"""
    evaluate_object_expression(kernel, columns, cols::AbstractDict, needed) -> Vector{Float64}

Values of a kernel from `compile_object_expression` for every object of the
jagged columns `cols[columns]` (one entry per flat index). Objects of events
with `needed[i] == false` get `NaN` (`needed === nothing`: all events).
"""
function evaluate_object_expression(kernel, columns::AbstractVector{<:AbstractString}, cols::AbstractDict, needed)
    isempty(columns) && throw(ArgumentError("object expression reads no column"))
    js = [cols[c] for c in columns]
    all(j -> j isa Jagged, js) || throw(ArgumentError("object expression columns must be jagged"))
    offsets = first(js).offsets
    ctx = KernelContext(NamedTuple{Tuple(Symbol.(columns))}(Tuple(j.content for j in js)), (;), (;))
    out = fill(NaN, length(first(js).content))
    Base.invokelatest(_object_loop!, out, kernel, ctx, offsets, needed)
    return out
end

function _object_loop!(out, kernel, ctx, offsets, needed)
    for i in 1:length(offsets)-1
        (needed === nothing || needed[i]) || continue
        for j in offsets[i]+1:offsets[i+1]
            out[j] = kernel(ctx, j)
        end
    end
    return out
end
