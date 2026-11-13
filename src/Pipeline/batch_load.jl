"""Load a frozen manifest and fail closed on configuration, code, payload or inventory drift."""
function batch_load(work; task_id = nothing)
    work = abspath(work)
    batch_safe_path(work)
    for name in ("manifest.json", "locks", "attempts", "receipts", "merges", "launches", "result")
        batch_safe_path(joinpath(work, name); root = work)
    end
    islink(joinpath(work, "manifest.json")) && error("symlink manifest")
    m = _jsdict(JSON3.read(read(joinpath(work, "manifest.json"), String)))
    body = copy(m); id = pop!(body, "id")
    batch_hash(body) == id || throw(ArgumentError("batch manifest checksum mismatch"))
    m["schema"] == 1 || error("unsupported batch schema")
    m["host"] == batch_host() || error("batch is local-host only")
    bytes2hex(open(sha256, m["config"])) == m["config_sha256"] || error("batch configuration changed")
    cfg = load_analysis(m["config"]; profile = m["profile"])
    checkpoints_enabled(cfg) || throw(ArgumentError("batch execution requires execution.checkpoints=true"))
    batch_validate_names(cfg)
    validate_reduced_inputs(cfg, [sample_by_name(cfg, n) for n in m["samples"]]; max_files = Int(m["max_files"]), verify_payloads = task_id === nothing)
    batch_hash(cfg.raw) == batch_hash(m["resolved"]) || error("resolved batch configuration changed")
    batch_hash(batch_fingerprint(cfg)) == batch_hash(m["fingerprint"]) || error("batch source/runtime/payload/hook contract changed")
    tasks = m["tasks"]
    length(unique(t["id"] for t in tasks)) == length(tasks) || error("duplicate manifest tasks")
    expected = Any[]
    for name in m["samples"]
        s = sample_by_name(cfg, name)
        current = [Dict("path" => p, "identity" => batch_input_identity(p)) for p in expand_files(s.files)]
        batch_hash(current) == batch_hash(m["inventory"][name]) || error("batch discovered input inventory changed: $name")
        discovered = [x["path"] for x in current]
        limit = Int(m["max_files"])
        selected = limit > 0 ? discovered[1:min(limit, length(discovered))] : discovered
        if s.format == "reduced_rntuple_group"
            current_groups = reduced_group_inventory(cfg, s, limit; verify_payloads = false)
            batch_hash(current_groups["files"]) == batch_hash(m["skims"][name]["files"]) &&
                batch_hash(current_groups["groups"]) == batch_hash(m["skims"][name]["groups"]) || error("wrong frozen logical/physical partition")
        else
            [e["path"] for e in m["skims"][name]["files"]] == selected || error("wrong frozen file partition")
        end
        for e in m["skims"][name]["files"]
            e["chunk"] == chunk_id(e["path"]) || error("wrong manifest chunk ID")
            is_mc(s) && s.format != "reduced_rntuple_group" && (get(e["normalization"], "status", "") != "available" ||
                e["normalization"]["value"] != e["gen_weight_sum"]) && error("wrong nominal normalization provenance")
            identity = if task_id !== nothing && s.format == "reduced_rntuple_group"
                frozen = only(t for t in tasks if t["sample"] == name && t["entry"]["chunk"] == e["chunk"])
                frozen["id"] == task_id ? batch_input_identity(e["path"]) : frozen["identity"]
            else
                batch_input_identity(e["path"])
            end
            t = Dict{String,Any}("sample" => name, "entry" => e, "identity" => identity)
            t["id"] = batch_hash(t); push!(expected, t)
        end
    end
    batch_hash(tasks) == batch_hash(expected) || error("batch task/input identity mismatch")
    return m, cfg
end
