# Focused tests for the named no-checkpoint file work callable (B2a).
# Standalone: stdlib only, no Cascade package load, no ROOT input, no package build.
#
# REAL production source included: Config struct/option files, IO/LumiMask.jl, Pipeline
# STEPS/RunOptions/StepContext/ordered_window and the new no_checkpoint_file_work.jl.
# STUB-ONLY (recording fakes, NOT science): benchmark_span, select_chunk_results,
# handoff_table_metadata, execute_correct_chunk, verify_correct_extraction,
# execute_histogram_chunk, region_counts, Fit.channel_overlap_provenance, cutflow_dict,
# _json_transport, Histograms.transport_store, default_correct and Selection.EventTable.
# The callees are unchanged by B2a; these tests prove the callable routes the same
# references/values to them in the same order and returns the same result as the former
# closure (embedded verbatim below), plus the declared precompile types.
using Test

module NCFWHarness
const ROOT = normpath(joinpath(@__DIR__, "../.."))
const CAND = ROOT
src(parts...) = isfile(joinpath(CAND,"src",parts...)) ? joinpath(CAND,"src",parts...) : joinpath(ROOT,"src",parts...)

module Cascade
module Config
const _src = parentmodule(parentmodule(@__MODULE__)).src
for f in ("SampleConfig", "ObjectConfig", "CutConfig", "RegionConfig", "HistogramConfig", "VariationConfig",
          "TriggerConfig", "DataQualityConfig", "ShapeVariationConfig", "AnalysisConfig", "column_readers",
          "decode_options", "windowed_selection", "streaming_selection_options", "event_ranges")
    include(_src("Config", f * ".jl"))
end
end # Config
module IO
include(parentmodule(parentmodule(@__MODULE__)).src("IO", "LumiMask.jl"))
end
module Selection
struct EventTable
    entry::Vector{Int}
    w::Vector{Float64}
    meta::Dict{String,Any}
end
struct Cutflow
    sumw::Vector{Float64}
    n::Vector{Int}
end
end
module Fit
const CALLS = Ref(0)
channel_overlap_provenance(table, cfg) = (parentmodule(@__MODULE__).Pipeline.FAIL[] === :provenance && error("injected provenance failure"); CALLS[] += 1; parentmodule(@__MODULE__).Pipeline.logcall((:provenance, table.entry, objectid(cfg))); Dict{String,Any}("rows" => copy(table.entry)))
end
module Histograms
transport_store(store) = (parentmodule(@__MODULE__).Pipeline.FAIL[] === :transport && error("injected transport failure"); parentmodule(@__MODULE__).Pipeline.logcall((:transport, store["sum"])); deepcopy(store))
end
module Pipeline
import ..Config
using ..Config: AnalysisConfig, SampleConfig, is_data
import ..IO as EventIO
using ..Selection: EventTable
import ..Selection
import ..Fit
import ..Histograms
const _src = parentmodule(parentmodule(@__MODULE__)).src
for f in ("STEPS", "RunOptions", "StepContext", "ordered_window")
    include(_src("Pipeline", f * ".jl"))
end

# ---------------- recording stubs (shared by the original closure and the callable) ----------------
const LOG = Any[]
const LOGLOCK = ReentrantLock()
logcall(x) = lock(() -> push!(LOG, x), LOGLOCK)
const FAIL = Ref(:none)
const STAGES = Any[]
const StubTable = Selection.EventTable
const StubCutflow = Selection.Cutflow
default_correct(args...) = error("stub hook is never called by these tests")
function benchmark_span(f, stage, workdir; sample = nothing, chunk = nothing)
    lock(()->push!(STAGES,f),LOGLOCK)
    logcall((:span_begin, stage, workdir, sample, chunk, typeof(chunk)))
    v = f()
    logcall((:span_end, stage))
    return v
end
# Signed, cancellation-sensitive weights: only the original order gives the reference sums.
const WEIGHTS = Dict("a.root" => [1e16, 1.0, -1e16, 3.0, -2.5], "b.root" => [0.1, 0.2, 0.3],
                     "zero.root" => Float64[], "m.root" => [-1.0, 2.0^60, 1.0, -(2.0^60)])
