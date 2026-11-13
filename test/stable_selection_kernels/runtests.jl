# Focused tests for execution.stable_selection_kernels (B2b). Standalone, stdlib only:
#   julia --startup-file=no test/stable_selection_kernels/runtests.jl
# Evidence runs set CASCADE_B2B_PROBE=1 and load the same harness from a package image
# (B2bProbe) generated in a separate process, to prove fresh-process type identity/reuse.
using Test
if get(ENV, "CASCADE_B2B_PROBE", "") == "1"
    using B2bProbe
end
const PROBE = isdefined(Main, :B2bProbe)
PROBE || include(joinpath(@__DIR__, "harness.jl"))
const H = PROBE ? B2bProbe.StableKernelHarness : StableKernelHarness
const S = H.Selection
const N = 400

# Arguments of the serial event loop; only the loop itself is called (and traced) later.
loop_args(sel, ctx, n) = (S._event_loop_recording!, sel, ctx, n, S.Cutflow(vcat("all", sel.cut_names)), Int64[], Int16[],
    Float64[], [Float64[] for _ in sel.output_names], nothing, Val(true))

bits(v::AbstractVector{Float64}) = reinterpret(UInt64, v)
function same_table(a, b)
    a.order == b.order || return false
    for k in a.order
        x, y = a.columns[k], b.columns[k]
        typeof(x) === typeof(y) || return false
        (eltype(x) === Float64 ? bits(x) == bits(y) : x == y) || return false
    end
    return isequal(a.meta, b.meta)
end
same_cutflow(a, b) = a.names == b.names && a.n == b.n && bits(a.sumw) == bits(b.sumw) && bits(a.sumw2) == bits(b.sumw2)
rt(k, ctx, extra...) = Base.invokelatest(Core.Compiler.return_type, k, Tuple{typeof(ctx), Int, map(typeof, extra)...})
errstring(f) = try f(); "no error" catch e; string(typeof(e), ": ", sprint(showerror, e)) end


# One outer testset: every group runs and is reported even if an earlier one fails.
@testset "B2b stable selection kernels" begin
if PROBE
    @testset "package image: identical stable types in a fresh process, loop code reused" begin
        G = B2bProbe.GEN
        @test G.generating && all(G.precompile_ok)                     # recorded while the image was generated
        Base.cumulative_compile_timing(true)
        sel = S.compile_selection(H.fixture_config(; stable = true, memo = true), :mc)
        raw = H.fixture_raw(N)
        ctx = S.selection_context(raw, sel, sel.collections; n = N)
        @test typeof(sel) === G.sel_type                               # same type object across process + image
        @test typeof(ctx) === G.ctx_type
        args = loop_args(sel, ctx, N)
        println(stderr, "B2B-TRACE-BEGIN stable"); flush(stderr)
        c0 = Base.cumulative_compile_time_ns()
        Base.@trace_compile Base.invokelatest(args...)
        c1 = Base.cumulative_compile_time_ns()
        println(stderr, "B2B-TRACE-END stable compile_ns=", c1[1] - c0[1]); flush(stderr)
        legacy = S.compile_selection(H.fixture_config(; stable = false, memo = true), :mc)
        @test typeof(legacy.cuts[1]) !== G.legacy_cut_type             # legacy identity is process-local
        lctx = S.selection_context(raw, legacy, legacy.collections; n = N)
        largs = loop_args(legacy, lctx, N)
        println(stderr, "B2B-TRACE-BEGIN legacy"); flush(stderr)
        l0 = Base.cumulative_compile_time_ns()
        Base.@trace_compile Base.invokelatest(largs...)
        l1 = Base.cumulative_compile_time_ns()
        println(stderr, "B2B-TRACE-END legacy compile_ns=", l1[1] - l0[1]); flush(stderr)
        Base.cumulative_compile_timing(false)
        @test (c1[1] - c0[1]) < (l1[1] - l0[1])
        @test args[6] == largs[6] && args[7] == largs[7]                # same retained entries/stages
        @test reinterpret(UInt64, args[8]) == reinterpret(UInt64, largs[8])
        global IMAGE_COMPILE_NS = (stable = c1[1] - c0[1], legacy = l1[1] - l0[1])
    end
