"""Opt-in stage-global read/analysis window budgets; never scientific parameters."""
function streaming_selection_options(raw::AbstractDict; validate_relations::Bool = true)
    e = get(raw, "execution", Dict())
    e isa AbstractDict || throw(ArgumentError("execution must be a table"))
    enabled = get(e, "streaming_selection", false)
    enabled isa Bool || throw(ArgumentError("execution.streaming_selection must be boolean"))
    defaults = (stream_window_events=20_000, stream_active_files=16, stream_queue_windows=32,
        stream_queue_bytes=8*1024^3, stream_window_bytes=64*1024^2,
        stream_basket_bytes=64*1024^2, stream_metadata_bytes=64*1024^2,
        stream_retained_bytes=8*1024^3)
    values = map(keys(defaults)) do key
        value = get(e, String(key), getproperty(defaults,key))
        value isa Integer && !(value isa Bool) && 1 <= value <= typemax(Int) ||
            throw(ArgumentError("execution.$key must be a positive integer"))
        Int(value)
    end
    out = NamedTuple{keys(defaults)}(Tuple(values))
    serial_windows = windowed_selection(raw)
    ranges = event_range_selection(raw)
    if validate_relations && enabled && !serial_windows && !ranges
        d = decode_options(raw)
        d.threads == 1 && column_readers(raw) == 1 ||
            throw(ArgumentError("streaming_selection requires decode_threads=1 and column_readers=1"))
    end
    if validate_relations && (enabled || serial_windows || ranges)
        out.stream_metadata_bytes < out.stream_queue_bytes ||
            throw(ArgumentError("stream metadata reservation must leave window queue capacity"))
    end
    # Preserve the public requested flag (including memory_handoff guards).
    # prepare_select suppresses async dispatch only for a serial-window request.
    return merge((enabled=enabled,),out)
end
streaming_selection_options(cfg::AnalysisConfig; validate_relations::Bool = true) =
    streaming_selection_options(cfg.raw; validate_relations)
