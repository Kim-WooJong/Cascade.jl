"""
    event_loop!(sel, ctx, n, cf, entry, stage, weight, outs)

Run the compiled selection over events `1:n`: record the cutflow for every
event and append kept events (`passed >= sel.keep_stage`) to the output
vectors. Must be entered via `Base.invokelatest` (kernels are runtime-compiled).
"""
function _event_loop_recording!(sel::CompiledSelection, ctx, n::Int, cf::Cutflow, entry::Vector{Int64},
                                stage::Vector{Int16}, weight::Vector{Float64}, outs::Vector{Vector{Float64}},
                                ledger, ::Val{Record}) where {Record}
    keep = sel.keep_stage
    for i in 1:n
        s, built = apply_cuts(sel.cuts, sel, ctx, i)
        w = sel.weight(ctx, i)
        _record_selection_event!(cf, s, w, ledger, i, Val(Record))
        if s >= keep
            # A retained early-region event may have failed before later objects
            # were needed. Complete those and output-only objects for this event;
            # never read buffers left over from the preceding event.
            sel.materialize(ctx, i, built, typemax(Int))
            push!(entry, i); push!(stage, Int16(s)); push!(weight, w)
            vals = sel.outputs(ctx, i, s)
            for k in eachindex(outs)
                push!(outs[k], vals[k])
            end
        end
    end
    return nothing
end

"""Finish the ordinary incremental route without replaying already evaluated cuts.
Record weights/cutflow once, in original event order, after all required reads.
"""
function _event_loop_recording!(sel, ctx, n::Int, cf::Cutflow, entry::Vector{Int64},
                                stage::Vector{Int16}, weight::Vector{Float64}, outs::Vector{Vector{Float64}},
                                progress::SelectionProgress, ledger, ::Val{Record}) where {Record}
    keep = sel.keep_stage
    for i in 1:n
        progress.current[] = i
        s = progress.passed[i]
        failed = progress.failed[i]
        attempted = failed ? s + 1 : s
        built = _progress_built(sel, attempted)
        if !failed
            s, built, failed = _advance_cuts(sel.cuts, sel, ctx, i, 1, s,
                                             length(sel.cuts), s, built)
            progress.passed[i] = s
            progress.failed[i] = failed
        end
        w = sel.weight(ctx, i)
        _record_selection_event!(cf, s, w, ledger, i, Val(Record))
        if s >= keep
            # May append an older event's output-only object span after later
            # events. Per-event ranges, not a monotonic snapshot cursor, own it.
            sel.materialize(ctx, i, built, typemax(Int))
            push!(entry, i); push!(stage, Int16(s)); push!(weight, w)
            vals = sel.outputs(ctx, i, s)
            for k in eachindex(outs)
                push!(outs[k], vals[k])
            end
        end
    end
    return nothing
end

# Keep established entry points; specialization compiles out ledger work when off.
@inline function _record_selection_event!(cf, s, w, ledger, i, ::Val{Record}) where {Record}
    ledger.stage[i] = s
    ledger.weight[i] = w
    Record && record!(cf, s, w)
    return nothing
end
@inline function _record_selection_event!(cf, s, w, ::Nothing, i, ::Val{Record}) where {Record}
    Record && record!(cf, s, w)
    return nothing
end

function event_loop!(sel::CompiledSelection, ctx, n::Int, cf::Cutflow, entry::Vector{Int64},
                     stage::Vector{Int16}, weight::Vector{Float64}, outs::Vector{Vector{Float64}})
    return _event_loop_recording!(sel, ctx, n, cf, entry, stage, weight, outs, nothing, Val(true))
end
function event_loop!(sel, ctx, n::Int, cf::Cutflow, entry::Vector{Int64},
                     stage::Vector{Int16}, weight::Vector{Float64}, outs::Vector{Vector{Float64}},
                     progress::SelectionProgress)
    return _event_loop_recording!(sel, ctx, n, cf, entry, stage, weight, outs, progress, nothing, Val(true))
end