function select_chunk_results(p, compiled, plans, lm, s, path, out; budget, kw...)
    logcall((:select, objectid(p), objectid(compiled), objectid(plans), lm === nothing ? nothing : objectid(lm),
             s.name, path, out, budget, collect(keys(kw))))
    FAIL[] === :select && error(string("injected select failure for ", path))
    w = WEIGHTS[basename(path)]
    table = StubTable(collect(1:length(w)), copy(w), Dict{String,Any}("nevents" => 10))
    cf = StubCutflow([foldl(+, w; init = 0.0), 7.0], [10, length(w)])
    plan = FAIL[] === :shape ? Dict{String,Any}() : nothing
    results = FAIL[] === :tworesults ? [("nominal", (table, cf)), ("x", (table, cf))] : [("nominal", (table, cf))]
    return results, Dict{String,Any}("execution" => true), plan, true
end
handoff_table_metadata(t) = (logcall((:handoff, t.entry)); StubTable(t.entry, t.w, merge(t.meta, Dict{String,Any}("handoff" => true))))
function execute_correct_chunk(ctx, p, item; table = nothing, persist::Bool = true)
    logcall((:correct, objectid(ctx), objectid(p), item, table.entry, table.meta["handoff"], persist))
    FAIL[] === :correct && throw(ArgumentError("injected correct failure"))
    cols = Dict{String,Any}("nominal" => table.w .* 2.0, "alt" => -table.w)
    return cols, Dict{String,Any}("sample" => item[1].name), ["nominal", "alt"]
end
function verify_correct_extraction(cfg, s, meta, order; expected)
    logcall((:verify, objectid(cfg), s.name, meta, order, objectid(expected)))
    FAIL[] === :verify && error("injected theory extraction mismatch")
    return nothing
end
function execute_histogram_chunk(ctx, p, item; table = nothing, weights = nothing, persist::Bool = true)
    logcall((:histogram, objectid(ctx), objectid(p), item, table.entry, weights[3], persist))
    FAIL[] === :histogram && error("injected histogram failure")
    wn = weights[1]["nominal"]
    s = 0.0
    for x in wn            # ordered left-to-right accumulation (order-sensitive)
        s += x
    end
    return Dict{String,Any}("sum" => s, "sumsq" => foldl((a, x) -> a + x * x, wn; init = 0.0), "n" => length(wn))
end
region_counts(t) = (FAIL[] === :counts && error("injected counts failure"); logcall((:region_counts, t.entry)); Dict{String,Any}("SR" => length(t.entry)))
cutflow_dict(cf) = Dict{String,Any}("sumw" => copy(cf.sumw), "n" => copy(cf.n))
_json_transport(x) = (FAIL[] === :json && error("injected json failure"); logcall((:json, x)); deepcopy(x))

include(_src("Pipeline", "no_checkpoint_file_work.jl"))

