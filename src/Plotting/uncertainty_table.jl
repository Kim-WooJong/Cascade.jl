"""
    uncertainty_table(groups; nuisances=infer_nuisances(groups), symmetrize=nothing,
                      digits=2, sort=true, caption="") -> TextTable

Breakdown of the relative uncertainty (in %) of the integrated yield of each
group and of the total prediction: one row per nuisance (`+high / -low` via
[`nuisance_shifts`](@ref) with `integrate=true`), then MC statistics, the total
systematic (nuisances in quadrature) and the total (`stat ⊕ syst`). Rows are
sorted by the larger side of the total-prediction impact when `sort=true`.
"""
function uncertainty_table(groups::AbstractVector{SampleTemplates};
                           nuisances::AbstractVector{Nuisance}=infer_nuisances(groups),
                           symmetrize::Union{Nothing,Symbol}=nothing, digits::Integer=2,
                           sort::Bool=true, caption::AbstractString="")
    ns = symmetrize === nothing ? collect(nuisances) : [with_symmetrize(n, symmetrize) for n in nuisances]
    columns = [[[g] for g in groups]; [collect(groups)]]
    yields = [sum(sum(t.nominal.sumw) for t in ts) for ts in columns]
    rel(x, y) = y == 0 ? NaN : 100 * x / y
    impacts = [[nuisance_shifts(ts, n; integrate=true) for ts in columns] for n in ns]
    order = collect(eachindex(ns))
    sort && sort!(order; by=i -> -max(impacts[i][end][1][1], impacts[i][end][2][1]))
    rows = Vector{Any}[]
    for i in order
        push!(rows, Any[ns[i].name; [uncertainty_cell(rel(s[1][1], y), rel(s[2][1], y); digits)
                                     for (s, y) in zip(impacts[i], yields)]])
    end
    rules = isempty(rows) ? Int[] : [length(rows)]
    stat = [sqrt(sum(sum(t.nominal.sumw2) for t in ts)) for ts in columns]
    shi = [sqrt(sum((impacts[i][k][1][1]^2 for i in eachindex(ns)); init=0.0)) for k in eachindex(columns)]
    slo = [sqrt(sum((impacts[i][k][2][1]^2 for i in eachindex(ns)); init=0.0)) for k in eachindex(columns)]
    push!(rows, Any["MC stat."; [uncertainty_cell(rel(s, y); digits) for (s, y) in zip(stat, yields)]])
    push!(rows, Any["Total syst."; [uncertainty_cell(rel(h, y), rel(l, y); digits) for (h, l, y) in zip(shi, slo, yields)]])
    push!(rules, length(rows))
    push!(rows, Any["Total"; [uncertainty_cell(rel(hypot(s, h), y), rel(hypot(s, l), y); digits)
                              for (s, h, l, y) in zip(stat, shi, slo, yields)]])
    header = ["Source (%)"; [g.name for g in groups]; "Total"]
    return TextTable(header, rows; rules, caption)
end
