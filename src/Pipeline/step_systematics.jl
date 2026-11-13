"""
    step_systematics(ctx::StepContext) -> Dict

Build fit templates from the merged store with the `:systematics` hook
(`systematics/templates.json`).
"""
function step_systematics(ctx::StepContext)
    ctx.input_scope === nothing || error("worker shard scope cannot certify a global stage or complete logical population")
    validate_reduced_skim(ctx)
    src = joinpath(ctx.workdir, "merge", "histograms.json")
    m = require_artifact(src, "merge")
    f, id = hook_for(ctx.config, :systematics)
    out = joinpath(ctx.workdir, "systematics", "templates.json")
    key = artifact_key("systematics", m["key"], section_hash(ctx.config, "systematics", "theory_weights"), id,
                       code_hash(["Systematics", "Pipeline"]))
    merged = Systematics.reduce_theory(ctx.config, read_store(src))
    !ctx.options.force && is_up_to_date(out, key) && return Dict("run" => 0, "skipped" => 1)
    templates = Base.invokelatest(f, ctx, merged)
    write_store(out, templates)
    write_meta(out, key; step = "systematics", hook = id)
    return Dict("run" => 1, "skipped" => 0)
end