# ---------------- the former closure, VERBATIM from run_no_checkpoints.jl (R5 6d84fcd7) ----------------
const ORIGINAL_CLOSURE = raw"""
    function work(item)
        s, e = item
        path = String(e["path"])
        chunk = e["chunk"]
        seconds = zeros(Float64, 3)
        t1 = time()
        results, _, plan, _ = benchmark_span(:select, workdir; sample = s.name, chunk) do
            select_chunk_results(psel, compiled, plans, lmask, s, path, ""; budget = 1)
        end
        (plan === nothing && length(results) == 1) || error("internal no-checkpoint error: unexpected shape results")
        table, cf = last(results[1])
        table = handoff_table_metadata(table)
        t2 = time(); seconds[1] = t2 - t1
        weights = benchmark_span(:correct, workdir; sample = s.name, chunk) do
            w = execute_correct_chunk(ctx, pcor, (s, path, "", "", "", chunk, String[]); table, persist = false)
            verify_correct_extraction(cfg, s, w[2], w[3]; expected = pcor.manifests[s.name])
            w
        end
        t3 = time(); seconds[2] = t3 - t2
        transported, meta, counts, chunk_provenance = benchmark_span(:histogram, workdir; sample = s.name, chunk) do
            local transported, meta, counts, chunk_provenance
            store = execute_histogram_chunk(ctx, phist, (s, "", "", "", "", chunk, String[]); table, weights, persist = false)
            counts = has_region_expr ? region_counts(table) : nothing
            chunk_provenance = check_overlap && is_data(s) ? Fit.channel_overlap_provenance(table, cfg) : nothing
            meta = _json_transport(Dict{String,Any}("cutflow" => cutflow_dict(cf)))
            transported = Histograms.transport_store(store)
            (transported, meta, counts, chunk_provenance)
        end
        seconds[3] = time() - t3
        return (; sample = s.name, chunk = String(chunk), store = transported, meta, counts,
                provenance = chunk_provenance, seconds)
    end
"""
include_string(@__MODULE__, "function make_original_work(cfg, workdir, ctx, psel, pcor, phist, compiled, plans, lmask, has_region_expr, check_overlap)\n" *
    ORIGINAL_CLOSURE * "\n    return work\nend\n", "ORIGINAL_CLOSURE")
end # Pipeline
end # Cascade

# Exact R5 fresh-run --trace-compile statement of the former closure (trace_compile.jl line 447,
# file sha256 5561bf7eeb14a9a81cf89d1d8e96a9b52bc058b33349eb1feb603d134d79ad4a).
const R5_TRACE = raw"""
precompile(Tuple{Cascade.Pipeline.var"#work#_run_no_checkpoints_traced##12"{Cascade.Config.AnalysisConfig, String, Bool, Bool, Base.Dict{String, Any}, Cascade.IO.LumiMask, Base.Dict{Symbol, Any}, NamedTuple{(:cfg, :code, :chash), Tuple{Cascade.Config.AnalysisConfig, String, String}}, NamedTuple{(:cfg, :f, :id, :code, :chash, :files, :manifests, :manifest_hashes), Tuple{Cascade.Config.AnalysisConfig, typeof(Cascade.Pipeline.default_correct), String, String, String, String, Base.Dict{String, Base.Dict{String, Any}}, Base.Dict{String, String}}}, NamedTuple{(:cfg, :requested_readers, :decode, :streaming, :windowed, :decode_enabled, :code, :dq, :chash, :shape, :shape_code), Tuple{Cascade.Config.AnalysisConfig, Int64, NamedTuple{(:threads, :jobs, :bytes), Tuple{Int64, Int64, Int64}}, NamedTuple{(:enabled, :stream_window_events, :stream_active_files, :stream_queue_windows, :stream_queue_bytes, :stream_window_bytes, :stream_basket_bytes, :stream_metadata_bytes, :stream_retained_bytes), Tuple{Bool, Vararg{Int64, 8}}}, Bool, Bool, String, Cascade.Config.DataQualityConfig, String, Array{Cascade.Config.ShapeVariationConfig, 1}, String}}, Cascade.Pipeline.StepContext}, Tuple{Cascade.Config.SampleConfig, Base.Dict{String, Any}}})
"""
end # NCFWHarness

const H = NCFWHarness
const P = H.Cascade.Pipeline
const C = H.Cascade.Config

function dedent(lines)
    k = minimum((length(l) - length(lstrip(l)) for l in lines if !isempty(strip(l))); init = typemax(Int))
    return [isempty(strip(l)) ? "" : String(l[k+1:end]) for l in lines]
end

