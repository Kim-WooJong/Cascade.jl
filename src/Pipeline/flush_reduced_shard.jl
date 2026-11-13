"""Write one bounded native RNTuple and mandatory normalization-free sidecar."""
function flush_reduced_shard(buffer, stage, relative, group_path, group_id, ordinal,
                             source_begin, source_end, retained_begin, contract)
    path = batch_safe_path(joinpath(stage, relative); root = stage)
    columns, bytes = write_reduced_rntuple(path, buffer.columns)
    record = Dict{String,Any}("path" => relative, "ordinal" => ordinal,
        "source_begin" => source_begin, "source_end" => source_end,
        "retained_begin" => retained_begin, "nevents" => length(buffer.columns["cascade_source_entry"]),
        "columns" => columns, "payload_bytes" => bytes)
    sidecar = merge(record, Dict("schema" => 2, "group_path" => group_path,
        "group_id" => group_id, "contract" => contract))
    write(path * ".cascade.json", JSON3.write(sidecar))
    record["sha256"] = bytes2hex(open(sha256, path))
    record["sidecar_sha256"] = bytes2hex(open(sha256, path * ".cascade.json"))
    return record
end
