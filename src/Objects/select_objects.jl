"""
    select_objects!(pred, buf::Vector{Int}, lo::Integer, hi::Integer) -> buf

Empty `buf` and push every flat index `j` in `lo+1:hi` (one event's slice of a
`Jagged` collection) for which `pred(j)` is true, in input order.
"""
@inline function select_objects!(pred::F, buf::Vector{Int}, lo::Integer, hi::Integer) where {F}
    empty!(buf)
    for j in lo+1:hi
        pred(j) && push!(buf, j)
    end
    return buf
end
