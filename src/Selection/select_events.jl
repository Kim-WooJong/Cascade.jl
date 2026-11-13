"""
    select_events(sel, raw, n; sample = "", meta = Dict()) -> (EventTable, Cutflow)

Run the compiled selection over the `n` events of the columns `raw` (as
returned by `read_selection_columns`): cutflow of all events and the
`EventTable` of kept events. Entries of `meta` are added to the table meta.
"""
function select_events(sel::CompiledSelection, raw::AbstractDict, n::Int; sample::AbstractString = "",
                       meta::AbstractDict = Dict{String,Any}(), cutflow = nothing,
                       progress::Union{Nothing,SelectionProgress} = nothing,
                       all_event_stage::Union{Nothing,Vector{Int}} = nothing,
                       all_event_weight::Union{Nothing,Vector{Float64}} = nothing,
                       record_cutflow::Bool = true)
    (all_event_stage === nothing) == (all_event_weight === nothing) ||
        throw(ArgumentError("all-event stage and weight buffers must be provided together"))
    ledger = all_event_stage === nothing ? nothing : (stage=all_event_stage, weight=all_event_weight)
    ledger === nothing || (length(ledger.stage) == n && length(ledger.weight) == n) ||
        throw(ArgumentError("all-event ledger length must equal event count"))
    record_cutflow || ledger !== nothing ||
        throw(ArgumentError("record_cutflow=false requires an all-event ledger"))
    progress === nothing || length(progress.passed) == n || error("selection progress event count mismatch")
    ctx = progress === nothing ? selection_context(raw, sel, sel.collections; n) :
          _progress_context(raw, sel, sel.collections, progress)
    cf = cutflow === nothing ? Cutflow(vcat("all", sel.cut_names)) : cutflow
    cf.names == vcat("all", sel.cut_names) || error("persistent cutflow stage mismatch")
    entry = Int64[]; stage = Int16[]; weight = Float64[]
    outs = [Float64[] for _ in sel.output_names]
    if progress === nothing
        Base.invokelatest(_event_loop_recording!, sel, ctx, n, cf, entry, stage, weight, outs, ledger, Val(record_cutflow))
    else
        Base.invokelatest(_event_loop_recording!, sel, ctx, n, cf, entry, stage, weight, outs, progress, ledger, Val(record_cutflow))
    end

    columns = Dict{String,Vector}("entry" => entry, "stage" => stage, "weight" => weight)
    for (k, name) in enumerate(sel.output_names)
        columns[name] = outs[k]
    end
    order = vcat(["entry", "stage", "weight"], sel.output_names)
    m = Dict{String,Any}("sample" => String(sample), "kind" => String(sel.kind), "nevents" => n,
                         "cut_names" => sel.cut_names, "region_stage" => sel.region_stage,
                         "region_columns" => Dict(r => string("r:", r) for r in keys(sel.region_stage)),
                         "hist_columns" => sel.hist_columns, "cutflow" => cutflow_dict(cf))
    merge!(m, meta)
    table = EventTable(columns, order, m)
    m["regions"] = region_counts(table)
    return table, cf
end