end

@testset "opt-in flag: default false, strict Bool, validate_keys and profiles" begin
    C = H.Config
    @test !C.stable_selection_kernels(Dict{String,Any}())
    @test C.stable_selection_kernels(Dict{String,Any}("execution" => Dict{String,Any}("stable_selection_kernels" => true)))
    for bad in (1, "true", nothing)
        d = Dict{String,Any}("execution" => Dict{String,Any}("stable_selection_kernels" => bad))
        @test_throws ArgumentError C.stable_selection_kernels(d)
        @test_throws ArgumentError C.validate_keys(d)
        @test_throws ArgumentError C.validate_keys(Dict{String,Any}("profiles" => Dict{String,Any}("p" => d)))
        cfg = H.fixture_config(); cfg.raw["execution"]["stable_selection_kernels"] = bad
        @test_throws ArgumentError S.compile_selection(cfg, :mc)          # compile-time, before data
    end
    @test C.validate_keys(Dict{String,Any}("execution" => Dict{String,Any}("stable_selection_kernels" => true))) isa AbstractDict
    @test !S.is_stable_selection(S.compile_selection(H.fixture_config(; stable = false), :mc))   # legacy stays default path
    @test S.is_stable_selection(S.compile_selection(H.fixture_config(; stable = true), :mc))
end

@testset "legacy == stable: tables, cutflow, inference, memo first-demand (mc/data, memo on/off)" begin
    raw = H.fixture_raw(N)
    for kind in (:mc, :data), memo in (false, true)
        L = S.compile_selection(H.fixture_config(; stable = false, memo), kind)
        T = S.compile_selection(H.fixture_config(; stable = true, memo), kind)
        @test S.is_stable_selection(T) && !S.is_stable_selection(L)
        @test L.cut_names == T.cut_names && L.output_names == T.output_names && L.columns_pre == T.columns_pre &&
              L.columns_post == T.columns_post && L.column_stages == T.column_stages && L.mat_at == T.mat_at &&
              L.keep_stage == T.keep_stage && L.region_stage == T.region_stage && length(L.variable_nodes) == length(T.variable_nodes)
        tl, cl = S.select_events(L, raw, N; sample = "fx")
        tt, ct = S.select_events(T, raw, N; sample = "fx")
        @test same_table(tl, tt) && same_cutflow(cl, ct)
        @test S.nrows(tt) > 0 && any(isnan, tt.columns["v:ratio"]) && any(x -> x === -0.0, tt.columns["v:negz"])
        @test any(isinf, tt.columns["h:met:2"])                        # 0^-1 through literal_pow
        # Same kernel-context type => identical memo slot inference.
        lctx = S.selection_context(raw, L, L.collections; n = N); tctx = S.selection_context(raw, T, T.collections; n = N)
        @test typeof(lctx) === typeof(tctx)
        @test all(rt(L.cuts[k], lctx) === rt(T.cuts[k], tctx) for k in eachindex(L.cuts))
        @test rt(L.weight, lctx) === rt(T.weight, tctx) === Float64
        @test rt(L.outputs, lctx, 1) === rt(T.outputs, tctx, 1)
        @test rt(L.materialize, lctx, 0, 1) === rt(T.materialize, tctx, 0, 1)
        @test all(rt(a.compute, lctx) === rt(b.compute, tctx) for (a, b) in zip(L.variable_nodes, T.variable_nodes))
        # prefix pass and the staged/incremental progress route
        nl = Base.invokelatest(S.prefix_pass!, Vector{Bool}(undef, N), L, lctx, N)
        nt = Base.invokelatest(S.prefix_pass!, Vector{Bool}(undef, N), T, tctx, N)
        @test nl == nt
        res = map((L, T)) do sel
            p = S.SelectionProgress(sel, raw, N)
            for limit in (max(sel.mat_at - 1, 0), 3, 4)
                ctx = S._progress_context(raw, sel, sel.collections, p)
                Base.invokelatest(S.advance_selection!, p, sel, ctx, min(limit, sel.keep_stage + 3))
            end
            t, c = S.select_events(sel, raw, N; sample = "fx", progress = p)
            demand = p.memo === nothing ? Int[] : [s isa S.VariableMemoColumn ? count(s.valid) : -1 for s in p.memo.slots]
            (t, c, copy(p.passed), copy(p.failed), demand)
        end
        @test same_table(res[1][1], res[2][1]) && same_cutflow(res[1][2], res[2][2])
        @test res[1][3] == res[2][3] && res[1][4] == res[2][4] && res[1][5] == res[2][5]
        memo && @test any(>(0), res[2][5]) && any(d -> 0 < d < N, res[2][5])   # lazy: demanded rows only
    end
