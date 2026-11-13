"""Open export inputs, preflighting eager cols before any payload allocation.

ROOT uses the existing unchanged reader/window path. Cols uses a validated
same-handle bounded opener; generic serial cols IO is deliberately unchanged.
"""
function open_export_source(sample, path, options)
    source_options = get(sample.raw, "source", Dict())
    if sample.format == "cols"
        all(k -> k == "gen_weight", keys(source_options)) || error("unsupported cols export source options")
        legacy = options["mode"] == "legacy_eager"
        return open_export_columns(path; gen_weight = get(source_options, "gen_weight", "genWeight"),
            max_input_bytes = legacy ? options["max_input_bytes"] : 256_000_000,
            max_events = legacy ? options["max_events"] : 1_000_000,
            max_payload_bytes = legacy ? options["max_payload_bytes"] : 256_000_000,
            max_buffer_bytes = options["max_buffer_bytes"])
    end
    return open_source(sample.format, path; options = source_options)
end
