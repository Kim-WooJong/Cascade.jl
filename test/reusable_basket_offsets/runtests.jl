# Focused regression tests for the reusable-basket offset validation function barrier
# (src/IO/read_reusable_basket.jl, 2026-11-10). In-memory only: no input files.
# Semantics: every original check, message and order; type: optimized helper IR (Julia 1.12.2 checker below);
# allocation: no per-entry allocation growth. Real reusable-reader admission/integration is NOT covered here.
using Test
using Cascade

const _V = Cascade.IO._validate_basket_offsets
const _K = 100

function _offset_raw(offs, content)
    raw = zeros(UInt8, content + 8 + 4 * length(offs))
    for (k, o) in enumerate(offs)
        raw[content+4k+1:content+4k+4] = reinterpret(UInt8, [hton(Int32(o + _K))])
    end
    return raw
end

function _outcome(raw, content, trailer, entries, canonical, ::Type{E}; lo = 1) where {E}
    try
        _V(raw, content, _K, trailer, entries, canonical, lo, E)
        return "ok"
    catch e
        return e isa ErrorException ? e.msg : "EXC: " * string(typeof(e))
    end
end

# ---- Optimized-IR checker, conservative and pinned to Julia 1.12.2 ----
# Control flow (GotoNode/GotoIfNot/ReturnNode/EnterNode) and non-value Exprs are excluded from the Any count; phi/pi
# values are counted. :invoke is a static call. For :call the callee is resolved from GlobalRef, QuoteNode, a literal,
# or an inferred Core.Const / singleton type of an SSA value or argument. Resolved intrinsics and non-dispatching
# builtins are static; dispatching builtins (invokelatest/invoke_in_world/_call_in_world_total/_apply_iterate/...)
# and generic functions are dynamic; anything unresolved is counted as unknown (treated as not static).
const _IR_VERSION = v"1.12.2"
const _SKIP = (:meta, :leave, :pop_exception, :code_coverage_effect, :gc_preserve_begin, :gc_preserve_end, :loopinfo)
const _DISPATCHING = Set{Any}(getfield(Core, s) for s in (:invokelatest, :invoke_in_world, :_call_in_world_total,
    :_apply_iterate, :_apply, :_call_latest, :_call_in_world, :invoke) if isdefined(Core, s))
function _constval(t)
    t isa Core.Const && return (true, t.val)
    tw = Core.Compiler.widenconst(t)
    (tw isa DataType && Base.issingletontype(tw)) && return (true, tw.instance)
    return (false, nothing)
end
function _callee(fx, ci, argtypes)
    fx isa GlobalRef && return isdefined(fx.mod, fx.name) && isconst(fx.mod, fx.name) ? (true, getglobal(fx.mod, fx.name)) : (false, nothing)
    fx isa QuoteNode && return (true, fx.value)
    fx isa Core.SSAValue && return _constval(ci.ssavaluetypes[fx.id])
    fx isa Core.Argument && return fx.n <= length(argtypes) ? _constval(argtypes[fx.n]) : (false, nothing)
    fx isa Expr && return (false, nothing)
    return (true, fx)
end
function _value_ops(f, tt)
    ci, _ = only(code_typed(f, tt; optimize = true))
    argtypes = Any[Core.Typeof(f), tt.parameters...]
    types = ci.ssavaluetypes isa Vector ? ci.ssavaluetypes : Any[]
    nany = 0; ndyn = 0; nunknown = 0
    for (i, st) in enumerate(ci.code)
        (st === nothing || st isa Core.GotoNode || st isa Core.GotoIfNot || st isa Core.ReturnNode ||
         (isdefined(Core, :EnterNode) && st isa Core.EnterNode)) && continue
        st isa Expr && st.head in _SKIP && continue
        Core.Compiler.widenconst(i <= length(types) ? types[i] : Any) === Any && (nany += 1)
        if st isa Expr && st.head === :call
            ok, fv = _callee(st.args[1], ci, argtypes)
            if !ok
                nunknown += 1
            elseif fv isa Core.IntrinsicFunction || (fv isa Core.Builtin && !(fv in _DISPATCHING))
            else
                ndyn += 1
            end
        end
    end
    return (nany, ndyn, nunknown)
end
# controls: typed positive; dynamic generic negative; dispatching-builtin negative with no Any and concrete result
_ir_typed(v::Vector{Int}) = (s = 0; for x in v; s += x; end; s)
_ir_dyn(v::Vector{Any}) = v[1] + v[2]
_ir_latest(x::Int) = Core.invokelatest(identity, x)::Int
_ir_splat(v::Vector{Int}) = (+(v...))::Int

