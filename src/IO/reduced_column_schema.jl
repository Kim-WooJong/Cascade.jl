"""Validate primitive scalar/jagged columns, lengths, counters and bounded payload."""
function reduced_column_schema(cols, n; max_payload_bytes = 64_000_000)
    isempty(cols) && error("reduced schema must contain columns")
    length(cols) <= 256 || error("reduced schema exceeds 256-column conservative limit")
    bytes = Int128(0)
    schema = Any[]
    for name in sort!(collect(keys(cols)))
        c = cols[name]
        c isa AbstractVector || c isa Jagged || error("unsupported column $name")
        length(c) == n || error("event length mismatch: $name")
        data = c isa Jagged ? c.content : c
        T = eltype(data)
        haskey(COLFILE_TYPES, string(T)) || error("unsupported primitive type $T for $name")
        bytes += Int128(sizeof(T)) * length(data)
        if c isa Jagged
            length(c.offsets) == n + 1 && first(c.offsets) == 0 && last(c.offsets) == length(data) &&
                issorted(c.offsets) || error("invalid jagged offsets: $name")
            bytes += 8 * Int128(n + 1)
            counter = "n" * first(split(name, '_'))
            if haskey(cols, counter)
                counts = cols[counter]
                counts isa AbstractVector && eltype(counts) <: Integer && !(eltype(counts) <: Bool) || error("invalid counter $counter")
                all(i -> counts[i] == c.offsets[i+1] - c.offsets[i], 1:n) || error("counter mismatch: $name")
            end
        end
        push!(schema, Dict("name" => name, "eltype" => string(T), "jagged" => c isa Jagged))
    end
    bytes <= max_payload_bytes || error("reduced payload exceeds conservative $max_payload_bytes byte limit")
    return schema, Int(bytes)
end
