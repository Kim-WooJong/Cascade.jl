const DEFAULT_COLORS = ["#C5001A", "#1F77B4", "#E377C2", "#9467BD", "#FF7F0E", "#2CA02C", "#8C564B", "#7F7F7F",
                        "#BCBD22", "#17BECF"]

"""
    analysis_stack_config(cfg::AnalysisConfig, store::HistogramStore, opts::PlotOptions) -> StackConfig

Stack definition of an analysis: `opts.groups` when given, otherwise one group
per sample `group` of the simulated samples (a sample without group forms its
own) labelled by `opts.labels` (default: the group name). Groups are stacked by
increasing total nominal yield in the store (largest on top); colours come from
`opts.colors` or a fixed palette assigned by decreasing yield. Data samples are
`opts.data` or all data samples of the analysis.
"""
function analysis_stack_config(cfg::AnalysisConfig, store::HistogramStore, opts::PlotOptions)
    data = opts.data === nothing ? [s.name for s in cfg.samples if is_data(s)] : opts.data
    opts.groups === nothing || return stack_config(Dict("groups" => opts.groups, "data" => data))
    order = String[]
    members = Dict{String,Vector{String}}()
    for s in cfg.samples
        is_mc(s) || continue
        g = isempty(s.group) ? s.name : s.group
        haskey(members, g) || (push!(order, g); members[g] = String[])
        push!(members[g], s.name)
    end
    isempty(order) && throw(ArgumentError("the analysis has no simulated samples to stack"))
    yields = Dict(g => 0.0 for g in order)
    region = isempty(store.hists) ? "" : first(keys(store)).region
    variable = isempty(store.hists) ? "" : first(keys(store)).variable
    for (k, h) in store.hists
        k.variation == NOMINAL && k.region == region && k.variable == variable || continue
        for g in order
            k.sample in members[g] && (yields[g] += sum(h.sumw))
        end
    end
    byyield = sort(order; by = g -> (-yields[g], findfirst(==(g), order)))
    color = Dict(g => get(opts.colors, g, DEFAULT_COLORS[mod1(i, length(DEFAULT_COLORS))]) for (i, g) in enumerate(byyield))
    groups = [SampleGroup(get(opts.labels, g, g), color[g], members[g]) for g in reverse(byyield)]
    return StackConfig(groups, data)
end
