"""
    step_correct(ctx::StepContext) -> Dict

Per chunk, compute the weight columns (nominal + variations) of the kept
events with the `:correct` hook (`correct/<sample>/<chunk>.cols`). For every
shape-variation table of the chunk the hook is called again
(`CorrectionContext.variation` = label) and its `"nominal"` weights are stored
in `correct/<sample>/<chunk>.<label>.cols`.
"""
function step_correct(ctx::StepContext)
    validate_reduced_skim(ctx)
    prepared = prepare_correct(ctx)
    tasks = Any[]; nskip = 0
    for s in ctx.samples
        for e in read_skim(ctx.workdir, s.name)["files"]
            sel = chunk_path(ctx.workdir, :select, s.name, e["chunk"], ".cols")
            m = require_artifact(sel, "select")
            (; key, out) = correct_chunk_spec(ctx, prepared, s, e, m)
            if !ctx.options.force && is_up_to_date(out, key)
                nskip += 1
                continue
            end
            push!(tasks, (s, String(e["path"]), sel, out, key, e["chunk"], String.(get(m, "shape", String[]))))
        end
    end
    isempty(tasks) || reset_correction_cache!()
    run_tasks(tasks; label = "correct") do (s, path, sel, out, key, chunk, labels)
        execute_correct_chunk(ctx, prepared, (s, path, sel, out, key, chunk, labels))
        nothing
    end
    return Dict("run" => length(tasks), "skipped" => nskip)
end

function _correct_weights(f, c::CorrectionContext, n::Int)
    w = Base.invokelatest(f, c)
    haskey(w, NOMINAL) || error("correct hook returned no '$(NOMINAL)' weights")
    for (k, v) in w
        length(v) == n || error("correct hook: weight '$k' has $(length(v)) entries, expected $n")
    end
    return w
end
