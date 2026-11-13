"""
    step_fit(ctx::StepContext) -> Dict

Run the `:fit` hook on the templates (`fit/result.json`; the default hook also
writes `fit/workspace.json` and `fit/result.txt`, see [`default_fit`](@ref)).
"""
function step_fit(ctx::StepContext)
    ctx.input_scope === nothing || error("worker shard scope cannot certify a global stage or complete logical population")
    validate_reduced_skim(ctx)
    src = joinpath(ctx.workdir, "systematics", "templates.json")
    m = require_artifact(src, "systematics")
    f, id = hook_for(ctx.config, :fit)
    out = joinpath(ctx.workdir, "fit", "result.json")
    key = artifact_key("fit", m["key"], section_hash(ctx.config, "fit"), id, code_hash(["Fit", "Histograms", "Systematics", "Config", "Pipeline"]))
    templates=read_store(src)
    Systematics.verify_theory_extraction(ctx.config,templates)
    !ctx.options.force && is_up_to_date(out, key) && return Dict("run" => 0, "skipped" => 1)
    result = Base.invokelatest(f, ctx, templates)
    mkpath(dirname(out))
    write(out, JSON3.write(result))
    write_meta(out, key; step = "fit", hook = id)
    return Dict("run" => 1, "skipped" => 0)
end
