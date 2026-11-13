"""
    group_cutflow(cf::Cutflow, config::StackConfig; scale=Dict{String,Float64}(), allow_missing=false) -> Cutflow

Sum the simulated columns of `cf` into the groups of `config` (in stack order)
after multiplying each sample by `scale[sample]` (default 1; e.g.
`σ L / Σw_gen`; `sumw2` scales with the square), and the data samples of
`config` into one unscaled `"Data"` column (omitted when `config.data` is empty).
"""
function group_cutflow(cf::Cutflow, config::StackConfig; scale::AbstractDict=Dict{String,Float64}(),
                       allow_missing::Bool=false)
    index = Dict(c => j for (j, c) in enumerate(cf.columns))
    function column_sum(names, scaled)
        w = zeros(length(cf.stages)); v = zeros(length(cf.stages)); found = false
        for n in names
            j = get(index, n, nothing)
            if j === nothing
                allow_missing || throw(ArgumentError("no cutflow column $n"))
                continue
            end
            k = scaled ? Float64(get(scale, n, 1.0)) : 1.0
            w .+= k .* cf.sumw[:, j]; v .+= k^2 .* cf.sumw2[:, j]; found = true
        end
        found || throw(ArgumentError("no cutflow column of $(collect(names))"))
        return w, v
    end
    cols = [column_sum(g.samples, true) for g in config.groups]
    names = [g.label for g in config.groups]
    isdata = falses(length(cols))
    if !isempty(config.data)
        push!(cols, column_sum(config.data, false)); push!(names, "Data"); push!(isdata, true)
    end
    return Cutflow(cf.stages, names, reduce(hcat, first.(cols)); sumw2=reduce(hcat, last.(cols)), is_data=isdata)
end