function fixture(; lmask = H.Cascade.IO.LumiMask(1, 10), has_region_expr = true, check_overlap = true, workdir = "/wd")
    data = C.SampleConfig("data", :data, String[], "nanoaod", 0.0, 1.0, "Muon", "", Dict{String,Any}())
    mc = C.SampleConfig("tt", :mc, String[], "nanoaod", 831.76, 1.0, "", "", Dict{String,Any}())
    cfg = C.AnalysisConfig("a", "/x/a.toml", "/x", 1210.0, [data, mc], C.ObjectConfig[], Dict{String,String}(),
        C.CutConfig[], C.RegionConfig[], C.HistogramConfig[], String[], String[], C.VariationConfig[], C.TriggerConfig(),
        C.DataQualityConfig(), String[], "/wd", Dict{String,Any}())
    ctx = P.StepContext(cfg, "/wd/no-checkpoints/.r.partial", :skim, [data, mc], P.RunOptions("/x/a.toml"))
    psel = (; cfg, requested_readers = 1, decode = C.decode_options(cfg), streaming = C.streaming_selection_options(cfg),
        windowed = false, decode_enabled = false, code = "c", dq = cfg.data_quality, chash = "h",
        shape = C.ShapeVariationConfig[], shape_code = "")
    pcor = (; cfg, f = P.default_correct, id = "default", code = "c", chash = "h", files = "f",
        manifests = Dict{String,Dict{String,Any}}("data" => Dict{String,Any}(), "tt" => Dict{String,Any}()),
        manifest_hashes = Dict{String,String}("data" => "x", "tt" => "y"))
    phist = (; cfg, code = "c", chash = "h")
    compiled = Dict{Symbol,Any}(:data => :seldata, :mc => :selmc)
    plans = Dict{String,Any}()
    args = (cfg, workdir, ctx, psel, pcor, phist, compiled, plans, lmask, has_region_expr, check_overlap)
    items = Any[(data, Dict{String,Any}("path" => "/in/a.root", "chunk" => "c0001")),
                (mc, Dict{String,Any}("path" => "/in/b.root", "chunk" => "c0002")),
                (data, Dict{String,Any}("path" => "/in/zero.root", "chunk" => "c0003")),
                (mc, Dict{String,Any}("path" => "/in/m.root", "chunk" => "c0004"))]
    return args, items
end

function runlog(f, item)
    empty!(P.LOG)
    empty!(P.STAGES)
    r = try
        f(item)
    catch e
        e
    end
    return r, copy(P.LOG)
end

bits(x::Float64) = reinterpret(UInt64, x)
bits(v::Vector{Float64}) = reinterpret(UInt64, v)
sameresult(a, b) = typeof(a) == typeof(b) && a.sample == b.sample && a.chunk == b.chunk &&
    isequal(a.store, b.store) && bits(a.store["sum"]) == bits(b.store["sum"]) && bits(a.store["sumsq"]) == bits(b.store["sumsq"]) &&
    isequal(a.meta, b.meta) && bits(a.meta["cutflow"]["sumw"]) == bits(b.meta["cutflow"]["sumw"]) &&
    isequal(a.counts, b.counts) && isequal(a.provenance, b.provenance) &&
    a.seconds isa Vector{Float64} && length(a.seconds) == length(b.seconds) == 3 && all(>=(0), a.seconds)

@testset "stage bodies verbatim from current preimage do-blocks" begin
    old=read(joinpath(@__DIR__,"baseline_file_work.jl"),String)
    new=read(H.src("Pipeline","no_checkpoint_file_work.jl"),String)
    for (name,label) in (("Select","select"),("Correct","correct"),("Histogram","histogram"))
        tag="benchmark_span(:"*label
        start=findfirst(tag,old).start
        body_start=findnext(" do\n",old,start).stop+1
        body_end=findnext("\n    end",old,body_start).start-1
        oldbody=dedent(split(old[body_start:body_end],'\n'))
        method="function (stage::NoCheckpoint"*name*"Stage)()"
        start=findfirst(method,new).stop+1
        alias_end=findnext('\n',new,start+1)
        stop=findnext("\nend",new,alias_end).start-1
        newbody=dedent(split(new[alias_end+1:stop],'\n'))
        @test oldbody==newbody
    end
    @test !occursin(" do\n",new[findfirst("function (unit::NoCheckpointFileWork)",new).start:findfirst("no_checkpoint_file_item_type() =",new).start])
end

