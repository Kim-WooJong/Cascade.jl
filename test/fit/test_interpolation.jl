@testset "interpolation" begin
    hi, lo = 1.12, 0.91
    c = code4_coefficients(hi, lo)
    g(a) = normsys_factor(:code4, a, hi, lo, c)
    e(a) = normsys_factor(:code1, a, hi, lo, c)
    @test g(0.0) == 1.0
    @test g(1.0) ≈ hi rtol = 1e-14
    @test g(-1.0) ≈ lo rtol = 1e-14
    @test g(2.5) ≈ hi^2.5 rtol = 1e-14
    @test g(-1.7) ≈ lo^1.7 rtol = 1e-14
    # value, first and second derivative continuous at alpha = +-1
    h = 1e-4
    for a0 in (1.0, -1.0)
        inner = a0 - sign(a0) * 1e-9
        @test g(inner) ≈ e(a0) rtol = 1e-8
        d1_in = (g(inner) - g(inner - sign(a0) * h)) / h
        d1_out = (e(a0 + sign(a0) * h) - e(a0)) / h
        @test d1_in ≈ d1_out rtol = 1e-3
        d2_in = (g(inner) - 2g(inner - sign(a0) * h) + g(inner - 2sign(a0) * h)) / h^2
        d2_out = (e(a0 + 2sign(a0) * h) - 2e(a0 + sign(a0) * h) + e(a0)) / h^2
        @test d2_in ≈ d2_out rtol = 1e-2
    end
    @test_throws ArgumentError code4_coefficients(1.1, 0.0)

    nom, up, dn = 10.0, 12.0, 9.0
    @test histosys_delta(:code4p, 0.0, nom, up, dn) == 0.0
    @test histosys_delta(:code4p, 1.0, nom, up, dn) ≈ 2.0
    @test histosys_delta(:code4p, -1.0, nom, up, dn) ≈ -1.0
    @test histosys_delta(:code4p, 2.0, nom, up, dn) ≈ 4.0
    @test histosys_delta(:code4p, -3.0, nom, up, dn) ≈ -3.0
    @test histosys_delta(:code0, 0.5, nom, up, dn) ≈ 1.0
    @test histosys_delta(:code0, -0.5, nom, up, dn) ≈ -0.5
    # code4p first derivative continuous at +-1
    for a0 in (1.0, -1.0)
        s = sign(a0)
        d_in = (histosys_delta(:code4p, a0 - s * 1e-9, nom, up, dn) -
                histosys_delta(:code4p, a0 - s * (1e-9 + h), nom, up, dn)) / (s * h)
        d_out = (histosys_delta(:code4p, a0 + s * (1e-9 + h), nom, up, dn) -
                 histosys_delta(:code4p, a0 + s * 1e-9, nom, up, dn)) / (s * h)
        @test d_in ≈ d_out rtol = 1e-3
    end
    @test_throws ArgumentError histosys_delta(:code9, 0.1, nom, up, dn)
end
