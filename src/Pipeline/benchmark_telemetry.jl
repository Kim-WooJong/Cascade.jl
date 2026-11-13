# Opt-in bounded diagnostic spans; never attributes process CPU to a task.
mutable struct BenchmarkTrace
    io::Base.Filesystem.File
    lock::ReentrantLock
    sequence::UInt64
    pending::Int
    directory::String
    records::Int
    limit::Int
end
const BENCHMARK_TRACE = Ref{Union{Nothing,BenchmarkTrace}}(nothing)
const BENCHMARK_TRACE_INIT_LOCK = ReentrantLock()

function benchmark_trace(workdir)
    directory = get(ENV, "CASCADE_BENCHMARK_TRACE_DIR", "")
    isempty(directory) && return nothing
    isabspath(directory) || throw(ArgumentError("CASCADE_BENCHMARK_TRACE_DIR must be absolute"))
    isdir(directory) || throw(ArgumentError("CASCADE_BENCHMARK_TRACE_DIR must exist"))
    function resolved(path)
        p = abspath(path)
        suffix = String[]
        while !ispath(p)
            push!(suffix, basename(p)); p = dirname(p)
        end
        return normpath(joinpath(realpath(p), reverse(suffix)...))
    end
    directory = realpath(directory)
    root = resolved(workdir)
    rel = relpath(directory, root)
    (rel == "." || !(rel == ".." || startswith(rel, "../"))) &&
        throw(ArgumentError("benchmark trace directory must be outside scientific workdir"))
    limit = tryparse(Int, get(ENV, "CASCADE_BENCHMARK_TRACE_MAX_RECORDS", "200000"))
    (limit !== nothing && 2 <= limit <= 1000000) ||
        throw(ArgumentError("CASCADE_BENCHMARK_TRACE_MAX_RECORDS must be 2..1000000"))
    return lock(BENCHMARK_TRACE_INIT_LOCK) do
        existing = BENCHMARK_TRACE[]
        if existing !== nothing
            existing.directory == directory || throw(ArgumentError("trace directory cannot change within a process"))
            return existing
        end
        path = joinpath(directory, "stages-$(getpid())-$(time_ns()).jsonl")
        io = Base.Filesystem.open(path, Base.Filesystem.JL_O_WRONLY | Base.Filesystem.JL_O_CREAT | Base.Filesystem.JL_O_EXCL, 0o600)
        trace = BenchmarkTrace(io, ReentrantLock(), 0, 0, directory, 0, limit)
        BENCHMARK_TRACE[] = trace
        atexit(() -> close(io))
        return trace
    end
end

function benchmark_record!(trace::BenchmarkTrace, record)
    trace.records < trace.limit || error("benchmark trace record bound exceeded")
    write(trace.io, JSON3.write(record), '\n')
    flush(trace.io)
    trace.records += 1
end

# f::F (where F) only forces specialization through the keyword wrapper, so the source-defined
# stage closures are reachable from the declared NoCheckpointFileWork instances; body unchanged.
function benchmark_span(f::F, stage, workdir; sample = nothing, chunk = nothing) where {F}
    # Disabled: one environment lookup, no clocks/IDs/files/sampler.
    trace = benchmark_trace(workdir)
    trace === nothing && return f()
    stage_label = String(stage)
    sample_label = sample === nothing ? nothing : String(sample)
    chunk_label = chunk === nothing ? nothing : string(chunk)
    all(x -> x === nothing || ncodeunits(x) <= 4096, (stage_label, sample_label, chunk_label)) ||
        throw(ArgumentError("benchmark trace labels must be at most 4096 bytes"))
    owner_task = current_task() # keep task identity live through the span
    id = lock(trace.lock) do
        trace.records + trace.pending + 2 <= trace.limit || error("benchmark trace record bound exceeded")
        trace.sequence += 1
        id = string(getpid(), ":", trace.sequence)
        benchmark_record!(trace, (; schema_version = 1, event = "begin", span_id = id,
            pid = getpid(), task_id = string(objectid(owner_task)), stage = stage_label,
            sample = sample_label, chunk = chunk_label, monotonic_ns = time_ns(),
            resource_scope = "process_nonadditive"))
        trace.pending += 1
        id
    end
    status = "failed"
    try
        value = f()
        status = "completed"
        return value
    finally
        lock(trace.lock) do
            trace.pending -= 1
            benchmark_record!(trace, (; schema_version = 1, event = "end", span_id = id,
                pid = getpid(), task_id = string(objectid(owner_task)), stage = stage_label,
                sample = sample_label, chunk = chunk_label, monotonic_ns = time_ns(),
                resource_scope = "process_nonadditive", status))
        end
    end
end
