"""Build a pinned shard signature after explicit group or own-task byte verification.

This does not replace verification: global operations verify the group once,
workers verify their own shard. Sibling stat checks never certify payload bytes.
"""
function group_shard_signature(group, record)
    path = joinpath(group["bundle_root"], record["path"])
    reduced_safe_path(group["bundle_root"], record["path"])
    reduced_safe_path(group["bundle_root"], record["path"] * ".cascade.json")
    st = stat(path)
    return Dict{String,Any}("path" => abspath(path), "size" => Int(st.size), "mtime" => Float64(st.mtime),
        "payload_sha256" => record["sha256"], "sidecar_sha256" => record["sidecar_sha256"],
        "manifest_sha256" => group["manifest_sha256"], "format" => "reduced_rntuple_group")
end
