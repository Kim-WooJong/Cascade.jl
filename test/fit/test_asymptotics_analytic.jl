# Closed-form asymptotics for a single-bin counting experiment without systematics.
_sf(x) = 0.5 * Cascade.Fit.erfc(x / sqrt(2))
function _counting_cls(mu, n, s, b)
    muhat = max((n - b) / s, 0.0)
    l(m) = (m * s + b) - n * log(m * s + b)
    q = muhat > mu ? 0.0 : max(2 * (l(mu) - l(muhat)), 0.0)
    qA = 2 * (mu * s - b * log(1 + mu * s / b))
    sq, sqA = sqrt(q), sqrt(qA)
    ts = sq <= sqA ? sq - sqA : (q - qA) / (2sqA)
    clsb, clb = _sf(ts + sqA), _sf(ts)
    exp = [_sf(k + sqA) / _sf(k) for k in (2, 1, 0, -1, -2)]
    return (q=q, qA=qA, cls=clsb / clb, clsb=clsb, clb=clb, exp=exp)
end
function _bisect(f, a, b)
    for _ in 1:200
        c = 0.5(a + b)
        sign(f(c)) == sign(f(a)) ? (a = c) : (b = c)
    end
    return 0.5(a + b)
end

@testset "asymptotics: analytic counting" begin
    for (n, s, b) in ((12.0, 5.0, 8.0), (6.0, 4.0, 8.0), (30.0, 6.0, 25.0))
        m = HistModel(ws_counting(; n=n, s=s, b=b))
        d = observed_data(m)
        for mu in (0.5, 1.0, 2.5)
            ref = _counting_cls(mu, n, s, b)
            ht = hypotest(m, d, mu)
            @test ht.q ≈ ref.q atol = 1e-9
            @test ht.qA ≈ ref.qA atol = 1e-9
            @test ht.cls ≈ ref.cls atol = 1e-9
            @test ht.clsb ≈ ref.clsb atol = 1e-9
            @test ht.cls_expected ≈ ref.exp atol = 1e-9
            @test qmu_tilde(m, d, mu) ≈ ref.q atol = 1e-9
        end
        ul = upper_limit(m, d; rtol=1e-9)
        obs = _bisect(x -> _counting_cls(x, n, s, b).cls - 0.05, 1e-6, 50.0)
        @test ul.observed ≈ obs rtol = 1e-6
        for k in 1:5
            e = _bisect(x -> _counting_cls(x, n, s, b).exp[k] - 0.05, 1e-6, 50.0)
            @test ul.expected[k] ≈ e rtol = 1e-6
        end
        # median expected: qA(mu) = 1.95996...^2
        z = 1.959963984540054
        med = _bisect(x -> 2 * (x * s - b * log(1 + x * s / b)) - z^2, 1e-6, 50.0)
        @test ul.expected[3] ≈ med rtol = 1e-6
        @test issorted(ul.expected)
    end

    # q vs qtilde differ only through the POI lower bound
    spec = ws_counting(; n=5.0, s=5.0, b=8.0)
    spec["measurements"][1]["config"]["parameters"] = Any[Dict{String,Any}("name" => "mu", "bounds" => [[-5.0, 10.0]])]
    m = HistModel(spec)
    d = observed_data(m)
    @test fit(m, d).parameters[1] ≈ -0.6 atol = 1e-9
    l(mu) = (5mu + 8) - 5 * log(5mu + 8)
    @test qmu(m, d, 1.0) ≈ 2 * (l(1.0) - l(-0.6)) atol = 1e-9
    @test qmu_tilde(m, d, 1.0) ≈ 2 * (l(1.0) - l(0.0)) atol = 1e-9
    @test tmu(m, d, -0.6) ≈ 0 atol = 1e-12

    # significance: on/off closed form, expected from Asimov(mu = 1)
    mo = HistModel(ws_onoff(; n=25.0, m=40.0, tau=4.0))
    sig = significance(mo, observed_data(mo))
    q0e = 2 * (25 * log(25 * 5 / 65) + 40 * log(40 * 5 / (4 * 65)))
    @test sig.q0 ≈ q0e rtol = 1e-8
    @test sig.Z ≈ sqrt(q0e) rtol = 1e-8
    @test sig.p0 ≈ _sf(sqrt(q0e)) rtol = 1e-8
    # Asimov(mu=1) with kb profiled on data at mu=1: n_A = 10 + 10 kb, m_A = 40 kb
    # d/dkb [NLL] = 0  <=>  50 kb^2 - 15 kb - 40 = 0
    kb1 = (15 + sqrt(15^2 + 4 * 50 * 40)) / (2 * 50)
    nA, mA = 10 + 10kb1, 40kb1
    q0A = 2 * (nA * log(nA * 5 / (nA + mA)) + mA * log(mA * 5 / (4 * (nA + mA))))
    @test sig.q0_expected ≈ q0A rtol = 1e-8
end
