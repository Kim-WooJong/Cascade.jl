"""
    file_signature(path) -> Dict{String,Any}

Original-file provenance: absolute path, size and modification time; large
original input content is not hashed. Recognized reduced bundle payloads also
verify and hash mandatory payload/sidecar/manifest bytes for cache integrity.
"""
function file_signature(path::AbstractString)
    st = stat(path)
    isfile(st) || throw(ArgumentError("not a file: $path"))
    out = Dict{String,Any}("path" => abspath(path), "size" => Int(st.size), "mtime" => Float64(st.mtime))
    if endswith(path, ".source.json")
        meta = read_reduced_group(path; verify_payloads = false)
        out["descriptor_sha256"] = meta["descriptor_sha256"]
        out["manifest_sha256"] = meta["manifest_sha256"]
    elseif isfile(path * ".cascade.json")
        meta = read_reduced_metadata(path)
        out["payload_sha256"] = meta["payload_sha256"]
        out["sidecar_sha256"] = meta["sidecar_sha256"]
        out["manifest_sha256"] = meta["manifest_sha256"]
    end
    return out
end
