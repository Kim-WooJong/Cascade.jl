module TestColsPreflight
using Test, Cascade, TOML, JSON3
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..StreamingFixtures

function fixture(path, descriptors; payload = UInt8[], meta = Dict{String,Any}())
    header = JSON3.write(Dict("version" => 1, "meta" => meta, "columns" => descriptors))
    open(path, "w") do io
        write(io, b"CASCOL01", htol(UInt64(sizeof(header))), header, payload)
    end
    return path
end
descriptor(; name = "x", type = "Float64", jagged = false, n = 1, m = n) =
    Dict("name" => name, "eltype" => type, "jagged" => jagged, "length" => n, "content_length" => m)
function rejection(path; kwargs...)
    try
        open_export_columns(path; kwargs...)
        return "NO REJECTION"
    catch err
        err isa ErrorException || rethrow()
        return sprint(showerror, err)
    end
end

@testset "cols export rejects before untrusted payload allocation" begin
mktempdir() do dir
    path = joinpath(dir, "bad.cols")
    # Not valid cols: the size guard must win before parsing even the magic.
    open(path, "w") do io
        seek(io, 256_000_000); write(io, UInt8(0))
    end
    @test occursin("max_input_bytes before parsing", rejection(path))
    @test (@allocated rejection(path)) < 2_000_000
    cases = [
        ([descriptor(n = typemax(Int))], UInt8[], "max_events before allocation"),
        ([descriptor(n = 0, jagged = true, m = typemax(Int))], UInt8[], "payload exceeds byte budget before allocation"),
        ([descriptor(n = 1_000_000)], UInt8[], "truncated cols compatibility payload before allocation"),
        ([descriptor(n = -1)], UInt8[], "declared rows"),
        ([descriptor(n = true)], UInt8[], "declared rows"),
        ([descriptor(n = 1.5)], UInt8[], "declared rows"),
        ([descriptor(type = "String")], UInt8[], "unsupported cols compatibility primitive"),
        ([descriptor(n = 0), descriptor(n = 0)], UInt8[], "duplicate"),
        ([descriptor(n = 0), descriptor(name = "y", n = 1)], UInt8[], "inconsistent cols compatibility row counts"),
        ([descriptor(n = 1, m = 2)], UInt8[], "scalar content length"),
        ([descriptor(n = 0, jagged = true, m = 0)], reinterpret(UInt8, Int64[1]), "offsets before allocation"),
        ([descriptor(n = 2, jagged = true, m = 1)], vcat(reinterpret(UInt8, Int64[0,1,0]), zeros(UInt8,8)), "offsets before allocation"),
        ([descriptor(type = "Bool")], UInt8[2], "Bool bytes"),
        ([1], UInt8[], "invalid cols compatibility descriptor")]
    for (descs, payload, message) in cases
        fixture(path, descs; payload)
        @test occursin(message, rejection(path))
        # Warmed call: tiny input declaring up to exabytes must not allocate N.
        @test (@allocated rejection(path)) < 2_000_000
    end
    fixture(path, [descriptor()]; payload = zeros(UInt8,8))
    @test occursin("eager allocation exceeds max_buffer_bytes", rejection(path; max_buffer_bytes = 4096))
    fixture(path, []; meta = Dict("nevents" => typemax(Int)))
    @test occursin("metadata rows exceed max_events", rejection(path))
    open(path, "w") do io
        write(io, b"CASCOL01", htol(typemax(UInt64)))
    end
    @test occursin("header exceeds bounded header budget", rejection(path))
    @test (@allocated rejection(path)) < 2_000_000
    # Bounded valid scalar/jagged Bool bytes use precisely the generic format.
    good = Dict{String,Any}("event" => UInt64[typemax(UInt64),2^53+1],
        "flags" => Jagged(Bool[true,false,true], [0,1,3]), "weight" => Float32[-1,2])
    write_column_file(path, good; meta = Dict("gen_weight_sum" => -4.0))
    src = open_export_columns(path)
    @test nevents(src) == 2
    @test gen_weight_sum(src) == -4.0
    @test src.cols["event"] == good["event"]
    @test src.cols["flags"].content == good["flags"].content
    @test src.cols["flags"].offsets == good["flags"].offsets
    @test reinterpret(UInt32,src.cols["weight"]) == reinterpret(UInt32,good["weight"])
end
end

@testset "both export modes preflight cols and publish nothing on failure" begin
for mode in ("streaming", "legacy_eager")
mktempdir() do dir
    p = setup_stream(dir; theory = true)
    raw = TOML.parsefile(p)
    mode == "legacy_eager" && (raw["reduced_skim"] = Dict("mode" => mode))
    rewrite(p,raw)
    path = joinpath(dir,"input/a.cols")
    original = read(path)
    for (label, descs) in (("huge-rows", [descriptor(n = typemax(Int))]),
                            ("huge-content", [descriptor(n = 0, jagged = true, m = typemax(Int))]),
                            ("truncated", [descriptor(n = 1_000_000)]))
        fixture(path, descs)
        out = joinpath(dir,label)
        @test_throws ErrorException reduce_analysis(RunOptions(p); output_dir = out)
        @test !ispath(out)
        @test !any(startswith(".cascade-reduce-"), readdir(dir))
    end
    open(path, "w") do io
        seek(io,256_000_000); write(io,UInt8(0))
    end
    out = joinpath(dir,"oversized")
    @test_throws ErrorException reduce_analysis(RunOptions(p); output_dir = out)
    @test !ispath(out)
    @test !any(startswith(".cascade-reduce-"), readdir(dir))
    write(path,original)
    out = joinpath(dir,"valid")
    manifest = reduce_analysis(RunOptions(p); output_dir = out)
    @test manifest["schema"] == (mode == "streaming" ? 2 : 1)
    @test isfile(joinpath(out,"analysis.toml"))
end
end
end
end
