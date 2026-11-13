"""
    canonical_hash(x) -> String

SHA-256 (hex) of a canonical JSON rendering of `x` (dictionary keys sorted
recursively), so equal content always hashes equally regardless of key order.
"""
canonical_hash(x) = bytes2hex(sha256(Vector{UInt8}(codeunits(canonical_json(x)))))

canonical_json(x::AbstractDict) =
    "{" * join((JSON3.write(string(k)) * ":" * canonical_json(x[k]) for k in sort!(collect(keys(x)); by = string)), ",") * "}"
canonical_json(x::Union{AbstractVector,Tuple}) = "[" * join((canonical_json(v) for v in x), ",") * "]"
canonical_json(x::Symbol) = JSON3.write(String(x))
canonical_json(::Nothing) = "null"
canonical_json(x::AbstractFloat) = isfinite(x) ? JSON3.write(Float64(x)) : JSON3.write(string(x))
canonical_json(x) = JSON3.write(x)
