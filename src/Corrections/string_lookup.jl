# Open-addressing string -> index table with an inlined FNV-1a hash. Category
# keys are short strings; this is several times faster than Dict{String}
# lookups, whose hashing goes through a C call.
struct StringLookup
    keys::Vector{String}
    hashes::Vector{UInt64}
    vals::Vector{Int32}     # 0 marks an empty slot
    mask::Int
end

@inline function fnv1a(s::String)
    h = 0xcbf29ce484222325
    @inbounds for i in 1:ncodeunits(s)
        h = (h ⊻ codeunit(s, i)) * 0x00000100000001b3
    end
    return h
end

function StringLookup(d::AbstractDict{String,Int32})
    cap = nextpow(2, max(4, 2 * length(d)))
    keys = fill("", cap)
    hashes = zeros(UInt64, cap)
    vals = zeros(Int32, cap)
    mask = cap - 1
    for (k, v) in d
        h = fnv1a(k)
        i = Int(h & UInt64(mask))
        while vals[i+1] != 0
            i = (i + 1) & mask
        end
        keys[i+1] = k
        hashes[i+1] = h
        vals[i+1] = v
    end
    return StringLookup(keys, hashes, vals, mask)
end

@inline function streq(a::String, b::String)
    n = ncodeunits(a)
    n == ncodeunits(b) || return false
    @inbounds for i in 1:n
        codeunit(a, i) == codeunit(b, i) || return false
    end
    return true
end

"""Index stored for `s`, or 0 when absent."""
@inline function lookup(t::StringLookup, s::String)::Int32
    h = fnv1a(s)
    i = Int(h & UInt64(t.mask))
    @inbounds while true
        v = t.vals[i+1]
        v == 0 && return Int32(0)
        (t.hashes[i+1] == h && streq(t.keys[i+1], s)) && return v
        i = (i + 1) & t.mask
    end
end
