# Focused adversarial tests for execution.windowed_reusable_decoder (stage1 A).
# Standalone: stdlib only, no Cascade load, no ROOT input, no package build.
#
# What this DOES exercise with production source files: config validation,
# StreamWindowReader basket overlap, the reusable decoder state/counter/window
# code, the REAL _read_reusable_basket! + _validate_basket_offsets +
# _reusable_branch logic on synthetic UNCOMPRESSED baskets laid out like ROOT
# (key, payload, entry-offset trailer), real Selection staged kernels and the
# real Pipeline window loop/publication validation.
# What it does NOT exercise (stub-only, must be proven by test_actual.jl on the
# gate): UnROOT metadata parsing, XZ/LZMA native decoding + CRC/checksums,
# source identity binding, plan_stream_windows on a real file, select_chunk_results.
using Test
module ReusableHarness
using Test
const ROOT = normpath(joinpath(@__DIR__, "../.."))
src(parts...) = joinpath(ROOT, "src", parts...)
struct AnalysisConfig
    raw::Dict{String,Any}
    variations::Vector{Any}
end
AnalysisConfig(raw) = AnalysisConfig(Dict{String,Any}(raw), Any[])
for file in ("TriggerConfig", "DataQualityConfig", "column_readers", "decode_options",
             "windowed_selection", "memory_handoff", "streaming_selection_options", "memoization_options",
             "checkpoint_options", "event_ranges", "validate_keys")
    include(src("Config", file * ".jl"))
end

module EventIO
module UnROOT
const ntoh = Base.ntoh
mutable struct MmapStream
    mmap_ary::Vector{UInt8}
end
struct TBranch
    fBasketSeek::Vector{Int}
    fBasketBytes::Vector{Int}
    fLeaves::NamedTuple{(:elements,),Tuple{Vector{Int}}}
    T::Any
    J::Any
    fBasketEntry::Vector{Int}   # ROOT layout: fMaxBaskets slots (zero tail when < 9 baskets)
    fEntries::Int
    fWriteBasket::Int
end
struct ROOTFile
    fobj::MmapStream
    customstructs::Dict{String,Any}
end
struct LazyBranch
    f::ROOTFile
    b::TBranch
    fEntry::Vector{Int}
end
struct Nojagg end
struct Nooffsetjagg end
struct TBasketKey
    fNbytes::Int32; fKeylen::Int16; fObjlen::Int32; fNevBuf::Int32; fLast::Int32; fSeekKey::Int64; fClassName::String
end
struct OffsetBuffer
    io::Base.IO
    offset::Int
end
const LEGACY_CALLS = Ref(0)
read_seek_nb(f::MmapStream, pos, n) = f.mmap_ary[pos+1:pos+n]
readtype(io, ::Type{T}) where {T} = ntoh(read(io, T))
function unpack(b::OffsetBuffer, ::Type{TBasketKey})
    io = b.io
    nbytes = readtype(io, Int32); readtype(io, Int16); objlen = readtype(io, Int32); readtype(io, UInt32)
    keylen = readtype(io, Int16); nev = readtype(io, Int32); last = readtype(io, Int32); seek = readtype(io, Int64)
    return TBasketKey(nbytes, keylen, objlen, nev, last, seek, "TBasket")
end
iscompressed(key) = false
auto_T_JaggT(f, b; customstructs) = (b.T, b.J)
basketarray(args...) = (LEGACY_CALLS[] += 1; error("legacy basketarray must never run on the reusable path"))
# Same formula as UnROOT.numbaskets (bootstrap.jl): first entry >= fEntries, minus one.
numbaskets(b) = findfirst(x -> x > (b.fEntries - 1), b.fBasketEntry) - 1
module CodecXz
module TranscodingStreams
finalize(codec) = nothing
end
end
end # UnROOT
struct NanoAODSource end
const COLFILE_TYPES = Dict{String,Any}()
for f in ("Jagged", "ReusableBasketScratch", "read_reusable_basket", "decode_interpretation_supported",
          "StreamWindowReader", "stream_reusable_decoder")
    include(joinpath(dirname(dirname(@__DIR__)), "src", "IO", f * ".jl"))
end
end # EventIO
using .EventIO: Jagged
const UnROOT = EventIO.UnROOT

module Objects
function select_objects!(pred, buf::Vector{Int}, lo, hi)
    empty!(buf)
    for j in lo+1:hi
        pred(j) && push!(buf, j)
    end
    buf
end
function sort_objects! end
end
for file in ("KernelContext", "CachedObjectBuffer", "ExpressionUsage", "VariableMemo", "Cutflow", "EventTable",
             "region_masks", "region_counts", "CompiledSelection", "SelectionProgress", "apply_cuts", "event_loop",
             "prefix_pass", "selection_context", "staged_column_mask", "select_events",
             "read_stream_selection_window", "read_reusable_selection_window")
    include(src("Selection", file * ".jl"))
end
const Selection = @__MODULE__
struct StreamFileError <: Exception end
const HOOKS = Dict{Symbol,Any}()
builtin_source_readers() = true
shape_variations(cfg) = get(cfg.raw, "shape_variations", Any[])
theory_weights(cfg) = get(cfg.raw, "theory_weights", Any[])
include(src("Pipeline", "stream_selection.jl"))

# ---------------- synthetic ROOT-like uncompressed basket file ----------------
const KEYLEN = 32
be(x) = sizeof(x) == 1 ? UInt8[reinterpret(UInt8, x)] : collect(reinterpret(UInt8, [hton(x)]))
payload_bytes(values::Vector{E}) where {E} = sizeof(E) == 1 ? collect(reinterpret(UInt8, copy(values))) :
    collect(reinterpret(UInt8, hton.(values)))

mutable struct FileBuilder
    bytes::Vector{UInt8}
    branches::Vector{Any}
end
FileBuilder() = FileBuilder(fill(0xee, 64), Any[]) # pos 0 is the recovered-basket sentinel

"""Append one basket. lengths===nothing => flat. Hooks allow targeted damage."""
function add_basket!(fb, values::Vector{E}, entries; lengths = nothing, trailer = true,
        offset_hook = identity, content_hook = identity, nev = entries) where {E}
    pos = length(fb.bytes)
    content = content_hook(payload_bytes(values))
    tail = UInt8[]
    if lengths !== nothing && trailer
        starts = Int[]; acc = 0
        for l in lengths; push!(starts, acc); acc += l * sizeof(E); end
        starts = offset_hook(starts)
        append!(tail, zeros(UInt8, 4))
        for s in starts; append!(tail, be(Int32(KEYLEN + s))); end
        append!(tail, zeros(UInt8, 4))
    end
    decoded = length(content) + length(tail)
    bytes = KEYLEN + decoded
    header = vcat(be(Int32(bytes)), be(Int16(4)), be(Int32(decoded)), be(UInt32(0)), be(Int16(KEYLEN)),
        be(Int32(nev)), be(Int32(KEYLEN + length(content))), be(Int64(pos)))
    length(header) == KEYLEN || error("bad synthetic key")
    append!(fb.bytes, header); append!(fb.bytes, content); append!(fb.bytes, tail)
    return (pos = pos, bytes = bytes, decoded = decoded)
end

"""column: Vector{E} (flat) or Vector{Vector{E}} (jagged); starts: 0-based cuts."""
function add_branch!(fb, name, column, starts; E, jagged = false, damage = Dict{Int,Any}(), J = nothing)
    seeks = Int[]; sizes = Int[]; descs = EventIO.StreamBasketDesc[]
    for ib in 1:length(starts)-1
        lo = starts[ib] + 1; hi = starts[ib+1]
        kw = get(damage, ib, NamedTuple())
        if jagged
            lists = column[lo:hi]
            b = add_basket!(fb, E[x for l in lists for x in l], hi - lo + 1; lengths = length.(lists), kw...)
        else
            b = add_basket!(fb, E[column[lo:hi]...], hi - lo + 1; kw...)
        end
        push!(seeks, b.pos); push!(sizes, b.bytes)
        push!(descs, EventIO.StreamBasketDesc((lo, hi, b.bytes, b.decoded, KEYLEN)))
    end
    T = jagged ? Vector{E} : E
    push!(fb.branches, (name = name, seeks = seeks, sizes = sizes, descs = descs, starts = collect(Int, starts),
        T = T, E = E, jagged = jagged, J = J === nothing ? (jagged ? UnROOT.Nooffsetjagg : UnROOT.Nojagg) : J))
    return fb
