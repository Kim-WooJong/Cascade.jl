"""
    advance_selection!(progress, sel, ctx, limit)

Advance only alive events and only new cuts (at, limit]. Object indices remain
in progress.objs for subsequent reads and final output. Compact active entries
in place; refine one persistent read mask instead of rescanning all events and
allocating another mask for every column group. No cutflow or weights recorded.
Entered through Base.invokelatest because the cut kernels are runtime-compiled.
"""
function advance_selection!(progress::SelectionProgress, sel, ctx, limit::Int)
    hi = min(limit, length(sel.cuts))
    hi >= progress.at || error("selection progress cannot move backwards")
    hi == progress.at && return progress
    written = 0
    lo = progress.at
    for i in progress.active
        progress.passed[i] == lo || error("inconsistent active selection stage")
        progress.current[] = i
        s, _, failed = _advance_cuts(sel.cuts, sel, ctx, i, 1, lo, hi, lo,
                                    _progress_built(sel, lo))
        progress.passed[i] = s
        progress.failed[i] = failed
        if failed
            progress.needed[i] = s >= sel.keep_stage
        else
            written += 1
            progress.active[written] = i
        end
    end
    resize!(progress.active, written)
    progress.at = hi
    return progress
end

@inline _advance_cuts(::Tuple{}, sel, ctx, i, k, lo, hi, s, built) = (s, built, false)
@inline function _advance_cuts(cuts::Tuple, sel, ctx, i, k, lo, hi, s, built)
    k > hi && return (s, built, false)
    if k > lo
        if sel.mat_at != 0 && k >= sel.mat_at
            sel.materialize(ctx, i, built, k)
            built = k
        end
        first(cuts)(ctx, i) || return (s, built, true)
        s = k
    end
    return _advance_cuts(Base.tail(cuts), sel, ctx, i, k + 1, lo, hi, s, built)
end
