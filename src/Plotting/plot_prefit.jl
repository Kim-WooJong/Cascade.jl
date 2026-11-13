"""
    plot_prefit(templates, config::StackConfig, outstem; xlabel, kwargs...) -> NamedTuple

Prefit data/MC plot: stacked groups of `config`, data points, and the
stat ⊕ syst band in the main and ratio panels. Writes `outstem.png` and/or
`outstem.pdf`.

`templates` is a `Dict{String,SampleTemplates}` holding all MC and data samples
(see [`collect_templates`](@ref) and [`store_templates`](@ref)); flow bins are
already part of the first / last bin ([`binned_hist`](@ref)). Keywords:

- `nuisances=nothing` (inferred from variation names), `symmetrize=nothing`,
  `stat=true`, `syst=true`: band content ([`uncertainty_band`](@ref)).
- `data_errors=:poisson`: see [`stack_comparison`](@ref).
- `xlabel`, `ylabel`, `lumi`, `energy`, `extra`, `annotation`, `logy`, `logx`,
  `ymin`, `ymax`, `ratio_limits`, `bin_labels`: see [`cms_panel_spec`](@ref); `ymin`/`ymax`
  default to [`auto_ylimits`](@ref) (room for label and legend).
- `format=:both` (`:png`, `:pdf`, `:both`), `allow_missing=false`.

Returns `(; files, comparison, band, groups, data)`.
"""
function plot_prefit(templates::AbstractDict{<:AbstractString,SampleTemplates}, config::StackConfig,
                     outstem::AbstractString; xlabel::AbstractString,
                     nuisances=nothing, symmetrize=nothing, stat::Bool=true, syst::Bool=true,
                     data_errors=:poisson, format::Symbol=:both, allow_missing::Bool=false,
                     panel...)
    groups = group_templates(templates, config; allow_missing)
    data = merge_data(templates, config; allow_missing)
    ns = nuisances === nothing ? infer_nuisances(groups) : nuisances
    band = uncertainty_band(groups; nuisances=ns, stat, syst, symmetrize)
    cmp = stack_comparison(data, groups, [g.color for g in config.groups], band; data_errors)
    kw = (; panel...)
    limits = auto_ylimits(cmp; logy=get(kw, :logy, false), ymin=get(kw, :ymin, nothing))
    spec = cms_panel_spec(xlabel; merge((ymin=limits[1], ymax=limits[2]), kw)...)
    files = render_root([cmp], [spec], outstem; ratio_limits=spec.ratio_limits, format)
    return (; files, comparison=cmp, band, groups, data)
end
