"""
    run_step(step::Symbol, ctx::StepContext) -> Dict

Dispatch to the implementation of `step`; returns run/skipped counts.
"""
function run_step(step::Symbol, ctx::StepContext)
    checkpoints_enabled(ctx.config) || throw(ArgumentError("execution.checkpoints=false: staged step $step reads and writes " *
        "per-file checkpoints; use run_pipeline / `cascade run` with an admitted full chain (docs/NO_CHECKPOINTS.md)"))
    impl = Dict(:skim => step_skim, :select => step_select, :correct => step_correct,
                :histogram => step_histogram, :merge => step_merge, :systematics => step_systematics,
                :fit => step_fit, :plot => step_plot)
    return benchmark_span(() -> impl[step](ctx), step, ctx.workdir)
end
