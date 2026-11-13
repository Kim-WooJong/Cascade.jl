"""Per-file reader width within the existing stage-wide file-worker budget."""
function column_reader_budget(requested::Integer, nfiles::Integer; threads::Integer = Threads.nthreads())
    !(requested isa Bool) && 1 <= requested <= 4 || throw(ArgumentError("column readers must be in 1:4"))
    nfiles >= 0 && threads >= 1 || throw(ArgumentError("invalid file/thread count"))
    return nfiles == 0 ? 1 : min(Int(requested), max(1, threads ÷ min(threads, nfiles)))
end
