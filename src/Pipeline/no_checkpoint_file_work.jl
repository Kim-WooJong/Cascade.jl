# Named per-file work unit of execution.checkpoints = false (select -> correct -> histogram).
#
# NoCheckpointFileWork's call retains the former anonymous `work(item)` closure of
# _run_no_checkpoints_traced body: same callees, arguments, order, guards,
# benchmark spans and returned NamedTuple. Its three inner do-block bodies are
# verbatim in named immutable stage callables below (fields instead of captures).
# A named, concretely parameterized callable
# lets the generation-only declarations in precompile_pipeline.jl name the exact method
# instance that OrderedWindow reaches by dynamic dispatch on its Any-typed `f`/items.
#
# Ownership: fields are the SAME read-only plan references the closure captured (config,
# workdir, step context, prepared select/correct/histogram plans, compiled selections,
# shape plans, lumimask, two Bool flags). Every mutable payload (tables, cutflows, weights,
# stores, timing vector) is created inside one call and owned by the calling worker task;
# only the returned NamedTuple crosses to the merge consumer.

"""
    NoCheckpointFileWork(cfg, workdir, ctx, psel, pcor, phist, compiled, plans, lmask,
                         has_region_expr, check_overlap)

Immutable callable for one no-checkpoint file work unit; `work((s, e))` runs
select -> correct -> histogram for sample `s` and skim file entry `e` and returns
`(; sample, chunk, store, meta, counts, provenance, seconds)`.
"""
struct NoCheckpointFileWork{W,PS,PC,PH,L}
    cfg::Config.AnalysisConfig
    workdir::W
    ctx::StepContext
    psel::PS
    pcor::PC
    phist::PH
    compiled::Dict{Symbol,Any}
    plans::Dict{String,Any}
    lmask::L
    has_region_expr::Bool
    check_overlap::Bool
end

# Immutable zero-argument stage callables. Each holds exactly the references the
# former do-block captured; mutable payloads remain owned by this file task and
# the span retains no callable after returning. No runtime method generation.
struct NoCheckpointSelectStage{PS,L}
    psel::PS
    compiled::Dict{Symbol,Any}
    plans::Dict{String,Any}
    lmask::L
    s::Config.SampleConfig
    path::String
end
function (stage::NoCheckpointSelectStage)()
    (; psel, compiled, plans, lmask, s, path) = stage
    select_chunk_results(psel, compiled, plans, lmask, s, path, ""; budget = 1)
end

struct NoCheckpointCorrectStage{PC,K,T}
    cfg::Config.AnalysisConfig
    ctx::StepContext
    pcor::PC
    s::Config.SampleConfig
    path::String
    chunk::K
    table::T
end
function (stage::NoCheckpointCorrectStage)()
    (; cfg, ctx, pcor, s, path, chunk, table) = stage
    w = execute_correct_chunk(ctx, pcor, (s, path, "", "", "", chunk, String[]); table, persist = false)
    verify_correct_extraction(cfg, s, w[2], w[3]; expected = pcor.manifests[s.name])
    w
end

struct NoCheckpointHistogramStage{PH,K,T,CF,W}
    cfg::Config.AnalysisConfig
    ctx::StepContext
    phist::PH
    s::Config.SampleConfig
    chunk::K
    table::T
    cf::CF
    weights::W
    has_region_expr::Bool
    check_overlap::Bool
end
function (stage::NoCheckpointHistogramStage)()
    (; cfg, ctx, phist, s, chunk, table, cf, weights, has_region_expr, check_overlap) = stage
    local transported, meta, counts, chunk_provenance
    store = execute_histogram_chunk(ctx, phist, (s, "", "", "", "", chunk, String[]); table, weights, persist = false)
    counts = has_region_expr ? region_counts(table) : nothing
    chunk_provenance = check_overlap && is_data(s) ? Fit.channel_overlap_provenance(table, cfg) : nothing
    meta = _json_transport(Dict{String,Any}("cutflow" => cutflow_dict(cf)))
    transported = Histograms.transport_store(store)
    (transported, meta, counts, chunk_provenance)
end

# The correction stage owns its local w; table/weights are immutable callable
# fields, not captured reassigned outer locals (no Core.Box is introduced).
function (unit::NoCheckpointFileWork)(item)
    (; cfg, workdir, ctx, psel, pcor, phist, compiled, plans, lmask, has_region_expr, check_overlap) = unit
    s, e = item
    path = String(e["path"])
    chunk = e["chunk"]
    seconds = zeros(Float64, 3)
    t1 = time()
    results, _, plan, _ = benchmark_span(NoCheckpointSelectStage(psel, compiled, plans, lmask, s, path),
        :select, workdir; sample = s.name, chunk)
    (plan === nothing && length(results) == 1) || error("internal no-checkpoint error: unexpected shape results")
    table, cf = last(results[1])
    table = handoff_table_metadata(table)
    t2 = time(); seconds[1] = t2 - t1
    weights = benchmark_span(NoCheckpointCorrectStage(cfg, ctx, pcor, s, path, chunk, table),
        :correct, workdir; sample = s.name, chunk)
    t3 = time(); seconds[2] = t3 - t2
    transported, meta, counts, chunk_provenance = benchmark_span(
        NoCheckpointHistogramStage(cfg, ctx, phist, s, chunk, table, cf, weights, has_region_expr, check_overlap),
        :histogram, workdir; sample = s.name, chunk)
    seconds[3] = time() - t3
    return (; sample = s.name, chunk = String(chunk), store = transported, meta, counts,
            provenance = chunk_provenance, seconds)
