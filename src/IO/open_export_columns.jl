"""Open bounded eager cols input for reduced export without trusting allocation headers.

This compatibility-only reader leaves generic serial ColumnFileSource behavior
unchanged. File/header budgets, primitive descriptors, all row/content arithmetic,
actual available bytes and jagged offsets are checked BEFORE payload vectors are
allocated. The validated header and payload use the SAME open file; no unsafe
second parse/reopen is performed. Metadata/header allocation itself is capped.
"""
function open_export_columns(path::AbstractString; gen_weight::AbstractString = "genWeight",
                             max_input_bytes = 256_000_000, max_events = 1_000_000,
                             max_payload_bytes = 256_000_000, max_buffer_bytes = 1_024_000_000,
                             max_header_bytes = 1_000_000)
    before = stat(path)
    isfile(before) || error("cols compatibility input is not a regular file")
    before.size <= max_input_bytes || error("cols compatibility input exceeds max_input_bytes before parsing")
    return open(path, "r") do io
        seekend(io); available = position(io); seekstart(io)
        available <= max_input_bytes || error("cols compatibility input exceeds max_input_bytes before parsing")
        available >= 16 || error("truncated cols compatibility prefix")
        read(io, 8) == COLFILE_MAGIC || error("invalid cols compatibility magic")
        header_bytes = ltoh(read(io, UInt64))
        0 < header_bytes <= min(max_header_bytes, max_buffer_bytes ÷ 16) || error("cols compatibility header exceeds bounded header budget")
        header_bytes <= available - 16 || error("truncated cols compatibility header")
        header = JSON3.read(read(io, Int(header_bytes)))
        haskey(header, :version) && header[:version] isa Integer && !(header[:version] isa Bool) && header[:version] == 1 || error("unsupported cols compatibility version")
        haskey(header, :meta) && header[:meta] isa JSON3.Object || error("invalid cols compatibility metadata")
        haskey(header, :columns) && header[:columns] isa JSON3.Array || error("invalid cols compatibility descriptors")
        meta = _plain(header[:meta]); order = String[]; seen = Set{String}()
        descriptors = Any[]; rows = nothing; payload_position = Int128(16) + header_bytes
        payload_bytes = Int128(0); offset_bytes = Int128(0)
        for d in header[:columns]
            d isa JSON3.Object || error("invalid cols compatibility descriptor")
            all(k -> haskey(d, k), (:name, :eltype, :jagged, :length, :content_length)) || error("missing cols compatibility descriptor fields")
            d[:name] isa AbstractString && !isempty(d[:name]) || error("invalid cols compatibility column name")
            name = String(d[:name]); name in seen && error("duplicate cols compatibility column")
            push!(seen, name); push!(order, name)
            d[:eltype] isa AbstractString && haskey(COLFILE_TYPES, String(d[:eltype])) || error("unsupported cols compatibility primitive")
            T = COLFILE_TYPES[String(d[:eltype])]
            d[:jagged] isa Bool || error("invalid cols compatibility jagged flag")
            n = _export_column_count(d[:length], "rows")
            m = _export_column_count(d[:content_length], "content")
            n <= max_events || error("cols compatibility declared rows exceed max_events before allocation")
            rows === nothing ? (rows = n) : rows == n || error("inconsistent cols compatibility row counts")
            jagged = d[:jagged]
            !jagged && m != n && error("inconsistent cols compatibility scalar content length")
            offsets = jagged ? 8 * (n + 1) : Int128(0)
            bytes = offsets + Int128(sizeof(T)) * m
            bytes <= max_payload_bytes && payload_bytes + bytes <= max_payload_bytes || error("cols compatibility declared payload exceeds byte budget before allocation")
            payload_position + bytes <= available || error("truncated cols compatibility payload before allocation")
            push!(descriptors, (name = name, T = T, jagged = jagged, n = Int(n), m = Int(m), position = Int(payload_position)))
            payload_position += bytes; payload_bytes += bytes; offset_bytes += offsets
        end
        payload_position == available || error("unexpected trailing cols compatibility bytes")
        if rows === nothing
            rows = _export_column_count(get(meta, "nevents", 0), "metadata rows")
            rows <= max_events || error("cols compatibility metadata rows exceed max_events")
        end
        estimate = payload_bytes + offset_bytes + 16 * Int128(header_bytes) + 4096 * length(descriptors)
        estimate <= max_buffer_bytes || error("cols compatibility eager allocation exceeds max_buffer_bytes before allocation")
        # Fixed-size verification workspaces only, independent of declared N/content.
        for d in descriptors
            seek(io, d.position)
            d.jagged && _export_column_offsets(io, d.n, d.m)
            if d.T === Bool
                _export_column_bools(io, d.m)
            end
        end
        cols = Dict{String,Any}()
        for d in descriptors
            seek(io, d.position)
            if d.jagged
                offsets = read!(io, Vector{Int64}(undef, d.n + 1))
                content = read!(io, Vector{d.T}(undef, d.m))
                cols[d.name] = Jagged(content, Vector{Int}(offsets))
            else
                cols[d.name] = read!(io, Vector{d.T}(undef, d.n))
            end
        end
        after = stat(path)
        (before.device, before.inode, before.size, before.mtime) ==
            (after.device, after.inode, after.size, after.mtime) || error("cols compatibility source changed during bounded open")
        return ColumnFileSource(String(path), cols, meta, order, String(gen_weight))
    end
end
