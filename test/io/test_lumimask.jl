module TestLumiMask
using Test, Cascade.IO

@testset "LumiMask" begin
    mktempdir() do d
        p = joinpath(d, "golden.json")
        write(p, """{"100": [[1, 10], [20, 30]], "101": [[5, 5]]}""")
        m = load_lumimask(p; run_min = 100, run_max = 100)
        @test in_lumimask(m, 100, 1) && in_lumimask(m, 100, 10) && in_lumimask(m, 100, 25)
        @test !in_lumimask(m, 100, 11) && !in_lumimask(m, 100, 0)
        @test !in_lumimask(m, 101, 5)                 # outside run range
        m2 = load_lumimask(p)
        @test in_lumimask(m2, 101, 5) && !in_lumimask(m2, 102, 1)
        @test lumimask_column(m2, UInt32[100, 100, 101], UInt32[2, 15, 5]) == [true, false, true]
        r = load_lumimask(""; run_min = 5, run_max = 6)
        @test in_lumimask(r, 5, 999) && !in_lumimask(r, 7, 1)
    end
end
end
