module TestColumnFile
using Test, Cascade.IO

@testset "column file round trip" begin
    mktempdir() do d
        p = joinpath(d, "t.cols")
        cols = Dict{String,Any}(
            "f64" => [1.0, -0.0, NaN, 1e-300, prevfloat(1.0)], "f32" => Float32[1.5, NaN32, 3, 4, 5],
            "i16" => Int16[1, -2, 3, 4, 5], "u8" => UInt8[0, 255, 1, 2, 3], "b" => [true, false, true, true, false],
            "jag" => Jagged([Float32[1, 2], Float32[], Float32[3], Float32[], Float32[4, 5, 6]]),
            "jb" => Jagged([[true], Bool[], [false, true], Bool[], Bool[]]))
        write_column_file(p, cols; meta = Dict("k" => 1, "s" => "x"))
        back, meta, order = read_column_file(p)
        @test order == sort(collect(keys(cols)))
        @test meta["k"] == 1 && meta["s"] == "x"
        for k in ["f64", "f32", "i16", "u8", "b"]
            @test eltype(back[k]) == eltype(cols[k])
            @test reinterpret(UInt8, back[k]) == reinterpret(UInt8, cols[k])   # bit-exact (NaN, -0.0)
        end
        @test back["jag"].offsets == cols["jag"].offsets && back["jag"].content == cols["jag"].content
        @test back["jb"].content == cols["jb"].content
        sub, _, _ = read_column_file(p; names = ["u8"])
        @test collect(keys(sub)) == ["u8"]
        @test_throws ArgumentError write_column_file(joinpath(d, "bad.cols"), Dict("s" => ["a"]))
        write(joinpath(d, "junk"), "notacolumnfile")
        @test_throws ArgumentError read_column_file(joinpath(d, "junk"))
    end
end
end
