import ..Plotting   # area dependency of the default plot hook (exported API only)

"""
    default_plot(ctx::StepContext, merged::HistogramStore, fit_result) -> Vector{String}

Built-in `:plot` hook: `Plotting.plot_analysis` on the merged store, the merge
cutflows (`merge/samples.json`) and the fit report (`fit_result`, when the fit
step produced one): prefit plots of every histogram with the stat ⊕ syst band,
postfit plots, yield / uncertainty / cutflow tables and the impact plot under
`plot/` (plots need native ROOT; without it only tables are written). Also
writes the plain-text yield summary `plot/yields.txt` (nominal integrals per
region and sample).
"""
function default_plot(ctx::StepContext, merged::HistogramStore, fit_result)
    dir = joinpath(ctx.workdir, "plot")
    files = [_write_yield_summary(ctx, merged, dir)]
    info_path = joinpath(ctx.workdir, "merge", "samples.json")
    info = isfile(info_path) ? _jsdict(JSON3.read(read(info_path, String)))["samples"] : nothing
    append!(files, Plotting.plot_analysis(ctx.config, merged, dir; fit_report = fit_result, samples_info = info))
    return files
end

function _write_yield_summary(ctx::StepContext, merged::HistogramStore, dir::AbstractString)
    mkpath(dir)
    path = joinpath(dir, "yields.txt")
    var = get(get(ctx.config.raw, "merge", Dict{String,Any}()), "yield_variable", "")
    open(path, "w") do io
        for r in store_axis(merged, :region)
            println(io, "region ", r)
            for s in store_axis(merged, :sample)
                vars = [k.variable for k in keys(merged) if k.region == r && k.sample == s && k.variation == NOMINAL]
                isempty(vars) && continue
                v = var in vars ? var : first(vars)
                println(io, "  ", rpad(s, 24), " ", integral(merged[r, s, NOMINAL, v]))
            end
        end
    end
    return path
end