end

const OPTS = (stream_window_bytes = 128 * 1024^2, stream_retained_bytes = 10^9)
"""padded: name => fMaxBaskets slot count (ROOT writes max(nb+1, 10)); exact otherwise
(nb+1 slots, last seek/bytes slot zero like ROOT). records: name => f -> f' damages the
raw TBranch arrays. A padded name takes maskable from the UNCHANGED production
classifier stream_basket_index (refused/malformed raw index => false so that the A
admission defense is exercised on its own); maskable overrides any flag.
LazyBranch.fEntry aliases the raw fBasketEntry exactly like UnROOT.LazyBranch."""
function build_reader(fb, windows; pre, post, counters, options = OPTS, maskable = Dict{String,Bool}(),
        padded = Dict{String,Int}(), records = Dict{String,Any}())
    file = UnROOT.ROOTFile(UnROOT.MmapStream(fb.bytes), Dict{String,Any}())
    branches = Dict{String,Any}()
    for b in fb.branches
        nb = length(b.seeks); slots = get(padded, b.name, nb + 1)
        slots >= nb + 1 || error("synthetic padding shorter than the basket prefix")
        pad(v) = vcat(Int.(v), zeros(Int, slots - length(v)))
        f = (fBasketSeek = pad(b.seeks), fBasketBytes = pad(b.sizes), fBasketEntry = pad(b.starts),
             fEntries = last(b.starts), fWriteBasket = nb)
        f = get(records, b.name, identity)(f)
        tb = UnROOT.TBranch(f.fBasketSeek, f.fBasketBytes, (elements = [1],), b.T, b.J, f.fBasketEntry, f.fEntries, f.fWriteBasket)
        flag = true
        if haskey(padded, b.name)
            index = try EventIO.stream_basket_index(tb)[1] catch; nothing end
            flag = index === nothing ? false : index.maskable
        end
        branches[b.name] = (lazy = UnROOT.LazyBranch(file, tb, tb.fBasketEntry), T = b.T, E = b.E, jagged = b.jagged,
            maskable = get(maskable, b.name, flag), baskets = b.descs)
    end
    diag = Dict{String,Any}("prefix_events" => 0, "prefix_pass" => 0, "max_raw_window_bytes" => 0,
        "unique_baskets" => 0, "repeated_baskets" => 0, "padded_decoded_baskets" => 0)
    return EventIO.StreamWindowReader(EventIO.NanoAODSource(), branches, String.(pre), String.(post),
        # Synthetic metadata still needs one positive reservation token per planned window.
        # Production plan_stream_windows supplies real byte charges; no production bound is changed here.
        Dict{String,String}(counters), collect(UnitRange{Int}, windows), fill(1, length(windows)), options, diag, Set{Tuple{String,Int}}())
end
audited_scratch() = EventIO._NanoAODScratch(UInt8[], true) # skips only the CodecXz file-hash audit
counting(f, calls) = (args...; kw...) -> (calls[] += 1; f(args...; kw...))
function snapshot_decoder(log)
    return (dest, dst, lb, ib, state, entries; kw...) -> begin
        before = copy(dest)
        try
            ok = EventIO._read_reusable_basket!(dest, dst, lb, ib, state, entries; kw...)
            push!(log, (ib = ib, ok = ok, untouched = ok ? missing : dest == before))
            return ok
        catch
            push!(log, (ib = ib, ok = :error, untouched = dest == before))
            rethrow()
        end
    end
end
state_for(r; kw...) = EventIO.StreamDecodeState(r; scratch = audited_scratch(), kw...)
errmsg(f) = try f(); "ok" catch e; sprint(showerror, e) end
errtype(f) = try f(); nothing catch e; typeof(e) end

# Ordinary full-file counter semantics (copy of IO._nanoaod_counter_offsets loop).
function ordinary_counter_error(counter, counts)
    o = zeros(Int, length(counts) + 1)
    for i in eachindex(counts)
        c = Int(counts[i])
        c >= 0 || return ArgumentError("negative collection count in $counter at event $i")
        c <= typemax(Int) - o[i] || return ArgumentError("collection offsets overflow in $counter at event $i")
        o[i+1] = o[i] + c
    end
    return o
end

function scalar_selection(; stages = true, nocuts = false)
    cuts = nocuts ? () : ((c,i)->c.cols.x[i] > 0, (c,i)->c.cols.y[i] > 0)
    CompiledSelection(:mc, nocuts ? String[] : ["x","y"], cuts, 0, (c,i,l,h)->nothing,
        (c,i)->c.cols.w[i], (c,i,s)->(c.cols.z[i], 1.0), ["z","r:early"],
        Dict{String,Vector{String}}(), String[], String[], ["w","x"], ["y","z"], String[],
        Dict("early"=>(nocuts ? 0 : 1)), nocuts ? 0 : 1, TriggerConfig(), DataQualityConfig(),
        stages ? Dict("y"=>2, "z"=>typemax(Int)) : Dict{String,Int}())
end
function object_selection(calls; stages = true)
    materialize = (ctx,i,lo,hi)->begin
        if lo < 2 <= hi
            Objects.select_objects!(j->ctx.cols.J_pt[j] > 0, ctx.objs.j, ctx.offs.J[i], ctx.offs.J[i+1])
        end
        if lo < typemax(Int) <= hi
            Objects.select_objects!(j->ctx.cols.K_pt[j] > 0, ctx.objs.k, ctx.offs.K[i], ctx.offs.K[i+1])
        end
        nothing
    end
    cuts = ((c,i)->(calls[1] += 1; c.cols.x[i] > 0),
            (c,i)->(calls[2] += 1; length(c.objs.j) >= 1),
            (c,i)->(calls[3] += 1; c.cols.J_eta[first(c.objs.j)] > 0))
    outputs = (c,i,s)->(sum(c.cols.J_pt[j] for j in c.objs.j; init=0.0),
        sum(c.cols.K_pt[j] for j in c.objs.k; init=0.0), 1.0)
    CompiledSelection(:mc, ["prefix","objects","late"], cuts, 2, materialize, (c,i)->c.cols.w[i], outputs,
        ["j","k","r:early"], Dict{String,Vector{String}}(), ["j","k"], ["J","K"],
        ["w","x"], ["J_pt","J_eta","K_pt"], String[], Dict("early"=>1), 1, TriggerConfig(), DataQualityConfig(),
        stages ? Dict("J_pt"=>2, "J_eta"=>3, "K_pt"=>typemax(Int)) : Dict{String,Int}())
end

"""Run the reusable window loop and compare bitwise to ordinary select_events."""
function compare_reusable(sel, raw, reader; n, expected_entries = nothing, decode = state_for(reader), reset = nothing, reuse_buffers=false, reuse_accounting=false)
    reference, cf = select_events(sel, raw, n; sample = "fixture")
    reset === nothing || fill!(reset, 0)
    a = StreamSelectionAnalysis(sel, "fixture")
    spec, reason = reuse_buffers ? window_buffer_spec(reader, sel, isempty(sel.object_names) ? nothing : ["j"=>"J", "k"=>"K"]) : (nothing, "")
    @test isempty(reason)
    pool = spec === nothing ? nothing : WindowBufferReuse(sel, spec.n, spec.bounds)
    pool === nothing || (pool.reserved_bytes = spec.bytes)
    reuse_accounting && (pool.accounting = WindowAccounting(32+8length(reader.branches)))
    diag = run_reusable_windows!(a, reader, decode, sel, n; stream = "", lumimask = nothing, buffer_reuse=pool)
    got = finish_stream_selection!(a, n; validate = true)
    @test got.order == reference.order
    @test isequal(got.meta, reference.meta)
    for key in reference.order
        @test reinterpret(UInt8, got[key]) == reinterpret(UInt8, reference[key])
    end
    for key in ("sumw", "sumw2")
        @test reinterpret(UInt64, cutflow_dict(a.cutflow)[key]) == reinterpret(UInt64, cutflow_dict(cf)[key])
    end
    @test a.cutflow.n == cf.n
    expected_entries === nothing || @test got["entry"] == expected_entries
    @test !any(v isa Union{EventIO.StreamWindowReader,EventIO.StreamDecodeState} for v in (getfield(a, k) for k in fieldnames(typeof(a))))
    return got, a, diag, decode
