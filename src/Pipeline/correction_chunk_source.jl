"""Choose invocation-local reuse only for known hooks and unchanged built-in readers.

Custom hooks retain source === nothing, including wrappers around built-ins.
Custom/replaced readers retain their historical open/close-per-reader lifetime.
"""
function correction_chunk_source(f, sample, path)
    (f === default_correct || f === Systematics.apply_corrections) || return nothing
    builtin_source_readers() || return nothing
    sample.format in ("nanoaod", "cols", "reduced_rntuple", "reduced_rntuple_group", "reduced_rntuple_shard") || return nothing
    return LazyEventSource(sample.format, path; options = get(sample.raw, "source", Dict()))
end
