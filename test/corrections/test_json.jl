@testset "read_json (RapidJSON number semantics)" begin
    rj = Cascade.Corrections.read_json
    v = rj("""{"a": [1, -0, 2.5, -1e-3, 1E2, 4294967296, -2147483649, NaN, -Infinity, Inf, "x\\u00e9\\n", true, null], "a": 7}""")
    @test v["a"][1] === Int64(1) && v["a"][2] === Int64(0)
    @test v["a"][3] === 2.5 && v["a"][4] === -1e-3 && v["a"][5] === 100.0
    @test v["a"][6] === Int64(4294967296) && v["a"][7] === Int64(-2147483649)
    @test isnan(v["a"][8]) && v["a"][9] === -Inf && v["a"][10] === Inf
    @test v["a"][11] == "x\u00e9\n" && v["a"][12] === true && v["a"][13] === nothing
    # 17 significant digits: significand rounded to double, then divided by 1e16
    @test rj("-2.4999999999999996") === -(Float64(24999999999999996) / 1e16)
    @test rj("0.1") === 0.1
    @test_throws CorrectionError rj("[1,]")
    @test_throws CorrectionError rj("1.")
    @test_throws CorrectionError rj("{} x")
end
