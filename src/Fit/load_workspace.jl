"""
    load_workspace(path) -> Dict{String,Any}

Read a pyhf-style JSON workspace (`channels`, `observations`,
`measurements`) into plain Julia dictionaries and vectors.
"""
function load_workspace(path::AbstractString)
    return _plain(JSON3.read(read(path, String)))
end

_plain(x::AbstractDict) = Dict{String,Any}(String(k) => _plain(v) for (k, v) in pairs(x))
_plain(x::AbstractVector) = Any[_plain(v) for v in x]
_plain(x::AbstractString) = String(x)
_plain(x) = x
