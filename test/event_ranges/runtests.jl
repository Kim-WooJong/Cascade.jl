# Standalone stdlib-only harness. Physical ROOT IO is deliberately stubbed.
using Test
module EventRangeHarness
using Test
const ROOT = normpath(joinpath(@__DIR__,"../.."))
src(parts...) = joinpath(ROOT,"src",parts...)
struct AnalysisConfig
    raw::Dict{String,Any}
    variations::Vector{Any}
end
AnalysisConfig(raw) = AnalysisConfig(Dict{String,Any}(raw),Any[])
for file in ("event_ranges","memory_handoff","column_readers","decode_options")
    include(src("Config",file*".jl"))
end
module EventIO
# Reuse the real supervised worker lifecycle, no replacement scheduler.
struct NanoAODSource end
include(joinpath(@__DIR__,"../../src/IO/DecodePipeline.jl"))
include(joinpath(@__DIR__,"../../src/IO/decode_worker_loop.jl"))
end
include(src("Selection","Cutflow.jl"))
include(src("Selection","EventTable.jl"))
include(src("Selection","region_masks.jl"))
include(src("Selection","region_counts.jl"))
const HOOKS = Dict{Symbol,Any}()
builtin_source_readers() = true
shape_variations(cfg) = get(cfg.raw,"shape_variations",Any[])
theory_weights(cfg) = get(cfg.raw,"theory_weights",Any[])
include(src("Pipeline","run_window_pipeline.jl"))
include(src("Pipeline","stream_selection.jl"))
include(src("Pipeline","run_event_range_pool.jl"))
include(src("Pipeline","event_range_selection.jl"))

const OPTIONS = (stream_active_files=3,stream_queue_windows=3,stream_queue_bytes=100_000,
    stream_metadata_bytes=100,stream_retained_bytes=100_000)
const SEL = (cut_names=["keep"],keep_stage=1)
function result(range,allweights,allstages)
    weights = copy(allweights[range]); stages = copy(allstages[range])
    keep = findall(>=(1),stages)
    table = EventTable(Dict{String,Vector}("entry"=>Int64.(keep),"stage"=>Int16.(stages[keep]),
        "weight"=>weights[keep],"value"=>Float64.(collect(range)[keep])),
        ["entry","stage","weight","value"],Dict{String,Any}(
            "sample"=>"fixture","kind"=>"mc","nevents"=>length(range),
            "cut_names"=>["keep"],"region_stage"=>Dict("kept"=>1),
            "region_columns"=>Dict{String,String}(),"hist_columns"=>Dict(),"cutflow"=>Dict()))
    EventRangeResult(table,range,stages,weights,Dict{String,Any}())
end
function fixture(;ranges=[1:1,2:3,4:5],weights=[1e16,1.,-1e16,3.,-2.],stages=[1,0,1,1,0])
    (ranges=ranges,weights=weights,stages=stages)
