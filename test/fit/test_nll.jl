import ForwardDiff

@testset "nll" begin
    m = HistModel(ws_counting(; n=12.0, s=5.0, b=8.0))
    d = observed_data(m)
    lgam(n) = sum(log, 1:Int(n); init=0.0)
    for mu in (0.0, 0.8, 2.0)
        lam = 5mu + 8
        @test nll(m, [mu], d) ≈ lam - 12 * log(lam) + lgam(12) rtol = 1e-13
    end
    # zero expected with zero observed contributes nothing; zero expected with data is Inf
    mm = HistModel(ws_masked())
    pars = [p.init for p in mm.parameters]
    @test isfinite(nll(mm, pars, observed_data(mm)))
    @test nll(mm, pars, Dataset(mm, [14.0, 1.0, 7.0])) == Inf

    # constraint terms: Gaussian and Poisson, against explicit formulas
    mf = HistModel(ws_full())
    df = observed_data(mf)
    x = [p.init for p in mf.parameters]
    base = nll(mf, x, df)
    i = mf.index["jes"]
    # moving only the constraint aux changes only the Gaussian term
    d2 = Dataset(df.main, copy(df.aux)); d2.aux[i] = 0.5
    @test nll(mf, x, d2) - base ≈ 0.5 * 0.25 rtol = 1e-12
    j = mf.index["cr_mc[0]"]
    tau = mf.parameters[j].tau
    d3 = Dataset(df.main, copy(df.aux)); d3.aux[j] = tau + 3
    lgm = Cascade.Fit.loggamma
    @test nll(mf, x, d3) - base ≈ -3 * log(tau) + lgm(tau + 4) - lgm(tau + 1) rtol = 1e-10
end

@testset "empty observation at zero expected yield has finite derivatives" begin
    m = HistModel(ws_counting(; n=0.0, s=5.0, b=0.0))
    f = x -> nll(m, x, observed_data(m))
    @test f([0.0]) == 0.0
    @test ForwardDiff.gradient(f, [0.0]) == [5.0]
    @test ForwardDiff.hessian(f, [0.0]) == zeros(1, 1)
    @test fit(m).converged
end