end
end # module ReusableHarness

const RWH = ReusableHarness
const RWE = RWH.EventIO

@testset "config: strict Bool, default false, requires windowed_selection, profiles" begin
    @test !RWH.windowed_reusable_decoder(Dict())
    on = Dict("execution"=>Dict("windowed_selection"=>true, "windowed_reusable_decoder"=>true))
    @test RWH.windowed_reusable_decoder(on)
    @test RWH.validate_keys(on) === on
    @test !RWH.windowed_reusable_decoder(Dict("execution"=>Dict("windowed_selection"=>true)))
    for value in (1, 0, "true", nothing, 1.0)
        bad = Dict("execution"=>Dict("windowed_selection"=>true, "windowed_reusable_decoder"=>value))
        @test_throws ArgumentError RWH.validate_keys(bad)
        @test_throws ArgumentError RWH.validate_keys(Dict("profiles"=>Dict("inactive"=>Dict("execution"=>Dict("windowed_reusable_decoder"=>value)))))
    end
    @test_throws ArgumentError RWH.validate_keys(Dict("execution"=>Dict("windowed_reusable_decoder"=>true)))
    @test_throws ArgumentError RWH.validate_keys(Dict("execution"=>Dict("windowed_selection"=>false, "windowed_reusable_decoder"=>true)))
    @test_throws ArgumentError RWH.validate_keys(Dict("execution"=>Dict("windowed_selection"=>true, "event_range_selection"=>true, "windowed_reusable_decoder"=>true)))
    # Overlay relations are checked on the merged profile, including inactive profiles.
    base = Dict{String,Any}("execution"=>Dict{String,Any}("windowed_selection"=>true))
    ok = merge(base, Dict("profiles"=>Dict("p"=>Dict("execution"=>Dict("windowed_reusable_decoder"=>true)))))
    @test RWH.validate_keys(ok) === ok
    @test_throws ArgumentError RWH.validate_keys(Dict("profiles"=>Dict("p"=>Dict("execution"=>Dict("windowed_reusable_decoder"=>true)))))
    inherited = Dict("execution"=>Dict("windowed_selection"=>true, "windowed_reusable_decoder"=>true),
        "profiles"=>Dict("inactive"=>Dict("execution"=>Dict("windowed_selection"=>false))))
    @test_throws ArgumentError RWH.validate_keys(inherited)
    @test occursin("requires execution.windowed_selection", RWH.errmsg(() -> RWH.windowed_reusable_decoder(Dict("execution"=>Dict("windowed_reusable_decoder"=>true)))))
    @test RWH.windowed_reusable_decoder(Dict("execution"=>Dict("windowed_reusable_decoder"=>true)); validate_relations=false)
end

@testset "flat decode through real reusable decoder; skip, IDs, scratch non-aliasing" begin
    fb = RWH.FileBuilder()
    x = Float32[1.5, -2.25, 3.0, 4.0, 5.5, -6.0, 7.0, 8.0]
    RWH.add_branch!(fb, "x", x, [0, 3, 4, 6, 8]; E = Float32)
    r = RWH.build_reader(fb, [1:4, 5:8]; pre = ["x"], post = String[], counters = Dict{String,String}())
    branchcalls = Ref(0); closecalls = Ref(0)
    d = RWH.state_for(r; branch = RWH.counting(RWE._reusable_branch, branchcalls), close = RWH.counting(RWE._close_reusable_branch, closecalls))
    @test RWE.reusable_stream_admission(r, d) == ""
    out1 = RWE.read_reusable_stream_branch(r, d, "x", 1:4)
    @test reinterpret(UInt32, out1) == reinterpret(UInt32, x[1:4])
    @test d.decoded_ids["x"] == [1, 2]
    scratchsnap = copy(d.scratch.raw)
    out1[1] = 99f0
    @test d.scratch.raw == scratchsnap                    # output never aliases scratch
    @test pointer(out1) != pointer(d.scratch.raw)
    out2 = RWE.read_reusable_stream_branch(r, d, "x", 5:8; needed = [false, false, true, false])
    @test out2 == Float32[0, 0, 7, 8]                     # skipped basket zero-filled
    @test d.skipped_ids["x"] == [3] && d.decoded_ids["x"] == [1, 2, 4]
    @test out1[1] == 99f0                                 # previous window output untouched by reuse
    @test d.live_states == 0 && branchcalls[] == closecalls[] == 3   # admission + 2 reads, all closed
    @test length(d.scratch.raw) <= RWE._nanoaod_scratch_limit()
    @test d.stats["duplicate_basket_decodes"] == 0
    RWE.read_reusable_stream_branch(r, d, "x", 1:4)
    @test d.stats["duplicate_basket_decodes"] == 2 && r.diagnostics["repeated_baskets"] == 2
    @test RWH.UnROOT.LEGACY_CALLS[] == 0
end

@testset "jagged siblings with different internal basket bounds over two common windows" begin
    fb = RWH.FileBuilder()
    pt = [[1.0, 2.0], Float64[], [3.0], [4.0, 5.0, 6.0], [7.0], Float64[], [8.0, 9.0], [10.0]]
    eta = [[-1.0, -2.0], Float64[], [-3.0], [-4.0, -5.0, -6.0], [-7.0], Float64[], [-8.0, -9.0], [-10.0]]
    nJ = Int32.(length.(pt))
    RWH.add_branch!(fb, "nJ", nJ, [0, 4, 8]; E = Int32)
    RWH.add_branch!(fb, "J_pt", pt, [0, 2, 4, 8]; E = Float64, jagged = true)
    RWH.add_branch!(fb, "J_eta", eta, [0, 4, 6, 8]; E = Float64, jagged = true)
    r = RWH.build_reader(fb, [1:4, 5:8]; pre = String[], post = ["J_pt", "J_eta"], counters = Dict("J_pt"=>"nJ", "J_eta"=>"nJ"))
    d = RWH.state_for(r)
    @test RWE.reusable_stream_admission(r, d) == ""
    for (k, w) in enumerate(r.windows)
        wc = RWE.reusable_window_counters!(r, d, k)
        o = RWE.reusable_canonical_offsets(r, d, wc, "J_pt")
        @test RWE.reusable_canonical_offsets(r, d, wc, "J_eta") === o          # shared read-only, once/window
        a = RWE.read_reusable_stream_branch(r, d, "J_pt", w; offsets = o, phase = "post")
        b = RWE.read_reusable_stream_branch(r, d, "J_eta", w; offsets = o, phase = "post")
        @test a.offsets == o && a.offsets !== o && b.offsets !== a.offsets  # no sibling/offset aliasing
        @test a.content !== b.content
        @test [collect(a[i]) for i in 1:length(w)] == pt[w]
        @test [collect(b[i]) for i in 1:length(w)] == eta[w]
    end
    @test d.counter_window["nJ"] == 2 && d.counter_next["nJ"] == 9 && d.counter_base["nJ"] == sum(nJ)
    @test d.sibling_reuses["nJ"] == 4
    diag = RWE.finish_reusable_stream!(r, d, 8)
    @test diag["reusable_counter_windows_checked"] == Dict("nJ"=>2)
    @test diag["reusable_branch_decoded_basket_ids"]["J_pt"] == [1, 2, 3]
    @test diag["reusable_branch_decoded_basket_ids"]["J_eta"] == [1, 2, 3]
    @test diag["reusable_duplicate_basket_decodes"] == 0 && diag["legacy_decoded_baskets"] == 0
    @test diag["reusable_destination_bytes"] == 2 * 8 * sum(nJ) + 4 * 8
    @test_throws ErrorException RWE.reusable_window_counters!(r, d, 1)        # no replay/reorder
    @test RWH.UnROOT.LEGACY_CALLS[] == 0
