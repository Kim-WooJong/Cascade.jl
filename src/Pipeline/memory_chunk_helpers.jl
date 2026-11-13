# Shared by the staged runner and the opt-in file-chain runner.
function prepare_select(ctx)
    cfg = ctx.config
    requested_readers = column_readers(cfg)
    decode = decode_options(cfg)
    streaming = streaming_selection_options(cfg)
    windowed = windowed_selection(cfg)
    # Explicit conflicts fall back to ordinary selection, never old async.
    (windowed || event_range_selection(cfg)) && (streaming = merge(streaming, (enabled=false,)))
    decode_enabled = decode.threads == "auto" || decode.threads > 1
    code = code_hash(["Config", "IO", "Objects", "Selection", "Pipeline"])
    # All shared execution helpers enter selection identity in BOTH modes.
    # One-time invalidation; execution.memory_handoff itself is never hashed.
    dq = cfg.data_quality
    golden = isempty(dq.golden_json) ? "" : bytes2hex(sha256(read(dq.golden_json)))
    hsel = [(h.name, h.values, h.when, h.regions) for h in cfg.histograms]
    chash = section_hash(cfg, "objects", "variables", "cuts", "regions", "weights", "triggers",
                         "data_quality", "output"; extra = Any[golden, hsel])
    shape = shape_variations(cfg)
    shape_code = isempty(shape) ? "" : code_hash(["Corrections", "Systematics/shape"])
    return (; cfg, requested_readers, decode, streaming, windowed, decode_enabled, code, dq, chash, shape, shape_code)
end

function select_chunk_spec(ctx, p, s, f)
    (; chash, code, shape_code) = p
    sv = shape_variations_for(p.shape, s)
    skey = isempty(sv) ? "" : shape_key(sv)
    parts = Any["select", s.name, String(s.kind), s.stream, s.format, get(s.raw, "source", Dict()), f["signature"], chash, code]
    isempty(sv) || append!(parts, Any[skey, shape_code])
    key = artifact_key(parts...)
    out = chunk_path(ctx.workdir, :select, s.name, f["chunk"], ".cols")
    return (; key, out)
end

function execute_select_chunk(ctx, p, compiled, plans, lm, item; budget, file_workers, stream_fallbacks = Dict{String,String}(), range_fallbacks = Dict{String,String}())
    (; cfg, requested_readers, decode, streaming, windowed, decode_enabled) = p
    s, path, out, key, _, chunk = item
    ranges = event_range_selection(cfg)
    results, execution, plan, eligible = select_chunk_results(p, compiled, plans, lm, s, path, out;
        budget, stream_fallbacks, range_fallbacks)
    mkpath(dirname(out))
    if decode_enabled && !eligible
        execution["decode_fallback"] = plan === nothing ? "unsupported_format" : "shape_variations"
    end
    if plan !== nothing
        merge!(execution, Dict("effective_readers" => 1, "fallback" => "shape_variations", "max_active_reads" => 0,
            "extra_opens" => 0, "extra_closes" => 0, "branch_jobs" => 0, "counter_reads" => 0))
    elseif !eligible
        execution["fallback"] = "unsupported_format"
    elseif budget == 1 && requested_readers > 1
        execution["fallback"] = "stage_thread_budget"
    end
    execution["requested_decode_threads"] = decode.threads
    execution["stage_file_workers"] = decode_enabled ? 1 : file_workers
    execution["requested_readers"] = requested_readers
    if get(get(cfg.raw, "execution", Dict()), "streaming_selection", false)
        execution["streaming_selection"] = false
        execution["streaming_fallback"] = ranges ? "event_range_selection_conflict" :
            (windowed ? "windowed_selection_conflict" : get(stream_fallbacks,out,"unsupported_path"))
    end
    extra = Dict{Symbol,Any}(:execution => execution)
    if s.format in ("reduced_rntuple", "reduced_rntuple_group")
        tm = last(results[1])[1].meta
        evidence_keys = s.format == "reduced_rntuple_group" ?
            ("cutflow_population", "original_nevents", "population", "retention_contract", "original_source_signature", "logical_group_id", "logical_descriptor") :
            ("cutflow_population", "original_cutflows", "original_nevents", "population", "retention_contract", "original_source_signature")
        for k in evidence_keys
            extra[Symbol(k)] = tm[k]
        end
    end
    if plan !== nothing
        for (label, (t, _)) in results[2:end]
            write_event_table(shape_chunk_path(ctx.workdir, :select, s.name, chunk, label, ".cols"), t)
        end
        extra[:shape] = [first(r) for r in results[2:end]]
        extra[:shape_cutflows] = Dict(first(r) => cutflow_dict(last(r)[2]) for r in results[2:end])
    end
    table, cf = last(results[1])
    write_event_table(out, table)
    write_meta(out, key; step = "select", sample = s.name, source = path, cutflow = cutflow_dict(cf),
               nevents = table.meta["nevents"], kept = nrows(table), extra...)
    return table
