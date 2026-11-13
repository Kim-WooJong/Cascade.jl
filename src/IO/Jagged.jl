"""
    Jagged{T}

Variable-length list per event stored flat: event `i` owns
`content[offsets[i]+1 : offsets[i+1]]`. `offsets` has `nevents + 1` entries
and starts at 0.
"""
struct Jagged{T}
    content::Vector{T}
    offsets::Vector{Int}
    function Jagged{T}(content::Vector{T}, offsets::Vector{Int}) where {T}
        (!isempty(offsets) && offsets[1] == 0 && offsets[end] == length(content)) ||
            throw(ArgumentError("invalid Jagged offsets"))
        return new{T}(content, offsets)
    end
end

Jagged(content::Vector{T}, offsets::Vector{Int}) where {T} = Jagged{T}(content, offsets)

"""
    Jagged(lists::AbstractVector{<:AbstractVector{T}})

Build a `Jagged` column from one vector per event.
"""
function Jagged(lists::AbstractVector{<:AbstractVector{T}}) where {T}
    offsets = zeros(Int, length(lists) + 1)
    for (i, l) in enumerate(lists)
        offsets[i+1] = offsets[i] + length(l)
    end
    return Jagged{T}(collect(T, Iterators.flatten(lists)), offsets)
end

Base.length(j::Jagged) = length(j.offsets) - 1
Base.getindex(j::Jagged, i::Integer) = view(j.content, j.offsets[i]+1:j.offsets[i+1])
Base.eltype(::Type{Jagged{T}}) where {T} = T
