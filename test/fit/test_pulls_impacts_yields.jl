@testset "pulls, impacts, yields" begin
    mf = HistModel(ws_full())
    df = observed_data(mf)
    r = fit(mf, df)

    pl = pulls(mf, r)
    @test length(pl) == count(r.floating)
    pj = only(filter(x -> x.name == "jes", pl))
    @test pj.pull ≈ r.parameters[mf.index["jes"]] rtol = 1e-12
    @test pj.constraint ≈ r.uncertainties[mf.index["jes"]] rtol = 1e-12
    pc = only(filter(x -> x.name == "cr_mc[0]", pl))
    @test pc.prefit_center ≈ 1.0
    @test pc.prefit_sigma ≈ 3 / 50
    @test isnan(only(filter(x -> x.name == "mu", pl)).pull)

    # Asimov at nominal: pulls vanish and constraints are <= 1
    ra = fit(mf, asimov_data(mf, [p.init for p in mf.parameters]))
    for x in pulls(mf, ra)
        isnan(x.pull) && continue
        @test abs(x.pull) < 1e-6
        @test x.constraint <= 1 + 1e-9
    end

    imp = impacts(mf, df, r)
    @test length(imp) == count(r.floating) - 1
    ij = only(filter(x -> x.name == "other_xs", imp))
    i = mf.index["other_xs"]
    rr = fit(mf, df; init=r.parameters, fixed=["other_xs" => r.parameters[i] + r.uncertainties[i]], hesse=false)
    @test ij.postfit_up ≈ rr.parameters[mf.index["mu"]] - r.parameters[mf.index["mu"]] atol = 1e-9
    @test isnan(only(filter(x -> x.name == "k_tt", imp)).prefit_up)
    # linear expectation: impact ~ cov(mu, theta) / sigma_theta
    lin = r.covariance[mf.index["mu"], i] / r.uncertainties[i]
    @test abs(lin) > 1e-3
    @test ij.postfit_up ≈ lin rtol = 0.2
    @test ij.postfit_down ≈ -lin rtol = 0.2

    # yields: totals match expected_main, single-parameter error is exact
    yp = postfit_yields(mf, r)
    lam = expected_main(mf, r.parameters)
    @test vcat([y.total for y in yp]...) ≈ lam rtol = 1e-12
    @test vcat([y.data for y in yp]...) == mf.observations
    @test all(all(y.total_errors .> 0) for y in yp)
    pre = prefit_yields(mf)
    @test vcat([y.total for y in pre]...) ≈ expected_main(mf, [p.init for p in mf.parameters])

    mc = HistModel(ws_counting())
    rc = fit(mc)
    yc = only(postfit_yields(mc, rc))
    @test yc.yield_errors[1, 1] ≈ 5 * rc.uncertainties[1] rtol = 1e-12
    @test yc.yield_errors[2, 1] == 0.0
    @test yc.total_errors[1] ≈ 5 * rc.uncertainties[1] rtol = 1e-12
end