end
function exercise(items;workers=1,options=OPTIONS,fail=nothing,cancel=false,publishfail=false,
        hook=(stage,k)->nothing,spawn=(stage,k,t)->nothing,controller=(stage,value)->nothing)
    lockstate = ReentrantLock(); opened = Ref(0); closed = Ref(0)
    active = Ref(0); maxactive = Ref(0); completed = Any[]; contexts = Any[]
    originals = Ref(0); originalcloses = Ref(0); published = Dict{Int,Any}(); diag = Dict{String,Any}()
    opener = item -> begin
        item === :fallback && return "unsupported_fixture"
        originals[] += 1
        id,fixture = item
        (id=id,fixture=fixture,windows=fixture.ranges,charges=fill(1000,length(fixture.ranges)),
            retained_charges=fill(1000,length(fixture.ranges)),analysis=StreamSelectionAnalysis(SEL,"fixture"),
            diagnostics=Dict{String,Any}())
    end
    rangeopener = (data,k) -> begin
        opened[] += 1
        # Every job receives fresh mutable state; compiled metadata only is shared.
        context = (data=data,k=k,current=Ref(0),memo=Float64[],closed=Ref(false))
        push!(contexts,context)
        context
    end
    analyzer = (context,k) -> begin
        lock(lockstate) do
            active[] += 1; maxactive[] = max(maxactive[],active[])
        end
        try
            # Deliberately scramble completion within one source.
            sleep(k==1 ? 0.035 : 0.001)
            context.current[] = k; push!(context.memo,Float64(k))
            fail == (context.data.id,k) && error("injected range failure")
            cancel && throw(InterruptException())
            lock(lockstate) do; push!(completed,(context.data.id,k)); end
            f = context.data.fixture
            result(f.ranges[k],f.weights,f.stages)
        finally
            lock(lockstate) do; active[] -= 1; end
        end
    end
    publisher = data -> begin
        publishfail && error("injected publisher failure")
        published[data.id] = finish_stream_selection!(data.analysis,length(data.fixture.weights);validate=true)
    end
    closer = data -> (originalcloses[] += 1)
    rangecloser = context -> begin
        lock(lockstate) do
            context.closed[] && error("double context close")
            context.closed[] = true; closed[] += 1
        end
    end
    failure = nothing; fallback = Any[]
    try
        fallback = run_event_range_pool(items,opener,rangeopener,analyzer,merge_event_range!,publisher,
            closer,rangecloser;options,diagnostics=diag,workers,worker_hook=hook,spawn_hook=spawn,controller_hook=controller)
    catch e
        failure = e
    end
    @test opened[] == closed[]
    @test originals[] == originalcloses[]
    @test all(c->c.closed[],contexts)
    @test length(unique(objectid(c.current) for c in contexts)) == length(contexts)
    @test length(unique(objectid(c.memo) for c in contexts)) == length(contexts)
    @test active[] == 0
    @test diag["workers_joined"]
    @test diag["active_workers_final"] == 0
    @test diag["live_windows_final"] == diag["live_bytes_final"] == diag["retained_bytes_final"] == 0
    @test diag["credits_reserved"] == diag["credits_released"]
    @test maxactive[] <= workers
    @test diag["created_workers"] <= workers
    @test get(diag,"queue_windows_highwater",0) <= min(workers,options.stream_queue_windows)
    @test get(diag,"queue_bytes_highwater",0) <= options.stream_queue_bytes
    @test get(diag,"retained_bytes_highwater",0) <= options.stream_retained_bytes
    return (;published,failure,fallback,diag,completed,contexts)
end

@testset "strict opt-in and pre-read conflicts" begin
    @test !event_range_selection(Dict())
    @test event_range_selection(Dict("execution"=>Dict("event_range_selection"=>true)))
    for bad in (1,0,nothing,"true",1.0)
        @test_throws ArgumentError event_range_selection(Dict("execution"=>Dict("event_range_selection"=>bad)))
    end
    for (setting,reason) in (("memory_handoff","memory_handoff_enabled"),("streaming_selection","streaming_selection_enabled"))
        cfg = AnalysisConfig(Dict("execution"=>Dict(setting=>true)))
        @test event_range_selection_fallback(cfg,(format="nanoaod",),nothing) == reason
    end
    if Threads.nthreads() > 1
        for (setting,value,reason) in (("decode_threads",2,"decode_threads_not_one"),
            ("column_readers",2,"column_readers_not_one"))
            cfg = AnalysisConfig(Dict("execution"=>Dict(setting=>value)))
            @test event_range_selection_fallback(cfg,(format="nanoaod",),nothing)==reason
        end
        cfg = AnalysisConfig(Dict())
        @test event_range_selection_fallback(cfg,(format="cols",),nothing)=="unsupported_format"
        @test event_range_selection_fallback(cfg,(format="nanoaod",),:shape)=="shape_variations"
        push!(HOOKS,:correct=>nothing)
        @test event_range_selection_fallback(cfg,(format="nanoaod",),nothing)=="custom_hooks"
        empty!(HOOKS)
    end
end
@testset "exact ordered all-event ledger including rejected cancellation weights" begin
    a = exercise([(1,fixture())];workers=1)
    @test a.failure === nothing
    reference = a.published[1]
    @test reference["entry"] == [1,3,4]
    @test reference.meta["cutflow"]["n"] == [5,3]
    @test reference.meta["cutflow"]["sumw"][1] == 1.0
    expected=Cutflow(["all","keep"])
    f=fixture()
    for i in eachindex(f.weights)
        record!(expected,f.stages[i],f.weights[i])
    end
    @test reinterpret(UInt64,reference.meta["cutflow"]["sumw"])==reinterpret(UInt64,expected.sumw)
    @test reinterpret(UInt64,reference.meta["cutflow"]["sumw2"])==reinterpret(UInt64,expected.sumw2)
    # Reject subtotal reduction as a valid implementation: its rounding differs.
    grouped=sum(f.weights[1:2])+sum(f.weights[3:5])
    @test grouped != expected.sumw[1]
    for workers in unique([1,min(2,Threads.nthreads())])
        b = exercise([(1,fixture())];workers)
        @test b.failure === nothing
        table = b.published[1]
        @test isequal(table.meta,reference.meta)
        @test table.order == reference.order
        @test all(reinterpret(UInt8,table[k])==reinterpret(UInt8,reference[k]) for k in table.order)
        if workers==2
            @test first(b.completed)==(1,2)
        end
    end
