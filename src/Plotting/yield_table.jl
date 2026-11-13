"""
    yield_table(groups; data=nothing, nuisances=infer_nuisances(groups), symmetrize=nothing,
                digits=1, caption="") -> TextTable
    yield_table(fit::FitYields, config::StackConfig; data=nothing, digits=1, caption="") -> TextTable

Integrated yields over all bins.

Prefit (first form, `groups` a vector of [`SampleTemplates`](@ref)): columns
Process, Yield, Stat. (`sqrt(Σ sumw2)`) and Syst. (nuisances in quadrature,
each evaluated on the integrated yield; omitted without nuisances). Rows: each
group, the total prediction (systematics correlated across groups), and with
`data` the observed yield (`sqrt(Σw²)`) and the ratio data / prediction, whose
Stat. is the data part and Syst. the prediction's `stat ⊕ syst` part.

Postfit (second form): columns Process, Yield, Unc. Group uncertainties are
taken from `fit.yield_errors` (by group label, or by the sample of a
one-sample group), otherwise `n/a`; the total uses `fit.total_error`. The ratio
uncertainty combines data statistics and `fit.total_error` in quadrature.
"""
function yield_table(groups::AbstractVector{SampleTemplates}; data::Union{Nothing,BinnedHist}=nothing,
                     nuisances::AbstractVector{Nuisance}=infer_nuisances(groups),
                     symmetrize::Union{Nothing,Symbol}=nothing, digits::Integer=1, caption::AbstractString="")
    ns = symmetrize === nothing ? collect(nuisances) : [with_symmetrize(n, symmetrize) for n in nuisances]
    withsyst = !isempty(ns)
    function syst(ts)
        s = [nuisance_shifts(ts, n; integrate=true) for n in ns]
        return (sqrt(sum((x[1][1]^2 for x in s); init=0.0)), sqrt(sum((x[2][1]^2 for x in s); init=0.0)))
    end
    header = withsyst ? ["Process", "Yield", "Stat.", "Syst."] : ["Process", "Yield", "Stat."]
    row(label, y, st, sy) = withsyst ?
        Any[label, value_cell(y; digits), uncertainty_cell(st; digits),
            sy === nothing ? "" : uncertainty_cell(sy...; digits)] :
        Any[label, value_cell(y; digits), uncertainty_cell(st; digits)]
    rows = Vector{Any}[]
    for g in groups
        t = total_yield(g.nominal)
        push!(rows, row(g.name, t.sumw, sqrt(t.sumw2), syst([g])))
    end
    total = sum(total_yield(g.nominal).sumw for g in groups)
    tstat = sqrt(sum(total_yield(g.nominal).sumw2 for g in groups))
    tsyst = syst(collect(groups))
    rules = [length(rows)]
    push!(rows, row("Total prediction", total, tstat, tsyst))
    if data !== nothing
        push!(rules, length(rows))
        d = total_yield(data)
        push!(rows, row("Data", d.sumw, sqrt(d.sumw2), nothing))
        r = d.sumw / total
        # A larger prediction lowers the ratio: the upper ratio error comes from the lower prediction error.
        phi, plo = hypot(tstat, tsyst[1]), hypot(tstat, tsyst[2])
        push!(rows, withsyst ?
            Any["Data / prediction", value_cell(r; digits=3), uncertainty_cell(sqrt(d.sumw2) / total; digits=3),
                uncertainty_cell(r * plo / total, r * phi / total; digits=3)] :
            Any["Data / prediction", value_cell(r; digits=3),
                uncertainty_cell(hypot(sqrt(d.sumw2) / total, r * tstat / total); digits=3)])
    end
    return TextTable(header, rows; rules, caption)
end

function yield_table(fit::FitYields, config::StackConfig; data::Union{Nothing,BinnedHist}=nothing,
                     digits::Integer=1, caption::AbstractString="")
    groups = postfit_groups(fit, config)
    rows = Vector{Any}[]
    for (g, spec) in zip(groups, config.groups)
        e = get(fit.yield_errors, g.name, length(spec.samples) == 1 ? get(fit.yield_errors, only(spec.samples), NaN) : NaN)
        push!(rows, Any[g.name, value_cell(sum(g.nominal.sumw); digits), uncertainty_cell(e; digits)])
    end
    total = sum(sum(g.nominal.sumw) for g in groups)
    rules = [length(rows)]
    push!(rows, Any["Total prediction", value_cell(total; digits), uncertainty_cell(fit.total_error; digits)])
    if data !== nothing
        push!(rules, length(rows))
        d = total_yield(data)
        push!(rows, Any["Data", value_cell(d.sumw; digits), uncertainty_cell(sqrt(d.sumw2); digits)])
        r = d.sumw / total
        push!(rows, Any["Data / prediction", value_cell(r; digits=3),
                        uncertainty_cell(hypot(sqrt(d.sumw2) / total, r * fit.total_error / total); digits=3)])
    end
    return TextTable(["Process", "Yield", "Unc."], rows; rules, caption)
end
