"""
    json_safe(x)

Copy of `x` (nested dictionaries, vectors, named tuples, numbers, strings,
symbols, plain structs) that `JSON3.write` accepts as strict JSON: non-finite floats become
`nothing` (null), symbols strings, named tuples and structs dictionaries and
matrices vectors of rows.
"""
json_safe(x::AbstractFloat) = isfinite(x) ? Float64(x) : nothing
json_safe(x::Union{Integer,Bool,Nothing,AbstractString}) = x
json_safe(x::Symbol) = String(x)
json_safe(x::AbstractDict) = Dict{String,Any}(String(k) => json_safe(v) for (k, v) in pairs(x))
json_safe(x::NamedTuple) = Dict{String,Any}(String(k) => json_safe(v) for (k, v) in pairs(x))
json_safe(x::AbstractMatrix) = Any[json_safe(collect(r)) for r in eachrow(x)]
json_safe(x::Union{AbstractVector,Tuple}) = Any[json_safe(v) for v in x]
function json_safe(x)
    T = typeof(x)
    isstructtype(T) || throw(ArgumentError("cannot convert $T to JSON"))
    return Dict{String,Any}(String(f) => json_safe(getfield(x, f)) for f in fieldnames(T))
end