end
@testset "global bounds, empty/single and multiple sources" begin
    for f in (fixture(ranges=[1:5]),fixture(ranges=[1:0],weights=Float64[],stages=Int[]))
        out = exercise([(1,f)];workers=min(2,Threads.nthreads()))
        @test out.failure === nothing
        @test length(out.published)==1
    end
    out = exercise(Any[];workers=1)
    @test isempty(out.published) && out.failure === nothing
    out = exercise([(i,fixture()) for i in 1:8];workers=min(2,Threads.nthreads()))
    @test out.failure === nothing
    @test length(out.published)==8
    @test out.diag["active_files_highwater"] <= OPTIONS.stream_active_files
end
@testset "no partial file publication; unrelated checkpoints survive" begin
    out = exercise(Any[(1,fixture()),(2,fixture()),:fallback];workers=min(2,Threads.nthreads()),fail=(1,2))
    @test out.failure isa EventRangeFileError
    @test !haskey(out.published,1) && haskey(out.published,2)
    @test out.failure.fallbacks == Any[(:fallback,"unsupported_fixture")]
    out = exercise([(1,fixture())];publishfail=true)
    @test out.failure isa EventRangeFileError
    @test isempty(out.published)
    out = exercise([(1,fixture())];cancel=true,workers=min(2,Threads.nthreads()))
    @test out.failure isa InterruptException
    @test isempty(out.published)
end
@testset "whole-file retained credits prevent two-file fragmentation" begin
    # Previously 2 x 1000/file filled 4000 while neither 3-window file could
    # finish. Admit one entire 3000-byte file, defer the other, then complete it.
    for workers in unique([1,min(2,Threads.nthreads())])
        out = exercise([(1,fixture()),(2,fixture())];workers,
            options=merge(OPTIONS,(stream_retained_bytes=4000,)))
        @test out.failure === nothing
        @test sort!(collect(keys(out.published))) == [1,2]
        @test out.diag["retained_bytes_highwater"] == 3000
        @test [c.data.id for c in out.contexts] == [1,1,1,2,2,2]
    end
    # Each range fits but the complete 3000-byte file genuinely does not.
    out = exercise([(1,fixture())];options=merge(OPTIONS,(stream_retained_bytes=2999,)))
    @test out.failure isa EventRangeFileError
    @test isempty(out.contexts) && isempty(out.published)
    @test event_range_retained_reservation([1000,1000,1000],4000) == 3000
    @test_throws ErrorException event_range_retained_reservation([1000,1000,1000],2999)
    @test_throws OverflowError event_range_retained_reservation([typemax(Int128),Int128(1)],typemax(Int128))
end

@testset "memory refusal and lifecycle-fatal cleanup" begin
    # Admission refuses before oversized output/raw can be materialized.
    out = exercise([(1,fixture())];options=merge(OPTIONS,(stream_retained_bytes=999,)))
    @test out.failure isa EventRangeFileError
    @test isempty(out.contexts)
    out = exercise([(1,fixture())];options=merge(OPTIONS,(stream_queue_bytes=1200,)))
    @test out.failure !== nothing
    @test isempty(out.contexts)
    out = exercise([(1,fixture())];hook=(stage,k)->(stage==:before_decode && error("worker fatal")))
    @test out.failure isa EventIO.DecodeWorkerError
    out = exercise([(1,fixture())];spawn=(stage,k,t)->(stage==:before_start && error("startup fatal")))
    @test out.failure !== nothing
    out = exercise([(1,fixture())];workers=min(2,Threads.nthreads()),
        controller=(stage,value)->(stage==:after_admit && throw(InterruptException())))
    @test out.failure isa InterruptException
    @test isempty(out.published)
end
include("remediation.jl")
end # module

include("selection.jl")