@testset "named call == former closure: values, call order, references, signed weights" begin
    for lm in (H.Cascade.IO.LumiMask(1, 10), nothing), hre in (true, false), co in (true, false)
        args, items = fixture(; lmask = lm, has_region_expr = hre, check_overlap = co)
        unit = P.NoCheckpointFileWork(args...)
        orig = P.make_original_work(args...)
        P.FAIL[] = :none
        for item in items
            a, la = runlog(orig, item)
            b, lb = runlog(unit, item)
            @test sameresult(a, b)
            @test la == lb                          # same callees, arguments/identities and order
            @test count(x -> x[1] === :select, lb) == 1 && count(x -> x[1] === :correct, lb) == 1 &&
                  count(x -> x[1] === :verify, lb) == 1 && count(x -> x[1] === :histogram, lb) == 1
            @test [x[2] for x in lb if x[1] === :span_begin] == [:select, :correct, :histogram]
            @test all(x -> x[3] == "/wd" && x[4] == item[1].name && x[5] === item[2]["chunk"], filter(x -> x[1] === :span_begin, lb))
            @test count(x -> x[1] === :region_counts, lb) == (hre ? 1 : 0)
            @test count(x -> x[1] === :provenance, lb) == (co && item[1].kind === :data ? 1 : 0)
            w = P.WEIGHTS[basename(item[2]["path"])]
            ref = 0.0
            for x in w
                ref += 2.0 * x
            end
            @test bits(b.store["sum"]) == bits(ref)  # ordered signed sum
            @test b.store["n"] == length(w)
            @test b.meta["cutflow"]["sumw"][1] === foldl(+, w; init = 0.0)
        end
        r = unit(items[3])                          # zero-selected file
        @test r.store["n"] == 0 && r.store["sum"] === 0.0 && r.meta["cutflow"]["n"] == [10, 0]
        @test hre ? r.counts == Dict{String,Any}("SR" => 0) : r.counts === nothing
        @test unit(items[1]).store["sum"] === ((((2e16 + 2.0) - 2e16) + 6.0) - 5.0)   # signed cancellation order
    end
end

@testset "failures and guards unchanged (same error, same partial calls)" begin
    args, items = fixture()
    unit = P.NoCheckpointFileWork(args...); orig = P.make_original_work(args...)
    for mode in (:select, :shape, :tworesults, :correct, :verify, :histogram, :counts, :provenance, :json, :transport)
        P.FAIL[] = mode
        a, la = runlog(orig, items[1]); b, lb = runlog(unit, items[1])
        @test a isa Exception && typeof(a) == typeof(b) && sprint(showerror, a) == sprint(showerror, b)
        @test la == lb
    end
    P.FAIL[] = :shape
    @test sprint(showerror, runlog(unit, items[1])[1]) == "internal no-checkpoint error: unexpected shape results"
    P.FAIL[] = :none
    bad = (items[1][1], Dict{String,Any}("path" => "/in/a.root", "chunk" => 7))        # non-String chunk
    a, la = runlog(orig, bad); b, lb = runlog(unit, bad)
    @test a isa MethodError && b isa MethodError && la == lb
end

@testset "OrderedWindow: dynamic dispatch, exact order, fail-fast, join" begin
    args, items = fixture()
    P.FAIL[] = :none
    ref = [P.make_original_work(args...)(it) for it in items]
    for workers in (1, 2, 4)
        ow = P.OrderedWindow(P.NoCheckpointFileWork(args...), items; window = 2, workers, label = "")
        got = try
            [P.take_next!(ow) for _ in items]
        finally
            P.shutdown_window!(ow)
        end
        @test all(sameresult(g, r) for (g, r) in zip(got, ref))
        @test [g.chunk for g in got] == ["c0001", "c0002", "c0003", "c0004"]
        @test all(istaskdone, ow.tasks) && ow.f isa P.NoCheckpointFileWork
        @test allunique(objectid(g.seconds) for g in got)      # task-private timing vectors
    end
    P.FAIL[] = :verify
    ow = P.OrderedWindow(P.NoCheckpointFileWork(args...), items; window = 2, workers = 2, label = "")
    err = try
        P.take_next!(ow); nothing
    catch e
        e
    finally
        P.shutdown_window!(ow)
    end
    P.FAIL[] = :none
    @test err isa ErrorException && err.msg == "injected theory extraction mismatch"
    @test all(istaskdone, ow.tasks)