# Exact-specialization allocation measurement: only simple arguments; setup outside; warmed before recording.
_alloc_measure(raw, content, trailer, n, c, ::Type{E}) where {E} = @allocated _V(raw, content, _K, trailer, n, c, 1, E)
function _alloc_case(n, c, ::Type{E}) where {E}
    w = sizeof(E); content = w * n
    raw = _offset_raw(collect(0:w:w*(n-1)), content); trailer = 4n + 8
    _alloc_measure(raw, content, trailer, n, c, E)                  # warm this exact measured specialization
    return _alloc_measure(raw, content, trailer, n, c, E)
end

@testset "reusable basket offset validation barrier" begin
    can = [0, 2, 2, 5]
    @testset "semantics: original checks and messages" begin
        cases = [
            ([0, 8, 8], 20, can, Float32, 20, "ok"),
            ([0, 8, 8], 20, nothing, Float32, 20, "ok"),
            ([0, 2, 2], 5, can, Bool, 20, "ok"),
            ([7, 3, 1], 20, can, Float32, 0, "ok"),                       # trailer == 0: no iteration
            ([4, 8, 8], 20, nothing, Float32, 20, "basket offsets do not start at zero"),
            ([0, 8, 4], 20, nothing, Float32, 20, "invalid basket offsets"),
            ([0, 8, 24], 20, nothing, Float32, 20, "invalid basket offsets"),
            ([-4, 0, 8], 20, nothing, Float32, 20, "invalid basket offsets"),
            ([0, 6, 8], 20, nothing, Float32, 20, "unaligned primitive basket offset"),
            ([0, 4, 8], 20, can, Float32, 20, "basket offsets disagree with canonical counter"),
            ([0, 8, 20], 20, nothing, Float32, 20, "ok"),                 # off == content: empty terminal entry
            ([4, 6, 8], 20, nothing, Float32, 20, "basket offsets do not start at zero"),   # first of several failures
            ([0, 2, 4], 8, nothing, Int16, 20, "ok"),
            ([0, 8, 16], 24, nothing, Float64, 20, "ok"),
            ([0, 8, 12], 24, nothing, Int64, 20, "unaligned primitive basket offset"),
            ([0, 1, 3], 4, nothing, Int8, 20, "ok")]
        for (offs, content, canonical, E, trailer, expected) in cases
            raw = _offset_raw(offs, content); snap = copy(raw); csnap = canonical === nothing ? nothing : copy(canonical)
            @test _outcome(raw, content, trailer, length(offs), canonical, E) == expected
            @test raw == snap
            @test canonical == csnap                                       # canonical is read-only
        end
        raw = _offset_raw([0, 8], 8)                                       # lo offset into a longer canonical vector
        @test _outcome(raw, 8, 16, 2, [0, 3, 3, 5, 6], Float32; lo = 3) == "ok"
        @test _outcome(UInt8[], 0, 0, 0, nothing, Float32) == "ok"          # zero entries, empty raw, trailer == 0
        @test _outcome(zeros(UInt8, 10), 4, 16, 3, nothing, Float32) == "EXC: BoundsError"     # raw too short
        @test _outcome(_offset_raw([0, 4, 8], 12), 12, 20, 3, [0, 1], Float32) == "EXC: BoundsError"   # canonical short
    end

    @testset "type: helper specializations are concrete (Julia $(_IR_VERSION) checker)" begin
        @test VERSION == _IR_VERSION
        @test _value_ops(_ir_typed, Tuple{Vector{Int}}) == (0, 0, 0)           # typed positive control
        a, d, u = _value_ops(_ir_dyn, Tuple{Vector{Any}}); @test a > 0 && d + u > 0   # generic dynamic negative
        a, d, u = _value_ops(_ir_latest, Tuple{Int}); @test d + u > 0           # dispatching builtin, concrete result
        a, d, u = _value_ops(_ir_splat, Tuple{Vector{Int}}); @test d + u > 0    # _apply_iterate, concrete result
        for E in (UInt8, Bool, Int16, Int32, Float32, Float64), C in (Vector{Int}, Nothing)
            @test _value_ops(_V, Tuple{Vector{UInt8},Int,Int,Int,Int,C,Int,Type{E}}) == (0, 0, 0)
        end
    end

    @testset "allocation: no per-entry growth (warmed exact measurement)" begin
        for C in (Nothing, Vector{Int}), E in (Float32, UInt8)
            mk(n) = C === Nothing ? nothing : collect(0:n)
            small = _alloc_case(4, mk(4), E); large = _alloc_case(4000, mk(4000), E)
            @test large == small
            @test large <= 64
        end
    end

    @testset "caller uses the barrier" begin
        src = read(joinpath(pkgdir(Cascade), "src", "IO", "read_reusable_basket.jl"), String)
        body = src[findfirst("function _read_reusable_basket!(", src)[1]:findfirst("\nfunction _validate_basket_offsets(", src)[1]]
        @test occursin("_validate_basket_offsets(raw, content, keylen, trailer, entries, canonical, lo, E)", body)
        @test !occursin("for k in 1:(trailer == 0 ? 0 : entries)", body)
        @test count("for k in 1:(trailer == 0 ? 0 : entries)", src) == 1
    end
end
