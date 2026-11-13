"""
    require_artifact(path, what) -> Dict{String,Any}

Meta record of an upstream artifact; throws `ArgumentError` if it is missing.
"""
function require_artifact(path::AbstractString, what::AbstractString)
    m = read_meta(path)
    (m === nothing || !ispath(path)) && throw(ArgumentError("missing $what artifact $path; run the upstream step first"))
    return m
end
