"""
    plot_postfit(data::BinnedHist, fit::FitYields, config::StackConfig, outstem; xlabel, kwargs...) -> NamedTuple

Postfit data/MC plot: the postfit yields of `fit` grouped as in `config`
([`postfit_groups`](@ref)), the fit's total postfit uncertainty as the band in
the main and ratio panels ([`postfit_band`](@ref)), and `data` (its binning
must equal `fit.edges`).

Other keywords as in [`plot_prefit`](@ref) (`data_errors`, `format` and the
[`cms_panel_spec`](@ref) keywords; `annotation` defaults to `"Postfit"`).
Returns `(; files, comparison, band, groups, data)`.
"""
function plot_postfit(data::BinnedHist, fit::FitYields, config::StackConfig, outstem::AbstractString;
                      xlabel::AbstractString,
                      data_errors=:poisson, format::Symbol=:both, annotation::AbstractString="Postfit",
                      panel...)
    observed = data
    observed.edges == fit.edges || throw(ArgumentError("data and fit binning differ"))
    groups = postfit_groups(fit, config)
    band = postfit_band(fit)
    cmp = stack_comparison(observed, groups, [g.color for g in config.groups], band; data_errors)
    kw = (; panel...)
    limits = auto_ylimits(cmp; logy=get(kw, :logy, false), ymin=get(kw, :ymin, nothing))
    spec = cms_panel_spec(xlabel; merge((annotation=annotation, ymin=limits[1], ymax=limits[2]), kw)...)
    files = render_root([cmp], [spec], outstem; ratio_limits=spec.ratio_limits, format)
    return (; files, comparison=cmp, band, groups, data=observed)
end
