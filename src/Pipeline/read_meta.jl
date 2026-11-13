"""
    read_meta(artifact) -> Union{Dict{String,Any},Nothing}

Read `<artifact>.meta.json` (`nothing` if missing).
"""
function read_meta(artifact::AbstractString)
    p = string(artifact, ".meta.json")
    isfile(p) || return nothing
    return _jsdict(JSON3.read(read(p, String)))
end

_jsdict(x::JSON3.Object) = Dict{String,Any}(String(k) => _jsdict(v) for (k, v) in pairs(x))
_jsdict(x::JSON3.Array) = Any[_jsdict(v) for v in x]
_jsdict(x) = x