end

@testset "type shape, ownership, no boxed captures, declared instances compile" begin
    hints = P.no_checkpoint_file_work_hint_types()
    item = P.no_checkpoint_file_item_type()
    @test length(hints) == 2 && all(isconcretetype, hints) && isconcretetype(item)
    for (lm, H0) in ((H.Cascade.IO.LumiMask(1, 10), hints[1]), (nothing, hints[2]))
        args, items = fixture(; lmask = lm)
        unit = P.NoCheckpointFileWork(args...)
        @test typeof(unit) === H0                                     # built from the real option producers
        @test !ismutabletype(typeof(unit))
        @test all(getfield(unit, k) === args[i] for (i, k) in enumerate(fieldnames(typeof(unit))))   # shared refs, no copies
        @test all(typeof(it) === item for it in items)
        @test !any(T -> T === Core.Box, fieldtypes(typeof(unit)))
        # Boxing inside the body is unchanged (the reassigned table is boxed in both; the
        # do-block w stays closure-local because the receiver is named unit).
        boxes(f) = count("Core.Box", sprint(show, code_lowered(f, (item,))))
        @test boxes(unit) <= boxes(P.make_original_work(args...))
        @test !occursin("Core.Box(unit", sprint(show, code_lowered(unit, (item,))))
        @test precompile(Tuple{H0, item})                             # the exact declared instance compiles
    end
    PS = fieldtype(hints[1], :psel)
    for raw in (Dict{String,Any}(), Dict{String,Any}("execution" => Dict{String,Any}("decode_threads" => 1,
            "decode_queue_jobs" => 7, "stream_window_events" => 5, "windowed_selection" => true)))
        @test typeof(C.decode_options(raw)) === fieldtype(PS, :decode)
        @test typeof(C.streaming_selection_options(raw)) === fieldtype(PS, :streaming)
    end
    # decode_threads="auto" would change psel's type; no-checkpoint admission rejects threads != 1.
    @test typeof(C.decode_options(Dict{String,Any}("execution" => Dict{String,Any}("decode_threads" => "auto")))) !== fieldtype(PS, :decode)
    @test fieldtype(fieldtype(hints[1], :pcor), :f) === typeof(P.default_correct)
    @test fieldtype(hints[1], :lmask) === H.Cascade.IO.LumiMask && fieldtype(hints[2], :lmask) === Nothing
end

@testset "declared types == R5 fresh trace closure types (multiset over captures)" begin
    ex = Meta.parse(H.R5_TRACE)
    @test ex.head === :call && ex.args[1] === :precompile
    tt = ex.args[2]
    @test tt.head === :curly && tt.args[1] === :Tuple
    clo, itemex = tt.args[2], tt.args[3]
    @test clo.head === :curly && occursin("#work#_run_no_checkpoints_traced", string(clo.args[1]))
    traced = [Core.eval(H, p) for p in clo.args[2:end]]
    hint = P.no_checkpoint_file_work_hint_types()[1]
    function count_map(v)
        d = Dict{Any,Int}()
        for x in v
            d[x] = get(d, x, 0) + 1
        end
        return d
    end
    @test length(traced) == fieldcount(hint) == 11
    @test count_map(traced) == count_map(collect(fieldtypes(hint)))
    @test Core.eval(H, itemex) === P.no_checkpoint_file_item_type()
    tr = get(ENV, "CASCADE_NCFW_R5_TRACE", "")         # evidence runs: embedded line == trace file
    if !isempty(tr)
        @test any(l -> endswith(l, strip(H.R5_TRACE)), eachline(tr))
    end
end

