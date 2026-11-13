"""
    step_plot(ctx::StepContext) -> Dict

Run the `:plot` hook on the merged store and the fit result (if present);
the produced file list is recorded in `plot/index.json` (default hook: see
[`default_plot`](@ref)).
"""
function step_plot(ctx::StepContext)
    ctx.input_scope === nothing || error("worker shard scope cannot certify a global stage or complete logical population")
    validate_reduced_skim(ctx)
    src = joinpath(ctx.workdir, "merge", "histograms.json")
    m = require_artifact(src, "merge")
    fitp = joinpath(ctx.workdir, "fit", "result.json")
    mf = read_meta(fitp)
    f, id = hook_for(ctx.config, :plot)
    out = joinpath(ctx.workdir, "plot", "index.json")
    key = artifact_key("plot", m["key"], mf === nothing ? nothing : mf["key"], section_hash(ctx.config, "plot"), section_hash(ctx.config, "fit"), section_hash(ctx.config, "theory_weights"),
                       id, code_hash(["Plotting", "Fit", "Histograms", "Systematics", "Config", "Pipeline"]))
    store = Systematics.reduce_theory(ctx.config, read_store(src))
    !ctx.options.force && is_up_to_date(out, key) && return Dict("run" => 0, "skipped" => 1)
    fit = isfile(fitp) ? _jsdict(JSON3.read(read(fitp, String))) : nothing
    files = Base.invokelatest(f, ctx, store, fit)
    mkpath(dirname(out))
    write(out, JSON3.write(Dict("files" => files)))
    write_meta(out, key; step = "plot", hook = id)
    return Dict("run" => 1, "skipped" => 0)
end
