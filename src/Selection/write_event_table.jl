"""
    write_event_table(path, t::EventTable) -> path

Store an `EventTable` as a Cascade column file (bit-exact round trip).
"""
write_event_table(path::AbstractString, t::EventTable) =
    write_column_file(path, t.columns; order = t.order, meta = t.meta)
