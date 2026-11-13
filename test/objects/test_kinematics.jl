module TestKinematics
using Test, Random, Cascade.Objects

# Independent oracle: the formulas of the reference analysis (TTbarEmu.jl).
ref_dr(eta1, phi1, eta2, phi2) = hypot(eta1 - eta2, mod(phi1 - phi2 + π, 2π) - π)
ref_mll(pt1, eta1, phi1, pt2, eta2, phi2) = sqrt(max(2pt1 * pt2 * (cosh(eta1 - eta2) - cos(phi1 - phi2)), 0.0))

@testset "kinematics" begin
    @test deltaR(0.0, 0.1, 0.0, 2π - 0.1) ≈ 0.2 atol = 1e-12
    @test deltaR(1.0, 0.0, 0.0, 0.0) == 1.0
    @test mass_massless(10.0, 0.0, 0.0, 10.0, 0.0, π) ≈ 20.0
    @test mass_massless(10.0f0, 0.3f0, 0.1f0, 10.0f0, 0.3f0, 0.1f0) === 0.0
    rng = MersenneTwister(1)
    for _ in 1:10_000
        a = (rand(rng, Float32) * 200, (rand(rng, Float32) - 0.5f0) * 5, (rand(rng, Float32) - 0.5f0) * 2π)
        b = (rand(rng, Float32) * 200, (rand(rng, Float32) - 0.5f0) * 5, (rand(rng, Float32) - 0.5f0) * 2π)
        @test deltaR(a[2], a[3], b[2], b[3]) === ref_dr(a[2], a[3], b[2], b[3])
        @test mass_massless(a..., b...) === ref_mll(a..., b...)
    end
end
end
