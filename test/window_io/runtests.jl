# Standalone, dependency-free focused tests for the window-reader basket index
# and direct column-file writes. Includes ONLY the production sources (plus the
# pre-change reference copies when supplied) into stub modules; no UnROOT/JSON3.
#   julia test/window_io/runtests.jl [before_snapshot_root]
using Test, Random

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const BEFORE = let b = length(ARGS) >= 1 ? ARGS[1] : get(ENV, "CASCADE_WINDOW_IO_BEFORE", "")
    isempty(b) ? b : abspath(b)
end

function stubmodule(name, files)
    m = Module(name)
    Core.eval(m, :(module UnROOT
        basketarray(args...) = error("UnROOT stub: real basket read not allowed")
        numbaskets(b) = error("UnROOT stub")
    end))
    Core.eval(m, :(module JSON3
        write(x) = repr(x)   # deterministic within one process; same for old/new
    end))
    Core.eval(m, :(struct NanoAODSource end))
    Base.include(m, joinpath(ROOT, "src", "IO", "Jagged.jl"))
    for f in files
        Base.include(m, f)
    end
    return m
end

const NEW = stubmodule(:NewIO, [joinpath(ROOT, "src/IO/write_column_file.jl"), joinpath(ROOT, "src/IO/StreamWindowReader.jl")])
const HAVE_OLD = !isempty(BEFORE) && isfile(joinpath(BEFORE, "src/IO/StreamWindowReader.jl"))
const OLD = HAVE_OLD ? stubmodule(:OldIO, [joinpath(BEFORE, "src/IO/write_column_file.jl"), joinpath(BEFORE, "src/IO/StreamWindowReader.jl")]) : nothing

# Descriptor vector that counts element accesses (proves no full scan).
struct CountingVec{T} <: AbstractVector{T}
    v::Vector{T}
    n::Base.RefValue{Int}
end
CountingVec(v) = CountingVec(v, Ref(0))
Base.size(c::CountingVec) = size(c.v)
Base.getindex(c::CountingVec, i::Int) = (c.n[] += 1; c.v[i])

mkbaskets(starts) = [NEW.StreamBasketDesc((starts[i] + 1, starts[i+1], 64 + i, 100 + 7i, 16)) for i in 1:length(starts)-1]

function runreader(M, br, name, ranges, opts; needed = nothing, offsets = nothing, reader)
    diag = Dict{String,Any}("unique_baskets" => 0, "repeated_baskets" => 0)
    seen = Set{Tuple{String,Int}}(); obs = Any[]; outs = Any[]; reads = Int[]
    for r in ranges
        nd = needed === nothing ? nothing : needed[r]
        off = offsets === nothing ? nothing : (o = offsets[first(r):last(r)+1]; o .- o[1])
        res = try
            x = M.read_stream_branch_owned(br, name, r, opts, diag, seen; needed = nd, offsets = off, phase = "post",
                basket_reader = (b, k) -> (push!(reads, k); reader(k)), basket_observer = o -> push!(obs, o))
            x isa M.Jagged ? (:jagged, reinterpret(UInt32, copy(x.content)), copy(x.offsets)) : (:flat, reinterpret(UInt32, copy(x)))
        catch e
            (:error, sprint(showerror, e))
        end
        push!(outs, res)
    end
    return (outs = outs, diag = diag, seen = sort!(collect(seen)), obs = obs, reads = reads)
end

