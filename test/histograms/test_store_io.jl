module TestStoreIO
using Test, Random, Cascade.Histograms

@testset "store JSON round trip is bit-exact" begin
    rng = MersenneTwister(7)
    s = HistogramStore()
    s.meta["lumi_pb"] = 1210.0
    for r in ("a", "b"), v in (NOMINAL, "xUp")
        h = hist!(s, HistKey(r, "smp", v, "pt"), collect(range(-2.4, 2.4; length = 21)))
        for _ in 1:1000
            fill_bin!(h, 6 * rand(rng) - 3, randn(rng) * 1e3)
        end
    end
    mktempdir() do d
        p = write_store(joinpath(d, "s.json"), s)
        t = read_store(p)
        @test keys(t) == keys(s)
        @test all(t[k] == s[k] for k in keys(s))
        @test t.meta["lumi_pb"] == 1210.0
        write(joinpath(d, "x.json"), "{}")
        @test_throws ArgumentError read_store(joinpath(d, "x.json"))
    end
end
end
