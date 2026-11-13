"""Validated execution-only column reader width (default one, maximum four)."""
function column_readers(raw::AbstractDict)
    execution = get(raw, "execution", Dict())
    execution isa AbstractDict || throw(ArgumentError("execution must be a table"))
    width = get(execution, "column_readers", 1)
    width isa Integer && !(width isa Bool) && 1 <= width <= 4 ||
        throw(ArgumentError("execution.column_readers must be an integer in 1:4"))
    return Int(width)
end
column_readers(cfg::AnalysisConfig) = column_readers(cfg.raw)