end

"""
    no_checkpoint_file_item_type() -> Type

Concrete runtime type of one OrderedWindow item of the no-checkpoint route:
`(s, e)` with `s::SampleConfig` and `e` a skim file entry after `_json_transport`
(`_jsdict` of a JSON object is always `Dict{String,Any}`).
"""
no_checkpoint_file_item_type() = Tuple{Config.SampleConfig,Dict{String,Any}}

"""
    no_checkpoint_file_work_hint_types() -> Tuple of concrete NoCheckpointFileWork types

The exact work types declared to the package image (generation-only, see
precompile_pipeline.jl). Derived from the R5 fresh-run trace of the former closure
(`#work#_run_no_checkpoints_traced##12{AnalysisConfig, String, Bool, Bool,
Dict{String,Any}, LumiMask, Dict{Symbol,Any}, <phist>, <pcor>, <psel>, StepContext}`):
- workdir `String` (RunOptions.workdir/CLI path);
- psel = prepare_select(ctx): admission requires decode_options(cfg).threads == 1, so
  `decode` is `(threads::Int, jobs::Int, bytes::Int)`; `streaming` is
  streaming_selection_options' `(enabled::Bool, 8 x Int)`; shape is
  `Vector{ShapeVariationConfig}`;
- pcor = prepare_correct(ctx) with the built-in default_correct hook (the R5 hook);
  Systematics.apply_corrections or a non-String hook id is NOT declared and keeps
  runtime compilation;
- phist = prepare_histogram(ctx);
- lmask `LumiMask` (any data sample, R5) and `Nothing` (MC-only plans).
A run whose actual type differs is still correct; it only compiles at runtime.
"""
function no_checkpoint_file_work_hint_types()
    AC = Config.AnalysisConfig
    decode = NamedTuple{(:threads, :jobs, :bytes),Tuple{Int64,Int64,Int64}}
    streaming = NamedTuple{(:enabled, :stream_window_events, :stream_active_files, :stream_queue_windows,
        :stream_queue_bytes, :stream_window_bytes, :stream_basket_bytes, :stream_metadata_bytes,
        :stream_retained_bytes),Tuple{Bool,Int64,Int64,Int64,Int64,Int64,Int64,Int64,Int64}}
    psel = NamedTuple{(:cfg, :requested_readers, :decode, :streaming, :windowed, :decode_enabled, :code, :dq,
        :chash, :shape, :shape_code),Tuple{AC,Int64,decode,streaming,Bool,Bool,String,Config.DataQualityConfig,
        String,Vector{Config.ShapeVariationConfig},String}}
    pcor = NamedTuple{(:cfg, :f, :id, :code, :chash, :files, :manifests, :manifest_hashes),
        Tuple{AC,typeof(default_correct),String,String,String,String,Dict{String,Dict{String,Any}},Dict{String,String}}}
    phist = NamedTuple{(:cfg, :code, :chash),Tuple{AC,String,String}}
    return (NoCheckpointFileWork{String,psel,pcor,phist,EventIO.LumiMask},
            NoCheckpointFileWork{String,psel,pcor,phist,Nothing})
end

"""
    no_checkpoint_stage_hint_types() -> Tuple of concrete zero-argument stage types

Generation-only signatures derived from the same prepared-plan fields as the
outer file-work hints. The payload types are the production EventTable/Cutflow
and execute_correct_chunk's exact in-memory return (Dict columns, Dict metadata,
Vector{String} order). No payloads are constructed or kernels invoked here.
The two select types retain LumiMask/Nothing coverage; correction/histogram
signatures shared by those work types are declared once. Different runtime
payload/plan types stay correct and compile normally, without fallback/retry.
"""
function no_checkpoint_stage_hint_types()
    hints = no_checkpoint_file_work_hint_types()
    select = map(W -> NoCheckpointSelectStage{fieldtype(W, :psel),fieldtype(W, :lmask)}, hints)
    W = first(hints)
    weights = Tuple{Dict{String,Any},Dict{String,Any},Vector{String}}
    return (select...,
        NoCheckpointCorrectStage{fieldtype(W, :pcor),String,Selection.EventTable},
        NoCheckpointHistogramStage{fieldtype(W, :phist),String,Selection.EventTable,Selection.Cutflow,weights})
end
