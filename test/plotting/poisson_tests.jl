@testset "Poisson data errors" begin
    # Oracle: scipy 1.17.1 (LCG_110 on gate), chi2.ppf(α/2, 2n)/2 and chi2.ppf(1-α/2, 2n+2)/2.
    oracle = [(0, 0.0, 1.8410216450092634), (1, 0.8272462209765501, 2.299526559115855),
              (2, 1.2918145601810287, 2.6378596234552454), (3, 1.632704686109566, 2.9181858328833963),
              (5, 2.1596911444067795, 3.3824726521468875), (10, 3.108694439361643, 4.266949761009391),
              (20, 4.43444798221412, 5.5465192295114605), (100, 9.983254822886593, 11.033360941149667),
              (1000, 31.61749859343422, 32.63332347484902), (2069, 45.482593925722085, 46.4935929724179),
              (10000, 99.99833258825674, 101.00333402802971)]
    lo, hi = poisson_errors(Float64[o[1] for o in oracle])
    for (i, o) in enumerate(oracle)
        @test isapprox(lo[i], o[2]; rtol=1e-9, atol=1e-12)
        @test isapprox(hi[i], o[3]; rtol=1e-9)
    end
    @test_throws ArgumentError poisson_errors([1.5])
    @test_throws ArgumentError poisson_errors([-1.0])
    @test_throws ArgumentError poisson_errors([1.0]; cl=1.0)
end
