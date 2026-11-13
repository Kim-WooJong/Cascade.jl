"""
    run_selection(sel::CompiledSelection, src::AbstractEventSource;
                  stream = "", lumimask = nothing, sample = "") -> (EventTable, Cutflow)

Process one chunk. Columns needed by object-free leading cuts (and weights,
builtins) are read for all events; object columns only where those cuts pass
(sources may skip unneeded baskets). The ordinary serial NanoAOD reader also
defers later post columns until their first dependent cut, carrying forward
passed cuts, selected object indices, one read mask and file-local counter
metadata. Full event indices are retained. Decode/parallel/custom-source paths
keep the conservative prefix read.
Builtins: `trigger` (from
`sel.triggers`, `stream`) and `lumimask` (`IO.LumiMask`; all true if
`nothing`). See `read_selection_columns` and `select_events`.
"""
function run_selection(sel::CompiledSelection, src::AbstractEventSource;
                       stream::AbstractString = "", lumimask = nothing, sample::AbstractString = "", cutflow = nothing,
                       column_readers::Integer = 1, decode_threads = 1, decode_queue_jobs = 32, decode_queue_bytes = 64*1024^2, execution_diagnostics::Dict{String,Any} = Dict{String,Any}())
    (decode_threads == "auto" || (decode_threads isa Integer && !(decode_threads isa Bool) && 1 <= decode_threads <= typemax(Int))) || throw(ArgumentError("invalid decode_threads"))
    if decode_threads != 1
        !(column_readers isa Bool) && column_readers == 1 || throw(ArgumentError("decode and column reader engines cannot be combined"))
        return with_decode_pipeline(src; threads = decode_threads, queue_jobs = decode_queue_jobs,
                                    queue_bytes = decode_queue_bytes, diagnostics = execution_diagnostics) do decode_scope
            raw, _, progress = _read_selection_columns(sel, src; stream, lumimask, decode_scope,
                reuse=!isempty(sel.variable_nodes))
            select_events(sel, raw, nevents(src); sample, cutflow, progress)
        end
    end
    return with_column_readers(src; readers = column_readers, diagnostics = execution_diagnostics) do reader_scope
        raw, _, progress = _read_selection_columns(sel, src; stream, lumimask, reader_scope, reuse = true)
        select_events(sel, raw, nevents(src); sample, cutflow, progress)
    end
end
