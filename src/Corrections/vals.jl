# Input values of one evaluation. Every input slot holds its value in the
# representation(s) needed by the nodes: `x` (real value, or Float64 of an
# int input), `k` (int value) and `s` (string value). Immutable, so nodes
# such as Transform create modified copies without heap allocation.
struct Vals{N}
    x::NTuple{N,Float64}
    k::NTuple{N,Int64}
    s::NTuple{N,String}
end

@inline function setreal(v::Vals{N}, i::Integer, val::Float64) where {N}
    return Vals{N}(Base.setindex(v.x, val, Int(i)), v.k, v.s)
end

@inline function setint(v::Vals{N}, i::Integer, val::Int64) where {N}
    return Vals{N}(Base.setindex(v.x, Float64(val), Int(i)), Base.setindex(v.k, val, Int(i)), v.s)
end
