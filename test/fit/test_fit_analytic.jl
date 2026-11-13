@testset "fit: analytic counting cases" begin
    n, s, b = 12.0, 5.0, 8.0
    m = HistModel(ws_counting(; n=n, s=s, b=b))
    d = observed_data(m)
    r = fit(m, d)
    @test r.converged
    @test r.parameters[1] ≈ (n - b) / s atol = 1e-9
    @test r.uncertainties[1] ≈ sqrt(n) / s rtol = 1e-8
    @test r.nll ≈ n - n * log(n) + sum(log, 1:Int(n)) rtol = 1e-13

    # POI at its lower bound when n < b
    rb = fit(HistModel(ws_counting(; n=5.0, s=5.0, b=8.0)))
    @test rb.parameters[1] == 0.0
    @test rb.converged

    # fixed parameters
    rf = fit(m, d; fixed=["mu" => 2.0])
    @test rf.parameters[1] == 2.0 && !rf.floating[1] && rf.uncertainties[1] == 0.0

    # profile scan: analytic Delta(2 NLL)
    vals = 0.0:0.25:2.5
    sc = profile_scan(m, d, "mu", vals)
    expect = [2 * ((mu * s + b) - n - n * log((mu * s + b) / n)) for mu in vals]
    @test sc.delta_twice_nll ≈ expect atol = 1e-9

    # on/off: closed-form MLE and q0
    non, moff, tau = 25.0, 40.0, 4.0
    mo = HistModel(ws_onoff(; n=non, m=moff, tau=tau))
    ro = fit(mo)
    kb = moff / (tau * 10)
    @test ro.parameters[mo.index["kb"]] ≈ kb rtol = 1e-9
    @test ro.parameters[mo.index["mu"]] ≈ (non - 10kb) / 10 rtol = 1e-9
    q0_exact = 2 * (non * log(non * (1 + tau) / (non + moff)) + moff * log(moff * (1 + tau) / (tau * (non + moff))))
    @test q0(mo, observed_data(mo)) ≈ q0_exact rtol = 1e-8

    # covariance equals inverse of a finite-difference Hessian of the NLL
    mf = HistModel(ws_full())
    df = observed_data(mf)
    rfull = fit(mf, df)
    @test rfull.converged
    fl = findall(rfull.floating)
    x = rfull.parameters
    h = 1e-4
    H = zeros(length(fl), length(fl))
    for (a, i) in enumerate(fl), (c, j) in enumerate(fl)
        f(di, dj) = (y = copy(x); y[i] += di; y[j] += dj; nll(mf, y, df))
        H[a, c] = (f(h, h) - f(h, -h) - f(-h, h) + f(-h, -h)) / (4h^2)
    end
    C = inv(Symmetric(H))
    @test maximum(abs.(C .- rfull.covariance[fl, fl]) ./ sqrt.(diag(C) * diag(C)')) < 1e-4
    cor = correlation_matrix(rfull)
    @test all(abs.(diag(cor)[fl]) .≈ 1)
    # minimum: gradient-free check that small moves do not lower the NLL
    for i in fl
        for dx in (-1e-3, 1e-3)
            y = copy(x); y[i] = clamp(y[i] + dx * rfull.uncertainties[i], mf.parameters[i].lower, mf.parameters[i].upper)
            @test nll(mf, y, df) >= rfull.nll - 1e-12
        end
    end

    # Asimov round trip: fitting the Asimov dataset returns the generating point
    p0 = [p.init for p in mf.parameters]
    p0[mf.index["mu"]] = 1.3
    ra = fit(mf, asimov_data(mf, p0))
    fa = findall(ra.floating)
    @test maximum(abs.(ra.parameters[fa] .- p0[fa]) ./ ra.uncertainties[fa]) < 1e-6
end