end

@testset "failures identical: translate errors, typeasserts, non-Bool &&, DomainError; unsupported is pre-data" begin
    raw = H.fixture_raw(N)
    for (cut, outs) in (("foo(MET_pt) > 1.0", nothing), ("MET_pt", nothing), ("MET_pt && true", nothing),
                        ("trigger", ["sqrtphi"]), ("jets.pt[3] > 0.0", nothing))
        vars = merge(H.FIXTURE_VARIABLES, Dict("sqrtphi" => "sqrt(MET_phi)"))
        mk(stable) = H.fixture_config(; stable, extra_cuts = [H.Config.CutConfig("x", cut, :all)],
                                      outputs = outs === nothing ? ["ratio"] : outs, variables = vars)
        el = errstring(() -> S.select_events(S.compile_selection(mk(false), :mc), raw, N))
        et = errstring(() -> S.select_events(S.compile_selection(mk(true), :mc), raw, N))
        @test el == et && el != "no error"
    end
    # Wider-than-Int64 literals are @int128_str/@big_str macrocalls: the unchanged translator
    # rejects them identically in both modes, before any kernel is built.
    for lit in ("100000000000000000000", "100000000000000000000000000000000000000000")
        mkbig(stable) = H.fixture_config(; stable, extra_cuts = [H.Config.CutConfig("big", "MET_pt < " * lit, :all)])
        el = errstring(() -> S.compile_selection(mkbig(false), :mc)); et = errstring(() -> S.compile_selection(mkbig(true), :mc))
        @test el == et && occursin("unsupported syntax 'macrocall'", et)
    end
    for (args, body) in (([:ctx, :k], :(true)), ([:ctx, :i], :(x = 1)), ([:ctx, :i], :(j -> true)),
                         ([:ctx, :i, :lo, :hi], :(j -> (k -> true))), ([:ctx, :i, :lo, :hi], :(j -> i > 0)),
                         ([:ctx, :i], :("s")), ([:ctx, :i], Expr(:call, :f, big"1")))
        @test_throws ArgumentError S.compile_stable_kernel(args, body)
    end
end

