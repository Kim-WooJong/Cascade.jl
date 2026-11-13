"""
Internal event-indexed object storage. Selected flat indices are appended once;
spans are isbits ranges, not separately allocated vectors for every event.
All buffers in one SelectionProgress share its current-event reference.
"""
struct CachedObjectBuffer <: AbstractVector{Int}
    data::Vector{Int}
    spans::Vector{UnitRange{Int}}
    current::Base.RefValue{Int}
    limit::Int
end
CachedObjectBuffer(data, spans, current) = CachedObjectBuffer(data, spans, current, typemax(Int))

CachedObjectBuffer(n::Int, current::Base.RefValue{Int}) =
    CachedObjectBuffer(Int[], fill(0:-1, n), current)

@inline function _object_span(buf::CachedObjectBuffer)
    i = buf.current[]
    checkbounds(buf.spans, i)
    span = buf.spans[i]
    first(span) > 0 || error("object read before materialization for event $i")
    return span
end

Base.IndexStyle(::Type{CachedObjectBuffer}) = IndexLinear()
Base.size(buf::CachedObjectBuffer) = (length(_object_span(buf)),)
Base.length(buf::CachedObjectBuffer) = length(_object_span(buf))
@inline function Base.getindex(buf::CachedObjectBuffer, k::Int)
    span = _object_span(buf)
    checkbounds(span, k)
    return buf.data[first(span) + k - 1]
end

# Extend the same generic functions imported by the generated Kernels module.
function Objects.select_objects!(pred::F, buf::CachedObjectBuffer,
                                 lo::Integer, hi::Integer) where {F}
    i = buf.current[]
    checkbounds(buf.spans, i)
    first(buf.spans[i]) == 0 || error("object rebuilt for event $i")
    start = length(buf.data) + 1
    for j in lo+1:hi
        if pred(j)
            length(buf.data) < buf.limit || error("reusable object index metadata bound exceeded")
            push!(buf.data, j)
        end
    end
    # A built-empty span starts at >=1; 0:-1 means not built, never empty.
    buf.spans[i] = start:length(buf.data)
    return buf
end

function Objects.sort_objects!(buf::CachedObjectBuffer, key::AbstractVector;
                               rev::Bool = true)
    sort!(view(buf.data, _object_span(buf)); by = k -> key[k], rev = rev)
    return buf
end
