import ..Fit   # area dependency of the default fit hook (exported API only)

"""
    default_fit(ctx::StepContext, templates::HistogramStore) -> Dict{String,Any}

Built-in `:fit` hook. Without a `[fit]` section the fit is skipped
(`status = "skipped"`). Otherwise the model is built from the templates and the
`[fit]` section (`Fit.fit_config`, `Fit.build_workspace`) and fitted
(`Fit.fit_report`: best fit, Hesse errors, profile interval, pulls, impacts,
optional upper limit / significance, pre/post-fit yields, counting
cross-check). Besides the returned report (`fit/result.json`) it writes the
fitted pyhf workspace `fit/workspace.json` and the text summary
`fit/result.txt`.
"""
function default_fit(ctx::StepContext, templates::HistogramStore)
    fc = Fit.fit_config(ctx.config)
    fc === nothing && return Dict{String,Any}("status" => "skipped", "reason" => "no [fit] section in the analysis",
                                              "n_templates" => length(templates))
    report = Fit.fit_report(templates, fc)
    dir = joinpath(ctx.workdir, "fit")
    mkpath(dir)
    Fit.write_workspace(joinpath(dir, "workspace.json"), report["workspace"])
    write(joinpath(dir, "result.txt"), Fit.fit_summary(report))
    return report
end