end

@testset "counters: global cumulative overflow across windows, negative rejected row" begin
    big = typemax(Int) - 10
    for (counts, windows, starts) in ((Int64[big, 5, 3, 3], [1:2, 3:4], [0, 2, 4]),
                                       (Int64[1, 2, 0, 4, -1, 2], [1:3, 4:6], [0, 3, 6]),
                                       (Int64[0, 0, 0], [1:3], [0, 3]))
        fb = RWH.FileBuilder()
        RWH.add_branch!(fb, "nC", counts, starts; E = Int64)
        r = RWH.build_reader(fb, windows; pre = String[], post = String[], counters = Dict("C_x"=>"nC"))
        d = RWH.state_for(r)
        got = try
            for k in eachindex(windows); RWE.reusable_window_counters!(r, d, k); end
            d.counter_base["nC"]
        catch e
            e
        end
        expected = RWH.ordinary_counter_error("nC", counts)
        if expected isa ArgumentError
            @test got isa ArgumentError && got.msg == expected.msg          # same type, message, global event
        else
            @test got == last(expected)
        end
    end
    # Each window alone is representable: only the file-cumulative check overflows.
    @test sum(Int128[3, 3]) < typemax(Int) && RWH.ordinary_counter_error("nC", Int64[big, 5, 3, 3]).msg ==
        "collection offsets overflow in nC at event 4"
    # A negative count in a row that no mask demands still fails before payload.
    fb = RWH.FileBuilder()
    RWH.add_branch!(fb, "nJ", Int32[1, -1], [0, 2]; E = Int32)
    RWH.add_branch!(fb, "J_pt", [[1.0], Float64[]], [0, 2]; E = Float64, jagged = true)
    r = RWH.build_reader(fb, [1:2]; pre = String[], post = ["J_pt"], counters = Dict("J_pt"=>"nJ"))
    sel = (builtins = String[], column_stages = Dict{String,Int}(), variable_nodes = (), mat_at = 0)
    err = try RWH.read_reusable_selection_window(r, RWH.state_for(r), sel, 1); nothing catch e; e end
    @test err isa ArgumentError && err.msg == "negative collection count in nJ at event 2"
    @test !haskey(r.diagnostics, "post_decoded_baskets")                       # no payload decoded
end

@testset "corruption: canonical +1/-1, offsets, Bool, key mismatch; no destination write" begin
    function jagged_case(damage; counts = Int32[1, 2], lists = [[1.0], [2.0, 3.0]])
        fb = RWH.FileBuilder()
        RWH.add_branch!(fb, "nJ", counts, [0, 2]; E = Int32)
        RWH.add_branch!(fb, "J_pt", lists, [0, 2]; E = Float64, jagged = true, damage = Dict(1 => damage))
        r = RWH.build_reader(fb, [1:2]; pre = String[], post = ["J_pt"], counters = Dict("J_pt"=>"nJ"))
        log = Any[]
        d = RWH.state_for(r; decoder = RWH.snapshot_decoder(log))
        msg = RWH.errmsg() do
            wc = RWE.reusable_window_counters!(r, d, 1)
            RWE.read_reusable_stream_branch(r, d, "J_pt", 1:2; offsets = RWE.reusable_canonical_offsets(r, d, wc, "J_pt"))
        end
        return msg, log, d
    end
    # Compensating per-row corruption: same basket total (3) but rows +1/-1.
    msg, log, d = jagged_case(NamedTuple(); counts = Int32[1, 2], lists = [[1.0, 2.0], [3.0]])
    @test msg == "basket offsets disagree with canonical counter"
    @test last(log).ok === :error && last(log).untouched && d.live_states == 0
    msg, log, _ = jagged_case((offset_hook = s -> s .+ 8,))
    @test msg == "basket offsets do not start at zero" && last(log).untouched
    msg, log, _ = jagged_case((offset_hook = s -> [0, 32],))
    @test msg == "invalid basket offsets" && last(log).untouched
    msg, log, _ = jagged_case((offset_hook = s -> [0, 4],))
    @test msg == "unaligned primitive basket offset" && last(log).untouched
    msg, log, _ = jagged_case((nev = 3,))
    @test msg == "basket key/index mismatch" && last(log).untouched
    msg, log, _ = jagged_case((content_hook = c -> c[1:end-8],), counts = Int32[1, 2])
    @test msg != "ok" && last(log).untouched
    # Real decoder decline (jagged basket without offset table) is an explicit error, never legacy.
    msg, log, _ = jagged_case((trailer = false,))
    @test occursin("unsupported", msg) && occursin("reusable_decoder_declined_demanded_basket", msg)
    @test last(log).ok === false && last(log).untouched
    # Bool damage.
    fb = RWH.FileBuilder()
    RWH.add_branch!(fb, "flag", Bool[true, false, true], [0, 3]; E = Bool, damage = Dict(1 => (content_hook = c -> (c[2] = 0x02; c),)))
    r = RWH.build_reader(fb, [1:3]; pre = ["flag"], post = String[], counters = Dict{String,String}())
    log = Any[]; d = RWH.state_for(r; decoder = RWH.snapshot_decoder(log))
    @test RWH.errmsg(() -> RWE.read_reusable_stream_branch(r, d, "flag", 1:3)) == "invalid primitive Bool encoding"
    @test last(log).untouched
    @test RWH.UnROOT.LEGACY_CALLS[] == 0
end

@testset "unsupported admission reasons before payload; injected decline; no fallback" begin
    fb = RWH.FileBuilder()
    RWH.add_branch!(fb, "nJ", Int32[1, 1], [0, 2]; E = Int32)
    RWH.add_branch!(fb, "J_pt", [[1.0], [2.0]], [0, 2]; E = Float64, jagged = true)
    RWH.add_branch!(fb, "x", Float32[1, 2], [0, 2]; E = Float32)
    mk(; counters = Dict("J_pt"=>"nJ"), maskable = Dict{String,Bool}()) =
        RWH.build_reader(fb, [1:2]; pre = ["x"], post = ["J_pt"], counters, maskable)
    r = mk(); @test RWE.reusable_stream_admission(r, RWH.state_for(r)) == ""
    # Forced maskable=false on an EXACT index has no padded-layout proof => refused.
    r = mk(maskable = Dict("x"=>false)); @test RWE.reusable_stream_admission(r, RWH.state_for(r)) == "unproven_padded_basket_index:x:not_padded"
    r = mk(counters = Dict{String,String}()); @test RWE.reusable_stream_admission(r, RWH.state_for(r)) == "jagged_branch_without_counter:J_pt"
    r = mk(); d = RWH.state_for(r; branch = (args...) -> nothing)
    @test RWE.reusable_stream_admission(r, d) == "reusable_branch_not_admitted:J_pt"
    r = mk(); r.branches["x"] = merge(r.branches["x"], (baskets = [RWE.StreamBasketDesc((1, 2, 64, RWE._nanoaod_scratch_limit() + 1, 32))],))
    @test RWE.reusable_stream_admission(r, RWH.state_for(r)) == "basket_exceeds_reusable_scratch:x:1"
    fb2 = RWH.FileBuilder(); RWH.add_branch!(fb2, "nJ", Float32[1, 1], [0, 2]; E = Float32)
    r2 = RWH.build_reader(fb2, [1:2]; pre = String[], post = String[], counters = Dict("J_pt"=>"nJ"))
    @test RWE.reusable_stream_admission(r2, RWH.state_for(r2)) == "invalid_counter_type:nJ"
    fb3 = RWH.FileBuilder(); RWH.add_branch!(fb3, "x", Float32[1, 2], [0, 2]; E = Float32, J = RWH.UnROOT.Nooffsetjagg)
    r3 = RWH.build_reader(fb3, [1:2]; pre = ["x"], post = String[], counters = Dict{String,String}())
    @test RWE.reusable_stream_admission(r3, RWH.state_for(r3)) == "reusable_branch_not_admitted:x"   # real interpretation check
    # Injected decline after admission => explicit error; state closed; never legacy.
    r = mk(); closes = Ref(0)
    d = RWH.state_for(r; decoder = (args...; kw...) -> false, close = RWH.counting(RWE._close_reusable_branch, closes))
    err = try RWE.read_reusable_stream_branch(r, d, "x", 1:2); nothing catch e; e end
    @test err isa RWE.WindowedReusableUnsupported && err.reason == "reusable_decoder_declined_demanded_basket"
    @test d.live_states == 0 && closes[] == 1
    d = RWH.state_for(r; decoder = (args...; kw...) -> 1)
    @test occursin("non-Bool", RWH.errmsg(() -> RWE.read_reusable_stream_branch(r, d, "x", 1:2)))
    @test_throws RWE.WindowedReusableUnsupported RWE.read_reusable_stream_branch(mk(maskable = Dict("x"=>false)), RWH.state_for(r), "x", 1:2)
    @test_throws RWE.WindowedReusableUnsupported RWE.read_reusable_stream_branch(r, RWH.state_for(r), "J_pt", 1:2)  # no offsets
    @test RWH.UnROOT.LEGACY_CALLS[] == 0
