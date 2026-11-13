"""
    is_up_to_date(artifact, key) -> Bool

True if the artifact exists and its meta file records `key`.
"""
function is_up_to_date(artifact::AbstractString, key::AbstractString)
    ispath(artifact) || return false
    m = read_meta(artifact)
    return m !== nothing && get(m, "key", "") == key
end
