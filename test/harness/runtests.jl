module TestAreaIsolation
using Test
include("../isolated_area_command.jl")

@testset "standalone Main, arguments, environment and failure propagation" begin
    mktempdir() do dir
        first = joinpath(dir, "first fixture.jl")
        second = joinpath(dir, "second fixture.jl")
        failed = joinpath(dir, "failed fixture.jl")
        write(first, "using Test
const SHARED_NAME = 1
@test isempty(ARGS)
@test Main.SHARED_NAME == 1
@test Threads.nthreads() == " * string(Threads.nthreads()) * "
@test Base.active_project() == " * repr(Base.active_project()) * "
@test ENV[\"CASCADE_TEST_ISOLATION\"] == \"preserved\"
")
        write(second, "using Test
const SHARED_NAME = 2
@test isempty(ARGS)
@test Main.SHARED_NAME == 2
")
        write(failed, "exit(7)
")
        withenv("CASCADE_TEST_ISOLATION" => "preserved") do
            @test success(run(ignorestatus(isolated_area_command(first))))
            @test success(run(ignorestatus(isolated_area_command(second))))
            @test !success(run(ignorestatus(isolated_area_command(failed))))
        end
        @test_throws ArgumentError isolated_area_command(joinpath(dir, "absent.jl"))
    end
end
end
