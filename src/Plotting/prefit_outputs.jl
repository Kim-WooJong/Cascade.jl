"""
    prefit_outputs(cfg, store, stack, opts, outdir; fit=nothing, render=true, notes=String[]) -> Vector{String}

Prefit outputs for every region x histogram of `store` (restricted to
`opts.regions`/`opts.variables`): a data/MC plot with the stat ⊕ syst band
(`prefit/<region>/<variable>` and, for `opts.logy` variables, `..._log`) whose
systematic part comes from the `<name>Up`/`<name>Down` variation histograms
plus, when `opts.band_normsys` and a [`FitConfig`](@ref Cascade.Fit.FitConfig)
`fit` is given, its normsys uncertainties; and per region yield and
uncertainty-breakdown tables of the merge yield variable
(`tables/yields_<region>`, `tables/uncertainties_<region>`). `render=false`
writes tables only. Items that cannot be drawn are reported in `notes`.
"""
function prefit_outputs(cfg::AnalysisConfig, store::HistogramStore, stack::StackConfig, opts::PlotOptions,
                        outdir::AbstractString; fit = nothing, render::Bool = true, notes::Vector{String} = String[])
    files = String[]
    regions = isempty(opts.regions) ? store_axis(store, :region) : opts.regions
    variables = isempty(opts.variables) ? [h.name for h in cfg.histograms] : opts.variables
    yvar = String(get(get(cfg.raw, "merge", Dict{String,Any}()), "yield_variable", ""))
    xlabels = Dict(h.name => (isempty(h.xlabel) ? h.name : h.xlabel) for h in cfg.histograms)
    for r in regions
        annotation = get(opts.region_labels, r, r)
        table_var = yvar
        for v in variables
            tpl = _band_templates(store_templates(store, r, v), fit)
            st = present_stack(stack, keys(tpl))
            st === nothing && continue
            isempty(table_var) && (table_var = v)
            v == table_var && opts.tables && append!(files, _region_tables(tpl, st, outdir, r, annotation))
            (render && opts.prefit) || continue
            if isempty(st.data)
                push!(notes, "prefit $r/$v: no data sample, plot skipped")
                continue
            end
            for logy in (v in opts.logy ? (false, true) : (false,))
                stem = joinpath(outdir, "prefit", r, logy ? v * "_log" : v)
                try
                    data = merge_data(tpl, st)
                    res = plot_prefit(tpl, st, stem; xlabel = get(xlabels, v, v), lumi = opts.lumi, energy = opts.energy,
                                      extra = opts.extra, annotation, logy, format = opts.formats,
                                      data_errors = all(isinteger, data.sumw) ? :poisson : :sumw2)
                    append!(files, filter(!isnothing, [res.files.png, res.files.pdf]))
                catch e
                    e isa ArgumentError || rethrow()
                    push!(notes, "prefit $r/$v: " * sprint(showerror, e))
                end
            end
        end
    end
    return files
end

function _band_templates(tpl, fit)
    fit === nothing && return tpl
    for n in fit.normsys
        fs = isempty(n.samples) ? fit.samples : [s for s in fit.samples if s.name in n.samples]
        tpl = add_norm_variations(tpl, n.name, n.hi, n.lo, Set(reduce(vcat, (s.members for s in fs); init = String[])))
    end
    return tpl
end

function _region_tables(tpl, st, outdir, region, annotation)
    groups = group_templates(tpl, st)
    data = isempty(st.data) ? nothing : merge_data(tpl, st)
    caption = format_label("Prefit yields, " * annotation, :text)
    files = write_table(yield_table(groups; data, caption), joinpath(outdir, "tables", "yields_" * region))
    append!(files, write_table(uncertainty_table(groups; caption = format_label("Prefit uncertainties (%), " * annotation, :text)),
                               joinpath(outdir, "tables", "uncertainties_" * region)))
    return files
end
