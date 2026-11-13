@testset "HashPRNG" begin
    # reference values from correctionlib tests/test_hashprng.py
    prng(dist) = make_cset(corr("prng", [var("var1"), var("var2"), var("var3", "int")],
        Dict("nodetype" => "hashprng", "inputs" => ["var1", "var2", "var3"], "distribution" => dist)))["prng"]
    @test evaluate(prng("normal"), 1.2, 2.3, 5) == -1.263776278956304
    @test evaluate(prng("stdflat"), 1.2, 2.3, 5) == 0.5312947726732237
    @test evaluate(prng("stdnormal"), 1.2, 2.3, 5) in (0.5320038585132821, 2.227655564267796)
    # XXH64 of the empty input with seed 0
    @test Cascade.Corrections.xxh64_words(i -> UInt64(0), 0) == 0xef46db3751d8e999
    c = prng("stdflat")
    v = evaluate(c, fill(1.2, 3), [2.3, 2.3, 2.4], [5, 5, 5])
    @test v[1] == v[2] && v[1] != v[3]
end