end

@testset "padded ROOT index (fMaxBaskets=10): unchanged flags, proven unmasked modern decode, bit parity" begin
    # ROOT TBranch::Streamer writes fMaxBaskets = max(fWriteBasket+1, 10) slots => < 9 baskets carry a zero tail.
    w = [1e16, 1.0, -1e16, 3.0, -2.0]; x = [1.0, 1.0, -1.0, 1.0, 1.0]
    J_pt = [[11.0], Float64[], [33.0], [44.0], [55.0]]; J_eta = [[-1.0], Float64[], [1.0], [1.0], [1.0]]
    K_pt = [[101.0], [102.0], [103.0], [104.0], Float64[]]
    raw = Dict{String,Any}("w"=>w, "x"=>x, "J_pt"=>RWH.Jagged(J_pt), "J_eta"=>RWH.Jagged(J_eta), "K_pt"=>RWH.Jagged(K_pt))
    function file()
        fb = RWH.FileBuilder()
        RWH.add_branch!(fb, "w", w, [0, 2, 5]; E = Float64)
        RWH.add_branch!(fb, "x", x, [0, 1, 2, 5]; E = Float64)
        RWH.add_branch!(fb, "nJ", Int32.(length.(J_pt)), [0, 2, 5]; E = Int32)
        RWH.add_branch!(fb, "nK", Int32.(length.(K_pt)), [0, 2, 3, 5]; E = Int32)
        RWH.add_branch!(fb, "J_pt", J_pt, [0, 1, 2, 3, 5]; E = Float64, jagged = true)     # basket 3 = rejected event 3 only
        RWH.add_branch!(fb, "J_eta", J_eta, [0, 2, 3, 5]; E = Float64, jagged = true)
        RWH.add_branch!(fb, "K_pt", K_pt, [0, 2, 4, 5]; E = Float64, jagged = true)
        fb
    end
    pads = Dict("x"=>10, "nJ"=>10, "J_pt"=>10, "K_pt"=>10)                                  # w, nK, J_eta stay exact
    counters = Dict("J_pt"=>"nJ", "J_eta"=>"nJ", "K_pt"=>"nK")
    for stages in (true, false)
        calls = zeros(Int, 3); sel = RWH.object_selection(calls; stages)
        r = RWH.build_reader(file(), [1:2, 3:5]; pre = sel.columns_pre, post = sel.columns_post, counters, padded = pads)
        # Historical flags from the unchanged classifier: exact => true, padded => false.
        @test Dict(n => br.maskable for (n, br) in r.branches) ==
            Dict("w"=>true, "x"=>false, "nJ"=>false, "nK"=>true, "J_pt"=>false, "J_eta"=>true, "K_pt"=>false)
        @test RWE.stream_basket_index(r.branches["x"].lazy.b) == ((count = 3, starts = [0, 1, 2, 5], maskable = false), "")
        @test RWE.stream_basket_index(r.branches["w"].lazy.b) == ((count = 2, starts = [0, 2, 5], maskable = true), "")
        saved = Dict(n => deepcopy((br.lazy.b.fBasketEntry, br.lazy.b.fBasketSeek, br.lazy.b.fBasketBytes)) for (n, br) in r.branches)
        d = RWH.state_for(r)
        @test RWE.reusable_stream_admission(r, d) == ""
        @test d.padded_proven == Set(keys(pads))
        got, a, diag, _ = RWH.compare_reusable(sel, raw, r; n = 5, expected_entries = [1, 2, 4, 5], decode = d, reset = calls)
        @test diag["reusable_padded_branches"] == ["J_pt", "K_pt", "nJ", "x"]
        for name in keys(pads)   # ORIGINAL unmasked contract: every basket decoded once, none skipped
            @test diag["reusable_branch_decoded_basket_ids"][name] == collect(1:length(r.branches[name].baskets))
            @test !haskey(diag["reusable_branch_skipped_basket_ids"], name)
        end
        @test 2 in diag["reusable_branch_skipped_basket_ids"]["J_eta"]                    # exact sibling still masked
        total = sum(length(r.branches[nm].baskets) for nm in keys(pads))
        @test diag["reusable_padded_decoded_baskets"] == r.diagnostics["padded_decoded_baskets"] == total
        @test diag["reusable_duplicate_basket_decodes"] == 0 && d.live_states == 0
        @test all(saved[n] == (br.lazy.b.fBasketEntry, br.lazy.b.fBasketSeek, br.lazy.b.fBasketBytes) for (n, br) in r.branches)
        @test r.branches["x"].lazy.fEntry === r.branches["x"].lazy.b.fBasketEntry && length(r.branches["x"].lazy.fEntry) == 10
        stages && @test calls == [5, 4, 3]
    end
    # Same arrays as the legacy unmasked stream read (actual values, not masked zeros).
    r = RWH.build_reader(file(), [1:2, 3:5]; pre = ["w", "x"], post = ["J_pt"], counters, padded = pads)
    d = RWH.state_for(r); @test RWE.reusable_stream_admission(r, d) == ""
    needed = falses(3); legacydiag() = Dict{String,Any}("unique_baskets"=>0, "repeated_baskets"=>0)
    br = r.branches["x"]
    gotx = RWE.read_reusable_stream_branch(r, d, "x", 3:5; needed, phase = "post")
    oldx = RWE.read_stream_branch_owned(br, "x", 3:5, RWH.OPTS, legacydiag(), Set{Tuple{String,Int}}(); needed, phase = "post",
        basket_reader = (b, k) -> x[br.baskets[k].lo:br.baskets[k].hi])
    @test reinterpret(UInt64, gotx) == reinterpret(UInt64, oldx) == reinterpret(UInt64, x[3:5])
    @test RWE.read_reusable_stream_branch(r, d, "w", 3:5; needed, phase = "post") == zeros(3)   # exact sibling stays masked
    o = [0, 1, 2, 3]; bj = r.branches["J_pt"]
    gotj = RWE.read_reusable_stream_branch(r, d, "J_pt", 3:5; needed, offsets = o, phase = "post")
    oldj = RWE.read_stream_branch_owned(bj, "J_pt", 3:5, RWH.OPTS, legacydiag(), Set{Tuple{String,Int}}(); needed, offsets = o,
        phase = "post", basket_reader = (b, k) -> J_pt[bj.baskets[k].lo:bj.baskets[k].hi])
    @test gotj.offsets == oldj.offsets && reinterpret(UInt64, gotj.content) == reinterpret(UInt64, oldj.content) == reinterpret(UInt64, [33.0, 44.0, 55.0])
    @test RWH.UnROOT.LEGACY_CALLS[] == 0
end