end

"""
    select_chunk_results(p, compiled, plans, lm, s, path, out; budget, ...) -> (results, execution, plan, eligible)

Selection of one source file exactly as the staged route runs it, without any
directory, artifact or metadata write. `out` is only the fallback-map identity.
Shared by `execute_select_chunk` (which then persists) and the no-checkpoint route.
"""
function select_chunk_results(p, compiled, plans, lm, s, path, out; budget, stream_fallbacks = Dict{String,String}(), range_fallbacks = Dict{String,String}())
    (; cfg, requested_readers, decode, streaming, windowed) = p
    ranges = event_range_selection(cfg)
    plan = get(plans, s.name, nothing)
    sel = compiled[s.kind]
    window_reason = ranges ? "event_range_selection_requested" :
        (windowed ? windowed_selection_fallback(cfg, s, plan) : "disabled")
    # Opt-in modern-only decoder: an unsupported request is an explicit error,
    # never a silent ordinary-reader fallback (decided here before any open).
    reusable = windowed && windowed_reusable_decoder(cfg)
    shared_offsets = reusable && Config.reusable_shared_offsets(cfg)
    reuse_buffers = Config.reuse_window_buffers(cfg)
    reuse_accounting = Config.reuse_window_accounting(cfg)
    reusable && !isempty(window_reason) && throw(EventIO.WindowedReusableUnsupported(path, window_reason))
    # ROOT fixed header bounds are checked before open_source metadata decode.
    windowed && isempty(window_reason) && validate_stream_metadata(path, Dict("max_metadata_bytes"=>streaming.stream_metadata_bytes))
    src = open_source(s.format, path; options = get(s.raw, "source", Dict()))
    execution = Dict{String,Any}("requested_readers" => requested_readers, "budget_readers" => budget,
        "windowed_selection"=>false, "windowed_selection_requested"=>windowed,
        "windowed_selection_effective"=>false, "windowed_selection_reason"=>window_reason,
        "event_range_selection_requested"=>ranges, "event_range_selection_effective"=>false,
        "event_range_selection_reason"=>ranges ?
            get(range_fallbacks,out,event_range_selection_fallback(cfg,s,plan)) : "disabled")
    # Keys are added only when requested: the default execution record is unchanged.
    reusable && merge!(execution, Dict{String,Any}("windowed_reusable_decoder_requested"=>true,
        "windowed_reusable_decoder_effective"=>false, "requested_reader_engine"=>"reusable_decoder_window_owned_copy"))
    shared_offsets && (execution["reusable_shared_offsets_requested"] = true)
    eligible = plan === nothing && s.format == "nanoaod"
    results = try
        lmask = is_data(s) ? lm : nothing
        window_result = nothing
        if windowed && isempty(window_reason)
            window_result, window_reason = reusable ?
                run_reusable_windowed_selection(sel, src, s, streaming; lumimask=lmask,
                    object_collections=[o.name => o.collection for o in cfg.objects], execution_diagnostics=execution,
                    shared_offsets, reuse_buffers, reuse_accounting) :
                run_windowed_selection(sel, src, s, streaming; lumimask=lmask,
                    object_collections=[o.name => o.collection for o in cfg.objects], execution_diagnostics=execution)
            execution["windowed_selection_reason"] = window_reason
            reusable && window_result === nothing && throw(EventIO.WindowedReusableUnsupported(path, window_reason))
        end
        rs = if window_result !== nothing
            ["nominal" => window_result]
        elseif plan === nothing
            ["nominal" => run_selection(sel, src; stream = s.stream, lumimask = lmask, sample = s.name,
                column_readers = eligible ? budget : 1, decode_threads = eligible ? decode.threads : 1,
                decode_queue_jobs = decode.jobs, decode_queue_bytes = decode.bytes, execution_diagnostics = execution)]
        else
            run_selection_variations(sel, src, (raw, needed) -> shape_columns(plan, raw, needed);
                                     inputs = plan.inputs, replaces = plan.replaces, stream = s.stream,
                                     lumimask = lmask, sample = s.name)
        end
        attach_reduced_provenance!(rs, src)
    finally
        close_source(src)
    end
    return results, execution, plan, eligible
end

function prepare_correct(ctx)
    cfg = ctx.config
    f, id = hook_for(cfg, :correct)
    code = code_hash(["IO", "Selection", "Corrections", "Systematics", "Pipeline"])
    chash = section_hash(cfg, "corrections", "weights", "theory_weights")
    files = correction_files_key(cfg)
    manifests = Dict(s.name => theory_extraction(cfg; samples = [s]) for s in ctx.samples)
    manifest_hashes = Dict(name => canonical_hash(m) for (name, m) in manifests)
    return (; cfg, f, id, code, chash, files, manifests, manifest_hashes)
