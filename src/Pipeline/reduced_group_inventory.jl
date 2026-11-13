"""Select complete logical originals before expanding bounded physical task entries.

A worker scope is explicit and permits processing only its pinned own shard;
it is not accepted as a complete-group normalization certificate.
"""
function reduced_group_inventory(cfg, sample, max_files; verify_payloads = true, scope = nothing)
    paths = expand_files(sample.files)
    selected = max_files > 0 ? paths[1:min(max_files, length(paths))] : paths
    groups = Any[]; files = Any[]; seen = Set{String}()
    if scope !== nothing
        g = read_reduced_group(scope["group"]["descriptor_path"]; verify_payloads = false)
        batch_hash(g) == batch_hash(scope["group"]) || error("worker logical group binding changed")
        read_reduced_shard(scope["entry"]["path"]; group = g)
        push!(groups, g)
    else
        for path in selected
            g = read_reduced_group(path; verify_payloads)
            identity = population_identity(g["population"])
            identity in seen && error("duplicate original normalization population in sample")
            push!(seen, identity); push!(groups, g)
        end
    end
    expected = reduced_contract(cfg, sample)
    for g in groups
        g["sample"] == sample.name && g["kind"] == String(sample.kind) && g["contract"] == expected || error("stale reduced logical retention/sample contract")
        for record in g["shards"]
            path = joinpath(g["bundle_root"], record["path"])
            scope !== nothing && path != scope["entry"]["path"] && continue
            signature = group_shard_signature(g, record)
            push!(files, Dict("path" => path, "chunk" => chunk_id(path), "signature" => signature,
                "nevents" => record["nevents"], "group_id" => g["group_id"], "ordinal" => record["ordinal"]))
        end
    end
    scope !== nothing && (length(files) != 1 || batch_hash(only(files)) != batch_hash(scope["entry"])) && error("worker physical task binding changed")
    available = isempty(groups) ? length(paths) : max(length(paths), maximum(g["coverage"]["available_nfiles"] for g in groups))
    return Dict{String,Any}("schema" => 2, "sample" => sample.name, "kind" => String(sample.kind),
        "groups" => groups, "files" => files, "available_nfiles" => available,
        "selected_nfiles" => length(groups), "physical_nfiles" => length(files),
        "truncated" => length(groups) < available || any(g["coverage"]["truncated"] for g in groups),
        "exposure_key" => canonical_hash(luminosity_spec(cfg)))
end
