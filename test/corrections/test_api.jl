@testset "API" begin
    c1 = corr("sf", [var("eta"), var("pt"), var("syst", "string")],
              binning("eta", [-2.5, 0.0, 2.5], [
                  category("syst", ["nominal" => formula("1+0.001*x", ["pt"]), "up" => 1.1]),
                  category("syst", ["nominal" => 0.9, "up" => 1.2])], "clamp"))
    json = cset_json([c1, corr("const", [], 1.234)])
    mktempdir() do dir
        plain = joinpath(dir, "set.json")
        write(plain, json)
        gz = joinpath(dir, "set.json.gz")
        write(gz, transcode(Cascade.Corrections.CodecZlib.GzipCompressor, Vector{UInt8}(json)))
        for path in (plain, gz)
            cs = load_correctionset(path)
            @test cs isa CorrectionSet
            @test keys(cs) == ["const", "sf"]
            @test haskey(cs, "sf") && !haskey(cs, "nope")
            @test_throws KeyError cs["nope"]
            csf = cs["sf"]
            @test csf.name == "sf" && csf.version == 1
            @test [v.type for v in csf.inputs] == [:real, :real, :string]
            @test evaluate(csf, -1.0, 50.0, "nominal") == 1 + 0.001 * 50.0
            @test evaluate(cs["const"]) == 1.234
        end
    end
    c = parse_correctionset(json)["sf"]
    # argument types: Float32 / Int / SubString
    @test evaluate(c, -1.0f0, 50, SubString("xnominal", 2)) == evaluate(c, -1.0, 50.0, "nominal")
    # vectorized evaluation equals scalar evaluation, scalars are broadcast
    etas = collect(range(-3.0, 3.0; length = 101))
    pts = collect(range(10.0, 500.0; length = 101))
    out = evaluate(c, etas, pts, "nominal")
    @test out == [evaluate(c, etas[i], pts[i], "nominal") for i in eachindex(etas)]
    syst = [isodd(i) ? "up" : "nominal" for i in eachindex(etas)]
    @test evaluate(c, etas, 40.0, syst) == [evaluate(c, etas[i], 40.0, syst[i]) for i in eachindex(etas)]
    buf = zeros(length(etas))
    @test evaluate!(buf, c, Float32.(etas), pts, "up") === buf
    @test buf == [evaluate(c, Float64(Float32(e)), p, "up") for (e, p) in zip(etas, pts)]
    @test_throws CorrectionError evaluate(c, etas, pts[1:10], "up")
    # no allocations on the scalar and in-place paths after compilation
    @test allocs_scalar(c, 1.0, 2.0, "up") == 0
    @test allocs_inplace(buf, c, etas, pts, "up") == 0
end