end

function correct_chunk_spec(ctx, p, s, e, m)
    (; chash, files, id, code) = p
    sel = chunk_path(ctx.workdir, :select, s.name, e["chunk"], ".cols")
    key = artifact_key("correct", m["key"], chash, p.manifest_hashes[s.name], files, id, code)
    out = chunk_path(ctx.workdir, :correct, s.name, e["chunk"], ".cols")
    return (; sel, key, out)
end

# persist=false (no-checkpoint route only): nominal-only in-memory table, nothing written.
function execute_correct_chunk(ctx, p, item; table = nothing, persist::Bool = true)
    (; cfg, f, id) = p
    s, path, sel, out, key, chunk, labels = item
    persist || (isempty(labels) && table !== nothing) ||
        throw(ArgumentError("in-memory correction requires a nominal-only in-memory event table"))
    return with_correction_source(f, s, path) do source
        for label in labels
            t = read_event_table(shape_chunk_path(ctx.workdir, :select, s.name, chunk, label, ".cols"))
            w = _correct_weights(f, CorrectionContext(cfg, s, path, t, label, source), nrows(t))
            write_column_file(shape_chunk_path(ctx.workdir, :correct, s.name, chunk, label, ".cols"),
                              Dict{String,Any}(NOMINAL => Vector{Float64}(w[NOMINAL])); order = [NOMINAL],
                              meta = Dict("sample" => s.name, "variation" => label))
        end
        table === nothing && (table = read_event_table(sel))
        w = _correct_weights(f, CorrectionContext(cfg, s, path, table, NOMINAL, source), nrows(table))
        w = Systematics.theory_member_weights(cfg, s, path, table, w; source)
        order = vcat(NOMINAL, sort!([k for k in keys(w) if k != NOMINAL]))
        meta=Dict{String,Any}("sample"=>s.name)
        manifest=p.manifests[s.name]
        isempty(manifest) || (meta["theory_extraction"]=manifest)
        validate_theory_manifest(manifest,[(s.name,label) for label in order])
        columns = Dict{String,Any}(k => Vector{Float64}(v) for (k, v) in w)
        # Validate converted payloads too; this exact dictionary is handed onward.
        for (label, values) in columns
            length(values) == nrows(table) || error("converted weight length mismatch: $label")
        end
        if persist
            write_column_file(out, columns; order, meta)
            write_meta(out, key; step = "correct", sample = s.name, hook = id)
        end
        return columns, meta, order
    end
end

function prepare_histogram(ctx)
    cfg = ctx.config
    code = code_hash(["Histograms", "Pipeline"])
    chash = section_hash(cfg, "histograms", "regions")
    return (; cfg, code, chash)
end

function histogram_chunk_spec(ctx, p, s, e, ms, mc)
    (; chash, code) = p
    key = artifact_key("histogram", ms["key"], mc["key"], chash, code)
    out = chunk_path(ctx.workdir, :histogram, s.name, e["chunk"], ".json")
    return (; key, out)
end

# persist=false (no-checkpoint route only): returns the filled store, nothing written.
function execute_histogram_chunk(ctx, p, item; table = nothing, weights = nothing, persist::Bool = true)
    cfg = p.cfg
    s, sel, cor, out, key, chunk, labels = item
    persist || (isempty(labels) && table !== nothing && weights !== nothing) ||
        throw(ArgumentError("in-memory histogram filling requires nominal-only in-memory table and weights"))
    table === nothing && (table = read_event_table(sel))
    wcols, cmeta, worder = weights === nothing ? read_column_file(cor) : weights
    manifest=get(cmeta,"theory_extraction",Dict{String,Any}())
    validate_theory_manifest(manifest,[(s.name,label) for label in worder])
    regions, values = _fill_inputs(cfg, table)
    weights = [k => wcols[k] for k in worder]
    store = fill_store!(HistogramStore(), s.name, cfg.histograms, values, regions, weights)
    isempty(manifest) || (store.meta["theory_extraction"]=deepcopy(manifest))
    for label in labels
        label in worder && error("shape variation label '$label' is also a weight variation of $(s.name)")
        t = read_event_table(shape_chunk_path(ctx.workdir, :select, s.name, chunk, label, ".cols"))
        wl, _, _ = read_column_file(shape_chunk_path(ctx.workdir, :correct, s.name, chunk, label, ".cols"))
        rl, vl = _fill_inputs(cfg, t)
        fill_store!(store, s.name, cfg.histograms, vl, rl, [label => wl[NOMINAL]])
    end
    Systematics.verify_theory_extraction(cfg,store)
    persist || return store
    write_store(out, store)
    write_meta(out, key; step = "histogram", sample = s.name)
    return nothing
end
