"""Whole-chain eligibility, checked before any chain artifact writes."""
function memory_handoff_fallback(ctx, steps)
    chain = [:select, :correct, :histogram]
    indices = findall(s -> s in chain, steps)
    length(indices) == 3 && steps[indices] == chain && indices == collect(first(indices):last(indices)) ||
        return "requires exactly one contiguous select/correct/histogram segment"
    ctx.input_scope === nothing || return "input_scope is active"
    cfg = ctx.config
    column_readers(cfg) == 1 || return "column_readers must be 1"
    decode_options(cfg).threads == 1 || return "decode_threads must be 1"
    !streaming_selection_options(cfg).enabled || return "streaming_selection is enabled"
    all(s -> s.format == "nanoaod", ctx.samples) || return "all samples must be nanoaod"
    builtin_source_readers() || return "source reader identities are replaced"
    f, _ = hook_for(cfg, :correct)
    (f === default_correct || f === Systematics.apply_corrections) || return "custom correction hook"
    shape = shape_variations(cfg)
    all(s -> isempty(shape_variations_for(shape, s)), ctx.samples) || return "active sample shape variations"
    isempty(theory_weights(cfg)) || return "active theory weights (initial conservative exclusion)"
    return ""
end

# Match read_event_table's JSON metadata semantics without copying any columns.
function handoff_table_metadata(table)
    meta = EventIO._plain(JSON3.read(JSON3.write(table.meta)))
    empty!(table.meta)
    merge!(table.meta, meta)
    return table
end

function run_memory_handoff(ctx)
    started = time()
    validate_reduced_skim(ctx)
    psel = prepare_select(ctx)
    pcor = prepare_correct(ctx)
    phist = prepare_histogram(ctx)
    tasks = Any[]
    compiled = Dict{Symbol,Any}()
    lm = nothing
    for s in ctx.samples
        for e in read_skim(ctx.workdir, s.name)["files"]
            spec = select_chunk_spec(ctx, psel, s, e)
            if ctx.options.force || !is_up_to_date(spec.out, spec.key)
                haskey(compiled, s.kind) || (compiled[s.kind] = compile_selection(ctx.config, s.kind))
                if is_data(s) && lm === nothing
                    dq = psel.dq
                    lm = load_lumimask(dq.golden_json; run_min = dq.run_min, run_max = dq.run_max)
                end
            end
            push!(tasks, (s, e, spec))
        end
    end
    sort!(tasks; by = item -> -Int(get(item[2]["signature"], "size", 0)))
    workers = min(Threads.nthreads(), length(tasks))
    # Public cache reset once, never per worker or per file.
    isempty(tasks) || reset_correction_cache!()
    plans = Dict{String,Any}()
    rows = run_tasks(tasks; label = "memory handoff") do (s, e, ss)
        # Only these invocation-local references own payloads; results are small.
        table = nothing
        weights = nothing
        ran = zeros(Int, 3)
        seconds = zeros(Float64, 3)
        table_handoffs = 0
        weight_handoffs = 0
        table_loads = 0
        weight_loads = 0
        path = String(e["path"])
        chunk = e["chunk"]
        t = time()
        if ctx.options.force || !is_up_to_date(ss.out, ss.key)
            table = execute_select_chunk(ctx, psel, compiled, plans, lm,
                (s, path, ss.out, ss.key, 0, chunk); budget = 1, file_workers = workers)
            table = handoff_table_metadata(table)
            ran[1] = 1
        end
        ms = require_artifact(ss.out, "select")
        labels = String.(get(ms, "shape", String[]))
        isempty(labels) || error("unexpected persisted shape labels in memory handoff")
        seconds[1] = time() - t
        t = time()
        cs = correct_chunk_spec(ctx, pcor, s, e, ms)
        fresh_weights = false
        if ctx.options.force || !is_up_to_date(cs.out, cs.key)
            if table === nothing
                table = read_event_table(ss.out)
                table_loads += 1
            else
                table_handoffs += 1
            end
            weights = execute_correct_chunk(ctx, pcor, (s, path, ss.out, cs.out, cs.key, chunk, labels); table)
            fresh_weights = true
            ran[2] = 1
        else
            # Saved weights and saved manifest, never recomputed or relabelled.
            weights = read_column_file(cs.out)
            weight_loads += 1
        end
        mc = require_artifact(cs.out, "correct")
        verify_correct_extraction(ctx.config, s, weights[2], weights[3]; expected = pcor.manifests[s.name])
        seconds[2] = time() - t
        t = time()
        hs = histogram_chunk_spec(ctx, phist, s, e, ms, mc)
        if !ctx.options.force && is_up_to_date(hs.out, hs.key)
            Systematics.verify_theory_extraction(ctx.config, read_store(hs.out))
        else
            if table === nothing
                table = read_event_table(ss.out)
                table_loads += 1
            else
                table_handoffs += 1
            end
            fresh_weights && (weight_handoffs += 1)
            execute_histogram_chunk(ctx, phist, (s, ss.out, cs.out, hs.out, hs.key, chunk, labels); table, weights)
            ran[3] = 1
        end
        seconds[3] = time() - t
        return (; ran, seconds, table_handoffs, weight_handoffs, table_loads, weight_loads)
    end
    wall = time() - started
    stages = Dict{Symbol,Any}()
    for (i, step) in enumerate((:select, :correct, :histogram))
        nrun = sum((r.ran[i] for r in rows); init = 0)
        stages[step] = Dict{String,Any}("run" => nrun, "skipped" => length(tasks) - nrun,
            "phase_worker_seconds" => sum((r.seconds[i] for r in rows); init = 0.0),
            "timing_kind" => "phase_worker_sum_not_stage_wall")
    end
    diagnostics = Dict{String,Any}("enabled" => true, "effective" => true, "fallback_reason" => "",
        "file_workers" => workers, "chain_wall_seconds" => wall,
        "timing_kind" => "chain_wall_and_overlapping_phase_worker_sums",
        "table_handoffs" => sum((r.table_handoffs for r in rows); init = 0),
        "weight_handoffs" => sum((r.weight_handoffs for r in rows); init = 0),
        "payloadloads" => Dict("table" => sum((r.table_loads for r in rows); init = 0),
            "weights" => sum((r.weight_loads for r in rows); init = 0)))
    return stages, diagnostics
end
