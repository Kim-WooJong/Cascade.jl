"""
    plot_analysis(cfg::AnalysisConfig, store::HistogramStore, outdir; fit_report=nothing,
                  samples_info=nothing, render=ROOTPlots.root_available()) -> Vector{String}

All plots and tables of an analysis under `outdir`, configured by `[plot]`
([`plot_options`](@ref)) and the stack of [`analysis_stack_config`](@ref):

- prefit plots and tables ([`prefit_outputs`](@ref)), with the `[fit]` normsys
  in the band when a fit configuration exists;
- the cutflow table and plot (`tables/cutflow`, `cutflow`) from
  `samples_info` (the `samples` table of `merge/samples.json`);
- postfit plots, postfit yield tables and the impact plot
  ([`postfit_outputs`](@ref)) when `fit_report` is a fit report (not a skipped
  fit).

Without native ROOT (`render=false`) only tables are written. Problems with
single items (e.g. an empty histogram) are listed in `notes.txt`. Returns the
written paths.
"""
function plot_analysis(cfg::AnalysisConfig, store::HistogramStore, outdir::AbstractString; fit_report = nothing,
                       samples_info = nothing, render::Bool = ROOTPlots.root_available())
    opts = plot_options(cfg; lumi_pb = get(store.meta, "lumi_pb", cfg.lumi_pb))
    notes = String[]
    present = Set(store_axis(store, :sample))
    if !any(s -> is_mc(s) && s.name in present, cfg.samples)
        mkpath(outdir)
        path = joinpath(outdir, "notes.txt")
        write(path, "no simulated sample in the store: nothing to plot\n")
        return [path]
    end
    stack = analysis_stack_config(cfg, store, opts)
    fit = fit_config(cfg)
    render || push!(notes, "native ROOT not available: plots skipped, tables written")
    files = prefit_outputs(cfg, store, stack, opts, outdir; fit = opts.band_normsys ? fit : nothing, render, notes)
    if opts.cutflow && samples_info !== nothing
        gc = analysis_cutflow(cfg, samples_info, stack)
        opts.tables && append!(files, write_table(cutflow_table(gc; caption = "Cutflow (simulation scaled to sigma L)"),
                                                  joinpath(outdir, "tables", "cutflow")))
        if render
            st = StackConfig([g for g in stack.groups if g.label in gc.columns], String[])
            res = plot_cutflow(gc, st, joinpath(outdir, "cutflow"); first_stage = min(2, length(gc.stages)),
                               lumi = opts.lumi, energy = opts.energy, extra = opts.extra, format = opts.formats)
            append!(files, filter(!isnothing, [res.files.png, res.files.pdf]))
        end
    end
    if fit_report isa AbstractDict && haskey(fit_report, "workspace")
        append!(files, postfit_outputs(fit_report, store, stack, opts, outdir; render, notes,
                                       xlabels = Dict(h.name => (isempty(h.xlabel) ? h.name : h.xlabel) for h in cfg.histograms)))
    end
    if !isempty(notes)
        path = joinpath(outdir, "notes.txt")
        mkpath(outdir)
        write(path, join(notes, "\n") * "\n")
        push!(files, path)
    end
    return files
end