@testset "encoding: lossless, literal type/bits exact, literal_pow identical" begin
    for body in (:(Core.typeassert(ctx.cols.x[i] < 1.5, Bool)), :(0.0 <= ctx.cols.x[i] < 1), :((-0.0, 0.0, 1, 1.0, true, 0x02, Int128(2)^70)),
                 :(ctx.cols.x[i]^3 + ctx.cols.x[i]^-2 + ctx.cols.x[i]^2.0 + ctx.cols.x[i]^0x03),
                 :(ctx.cols.x[i] > 0 ? π * ctx.cols.x[i] : NaN), :(ctx.cols.x[i] > 0 && ctx.cols.x[i] < 2 || false))
        k = S.compile_stable_kernel([:ctx, :i], body)
        @test S._stable_same(S.stable_kernel_expr(k)[2], S._stable_strip(body))
        @test S.compile_stable_kernel([:ctx, :i], body) === k                    # same body => same singleton
    end
    @test typeof(S.compile_stable_kernel([:ctx, :i], :(ctx.cols.x[i] < 1.0))) !== typeof(S.compile_stable_kernel([:ctx, :i], :(ctx.cols.x[i] < 1)))
    @test typeof(S.compile_stable_kernel([:ctx, :i], :(0.0 * ctx.cols.x[i]))) !== typeof(S.compile_stable_kernel([:ctx, :i], :(-0.0 * ctx.cols.x[i])))
    @test sizeof(S.compile_stable_kernel([:ctx, :i], :(true))) == 0
    r = H.XorShift(0x1234)
    for E in (Float32, Float64)
        xs = E[E(-50 + 100 * H.unif!(r)) for _ in 1:2000]; push!(xs, E(0), -E(0), E(NaN), E(Inf), floatmax(E), nextfloat(E(0)))
        ctx = S.KernelContext((x = xs,), NamedTuple(), NamedTuple())
        for body in (:(ctx.cols.x[i]^3), :(ctx.cols.x[i]^-3), :(ctx.cols.x[i]^5), :(ctx.cols.x[i]^2.0),
                     :(ctx.cols.x[i]^0x03), :(Float64(ctx.cols.x[i]) * π - ctx.cols.x[i] / 3))
            lk = S.compile_kernel([:ctx, :i], body); sk = S.compile_stable_kernel([:ctx, :i], body)
            a = [Base.invokelatest(lk, ctx, i) for i in eachindex(xs)]; b = [sk(ctx, i) for i in eachindex(xs)]
            @test typeof(a) === typeof(b) && reinterpret(UInt8, a) == reinterpret(UInt8, b)
        end
    end
end

@testset "stable identity: repeated config same types, changed config no alias, bounded ownership" begin
    raw = H.fixture_raw(N)
    a = S.compile_selection(H.fixture_config(; stable = true, memo = true), :mc)
    b = S.compile_selection(H.fixture_config(; stable = true, memo = true), :mc)
    @test typeof(a) === typeof(b) && a.cuts === b.cuts && a.outputs === b.outputs && a.materialize === b.materialize
    la = S.compile_selection(H.fixture_config(; stable = false), :mc); lb = S.compile_selection(H.fixture_config(; stable = false), :mc)
    @test typeof(la.cuts[1]) !== typeof(lb.cuts[1])                          # legacy: new type every compile
    # 100.0 changes the stage of fixture events (offline emulation: 6 of 400; 60.0 changed none).
    c = S.compile_selection(H.fixture_config(; stable = true, memo = true, lead_cut = 100.0), :mc)
    @test typeof(c.cuts[4]) !== typeof(a.cuts[4]) && typeof(c.cuts[1]) === typeof(a.cuts[1])
    ta, _ = S.select_events(a, raw, N); tc, _ = S.select_events(c, raw, N)
    lc, _ = S.select_events(S.compile_selection(H.fixture_config(; stable = false, memo = true, lead_cut = 100.0), :mc), raw, N)
    @test same_table(tc, lc)                                                 # changed config == its legacy result
    @test !same_table(ta, tc)                                                # ... and differs from the old config (no alias)
    @test ta.columns["stage"] != tc.columns["stage"]
    K = S.Kernels
    before = length(names(K; all = true))
    for _ in 1:10; S.compile_selection(H.fixture_config(; stable = true, memo = true), :mc); end
    @test length(names(K; all = true)) == before                             # stable: no runtime definitions
    for _ in 1:3; S.compile_selection(H.fixture_config(; stable = false, memo = true), :mc); end
    @test length(names(K; all = true)) > before                              # legacy: grows per compile
    @test all(k -> sizeof(k) == 0, (a.cuts..., a.weight, a.outputs, a.materialize))
end

