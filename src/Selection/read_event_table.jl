"""
    read_event_table(path) -> EventTable

Load an `EventTable` written by `write_event_table`.
"""
function read_event_table(path::AbstractString)
    cols, meta, order = read_column_file(path)
    return EventTable(Dict{String,Vector}(k => v for (k, v) in cols), order, meta)
end
