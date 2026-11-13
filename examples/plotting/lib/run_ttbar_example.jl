"""
    run_ttbar_example(root, outdir) -> Bool

Plots and tables from the prior ttbar e-mu outputs under `root` (out_slim,
out_data, out_cutflow; read-only) into `outdir`: prefit data/MC plots of every
configured variable (linear and log), illustrative postfit plots, yield,
uncertainty-breakdown and cutflow tables, and an MC cutflow plot. Checks the
yields against the reference numbers of docs/DESIGN.md and the prior plots.log
and returns whether all checks pass.
"""
function run_ttbar_example(root::AbstractString, outdir::AbstractString)
    mkpath(outdir)
    cfg = TOML.parsefile(joinpath(@__DIR__, "..", "ttbar_ctrl.toml"))
    config = stack_config(cfg)
    templates = load_ttbar_templates(joinpath(root, "out_slim"), joinpath(root, "out_data"), cfg)
    label = (lumi=cfg["lumi_label"], energy=cfg["energy"], annotation=cfg["annotation"])

    njet = templates["njet"]
    groups = group_templates(njet, config)
    data = merge_data(njet, config)
    mc = sum(sum(g.nominal.sumw) for g in groups)
    println("Per-sample yields (njet histogram, sigma L / sum w_gen):")
    for g in config.groups, s in g.samples
        println("  ", rpad(s, 18), round(sum(njet[s].nominal.sumw); digits=1))
    end
    println("\nReference checks:")
    checks = Bool[
        check_reference("MC total, >=1 jet", mc, 6434.9316; digits=4),
        check_reference("MC total, >=2 jets", mc - sum(g.nominal.sumw[1] for g in groups), 4235.2102; digits=4),
        check_reference("Data, >=1 jet", sum(data.sumw), 5905.0; digits=1),
        check_reference("Data, >=2 jets", sum(data.sumw) - data.sumw[1], 3836.0; digits=1)]
    for (g, ref) in zip(groups, [105.5, 234.9, 533.1, 5561.5])
        push!(checks, check_reference("group " * g.name, sum(g.nominal.sumw), ref; digits=1))
    end
    for (i, ref) in enumerate([2199.7, 2428.4, 1190.5, 436.8, 132.8, 35.8, 10.8])
        push!(checks, check_reference("MC njet bin $i", sum(g.nominal.sumw[i] for g in groups), ref; digits=1))
    end

    files = String[]
    for v in cfg["variables"]
        for logy in (false, true)
            r = plot_prefit(templates[v["name"]], config, joinpath(outdir, "prefit_$(v["name"])_" * (logy ? "log" : "lin"));
                            xlabel=v["xlabel"], ylabel=v["ylabel"], logy, label...)
            append!(files, (r.files.png, r.files.pdf))
        end
    end
    mu, sigma = illustrative_normfactor(groups, data, "t#bar{t}")
    println("\nIllustrative ttbar normalisation (not a fit): mu = ", round(mu; digits=4), " ± ", round(sigma; digits=4))
    for v in cfg["variables"]
        vg = group_templates(templates[v["name"]], config)
        fit = illustrative_postfit(vg, "t#bar{t}", mu, sigma)
        r = plot_postfit(merge_data(templates[v["name"]], config), fit, config, joinpath(outdir, "postfit_$(v["name"])");
                         xlabel=v["xlabel"], ylabel=v["ylabel"], logy=v["logy"], lumi=label.lumi,
                         energy=label.energy, annotation="Illustrative postfit")
        append!(files, (r.files.png, r.files.pdf))
        v["name"] == "njet" && push!(checks, check_reference("illustrative postfit total = data", sum(r.band.prediction), sum(data.sumw); digits=6))
        v["name"] == "njet" && append!(files, write_table_files(yield_table(fit, config; data, caption="Postfit yields (illustrative)"),
                                                                joinpath(outdir, "yields_postfit")))
    end

    println()
    append!(files, write_table_files(yield_table(groups; data, caption="Prefit yields, e-mu >= 1 jet (illustrative norm. syst.)"),
                                     joinpath(outdir, "yields_prefit")))
    append!(files, write_table_files(uncertainty_table(groups; caption="Prefit uncertainty breakdown (illustrative)"),
                                     joinpath(outdir, "uncertainties_prefit")))
    cf = load_ttbar_cutflow(joinpath(root, "out_cutflow"), cfg)
    gc = group_cutflow(cf, StackConfig(config.groups, String[]); scale=ttbar_scale_factors(joinpath(root, "out_cutflow"), cfg))
    append!(files, write_table_files(cutflow_table(gc; caption="MC cutflow (sigma L / sum w_gen)"), joinpath(outdir, "cutflow_mc")))
    i = findfirst(==("njet_ge1"), gc.stages)
    push!(checks, check_reference("cutflow njet_ge1 total MC", sum(gc.sumw[i, :]), 6434.9316; digits=4))
    r = plot_cutflow(gc, config, joinpath(outdir, "cutflow_mc"); first_stage=2, lumi=label.lumi, energy=label.energy)
    append!(files, (r.files.png, r.files.pdf))
    println("\nWrote $(length(files)) files to $outdir")
    println(all(checks) ? "ALL REFERENCE CHECKS PASS" : "SOME REFERENCE CHECKS FAIL")
    return all(checks)
end
