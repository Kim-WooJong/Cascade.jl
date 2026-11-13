"""Read and verify a reduced bundle's mandatory manifest, sidecar and payload bytes.

These hashes certify consistency, not a malicious producer's authenticity.
Original source paths are provenance only and are never opened.
"""
function read_reduced_metadata(path::AbstractString)
    endswith(path, ".source.json") && return read_reduced_group(path)
    if isfile(path * ".cascade.json")
        header = _plain(JSON3.read(read(path * ".cascade.json", String)))
        get(header, "schema", 1) == 2 && return read_reduced_shard(path)
    end
    p = abspath(path)
    root = dirname(dirname(p))
    for q in (p, p * ".cascade.json", joinpath(root, "manifest.json"))
        current = q
        while true
            islink(current) && error("symlink in reduced bundle: $current")
            parent = dirname(current)
            parent == current && break
            current = parent
        end
        isfile(q) || error("missing reduced bundle artifact: $q")
    end
    manifest = _plain(JSON3.read(read(joinpath(root, "manifest.json"), String)))
    manifest["schema"] == 1 || error("unsupported reduced manifest schema")
    body = copy(manifest); id = pop!(body, "id")
    reduced_metadata_hash(body) == id || error("reduced manifest checksum mismatch")
    rel = relpath(p, root)
    records = [r for r in manifest["files"] if r["path"] == rel]
    length(records) == 1 || error("payload is not uniquely listed in reduced manifest")
    record = only(records)
    bytes2hex(open(sha256, p)) == record["sha256"] || error("reduced ROOT payload checksum mismatch")
    bytes2hex(open(sha256, p * ".cascade.json")) == record["sidecar_sha256"] || error("reduced sidecar checksum mismatch")
    meta = _plain(JSON3.read(read(p * ".cascade.json", String)))
    meta["schema"] == 1 || error("unsupported reduced sidecar schema")
    meta["retained_nevents"] isa Integer && 0 <= meta["retained_nevents"] <= 1_000_000 || error("invalid retained count")
    meta["original_nevents"] isa Integer && meta["original_nevents"] >= meta["retained_nevents"] || error("invalid original population")
    meta["population"] == record["population"] || error("reduced population mismatch")
    meta["sample"] == record["sample"] || error("reduced sample mismatch")
    if meta["kind"] == "mc"
        n = meta["normalization"]
        n["status"] == "available" && n["value"] isa Real && !(n["value"] isa Bool) && isfinite(n["value"]) ||
            error("missing or malformed original MC normalization")
    end
    meta["payload_sha256"] = record["sha256"]
    meta["sidecar_sha256"] = record["sidecar_sha256"]
    meta["bundle_id"] = id
    meta["manifest_sha256"] = bytes2hex(open(sha256, joinpath(root, "manifest.json")))
    return meta
end