@testset "window_io" begin
    @testset "typed descriptors are concrete isbits" begin
        @test isbitstype(NEW.StreamBasketDesc)
        @test isconcretetype(Vector{NEW.StreamBasketDesc})
    end

    @testset "overlap finder == exhaustive linear oracle" begin
        rng = MersenneTwister(7)
        oracle(bs, r) = [i for (i, b) in enumerate(bs) if !(b.lo > last(r) || b.hi < first(r))]
        bad = 0
        for trial in 1:300
            nb = rand(rng, 0:9)
            starts = [0; cumsum(rand(rng, 1:4, nb))]
            bs = mkbaskets(starts)
            gapped = [(lo = 3i, hi = 3i + 1, bytes = 1, decoded = 1, keylen = 16) for i in 1:nb]  # monotonic, gaps
            M = last(starts) + 3nb + 3
            for B in (bs, gapped), f in 0:M, l in (f - 1):M
                collect(NEW.stream_basket_overlap(B, f:l)) == oracle(B, f:l) || (bad += 1)
            end
        end
        @test bad == 0
        @test NEW.stream_basket_overlap(NEW.StreamBasketDesc[], 1:0) == 1:0
    end

    @testset "logarithmic descriptor access" begin
        cv = CountingVec(mkbaskets(collect(0:4:4000)))   # 1000 baskets x 4 events
        @test NEW.stream_basket_overlap(cv, 401:800) == 101:200
        @test cv.n[] <= 2 * (ceil(Int, log2(1001)) + 1)
    end

    @testset "reader parity vs pre-change reference" begin
        if !HAVE_OLD
            @info "before snapshot not supplied; parity skipped"
            @test_skip false
        else
            rng = MersenneTwister(11)
            opts = (stream_window_bytes = 10^6, stream_basket_bytes = 10^6)
            ncases = 0; mism = 0; errs = 0
            for trial in 1:120
                nb = rand(rng, 1:7)
                starts = [0; cumsum(rand(rng, 1:4, nb))]; N = last(starts)
                bsv = mkbaskets(starts)
                lens = rand(rng, 0:3, N); evoffs = [0; cumsum(lens)]
                flat = [Float32.(rand(rng, starts[k+1]-starts[k])) for k in 1:nb]
                jag = [[Float32.(rand(rng, lens[e])) for e in starts[k]+1:starts[k+1]] for k in 1:nb]
                cuts = sort!(unique!([0; rand(rng, starts, rand(rng, 0:3)); N]))
                ranges = [cuts[i]+1:cuts[i+1] for i in 1:length(cuts)-1]
                ranges = vcat(ranges, ranges[1:1], [1:0])          # repeat (seen) + empty range
                trial % 10 == 0 && push!(ranges, 2:N)               # may split a basket -> error parity
                needed = rand(rng, Bool, N)
                for maskable in (true, false), jagged in (false, true), mask in (false, true)
                    br = (E = Float32, jagged = jagged, maskable = maskable, baskets = bsv)
                    rd = jagged ? (k -> jag[k]) : (k -> flat[k])
                    kw = mask ? (needed = needed, offsets = jagged ? evoffs : nothing) : (needed = nothing, offsets = nothing)
                    a = runreader(NEW, br, "b", ranges, opts; reader = rd, kw...)
                    b = runreader(OLD, br, "b", ranges, opts; reader = rd, kw...)
                    (a.outs == b.outs && a.diag == b.diag && a.seen == b.seen && a.obs == b.obs && a.reads == b.reads) || (mism += 1)
                    errs += count(o -> o[1] == :error, a.outs)
                    ncases += 1
                end
            end
            @test mism == 0
            @test ncases == 960
            @test errs > 0
            starts = [0, 2, 4]; bsv = mkbaskets(starts)
            jag = [[[1f0], [2f0, 3f0]], [Float32[], [4f0]]]
            for (opts2, offs, rd) in (
                    ((stream_window_bytes = 40,), [0, 1, 3, 3, 4], k -> jag[k]),            # canonical budget (4*4+8*5=56>40)
                    ((stream_window_bytes = 10^6,), [0, 100, 100, 100, 100], k -> jag[k]),  # exceeds declared
                    ((stream_window_bytes = 10^6,), [0, 2, 3, 3, 4], k -> jag[k]),          # counter mismatch
                    ((stream_window_bytes = 10^6,), [0, 1, 3, 3, 4], k -> jag[k][1:1]))     # entry mismatch
                br = (E = Float32, jagged = true, maskable = true, baskets = bsv)
                a = runreader(NEW, br, "p", [1:4], opts2; needed = trues(4), offsets = offs, reader = rd)
                b = runreader(OLD, br, "p", [1:4], opts2; needed = trues(4), offsets = offs, reader = rd)
                @test a.outs[1][1] == :error
                @test a.outs == b.outs && a.diag == b.diag && a.obs == b.obs && a.reads == b.reads
            end
            br = (E = Float32, jagged = true, maskable = true, baskets = bsv)   # unmasked output budget
            a = runreader(NEW, br, "p", [1:4], (stream_window_bytes = 50,); reader = k -> jag[k])
            b = runreader(OLD, br, "p", [1:4], (stream_window_bytes = 50,); reader = k -> jag[k])
            @test a.outs[1][1] == :error && a.outs == b.outs && a.diag == b.diag
        end
    end

    @testset "reader touches only overlapping descriptors" begin
        cv = CountingVec(mkbaskets(collect(0:2:2000)))
        br = (E = Float32, jagged = false, maskable = true, baskets = cv)
        diag = Dict{String,Any}("unique_baskets" => 0, "repeated_baskets" => 0)
        obs = Int[]
        x = NEW.read_stream_branch_owned(br, "f", 1001:1010, (stream_window_bytes = 10^6,), diag, Set{Tuple{String,Int}}();
            basket_reader = (b, k) -> Float32[k, k], basket_observer = o -> push!(obs, o.basket))
        @test obs == collect(501:505)          # original basket indices
        @test x == Float32[501, 501, 502, 502, 503, 503, 504, 504, 505, 505]
        @test diag["unique_baskets"] == 5
        @test cv.n[] <= 2 * (ceil(Int, log2(1001)) + 1) + 5
    end

    @testset "writer bytes identical to pre-change reference" begin
        dir = mktempdir()
        nanpayload = reinterpret(Float64, 0x7ff8_dead_beef_0001)
        cols = Dict{String,Any}(
            "f64" => [nanpayload, -0.0, Inf, -Inf, nextfloat(0.0), 1.5, floatmin(Float64) / 2],
            "f32" => Float32[reinterpret(Float32, 0x7fc0_1234), -0f0, Inf32, nextfloat(0f0)],
            "i16" => Int16[typemin(Int16), -1, 0, typemax(Int16)],
            "boolv" => Bool[true, false, true],
            "bitv" => BitVector([true, false, false, true, true]),
            "viewv" => view([1.0, 2.0, NaN, 4.0], 2:4),
            "rng" => Int32(1):Int32(3),
            "emptyv" => Float32[],
            "jag" => NEW.Jagged(Float32[1, 2, NaN], [0, 2, 2, 3]),
            "jagempty" => NEW.Jagged(Int64[], [0, 0, 0]),
            "jag0" => NEW.Jagged(UInt8[], [0]))
        meta = Dict{String,Any}("k" => "v")
        order = sort!(collect(keys(cols)))
        pn = NEW.write_column_file(joinpath(dir, "new.col"), cols; order, meta)
        if HAVE_OLD
            jcols = Dict{String,Any}(k => (v isa NEW.Jagged ? OLD.Jagged(v.content, v.offsets) : v) for (k, v) in cols)
            po = OLD.write_column_file(joinpath(dir, "old.col"), jcols; order, meta)
            @test read(pn) == read(po)
            @test filesize(pn) > 100
        else
            @test_skip false
        end
        @test reinterpret(UInt64, cols["f64"][1]) == 0x7ff8_dead_beef_0001
        @test_throws ArgumentError NEW.write_column_file(joinpath(dir, "bad.col"), Dict("x" => Any[1]))
        @test isempty(filter(f -> occursin(".tmp.", f), readdir(dir)))
    end
end
