# Named per-file work unit of execution.checkpoints = false (select -> correct -> histogram).
#
# The body of NoCheckpointFileWork's call is the former anonymous `work(item)` closure of
# _run_no_checkpoints_traced, moved unchanged: same callees, arguments, order, guards,
# benchmark spans and returned NamedTuple. Only how captured context is reached differs
# (struct fields instead of closure captures). A named, concretely parameterized callable
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

# Receiver is `unit`, not `w`: the unchanged body assigns `w` inside a do-block, which must stay
# a closure-local (a captured outer `w` would be reassigned/boxed).
function (unit::NoCheckpointFileWork)(item)
    (; cfg, workdir, ctx, psel, pcor, phist, compiled, plans, lmask, has_region_expr, check_overlap) = unit
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
