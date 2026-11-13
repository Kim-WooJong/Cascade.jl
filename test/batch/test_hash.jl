@testset "batch JSON wire hash stability" begin
    for x in (Dict("v" => 1.), Dict("v" => [1., 2.]), Dict("v" => -0.),
        Dict("v" => typemin(Int)), Dict("v" => [true, false, nothing]))
        y = BP._jsdict(JSON3.read(JSON3.write(x)))
        @test BP.batch_hash(x) == BP.batch_hash(y)
    end
    @test BP.batch_hash(Dict("v" => 1)) != BP.batch_hash(Dict("v" => 2))
end