@testset "padded index refusals, unproven reads, post-admission corruption, coverage proof" begin
    xs = Float32[1, 2, 3, 4]
    function mk(; rec = identity, maskable = Dict{String,Bool}(), damage = Dict{Int,Any}(), descs = nothing, pad = 10)
        fb = RWH.FileBuilder(); RWH.add_branch!(fb, "x", xs, [0, 2, 4]; E = Float32, damage)
        descs === nothing || (fb.branches[1] = merge(fb.branches[1], (descs = descs,)))
        RWH.build_reader(fb, [1:2, 3:4]; pre = ["x"], post = String[], counters = Dict{String,String}(),
            padded = pad === nothing ? Dict{String,Int}() : Dict("x"=>pad), records = Dict{String,Any}("x"=>rec), maskable)
    end
    set(field, i, v) = f -> (a = copy(getfield(f, field)); a[i] = v; merge(f, NamedTuple{(field,)}((a,))))
    r = mk(); @test !r.branches["x"].maskable && RWE.reusable_stream_admission(r, RWH.state_for(r)) == ""
    @test RWE.reusable_stream_admission(mk(pad = 3), RWH.state_for(mk(pad = 3))) == ""     # exact: no proof needed
    @test mk(pad = 3).branches["x"].maskable
    good = mk().branches["x"].lazy.b
    cases = [
        (mk(pad = nothing, maskable = Dict("x"=>false)), "not_padded"),
        (mk(rec = f -> merge(f, (fWriteBasket = 3,))), "write_basket_count_mismatch"),
        (mk(rec = f -> merge(f, (fWriteBasket = 9,))), "write_basket_count_mismatch"),
        (mk(rec = set(:fBasketSeek, 10, 7)), "nonzero_basket_record_tail"),
        (mk(rec = set(:fBasketSeek, 3, good.fBasketSeek[2])), "nonzero_basket_record_tail"),   # orphan record
        (mk(rec = set(:fBasketBytes, 4, 64)), "nonzero_basket_record_tail"),
        (mk(rec = f -> merge(f, (fBasketBytes = f.fBasketBytes[1:9],))), "basket_array_length_mismatch"),
        (mk(rec = set(:fBasketBytes, 1, good.fBasketBytes[1] + 1)), "basket_record_mismatch"),
        (mk(rec = set(:fBasketSeek, 2, 0)), "basket_record_mismatch"),
        (mk(rec = set(:fBasketEntry, 10, 1)), "unsupported_basket_index"),                     # nonzero entry tail
        (mk(rec = f -> merge(f, (fBasketEntry = [0, 2, 2, 4, 0, 0, 0, 0, 0, 0],))), "empty_baskets"),
        (mk(descs = [RWE.StreamBasketDesc((1, 1, d.bytes, d.decoded, d.keylen)) for d in mk().branches["x"].baskets[1:1]]), "descriptor_count_mismatch"),
        (mk(descs = (b = mk().branches["x"].baskets; [RWE.StreamBasketDesc((1, 1, b[1].bytes, b[1].decoded, b[1].keylen)),
            RWE.StreamBasketDesc((2, 4, b[2].bytes, b[2].decoded, b[2].keylen))])), "descriptor_boundary_mismatch"),
    ]
    for (rr, why) in cases
        calls = Ref(0); d = RWH.state_for(rr; decoder = RWH.counting(RWE._read_reusable_basket!, calls))
        @test RWE.reusable_stream_admission(rr, d) == "unproven_padded_basket_index:x:" * why
        @test isempty(d.padded_proven) && calls[] == 0                                      # refused before any payload
        @test_throws RWE.WindowedReusableUnsupported RWE.read_reusable_stream_branch(rr, d, "x", 1:2)
        @test calls[] == 0
    end
    # Non-monotone / overflowing prefixes remain corruption (throw), as in the planner.
    for bad in ([0, 3, 2, 4, 0, 0, 0, 0, 0, 0], [0, 2, 5, 0, 0, 0, 0, 0, 0, 0], [1, 2, 4, 0, 0, 0, 0, 0, 0, 0])
        rr = mk(rec = f -> merge(f, (fBasketEntry = bad,)))
        @test !rr.branches["x"].maskable
        @test occursin("malformed stream basket index", RWH.errmsg(() -> RWE.reusable_stream_admission(rr, RWH.state_for(rr))))
    end
    @test RWE.reusable_padded_index_reason(good, mk().branches["x"].baskets; basket_count = b -> typemax(Int)) == "unsupported_basket_index"
    @test RWE.reusable_padded_index_reason((fBasketEntry = good.fBasketEntry, fEntries = 4, fBasketBytes = good.fBasketBytes,
        fBasketSeek = good.fBasketSeek), mk().branches["x"].baskets) == "write_basket_count_unavailable"
    # A padded branch is never read without the admission proof.
    r = mk(); err = try RWE.read_reusable_stream_branch(r, RWH.state_for(r), "x", 1:2); nothing catch e; e end
    @test err isa RWE.WindowedReusableUnsupported && err.reason == "unproven_padded_basket_index"
    # Metadata-proven but payload-inconsistent basket: corruption error, destination untouched, never legacy.
    r = mk(damage = Dict(2 => (nev = 3,))); log = Any[]; d = RWH.state_for(r; decoder = RWH.snapshot_decoder(log))
    @test RWE.reusable_stream_admission(r, d) == ""
    @test RWE.read_reusable_stream_branch(r, d, "x", 1:2) == xs[1:2]
    @test RWH.errmsg(() -> RWE.read_reusable_stream_branch(r, d, "x", 3:4)) == "basket key/index mismatch"
    @test last(log).untouched && d.live_states == 0
    # Jagged padded branch whose canonical counter disagrees with the basket payload.
    fb = RWH.FileBuilder(); J = [[1.0], [2.0, 3.0], [4.0], Float64[]]
    RWH.add_branch!(fb, "nJ", Int32[1, 2, 1, 1], [0, 2, 4]; E = Int32)                   # event 4 claims 1, payload has 0
    RWH.add_branch!(fb, "J_pt", J, [0, 2, 4]; E = Float64, jagged = true)
    r = RWH.build_reader(fb, [1:2, 3:4]; pre = String[], post = ["J_pt"], counters = Dict("J_pt"=>"nJ"), padded = Dict("J_pt"=>10))
    d = RWH.state_for(r); @test RWE.reusable_stream_admission(r, d) == "" && !r.branches["J_pt"].maskable
    wc = RWE.reusable_window_counters!(r, d, 1)
    j = RWE.read_reusable_stream_branch(r, d, "J_pt", 1:2; needed = [false, false],
        offsets = RWE.reusable_canonical_offsets(r, d, wc, "J_pt"), phase = "post")
    @test [collect(j[i]) for i in 1:2] == J[1:2]                                          # needed ignored (unmasked)
    wc = RWE.reusable_window_counters!(r, d, 2)
    @test occursin("canonical counter", RWH.errmsg(() -> RWE.read_reusable_stream_branch(r, d, "J_pt", 3:4;
        offsets = RWE.reusable_canonical_offsets(r, d, wc, "J_pt"), phase = "post")))
    # Final coverage proof for padded branches.
    function runall(r)
        d = RWH.state_for(r); RWE.reusable_stream_admission(r, d) == "" || error("fixture not admitted")
        for k in 1:2; RWE.reusable_window_counters!(r, d, k); RWE.read_reusable_stream_branch(r, d, "x", r.windows[k]); end
        d
    end
    r = mk(); d = runall(r)
    diag = RWE.finish_reusable_stream!(r, d, 4)
    @test diag["reusable_padded_branches"] == ["x"] && diag["reusable_padded_decoded_baskets"] == 2
    @test diag["reusable_padded_index_policy"] == "validated_prefix_unmasked_modern_decode"
    d = runall(r); pop!(d.decoded_ids["x"])
    @test occursin("basket coverage mismatch", RWH.errmsg(() -> RWE.finish_reusable_stream!(r, d, 4)))
    d = runall(r); delete!(d.padded_proven, "x")
    @test occursin("not proven at admission", RWH.errmsg(() -> RWE.finish_reusable_stream!(r, d, 4)))
    @test RWH.UnROOT.LEGACY_CALLS[] == 0
end

