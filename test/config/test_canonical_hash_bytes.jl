module TestCanonicalHashBytes
using Test, SHA, Cascade, Cascade.Config

legacy_hash(value) = bytes2hex(sha256(Cascade.Config.canonical_json(value)))

@testset "canonical hash byte input preserves wire semantics" begin
    unicode = Dict("a" => 1, "b" => Any[true, nothing, "é", "한글", "😀"])
    reordered = Dict("b" => Any[true, nothing, "é", "한글", "😀"], "a" => 1)
    nonfinite = Any[NaN, Inf, -Inf, :symbol]
    values = Any[nothing, Dict(), unicode, reordered, nonfinite, :symbol,
        -0.0, Float32(1.5), typemax(UInt64), "é versus é",
        Dict("nested" => (Dict("z" => false, "a" => nothing), Any[1, "\n", "\""]))]
    for value in values
        @test canonical_hash(value) == legacy_hash(value)
    end
    @test canonical_hash(unicode) == canonical_hash(reordered)
    @test canonical_hash(nothing) == "74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b"
    @test canonical_hash(Dict()) == "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
    @test canonical_hash(unicode) == "9fd2cff0501072c172a73ae2ca7ea6202cefd9e88eee4b407ab3075bd2da6ff2"
    @test canonical_hash(nonfinite) == "a47a863ce0ccf36e9c916b8bea446fc890fd680d5838aa7ffce303dae2c397f1"
    large = [Dict("entry" => i, "text" => "é/한글/😀", "values" => Any[i / 8, nothing, true]) for i in 1:1024]
    @test sizeof(Cascade.Config.canonical_json(large)) > 65_536
    @test canonical_hash(large) == legacy_hash(large)
end
end
