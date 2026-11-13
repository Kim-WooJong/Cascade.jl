"""
    plot_cutflow(cf::Cutflow, config::StackConfig, outstem; labels=stages with "_" as spaces,
                 first_stage=1, logy=true, ylabel="Events", lumi="", energy="13.6 TeV",
                 extra="Preliminary", annotation="", format=:both) -> NamedTuple

Cutflow plot with one bin per stage (from `first_stage`), stacked in the group
order of `config` (`cf` must hold the group columns, see [`group_cutflow`](@ref)).
With a data column the plot is a data/MC comparison with ratio panel and MC
statistical band; without data it is a stacked histogram. Negative stacked
values are drawn as zero. Returns `(; files)` plus `comparison` when data exist.
"""
function plot_cutflow(cf::Cutflow, config::StackConfig, outstem::AbstractString;
                      labels::AbstractVector=[replace(s, "_" => " ") for s in cf.stages], first_stage::Integer=1,
                      logy::Bool=true, ylabel::AbstractString="Events", lumi::AbstractString="",
                      energy::AbstractString="13.6 TeV", extra::AbstractString="Preliminary",
                      annotation::AbstractString="", format::Symbol=:both)
    1 <= first_stage <= length(cf.stages) || throw(ArgumentError("first_stage outside the cutflow"))
    length(labels) == length(cf.stages) || throw(ArgumentError("one label per stage is needed"))
    rows = first_stage:length(cf.stages)
    edges = collect(0.0:length(rows))
    index = Dict(c => j for (j, c) in enumerate(cf.columns))
    for g in config.groups
        haskey(index, g.label) || throw(ArgumentError("cutflow has no column for group $(g.label)"))
    end
    groups = [SampleTemplates(g.label, binned_hist(edges, cf.sumw[rows, index[g.label]], cf.sumw2[rows, index[g.label]]))
              for g in config.groups]
    colors = [g.color for g in config.groups]
    binlabels = String.(labels[rows])
    datacols = findall(cf.is_data)
    if !isempty(datacols)
        data = binned_hist(edges, vec(sum(cf.sumw[rows, datacols]; dims=2)), vec(sum(cf.sumw2[rows, datacols]; dims=2)))
        band = uncertainty_band(groups; nuisances=Nuisance[], label="MC stat. unc.")
        cmp = stack_comparison(data, groups, colors, band;
                               data_errors=all(isinteger, data.sumw) ? :poisson : :sumw2)
        lo, hi = auto_ylimits(cmp; logy)
        spec = cms_panel_spec(""; ylabel, lumi, energy, extra, annotation, logy, ymin=lo, ymax=hi, bin_labels=binlabels)
        files = render_root([cmp], [spec], outstem; ratio_limits=spec.ratio_limits, format)
        return (; files, comparison=cmp)
    end
    hists = [Hist1D(edges, max.(g.nominal.sumw, 0.0), g.nominal.sumw2) for g in groups]
    stack = HistStack(hists; labels=[g.name for g in groups], fill_colors=colors)
    cumulative = accumulate(+, [h.sumw for h in hists])
    ylimits = auto_ylimits(cumulative, maximum(last(cumulative)); logy)
    spec = GraphSpec(; xlabel="", ylabel=String(ylabel), logy, ylimits, legend=:topright,
                     xaxis=AxisStyle(bin_labels=binlabels), style=:CMS,
                     cms_label=(extra=String(extra), lumi=String(lumi), energy=String(energy)))
    files = render_root(stack, spec, outstem; format)
    return (; files)
end