@testset "selection parity: objects, staged/unstaged, all-rejected + single-survivor baskets" begin
    w = [1e16, 1.0, -1e16, 3.0, -2.0]; x = [1.0, 1.0, -1.0, 1.0, 1.0]
    J_pt = [[11.0], Float64[], [33.0], [44.0], [55.0]]; J_eta = [[-1.0], Float64[], [1.0], [1.0], [1.0]]
    K_pt = [[101.0], [102.0], [103.0], [104.0], Float64[]]
    raw = Dict{String,Any}("w"=>w, "x"=>x, "J_pt"=>RWH.Jagged(J_pt), "J_eta"=>RWH.Jagged(J_eta), "K_pt"=>RWH.Jagged(K_pt))
    function file()
        fb = RWH.FileBuilder()
        RWH.add_branch!(fb, "w", w, [0, 2, 5]; E = Float64)
        RWH.add_branch!(fb, "x", x, [0, 1, 2, 5]; E = Float64)
        RWH.add_branch!(fb, "nJ", Int32.(length.(J_pt)), [0, 2, 5]; E = Int32)
        RWH.add_branch!(fb, "nK", Int32.(length.(K_pt)), [0, 2, 3, 5]; E = Int32)
        RWH.add_branch!(fb, "J_pt", J_pt, [0, 1, 2, 3, 5]; E = Float64, jagged = true)     # basket 3 = event 3 only
        RWH.add_branch!(fb, "J_eta", J_eta, [0, 2, 3, 5]; E = Float64, jagged = true)
        RWH.add_branch!(fb, "K_pt", K_pt, [0, 2, 4, 5]; E = Float64, jagged = true)        # basket 2 = events 3,4
        fb
    end
    for stages in (true, false)
        calls = zeros(Int, 3); sel = RWH.object_selection(calls; stages)
        r = RWH.build_reader(file(), [1:2, 3:5]; pre = sel.columns_pre, post = sel.columns_post,
            counters = Dict("J_pt"=>"nJ", "J_eta"=>"nJ", "K_pt"=>"nK"))
        got, a, diag, d = RWH.compare_reusable(sel, raw, r; n = 5, expected_entries = [1, 2, 4, 5], reset = calls)
        @test got["j"] == [11.0, 0.0, 44.0, 55.0] && got["k"] == [101.0, 102.0, 104.0, 0.0]
        @test 3 in diag["reusable_branch_skipped_basket_ids"]["J_pt"]             # all-rejected basket not decoded
        @test 2 in diag["reusable_branch_decoded_basket_ids"]["K_pt"]             # single-survivor basket decoded
        for (name, br) in r.branches                                              # each basket exactly once
            ids = vcat(get(diag["reusable_branch_decoded_basket_ids"], name, Int[]), get(diag["reusable_branch_skipped_basket_ids"], name, Int[]))
            @test sort(ids) == collect(1:length(br.baskets))
        end
        @test diag["reusable_counter_windows_checked"] == Dict("nJ"=>2, "nK"=>2)
        @test diag["reusable_counter_final_totals"] == Dict("nJ"=>4, "nK"=>4)
        @test diag["reusable_duplicate_basket_decodes"] == 0 && diag["reusable_live_within_bound"]
        @test diag["reusable_scratch_capacity_highwater_bytes"] <= RWE._nanoaod_scratch_limit()
        @test diag["reusable_live_highwater_bytes"] >= RWE._nanoaod_decoder_limit()
        stages && @test calls == [5, 4, 3]                                         # cut short-circuit, no replay
        @test d.live_states == 0
    end
    @test RWH.UnROOT.LEGACY_CALLS[] == 0
end

@testset "scalar parity: split vs whole, empty input, progress isolation" begin
    w = [1e16, 1.0, -1e16, 3.0, -2.0]; x = [1.0, 1.0, 1.0, -1.0, 1.0]
    y = [-1.0, 1.0, 1.0, 1.0, -1.0]; z = [11.0, 12.0, 13.0, 14.0, 15.0]
    raw = Dict{String,Any}("w"=>w, "x"=>x, "y"=>y, "z"=>z)
    function file(cols, cuts)
        fb = RWH.FileBuilder()
        for (name, v) in cols; RWH.add_branch!(fb, name, v, cuts[name]; E = Float64); end
        fb
    end
    cuts = Dict("w"=>[0, 1, 3, 5], "x"=>[0, 1, 2, 3, 5], "y"=>[0, 1, 3, 4, 5], "z"=>[0, 1, 3, 5])
    for sel in (RWH.scalar_selection(), RWH.scalar_selection(stages = false), RWH.scalar_selection(nocuts = true))
        for windows in ([1:1, 2:3, 4:5], [1:5])
            cs = windows == [1:5] ? Dict(k=>[0, 5] for k in keys(cuts)) : cuts
            r = RWH.build_reader(file(raw, cs), windows; pre = sel.columns_pre, post = sel.columns_post, counters = Dict{String,String}())
            RWH.compare_reusable(sel, raw, r; n = 5)
        end
        empty = Dict{String,Any}(k=>Float64[] for k in keys(raw))
        r = RWH.build_reader(file(empty, Dict(k=>[0] for k in keys(raw))), [1:0]; pre = sel.columns_pre, post = sel.columns_post, counters = Dict{String,String}())
        got, a, diag, _ = RWH.compare_reusable(sel, empty, r; n = 0)
        @test isempty(got["entry"]) && diag["reusable_decoded_baskets"] == 0
    end
    sel = RWH.scalar_selection()
    r = RWH.build_reader(file(raw, cuts), [1:1, 2:3, 4:5]; pre = sel.columns_pre, post = sel.columns_post, counters = Dict{String,String}())
    d = RWH.state_for(r)
    p1 = RWH.read_reusable_selection_window(r, d, sel, 1); p2 = RWH.read_reusable_selection_window(r, d, sel, 2)
    @test p1.progress !== p2.progress && p1.raw !== p2.raw && p1.raw["z"] !== p2.raw["z"]
    @test_throws ErrorException RWH.read_reusable_selection_window(r, d, sel, 2)   # duplicate window
    @test_throws ErrorException RWE.finish_reusable_stream!(r, d, 5)              # final coverage incomplete
    tight = RWH.build_reader(file(raw, cuts), [1:1, 2:3, 4:5]; pre = sel.columns_pre, post = sel.columns_post,
        counters = Dict{String,String}(), options = (stream_window_bytes = RWE._nanoaod_decoder_limit() + 64, stream_retained_bytes = 10^9))
    @test occursin("native decoder bound", RWH.errmsg(() -> RWH.read_reusable_selection_window(tight, RWH.state_for(tight), sel, 1)))
end

@testset "empty rows and empty jagged baskets" begin
    fb = RWH.FileBuilder()
    RWH.add_branch!(fb, "nJ", Int32[0, 0, 0, 2], [0, 2, 4]; E = Int32)
    RWH.add_branch!(fb, "J_pt", [Float64[], Float64[], Float64[], [1.0, 2.0]], [0, 2, 4]; E = Float64, jagged = true)
    r = RWH.build_reader(fb, [1:2, 3:4]; pre = String[], post = ["J_pt"], counters = Dict("J_pt"=>"nJ"))
    d = RWH.state_for(r)
    for (k, w) in enumerate(r.windows)
        wc = RWE.reusable_window_counters!(r, d, k)
        v = RWE.read_reusable_stream_branch(r, d, "J_pt", w; offsets = RWE.reusable_canonical_offsets(r, d, wc, "J_pt"))
        @test [collect(v[i]) for i in 1:2] == (k == 1 ? [Float64[], Float64[]] : [Float64[], [1.0, 2.0]])
    end
    @test RWE.finish_reusable_stream!(r, d, 4)["reusable_branch_decoded_basket_ids"]["J_pt"] == [1, 2]
end

@testset "source contracts: modern-only, no fallback, default path unchanged" begin
    root = RWH.ROOT
    io = read(joinpath(root, "src/IO/stream_reusable_decoder.jl"), String)
    sel = read(joinpath(root, "src/Selection/read_reusable_selection_window.jl"), String)
    pipe = read(joinpath(root, "src/Pipeline/stream_selection.jl"), String)
    chunk = read(joinpath(root, "src/Pipeline/memory_chunk_helpers.jl"), String)
    @test !occursin("basketarray", io) && !occursin("stream_basket_array", io)
    @test !occursin("read_stream_branch(", sel) && !occursin(r"\bcatch\b", io) && !occursin(r"\bcatch\b", sel)
    body = pipe[findfirst("function run_reusable_windowed_selection", pipe)[1]:end]
    @test !occursin(r"\bcatch\b", body) && !occursin("run_windowed_selection(", body) && !occursin("run_selection(", body)
    @test occursin("reusable && !isempty(window_reason) && throw(EventIO.WindowedReusableUnsupported(path, window_reason))", chunk)
    @test occursin("reusable && window_result === nothing && throw(EventIO.WindowedReusableUnsupported(path, window_reason))", chunk)
    @test occursin("\"reader_engine\"=>\"UnROOT_window_legacy_basketarray_owned_copy\"", pipe)   # legacy route kept
    @test !occursin("@inbounds", io * sel) && !occursin("@fastmath", io * sel)
