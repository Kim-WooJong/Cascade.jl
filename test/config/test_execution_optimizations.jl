@testset "bounded variable memo execution configuration" begin
    @test memoization_options(Dict()) == (enabled=false, max_bytes=268435456)
    raw = Dict("execution" => Dict("memoize_variables"=>true, "memoize_max_bytes"=>4096))
    @test memoization_options(raw) == (enabled=true, max_bytes=4096)
    @test validate_keys(raw) === raw
    for bad in (0, 1, "true", nothing, 1.0)
        @test_throws ArgumentError validate_keys(Dict("execution"=>Dict("memoize_variables"=>bad)))
        @test_throws ArgumentError validate_keys(Dict("profiles"=>Dict("unused"=>Dict("execution"=>Dict("memoize_variables"=>bad)))))
    end
    for bad in (0, -1, true, false, 1.5, "4096", nothing, big(typemax(Int))+1)
        @test_throws ArgumentError validate_keys(Dict("execution"=>Dict("memoize_max_bytes"=>bad)))
        @test_throws ArgumentError validate_keys(Dict("profiles"=>Dict("unused"=>Dict("execution"=>Dict("memoize_max_bytes"=>bad)))))
    end
    @test_throws ArgumentError memoization_options(Dict("execution"=>42))
end

@testset "event-range execution configuration" begin
    @test !event_range_selection(Dict())
    @test event_range_selection(Dict("execution"=>Dict("event_range_selection"=>true)))
    for bad in (0,1,1.0,"true",nothing)
        @test_throws ArgumentError validate_keys(Dict("execution"=>Dict("event_range_selection"=>bad)))
        @test_throws ArgumentError validate_keys(Dict("profiles"=>Dict("inactive"=>Dict("execution"=>Dict("event_range_selection"=>bad)))))
    end
    @test_throws ArgumentError validate_keys(Dict("execution"=>Dict("event_range_selection"=>true,"stream_metadata_bytes"=>4096,"stream_queue_bytes"=>4096)))
end

@testset "execution profile relations use merged base values" begin
    base = Dict("execution"=>Dict("stream_metadata_bytes"=>4096),
        "profiles"=>Dict("valid"=>Dict("execution"=>Dict("event_range_selection"=>true,"stream_queue_bytes"=>8192))))
    @test validate_keys(base) === base
    invalid = deepcopy(base)
    invalid["profiles"]["valid"]["execution"]["stream_queue_bytes"] = 2048
    @test_throws ArgumentError validate_keys(invalid)
end
