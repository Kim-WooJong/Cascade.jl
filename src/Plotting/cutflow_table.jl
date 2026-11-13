"""
    cutflow_table(cf::Cutflow; labels=cf.stages, digits=1, total=true, efficiency=true, caption="") -> TextTable

Cutflow table: one row per stage (`labels` for display), one column per column
of `cf`, a "Total MC" column (sum of the simulated columns; when `total` and
there is more than one), and "Eff. (%)": the total simulated yield relative to
the previous stage (when `efficiency`).
"""
function cutflow_table(cf::Cutflow; labels::AbstractVector=cf.stages, digits::Integer=1,
                       total::Bool=true, efficiency::Bool=true, caption::AbstractString="")
    length(labels) == length(cf.stages) || throw(ArgumentError("one label per stage is needed"))
    mc = findall(!, cf.is_data)
    showtotal = total && length(mc) > 1
    mctotal = isempty(mc) ? zeros(length(cf.stages)) : vec(sum(cf.sumw[:, mc]; dims=2))
    header = ["Selection"; cf.columns[mc]; showtotal ? ["Total MC"] : String[]; cf.columns[cf.is_data];
              efficiency && !isempty(mc) ? ["Eff. (%)"] : String[]]
    rows = Vector{Any}[]
    for i in eachindex(cf.stages)
        r = Any[String(labels[i])]
        append!(r, [value_cell(cf.sumw[i, j]; digits) for j in mc])
        showtotal && push!(r, value_cell(mctotal[i]; digits))
        append!(r, [value_cell(cf.sumw[i, j]; digits=0) for j in findall(cf.is_data)])
        if efficiency && !isempty(mc)
            push!(r, i == 1 || mctotal[i-1] == 0 ? "" : value_cell(100 * mctotal[i] / mctotal[i-1]; digits=1))
        end
        push!(rows, r)
    end
    return TextTable(header, rows; caption)
end
