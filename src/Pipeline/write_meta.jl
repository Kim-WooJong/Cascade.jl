"""
    write_meta(artifact, key; info...) -> path

Write `<artifact>.meta.json` with the artifact key and extra information.
Written after the artifact itself, so a meta file implies a complete artifact.
"""
function write_meta(artifact::AbstractString, key::AbstractString; info...)
    d = Dict{String,Any}("key" => key, "artifact" => basename(artifact), "created_unix" => time(),
                         "julia" => string(VERSION))
    for (k, v) in info
        d[String(k)] = v
    end
    path = string(artifact, ".meta.json")
    mkpath(dirname(abspath(path)))
    tmp = string(path, ".tmp.", getpid(), ".", objectid(d))
    write(tmp, JSON3.write(d))
    mv(tmp, path; force = true)
    return path
end
