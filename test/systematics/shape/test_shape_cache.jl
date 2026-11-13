module TestShapeCache
using Test, JSON3
using Cascade.Corrections: evaluate
using Cascade.Systematics.Shape: shape_correction

@testset "shape payload content cache" begin
    mktempdir() do dir
        p = joinpath(dir, "jes.json")
        payload(v) = JSON3.write(Dict("schema_version" => 2, "corrections" => [Dict(
            "name" => "unc", "version" => 1, "inputs" => [],
            "output" => Dict("name" => "weight", "type" => "real"), "data" => v)]))
        write(p, payload(0.1))
        run(`touch -t 202001010000.00 $p`)
        oldstat = stat(p)
        first = shape_correction(p, "unc")
        @test evaluate(first) == 0.1
        @test shape_correction(p, "unc") === first
        write(p, payload(0.2))
        run(`touch -t 202001010000.00 $p`)
        @test stat(p).size == oldstat.size
        @test stat(p).mtime == oldstat.mtime
        second = shape_correction(p, "unc")
        @test evaluate(second) == 0.2
        @test evaluate(first) == 0.1
        @test 100 * (1 + evaluate(second)) ≈ 120
        @test 100 * (1 - evaluate(second)) ≈ 80
        @test 100 * (1 + evaluate(first)) ≈ 110
        @test 100 * (1 - evaluate(first)) ≈ 90
    end
end
end
