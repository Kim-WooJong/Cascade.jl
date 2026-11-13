"""Verify a schema2 logical source, with optional sequential full-payload validation.

Normalization belongs to this complete ordered group, never to a physical
shard. Metadata-only mode is for explicit worker/task scope and signatures;
coordinators must request full validation before global normalization.
"""
function read_reduced_group(path; verify_payloads = true)
    p = abspath(path); root = dirname(dirname(p))
    reduced_safe_path(root, relpath(p, root))
    manifestpath = reduced_safe_path(root, "manifest.json")
    filesize(p) <= 64_000_000 && filesize(manifestpath) <= 64_000_000 || error("reduced metadata exceeds reader budget")
    manifest = _plain(JSON3.read(read(manifestpath, String)))
    manifest["schema"] == 2 || error("unsupported grouped reduced schema")
    body = copy(manifest); id = pop!(body, "id")
    reduced_metadata_hash(body) == id || error("reduced manifest checksum mismatch")
    length(unique(r["path"] for r in manifest["groups"])) == length(manifest["groups"]) &&
        length(unique(r["group_id"] for r in manifest["groups"])) == length(manifest["groups"]) || error("duplicate manifest logical source")
    records = [r for r in manifest["groups"] if r["path"] == relpath(p, root)]
    length(records) == 1 || error("logical descriptor not uniquely listed")
    record = only(records)
    bytes2hex(open(sha256, p)) == record["sha256"] || error("logical descriptor checksum mismatch")
    g = _plain(JSON3.read(read(p, String)))
    g["schema"] == 2 && g["group_id"] == record["group_id"] && g["sample"] == record["sample"] || error("logical source identity mismatch")
    g["population"] == record["population"] || error("logical population mismatch")
    n = g["original_nevents"]; retained = g["retained_nevents"]
    n isa Integer && !(n isa Bool) && n >= 0 && retained isa Integer && 0 <= retained <= n || error("invalid logical counts")
    if g["kind"] == "mc"
        norm = g["normalization"]
        norm["status"] == "available" && _normalization_number(norm["value"]) || error("missing or invalid original normalization")
    end
    length(unique(d["name"] for d in g["columns"])) == length(g["columns"]) <= 256 || error("invalid logical schema names")
    shards = g["shards"]; isempty(shards) && error("logical source requires a carrier")
    length(shards) <= 1_000_000 || error("logical shard metadata limit exceeded")
    nextentry = 1; nextrow = 1; paths = Set{String}()
    for (i, r) in enumerate(shards)
        all(k -> r[k] isa Integer && !(r[k] isa Bool), ("ordinal", "source_begin", "source_end", "retained_begin", "nevents", "payload_bytes")) || error("invalid shard integer metadata")
        r["ordinal"] == i && !(r["path"] in paths) || error("duplicate or reordered shard")
        push!(paths, r["path"])
        r["source_begin"] == nextentry && r["source_end"] >= r["source_begin"] - 1 || error("gapped or overlapping source coverage")
        r["retained_begin"] == nextrow && 0 <= r["nevents"] <= 1_000_000 || error("gapped retained coverage")
        r["nevents"] <= r["source_end"] - r["source_begin"] + 1 || error("shard population exceeds coverage")
        r["columns"] == g["columns"] || error("inconsistent shard schema")
        nextentry = r["source_end"] + 1; nextrow += r["nevents"]
    end
    nextentry == n + 1 && nextrow == retained + 1 || error("incomplete logical source coverage")
    n == 0 && length(shards) != 1 && error("empty source must have one carrier")
    g["bundle_id"] = id; g["manifest_sha256"] = bytes2hex(open(sha256, manifestpath))
    g["descriptor_sha256"] = record["sha256"]; g["descriptor_path"] = p; g["bundle_root"] = root
    if verify_payloads
        for r in shards
            shard = reduced_safe_path(root, r["path"])
            metadata = read_reduced_shard(shard; group = g)
            source = ReducedShardSource(shard; metadata)
            close_source(source)
        end
    end
    return g
end