@testset "concurrency: shared immutable stable kernels, task-owned contexts" begin
    sel = S.compile_selection(H.fixture_config(; stable = true, memo = true), :mc)
    raws = [H.fixture_raw(N; seed = UInt64(1000 + k)) for k in 1:8]
    serial = [S.select_events(sel, raw, N) for raw in raws]
    tasks = [Threads.@spawn S.select_events(sel, raw, N) for raw in raws]
    par = fetch.(tasks)
    @test all(same_table(serial[k][1], par[k][1]) && same_cutflow(serial[k][2], par[k][2]) for k in eachindex(raws))
    legacy = S.compile_selection(H.fixture_config(; stable = false, memo = true), :mc)
    @test all(same_table(S.select_events(legacy, raws[k], N)[1], par[k][1]) for k in eachindex(raws))
end

@testset "precompile helper: type-level, stable only" begin
    sel = S.compile_selection(H.fixture_config(; stable = true), :data)
    ctx = S.selection_context(H.fixture_raw(0), sel, sel.collections; n = 0)
    @test all(S.precompile_stable_selection(sel, ctx))
    legacy = S.compile_selection(H.fixture_config(; stable = false), :data)
    @test_throws ArgumentError S.precompile_stable_selection(legacy, S.selection_context(H.fixture_raw(0), legacy, legacy.collections; n = 0))
    PROBE && println("B2B-IMAGE-COMPILE-NS ", IMAGE_COMPILE_NS)
end
@testset "training workload driver: zero-event staged contexts == same-schema real contexts" begin
    trig = H.Config.TriggerConfig(Dict("g1" => ["HLT_A"], "g2" => ["HLT_B"]), ["S1", "S2"],
                                  Dict("S1" => ["g1"], "S2" => ["g2"]), ["g1", "g2"])
    proto = H.fixture_raw(1); full = H.fixture_raw(N)
    for d in (proto, full)
        m = length(d["MET_pt"])
        d["HLT_A"] = fill(true, m); d["HLT_B"] = [isodd(i) for i in 1:m]; d["luminosityBlock"] = Int32.(1:m)
    end
    column(name) = (v = proto[name]; v isa H.Jagged ? H.Jagged(eltype(v.content)[], [0]) : eltype(v)[])
    lm = H.IO.LumiMask(1, typemax(Int))
    for (kind, stream, L) in ((:mc, "", nothing), (:data, "S1", lm), (:data, "S2", lm)), memo in (false, true)
        extra = kind === :data ? [H.Config.CutConfig("lm", "lumimask", :data)] : H.Config.CutConfig[]
        sel = S.compile_selection(H.fixture_config(; stable = true, memo, triggers = trig, extra_cuts = extra), kind)
        tr = S.stable_selection_training!(sel, stream, L, column)
        @test tr.progress isa S.SelectionProgress && !isempty(tr.stages)
        @test ("trigger" in tr.columns) && (kind === :data) == ("lumimask" in tr.columns)
        @test all(p -> p in tr.columns, S.trigger_paths(trig, kind, stream))
        raw = Dict{String,Any}(k => (k == "lumimask" ? fill(true, N) : full[k]) for k in tr.columns)
        p = S.SelectionProgress(sel, raw, N)
        @test typeof(p) === typeof(tr.progress)
        @test typeof(S._progress_context(raw, sel, sel.collections, p)) === tr.final   # event-loop context type
        tb, _ = S.select_events(sel, raw, N; sample = "fx", progress = p)
        @test S.nrows(tb) > 0
    end
    legacy = S.compile_selection(H.fixture_config(; stable = false, triggers = trig), :mc)
    @test_throws ArgumentError S.stable_selection_training!(legacy, "", nothing, column)
    @test_throws ArgumentError S.stable_selection_training!(S.compile_selection(H.fixture_config(; stable = true, triggers = trig), :mc),
                                                             "", nothing, name -> throw(ArgumentError("no column $name")))
end
end # outer testset
