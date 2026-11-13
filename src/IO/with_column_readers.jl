"""Borrow a source for one invocation and finally close only extra slots.

Extra handles are opened lazily, once per slot across pre/post phases. Serial,
ineligible and one-thread execution retain read_columns with no extra handles.
"""
function with_column_readers(run, src::AbstractEventSource; readers::Integer = 1,
                             diagnostics::Dict{String,Any} = Dict{String,Any}())
    !(readers isa Bool) && 1 <= readers <= 4 || throw(ArgumentError("column readers must be in 1:4"))
    reason = readers == 1 ? "serial_requested" : column_read_eligibility(src)
    width = min(Int(readers), Threads.nthreads())
    isempty(reason) && width == 1 && (reason = "one_thread")
    merge!(diagnostics, Dict("requested_readers" => Int(readers), "effective_readers" => 1,
        "fallback" => isempty(reason) ? "empty_or_single_column" : reason,
        "max_active_reads" => 0, "extra_opens" => 0, "extra_closes" => 0,
        "branch_jobs" => 0, "counter_reads" => 0))
    isempty(reason) || return run(nothing)
    identity = column_source_identity(src)
    if identity === nothing
        diagnostics["fallback"] = "unbound_mmap_identity"
        return run(nothing)
    end
    scope = ColumnReadScope(src, width, Any[src],
        () -> open_column_reader(src, identity),
        close_source, (s, name, needed, offsets) -> read_nanoaod_branch(s.file, s.tree, name; needed, offsets),
        () -> (column_source_identity(src) == identity || error("column reader source drift after read")),
        diagnostics, ReentrantLock(), 0)
    return with_column_read_scope(run, scope)
end
