"""Copy complete original lists/scalars in original-entry order, never masked placeholders."""
function reduced_raw_columns(src, names, entries, limit)
    raw = read_columns(src, names) # Deliberately no needed mask: no placeholder values are exported.
    reduced_column_schema(raw, nevents(src); max_payload_bytes = limit)
    out = Dict{String,Any}()
    for name in names
        c = raw[name]
        out[name] = c isa Jagged ? Jagged([collect(c[i]) for i in entries]) : c[entries]
    end
    out["cascade_source_entry"] = Int64.(entries)
    return out
end
