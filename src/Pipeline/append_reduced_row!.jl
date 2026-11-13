"""Append one original typed event after checking its complete uncompressed footprint."""
function append_reduced_row!(buffer::ReducedShardBuffer, raw, row, entry, target)
    bytes = 8
    for c in values(raw)
        bytes += c isa Jagged ? sizeof(eltype(c.content)) * length(c[row]) + 8 : sizeof(eltype(c))
    end
    buffer.bytes + bytes <= target || error("single event or pending shard exceeds target_shard_payload_bytes")
    for (name, c) in raw
        out = buffer.columns[name]
        if c isa Jagged
            append!(out.content, c[row]); push!(out.offsets, length(out.content))
        else
            push!(out, c[row])
        end
    end
    push!(buffer.columns["cascade_source_entry"], Int64(entry))
    buffer.bytes += bytes
    return nothing
end
