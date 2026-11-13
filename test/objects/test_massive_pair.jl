module TestMassivePair
using Test, Random, Cascade.Objects

@testset "massive two-object kinematics" begin
    @test mass_massive(0, 0, 0, 3, 0, 0, 0, 4) == 7.0
    @test mass_massive(5, 0, 0, 12, 5, 0, π, 12) ≈ 26.0
    @test mass_massive(1e9, 2, 0, 3, 1e9, 2, 0, 3) ≈ 6.0
    @test mass_massive(0, 0, 0, 0, 5, 1, 2, 3) ≈ 3.0
    @test mass_massive(10f0, 0f0, 0f0, 0f0, 10f0, 0f0, Float32(π), 0f0) isa Float64
    @test_throws DomainError mass_massive(-1, 0, 0, 1, 1, 0, 0, 1)
    @test_throws DomainError mass_massive(1, 0, 0, -1, 1, 0, 0, 1)
    @test pair_pt(10, 0, 20, 0) ≈ 30.0
    @test pair_pt(10, 0, 10, π) ≈ 0.0 atol = 1e-12
    @test pair_pt(3, 0, 4, π / 2) ≈ 5.0
    @test pair_pt(0f0, 0f0, 0f0, 0f0) === 0.0
    rng = MersenneTwister(904)
    for _ in 1:1000
        p, q = 1 .+ 100 .* rand(rng, 2)
        e, f = 4 .* rand(rng, 2) .- 2
        a, b = 2π .* rand(rng, 2)
        m, n = 20 .* rand(rng, 2)
        E = hypot(p * cosh(e), m) + hypot(q * cosh(f), n)
        px = p * cos(a) + q * cos(b)
        py = p * sin(a) + q * sin(b)
        pz = p * sinh(e) + q * sinh(f)
        expected = sqrt(max(E^2 - px^2 - py^2 - pz^2, 0.0))
        @test mass_massive(p, e, a, m, q, f, b, n) ≈ expected rtol = 1e-10
        @test pair_pt(p, a, q, b) ≈ hypot(px, py)
        @test mass_massive(p, e, a, 0, q, f, b, 0) ≈ mass_massless(p, e, a, q, f, b) rtol = 1e-10
    end
end
end
