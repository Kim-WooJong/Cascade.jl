"""Verify one bounded physical shard in an explicit immutable logical-group context."""
function read_reduced_shard(path; group = nothing)
    p = abspath(path); root = dirname(dirname(p))
    reduced_safe_path(root, relpath(p, root)); side = reduced_safe_path(root, relpath(p * ".cascade.json", root))
    filesize(p) < 256_000_000 && filesize(side) <= 64_000_000 || error("physical artifact exceeds reader budget")
    meta = _plain(JSON3.read(read(side, String)))
    meta["schema"] == 2 || error("unsupported shard schema")
    g = group === nothing ? read_reduced_group(reduced_safe_path(root, meta["group_path"]); verify_payloads = false) : group
    records = [r for r in g["shards"] if r["path"] == relpath(p, root)]
    length(records) == 1 || error("foreign physical shard")
    r = only(records)
    bytes2hex(open(sha256, p)) == r["sha256"] || error("physical payload checksum mismatch")
    bytes2hex(open(sha256, side)) == r["sidecar_sha256"] || error("physical sidecar checksum mismatch")
    meta["group_id"] == g["group_id"] && meta["group_path"] == relpath(g["descriptor_path"], root) || error("foreign shard group")
    for key in ("ordinal", "source_begin", "source_end", "retained_begin", "nevents", "columns", "payload_bytes")
        meta[key] == r[key] || error("conflicting shard metadata: $key")
    end
    haskey(meta, "normalization") && error("physical shard must not own normalization")
    meta["contract"] == g["contract"] || error("conflicting shard retention contract")
    0 <= meta["payload_bytes"] <= 64_000_000 || error("invalid physical payload size")
    return merge(meta, Dict("group" => g, "retained_nevents" => meta["nevents"],
        "original_nevents" => g["original_nevents"], "sample" => g["sample"], "kind" => g["kind"],
        "population" => g["population"], "payload_sha256" => r["sha256"],
        "sidecar_sha256" => r["sidecar_sha256"], "bundle_id" => g["bundle_id"], "manifest_sha256" => g["manifest_sha256"]))
end
