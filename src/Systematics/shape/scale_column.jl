"""
    scale_column(col::Jagged{T}, factors, needed) -> Jagged{T}

`T(Float64(x) * f)` for every object of events with `needed[i]` (others keep
their value). The result shares the offsets of `col` and keeps its element
type (Float32 for NanoAOD), so compiled kernels see the same column types.
"""
function scale_column(col::Jagged{T}, factors::AbstractVector{Float64}, needed) where {T<:AbstractFloat}
    length(factors) == length(col.content) || throw(ArgumentError("factor count does not match the column"))
    out = copy(col.content)
    o = col.offsets
    for i in 1:length(o)-1
        (needed === nothing || needed[i]) || continue
        for j in o[i]+1:o[i+1]
            out[j] = T(Float64(col.content[j]) * factors[j])
        end
    end
    return Jagged{T}(out, col.offsets)
end
