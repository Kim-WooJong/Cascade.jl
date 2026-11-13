"""Execution-only detached basket budget; one preserves the original reader exactly."""
function decode_options(raw::AbstractDict)
    execution = get(raw, "execution", Dict())
    execution isa AbstractDict || throw(ArgumentError("execution must be a table"))
    threads = get(execution, "decode_threads", 1)
    (threads == "auto" || (threads isa Integer && !(threads isa Bool) && 1 <= threads <= typemax(Int))) ||
        throw(ArgumentError("execution.decode_threads must be a positive integer or auto"))
    values = map(("decode_queue_jobs", "decode_queue_bytes"), (32, 64 * 1024^2)) do key, default
        value = get(execution, key, default)
        value isa Integer && !(value isa Bool) && 1 <= value <= typemax(Int) ||
            throw(ArgumentError("execution.$key must be a positive integer"))
        Int(value)
    end
    (threads == "auto" || threads > 1) && column_readers(raw) > 1 &&
        throw(ArgumentError("decode_threads and column_readers cannot both be enabled"))
    return (threads = threads == "auto" ? threads : Int(threads), jobs = values[1], bytes = values[2])
end
decode_options(cfg::AnalysisConfig) = decode_options(cfg.raw)