@testset "generation-only declarations: original three kept, file-work hints added" begin
    text = read(H.src("Pipeline", "precompile_pipeline.jl"), String)
    @test occursin("if ccall(:jl_generating_output, Cint, ()) == 1", text)
    for decl in ("precompile(main, (Vector{String},))",
                 "precompile(run_no_checkpoints, (Config.AnalysisConfig, String, Vector{Config.SampleConfig}, RunOptions))",
                 "precompile(_run_no_checkpoints_traced, (Config.AnalysisConfig, String, Vector{Config.SampleConfig}, RunOptions))")
        @test count(decl, text) == 1
    end
    @test occursin("no_checkpoint_file_work_hint_types()", text) && occursin("precompile(Tuple{W,item})", text)
    @test ccall(:jl_generating_output, Cint, ()) == 0           # declarations never run at ordinary load
    pl = read(H.src("Pipeline", "Pipeline.jl"), String)
    @test occursin("include(\"ordered_window.jl\")\ninclude(\"no_checkpoint_file_work.jl\")\ninclude(\"run_no_checkpoints.jl\")", pl)
    @test findfirst("include(\"no_checkpoint_file_work.jl\")", pl)[1] < findfirst("include(\"precompile_pipeline.jl\")", pl)[1]
end

@testset "exact named stage types, borrowed references and no escaped payload" begin
    hints=P.no_checkpoint_stage_hint_types()
    @test length(hints)==4 && all(isconcretetype,hints) && allunique(hints)
    for (lm,i) in ((H.Cascade.IO.LumiMask(1,10),1),(nothing,2))
        args,items=fixture(;lmask=lm)
        unit=P.NoCheckpointFileWork(args...)
        result,log=runlog(unit,items[1])
        @test !(result isa Exception)
        stages=copy(P.STAGES)
        @test Tuple(typeof.(stages))==(hints[i],hints[3],hints[4])
        select,correct,histogram=stages
        @test select.psel===unit.psel && select.lmask===unit.lmask
        @test select.compiled===unit.compiled && select.plans===unit.plans
        @test correct.table===histogram.table && correct.pcor===unit.pcor
        @test histogram.phist===unit.phist && correct.ctx===histogram.ctx===unit.ctx
        @test histogram.weights isa Tuple{Dict{String,Any},Dict{String,Any},Vector{String}}
        @test correct.table.meta["handoff"]===true
        @test all(!ismutabletype(typeof(stage)) for stage in stages)
        @test all(all(T->T!==Core.Box && isconcretetype(T),fieldtypes(typeof(stage))) for stage in stages)
        @test all(!occursin("Core.Box",sprint(show,code_lowered(stage,()))) for stage in stages)
        @test all(precompile(Tuple{typeof(stage)}) for stage in stages)
        kw=NamedTuple{(:sample,:chunk),Tuple{String,String}}
        @test all(precompile(Core.kwcall,(kw,typeof(P.benchmark_span),typeof(stage),Symbol,String)) for stage in stages)
        # No table/weight/cutflow/callable crosses the existing outer result boundary.
        contains(x,target)=x===target || (x isa NamedTuple || x isa Tuple || x isa AbstractArray ? any(y->contains(y,target),x) :
            x isa AbstractDict ? any(y->contains(y,target),values(x)) : false)
        for payload in (correct.table,histogram.cf,histogram.weights,stages...)
            @test !contains(result,payload)
        end
        boxes(f)=count("Core.Box",sprint(show,code_lowered(f,(P.no_checkpoint_file_item_type(),))))
        @test boxes(unit)<=boxes(P.make_original_work(args...))
        println("BOX_COUNTS baseline=",boxes(P.make_original_work(args...))," candidate=",boxes(unit))
    end
    pre=read(joinpath(@__DIR__,"baseline_precompile_pipeline.jl"),String)
    post=read(H.src("Pipeline","precompile_pipeline.jl"),String)
    start=findfirst("    # Exact zero-argument inner stages",post).start
    stop=findnext("    # Opt-in stable selection kernels:",post,start).start
    @test post[1:start-1]*post[stop:end]==pre # R28 bytes preserved except insertion
    @test occursin("precompile(Core.kwcall, (kw, typeof(benchmark_span), S, Symbol, String))",post)
    @test !occursin("var\"#",post[start:stop-1])
    @test !occursin("Core.eval",read(H.src("Pipeline","no_checkpoint_file_work.jl"),String))
end
