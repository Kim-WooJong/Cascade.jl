@testset "fit from a histogram store" begin
    samples = fixture_samples()
    fc = fit_config(fixture_section(), samples)
    @test [s.name for s in fc.samples] == ["signal", "bkg"] && fc.samples[1].members == ["sig1", "sig2"]
    @test fc.data == ["data"] && fc.poi == "mu_sig" && fc.poi_bounds == (0.0, 10.0) && fc.staterror && fc.histosys
    @test fc.normsys[1].samples == String[] && fc.normsys[1].hi ≈ 1.02 && fc.normsys[2].placeholder
    @test only(fc.channels).name == "SR_x"
    @test_throws ArgumentError fit_config(fixture_section(bogus = 1), samples)
    @test_throws ArgumentError fit_config(fixture_section(signal = ["nope"]), samples)
    @test_throws ArgumentError fit_config(fixture_section(normsys = [Dict("name" => "a", "size" => 0.1, "hi" => 1.1)]), samples)
    @test_throws ArgumentError fit_config(fixture_section(channels = Any[]), samples)
    @test [s.name for s in fit_config(fixture_section(grouping = "sample", signal = ["sig1"]), samples).samples] ==
          ["sig1", "sig2", "bkg"]
    g = fit_config(fixture_section(groups = Dict("bkg" => ["bkg"], "signal" => ["sig2", "sig1"])), samples)
    @test [s.name for s in g.samples] == ["signal", "bkg"]          # ordered by the first member's config position
    @test g.samples[1].members == ["sig2", "sig1"]
    @test_throws ArgumentError fit_config(fixture_section(groups = Dict("a" => ["bkg"], "signal" => ["bkg", "sig1"])), samples)
    @test fit_config(Cascade.Config.parse_analysis(Dict("samples" => Any[]))) === nothing

    store = fixture_store()
    b = build_workspace(store, fc)
    ws = b.workspace
    ch = only(ws["channels"])
    @test ch["name"] == "SR_x" && [s["name"] for s in ch["samples"]] == ["signal", "bkg"]
    sig, bkg = ch["samples"]
    @test sig["data"] == FIX_SIG1 .+ FIX_SIG2 && bkg["data"] == FIX_BKG
    @test [m["name"] for m in sig["modifiers"]] == ["mu_sig", "lumi", "jes", "staterror_SR_x"]
    @test [m["name"] for m in bkg["modifiers"]] == ["lumi", "bkg_norm", "shape", "staterror_SR_x"]
    jes = sig["modifiers"][3]["data"]
    @test jes["hi_data"] ≈ FIX_SIG1 .* [1.05, 1.0, 0.95] .+ FIX_SIG2 && jes["lo_data"] ≈ FIX_SIG1 .* [0.96, 1.0, 1.04] .+ FIX_SIG2
    sh = bkg["modifiers"][3]["data"]
    @test sh["lo_data"] ≈ 2 .* FIX_BKG .- FIX_BKG .* [0.9, 1.0, 1.1]
    @test sig["modifiers"][4]["data"] ≈ sqrt.(0.04 .* FIX_SIG1 .+ 0.09 .* FIX_SIG2)
    @test only(ws["observations"])["data"] ≈ 1.3 .* (FIX_SIG1 .+ FIX_SIG2) .+ FIX_BKG
    @test only(ws["measurements"])["config"]["poi"] == "mu_sig"
    @test any(occursin("mirrored", n) for n in b.notes)
    @test only(b.channels).members == Dict("signal" => ["sig1", "sig2"], "bkg" => ["bkg"])
    @test only(b.channels).histosys == ["jes", "shape"] && only(b.channels).edges == FIX_EDGES
    @test isempty(build_workspace(store, fit_config(fixture_section(histosys = false, staterror = false), samples)).workspace["channels"][1]["samples"][2]["modifiers"][3:end])
    @test_throws ArgumentError build_workspace(store, fit_config(fixture_section(channels = [Dict("region" => "XX", "variable" => "x")]), samples))
    @test_throws ArgumentError build_workspace(store, fit_config(fixture_section(channels = [Dict("region" => "CR", "variable" => "x")]), samples))

    pruned = build_workspace(store, fit_config(fixture_section(histosys_prune = 0.2), samples))
    @test isempty(only(pruned.channels).histosys)

    m = HistModel(store, fc)
    @test [p.name for p in m.parameters] == ["bkg_norm", "jes", "lumi", "mu_sig", "shape",
                                             "staterror_SR_x[0]", "staterror_SR_x[1]", "staterror_SR_x[2]"]
    @test m.parameters[m.poi].name == "mu_sig"
    path = write_workspace(joinpath(mktempdir(), "ws.json"), ws)
    m2 = HistModel(load_workspace(path))
    x0 = [p.init for p in m.parameters]
    @test nll(m2, x0, observed_data(m2)) == nll(m, x0, observed_data(m))

    # data = 1.3 S + B exactly: the best fit is mu = 1.3 with all nuisances at their centre
    r = fit(m, observed_data(m))
    @test r.converged
    @test r.parameters[m.poi] ≈ 1.3 rtol = 1e-7
    @test all(abs(x.pull) < 1e-5 for x in pulls(m, r) if isfinite(x.pull))

    # group_yields agrees with the per-sample propagation of yields_with_uncertainty
    gy = group_yields(m, r.parameters, r.covariance, "SR_x")
    cy = only(postfit_yields(m, r))
    @test gy.groups == cy.samples && gy.yields ≈ cy.yields && gy.errors ≈ cy.yield_errors && gy.total_errors ≈ cy.total_errors
    one_group = group_yields(m, r.parameters, r.covariance, "SR_x"; groups = ["all" => ["signal", "bkg"]])
    @test one_group.yields[1, :] ≈ gy.total && one_group.errors[1, :] ≈ gy.total_errors
    @test one_group.integrated_errors[1] ≈ gy.total_integrated_error
    @test gy.total_integrated_error < sqrt(sum(gy.total_errors .^ 2)) + sum(gy.total_errors)   # finite, correlated sum
    @test_throws ArgumentError group_yields(m, r.parameters, r.covariance, "SR_x"; groups = ["a" => ["nope"]])

    ce = counting_estimate(m, "SR_x"; signal = ["signal"])
    @test ce.mu ≈ 1.3 && ce.signal ≈ sum(FIX_SIG1 .+ FIX_SIG2) && ce.background ≈ sum(FIX_BKG)

    rep = fit_report(store, fit_config(fixture_section(upper_limit = true, significance = true), samples))
    @test rep["status"] == "ok"
    @test rep["poi_value"] ≈ 1.3 rtol = 1e-7
    lo, hi = rep["poi_interval"]
    @test lo < 1.3 < hi && isapprox(hi - lo, 2 * rep["poi_error"]; rtol = 0.1)
    @test length(rep["impacts"]) == 7 && issorted([-max(abs(x["postfit_up"]), abs(x["postfit_down"])) for x in rep["impacts"]])
    @test rep["upper_limit"]["observed"] > 1.3 && rep["significance"]["Z"] > 3
    @test only(rep["channels"])["prefit"]["groups"] == ["signal", "bkg"]
    @test only(rep["counting"])["mu"] ≈ 1.3
    @test rep["normsys"][2]["placeholder"] && rep["normsys"][1]["samples"] == ["all"]
    s = JSON3.write(rep)                                            # strict JSON (no NaN)
    @test !occursin("NaN", s)
    d = plainjson(JSON3.read(s))
    md = report_model(d)
    rd = report_result(d, md)
    @test rd.parameters ≈ [rep["parameters"][i]["value"] for i in eachindex(md.parameters)]
    @test nll(md, rd.parameters, observed_data(md)) ≈ rep["nll"]
    @test rd.covariance ≈ r.covariance rtol = 1e-6
    txt = fit_summary(d)
    @test occursin("POI mu_sig = 1.3", txt) && occursin("PLACEHOLDER", txt) && occursin("Counting cross-check", txt)

    # Asimov export, report/counting and reconstructed likelihood must use the same data.
    ar = fit_report(store, fit_config(fixture_section(asimov = true, impacts = false,
                                                     profile_interval = false), samples))
    am = report_model(ar)
    @test ar["dataset"] == "asimov"
    @test ar["poi_value"] ≈ 1.0 atol = 1e-6
    @test only(ar["workspace"]["observations"])["data"] == only(ar["channels"])["data"]
    @test only(ar["channels"])["data"] ≈ FIX_SIG1 .+ FIX_SIG2 .+ FIX_BKG
    @test only(ar["counting"])["mu"] ≈ 1.0
    @test nll(am, report_result(ar, am).parameters, observed_data(am)) ≈ ar["nll"]

    # Postfit tables use the fit data even when the plotting stack excludes all data.
    P = Cascade.Plotting
    stack = P.StackConfig([P.SampleGroup("signal", "#C5001A", ["sig1", "sig2"]),
                           P.SampleGroup("bkg", "#1F77B4", ["bkg"])], String[])
    opts = P.plot_options(Cascade.Config.parse_analysis(Dict("samples" => Any[])))
    outdir = mktempdir()
    files = P.postfit_outputs(rep, store, stack, opts, outdir; render = false)
    @test !isempty(files)
    table = read(joinpath(outdir, "tables", "postfit_yields_SR_x.md"), String)
    @test occursin(r"\| Data\s*\|\s*378(?:\.0)?\s*\|", table)
    afiles = P.postfit_outputs(ar, store, stack, opts, outdir; render = false)
    atable = read(joinpath(outdir, "tables", "postfit_yields_SR_x.md"), String)
    @test occursin("Asimov", atable)
    @test occursin(r"\| Data\s*\|\s*330(?:\.0)?\s*\|", atable)

    # profile interval of a one-bin counting experiment against the analytic Δ(2 NLL) = 1 crossings
    mc = HistModel(ws_counting(; n = 130.0, s = 50.0, b = 50.0))
    dc = observed_data(mc)
    rc = fit(mc, dc)
    q(mu) = 2 * ((50mu + 50) - 130 + 130 * log(130 / (50mu + 50))) - 1
    bisect(f, a, b) = (for _ in 1:200; c = (a + b) / 2; sign(f(c)) == sign(f(a)) ? (a = c) : (b = c); end; (a + b) / 2)
    il, ih = profile_interval(mc, dc, rc)
    @test il ≈ bisect(q, 0.0, 1.6) atol = 1e-5
    @test ih ≈ bisect(q, 1.6, 5.0) atol = 1e-5

    @test json_safe([1.0, NaN, Inf]) == Any[1.0, nothing, nothing] && json_safe(:a) == "a"
    @test json_safe([1.0 2.0; 3.0 4.0]) == Any[Any[1.0, 2.0], Any[3.0, 4.0]]
end