end

@testset "rev2 C1: non-pre counter counts+offsets enter window memory accounting" begin
    fb = RWH.FileBuilder()
    nJ = Int64[3, 0, 2, 1]
    RWH.add_branch!(fb, "nJ", nJ, [0, 4]; E = Int64)
    RWH.add_branch!(fb, "J_pt", [[1.0, 2.0, 3.0], Float64[], [4.0, 5.0], [6.0]], [0, 2, 4]; E = Float64, jagged = true)
    r = RWH.build_reader(fb, [1:4]; pre = String[], post = ["J_pt"], counters = Dict("J_pt"=>"nJ"))
    d = RWH.state_for(r)
    sel = (builtins = String[], column_stages = Dict{String,Int}(), variable_nodes = (), mat_at = 0)
    payload = RWH.read_reusable_selection_window(r, d, sel, 1)
    counts = payload.counters.counts["nJ"]; offsets = payload.counters.offsets["nJ"]
    @test !haskey(payload.raw, "nJ") && counts == nJ && offsets == [0, 3, 3, 5, 6]
    @test d.stats["owned_window_highwater_bytes"] >= Base.summarysize((counts, offsets))
    @test d.stats["owned_window_highwater_bytes"] >= Base.summarysize((payload.raw, counts, offsets))
    @test RWH.reusable_window_bytes(payload.raw, nothing, payload.counters, nothing) > RWH.reusable_window_bytes(payload.raw, nothing, nothing, nothing)
    # A pre counter shared with raw is not double counted (summarysize identity de-duplication).
    r2 = RWH.build_reader(fb, [1:4]; pre = ["nJ"], post = ["J_pt"], counters = Dict("J_pt"=>"nJ"))
    p2 = RWH.read_reusable_selection_window(r2, RWH.state_for(r2), sel, 1)
    @test p2.raw["nJ"] === p2.counters.counts["nJ"]
    @test RWH.reusable_window_bytes(p2.raw, nothing, p2.counters, nothing) <
        Base.summarysize(p2.raw) + Base.summarysize(p2.counters)
    src = read(joinpath(RWH.ROOT, "src/Selection/read_reusable_selection_window.jl"), String)
    @test count("_finish_reusable_window_read!(reader, decode, raw, progress, wc,", src) == 2
    pipe = read(joinpath(RWH.ROOT, "src/Pipeline/stream_selection.jl"), String)
    @test occursin("reusable_window_bytes(payload.raw, payload.progress, payload.counters, payload.needed; buffer_reuse)", pipe)
end

@testset "rev2 C2: failed decode dependency contract has a precise reason" begin
    fb = RWH.FileBuilder()
    RWH.add_branch!(fb, "x", Float32[1, 2], [0, 2]; E = Float32)
    r = RWH.build_reader(fb, [1:2]; pre = ["x"], post = String[], counters = Dict{String,String}())
    @test RWE.reusable_stream_admission(r, RWE.StreamDecodeState(r; scratch = RWE._NanoAODScratch(UInt8[], false))) ==
        "reusable_decode_contract_failed"
    @test RWE.reusable_stream_admission(r, RWH.state_for(r; branch = (args...) -> nothing)) == "reusable_branch_not_admitted:x"
    @test RWE.reusable_stream_admission(r, RWH.state_for(r)) == ""
end

@testset "rev2 T3: reusable extra bytes charged at reservation with window_index/required_bytes" begin
    fb = RWH.FileBuilder()
    for name in ("w", "x", "y", "z"); RWH.add_branch!(fb, name, [1.0, 2.0, 3.0, 4.0], [0, 2, 4]; E = Float64); end
    sel = RWH.scalar_selection()
    big = RWH.build_reader(fb, [1:2, 3:4]; pre = sel.columns_pre, post = sel.columns_post, counters = Dict{String,String}())
    extra = RWE.reusable_reservation_bytes(big)
    @test extra.native == RWE._nanoaod_decoder_limit() && extra.scratch == 16 # max decoded basket: 2 Float64, flat (no offset trailer)
    base, reason = RWH.reserve_windowed_selection(big, sel, nothing)
    @test reason == ""
    @test RWH.reserve_windowed_selection(big, sel, nothing; extra_bytes = extra.total) == (base + Int(extra.total), "")
    tight = RWH.build_reader(fb, [1:2, 3:4]; pre = sel.columns_pre, post = sel.columns_post, counters = Dict{String,String}(),
        options = (stream_window_bytes = base + Int(extra.total) - 1, stream_retained_bytes = 10^9))
    msg = RWH.errmsg(() -> RWH.reserve_windowed_selection(tight, sel, nothing; extra_bytes = extra.total))
    @test occursin("windowed selection window_index=", msg) && occursin("required_bytes=$(base + Int(extra.total))", msg) &&
        occursin("exceeds execution.stream_window_bytes=$(base + Int(extra.total) - 1)", msg)
end

@testset "rev2 bounded prefix seam: first two windows, fresh state, exact prefix parity" begin
    w = [1e16, 1.0, -1e16, 3.0, -2.0, 7.0]; x = [1.0, 1.0, 1.0, -1.0, 1.0, 1.0]
    y = [-1.0, 1.0, 1.0, 1.0, -1.0, 1.0]; z = [11.0, 12.0, 13.0, 14.0, 15.0, 16.0]
    fb = RWH.FileBuilder()
    for (name, v) in (("w", w), ("x", x), ("y", y), ("z", z)); RWH.add_branch!(fb, name, v, [0, 2, 4, 6]; E = Float64); end
    sel = RWH.scalar_selection()
    full = RWH.build_reader(fb, [1:2, 3:4, 5:6]; pre = sel.columns_pre, post = sel.columns_post, counters = Dict{String,String}())
    full.diagnostics["prefix_events"] = 99                               # proves deep-copied, not shared
    pre = RWE.stream_window_prefix(full, 2)
    @test pre.windows == [1:2, 3:4] && pre.branches === full.branches && pre.diagnostics !== full.diagnostics
    @test pre.diagnostics["window_prefix_events"] == 4 && pre.diagnostics["window_prefix_source_windows"] == 3
    pre.diagnostics["prefix_events"] = 0
    @test full.diagnostics["prefix_events"] == 99 && isempty(pre.seen)
    @test_throws ArgumentError RWE.stream_window_prefix(full, 0)
    @test_throws ArgumentError RWE.stream_window_prefix(full, 4)
    @test_throws ArgumentError RWE.stream_window_prefix(full, true)
    raw4 = Dict{String,Any}("w"=>w[1:4], "x"=>x[1:4], "y"=>y[1:4], "z"=>z[1:4])
    got, a, diag, d = RWH.compare_reusable(sel, raw4, pre; n = 4)
    @test diag["reusable_branch_decoded_basket_ids"]["w"] == [1, 2]       # basket 3 never touched
    @test !haskey(diag["reusable_branch_skipped_basket_ids"], "w") || !(3 in diag["reusable_branch_skipped_basket_ids"]["w"])
    @test isempty(full.seen)
    @test_throws ErrorException RWE.finish_reusable_stream!(pre, RWH.state_for(pre), 4)   # unvisited prefix => coverage error
end

# Actual decoder integration is gate-only and never claimed from the stubs above.
if get(ENV, "CASCADE_WINDOWED_REUSABLE_REAL", "0") == "1"
    error("The historical site-pinned real-input harness is not distributed. Configure an independently validated real-input test for your site; no substitute result is implied.")
end
