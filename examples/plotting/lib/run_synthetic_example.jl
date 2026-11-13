"""
    run_synthetic_example(outdir) -> Vector{String}

All plot and table types from synthetic inputs: prefit (linear, log, and
symmetrized band; overflow folded on input), postfit from a synthetic `FitYields`,
yield/uncertainty/postfit tables, and cutflow plots with and without data.
Returns the written paths.
"""
function run_synthetic_example(outdir::AbstractString)
    mkpath(outdir)
    config = stack_config(Dict("plotting" => Dict("data" => ["pseudodata"], "groups" => [
        Dict("label" => "Nonprompt", "color" => "#999999", "samples" => ["fakes"]),
        Dict("label" => "Z/#gamma* #rightarrow ll", "color" => "#1F77B4", "samples" => ["dy"]),
        Dict("label" => "Single t", "color" => "#E377C2", "samples" => ["singletop"]),
        Dict("label" => "t#bar{t}", "color" => "#C5001A", "samples" => ["ttbar"])])))
    templates = synthetic_templates()
    nuisances = synthetic_nuisances()
    common = (xlabel="m (GeV)", ylabel="Events / 20 GeV", lumi="10 fb^{-1}", energy="13.6 TeV",
              extra="Simulation Preliminary", annotation="Synthetic inputs")
    files = String[]
    for (stem, kw) in (("prefit_lin", (logy=false,)), ("prefit_log", (logy=true,)),
                       ("prefit_log_symmetrized", (logy=true, symmetrize=:max)))
        r = plot_prefit(templates, config, joinpath(outdir, stem); nuisances, common..., kw...)
        append!(files, (r.files.png, r.files.pdf))
    end
    groups = group_templates(templates, config)
    data = merge_data(templates, config)
    append!(files, write_table_files(yield_table(groups; data, nuisances, caption="Synthetic prefit yields"),
                                     joinpath(outdir, "yields_prefit")))
    append!(files, write_table_files(uncertainty_table(groups; nuisances, caption="Synthetic uncertainty breakdown"),
                                     joinpath(outdir, "uncertainties_prefit")))

    band = uncertainty_band(groups; nuisances)
    yields = Dict(g.name => (g.name == "t#bar{t}" ? 0.97 : 1.0) .* g.nominal.sumw for g in groups)
    fit = FitYields(data.edges, yields, 0.6 .* band.high; errors_low=0.6 .* band.low,
                    yield_errors=Dict("t#bar{t}" => 25.0), total_error=30.0)
    r = plot_postfit(templates["pseudodata"].nominal, fit, config, joinpath(outdir, "postfit_log"); common..., logy=true)
    append!(files, (r.files.png, r.files.pdf))
    append!(files, write_table_files(yield_table(fit, config; data, caption="Synthetic postfit yields"),
                                     joinpath(outdir, "yields_postfit")))

    stages = ["all", "trigger", "two_leptons", "opposite_sign", "njet_ge1"]
    cf = Cutflow(stages, Dict("ttbar" => [5.0e4, 3.0e4, 9.0e3, 8.8e3, 8.0e3], "singletop" => [4.0e3, 2.4e3, 700.0, 690.0, 520.0],
                              "dy" => [9.0e5, 2.0e5, 3.0e3, 2.9e3, 400.0], "fakes" => [1.0e5, 2.0e4, 300.0, 150.0, 80.0],
                              "pseudodata" => [1060000.0, 251000.0, 13100.0, 12600.0, 9100.0]); data=["pseudodata"])
    gc = group_cutflow(cf, config)
    append!(files, write_table_files(cutflow_table(gc; caption="Synthetic cutflow"), joinpath(outdir, "cutflow")))
    r = plot_cutflow(gc, config, joinpath(outdir, "cutflow_data"); lumi="10 fb^{-1}", extra="Simulation Preliminary")
    append!(files, (r.files.png, r.files.pdf))
    mc = group_cutflow(cf, StackConfig(config.groups, String[]))
    r = plot_cutflow(mc, config, joinpath(outdir, "cutflow_mc"); lumi="10 fb^{-1}", extra="Simulation Preliminary")
    append!(files, (r.files.png, r.files.pdf))
    println("Wrote $(length(files)) files to $outdir")
    return files
end
