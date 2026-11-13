"""
    sort_objects!(buf::Vector{Int}, key::AbstractVector; rev = true) -> buf

Order selected flat indices by `key[j]` (descending by default) using Julia's
default stable sort, i.e. ties keep the input order.
"""
@inline function sort_objects!(buf::Vector{Int}, key::AbstractVector; rev::Bool = true)
    return sort!(buf; by = k -> key[k], rev = rev)
end
