"""
    step_select(ctx::StepContext) -> Dict

Run the compiled selection on every chunk (input file) of the selected
samples, in parallel. Per chunk: `select/<sample>/<chunk>.cols` (event table)
and its meta file (key, cutflow, event counts). Unchanged chunks are skipped.

MC samples with `[[shape_variations]]` read their columns once and also run
the selection on the varied columns of every label (`<name>Up`/`<name>Down`),
writing `select/<sample>/<chunk>.<label>.cols`; the meta file of the nominal
table lists the labels (`shape`) and their cutflows (`shape_cutflows`). The
shape configuration and correction files enter the key of those samples only.
"""
function step_select(ctx::StepContext)
    validate_reduced_skim(ctx)
    prepared = prepare_select(ctx)
    (; cfg, requested_readers, decode, streaming, decode_enabled, code, dq, chash, shape, shape_code) = prepared
    compiled = Dict{Symbol,Any}()
    plans = Dict{String,Any}()
    lm = nothing
    tasks = Any[]
    nskip = 0
    for s in ctx.samples
        skim = read_skim(ctx.workdir, s.name)
        sv = shape_variations_for(shape, s)
        for f in skim["files"]
            (; key, out) = select_chunk_spec(ctx, prepared, s, f)
            if !ctx.options.force && is_up_to_date(out, key)
                nskip += 1
                continue
            end
            haskey(compiled, s.kind) || (compiled[s.kind] = compile_selection(cfg, s.kind))
            if is_data(s) && lm === nothing
                lm = load_lumimask(dq.golden_json; run_min = dq.run_min, run_max = dq.run_max)
            end
            if !isempty(sv) && !haskey(plans, s.name)
                sel = compiled[s.kind]
                plans[s.name] = shape_plan(sv, vcat(sel.columns_pre, sel.columns_post))
            end
            push!(tasks, (s, String(f["path"]), out, key, Int(get(f["signature"], "size", 0)), f["chunk"]))
        end
    end
    sort!(tasks; by = t -> -t[5])
    total_tasks = length(tasks)
    stream_diagnostics = Dict{String,Any}()
    stream_fallbacks = Dict{String,String}()
    stream_failure = nothing
    range_requested = event_range_selection(cfg)
    range_diagnostics = Dict{String,Any}()
    range_fallbacks = Dict{String,String}()
    range_failure = nothing
    if range_requested
        eligible_tasks = Any[]; ordinary_tasks = Any[]
        for item in tasks
            reason = event_range_selection_fallback(cfg,item[1],get(plans,item[1].name,nothing))
            if isempty(reason)
                push!(eligible_tasks,item)
            else
                range_fallbacks[item[3]] = reason
                push!(ordinary_tasks,item)
            end
        end
        outcome = capture_event_range_failure() do
            run_event_range_selection(eligible_tasks,compiled,lm,cfg,streaming;diagnostics=range_diagnostics)
        end
        range_failure = outcome.failure
        for (item,reason) in outcome.fallbacks
            range_fallbacks[item[3]] = reason
            push!(ordinary_tasks,item)
        end
        tasks = ordinary_tasks
        println("  [select ranges] ",JSON3.write(range_diagnostics)); flush(stdout)
    end
    # A conflicting explicit range request never dispatches the old async path.
    if !range_requested && streaming.enabled && Threads.nthreads() >= 3
        eligible_tasks = Any[]; serial_tasks = Any[]
        for item in tasks
            sample = item[1]
            reason = stream_selection_fallback(cfg, sample, get(plans,sample.name,nothing))
            if isempty(reason)
                push!(eligible_tasks,item)
            else
                stream_fallbacks[item[3]] = reason
                push!(serial_tasks,item)
            end
        end
        outcome = capture_stream_file_failure() do
            run_stream_selection(eligible_tasks,compiled,lm,streaming;diagnostics=stream_diagnostics)
        end
        stream_failure = outcome.failure
        for (item,reason) in outcome.fallbacks
            stream_fallbacks[item[3]] = reason
            push!(serial_tasks,item)
        end
        tasks = serial_tasks
        println("  [select stream] ",JSON3.write(stream_diagnostics));flush(stdout)
    elseif !range_requested && streaming.enabled
        for item in tasks;stream_fallbacks[item[3]]=Threads.nthreads()==1 ? "one_thread" : "stage_thread_budget";end
    end
    budget = column_reader_budget(requested_readers, length(tasks))
    runner = decode_enabled ? run_decode_file_tasks : run_tasks
    finish_event_range_fallbacks(range_failure) do
    finish_stream_selection_fallbacks(stream_failure) do
    runner(tasks; label = "select") do (s, path, out, key, _, chunk)
        execute_select_chunk(ctx, prepared, compiled, plans, lm, (s, path, out, key, 0, chunk);
            budget, file_workers = min(Threads.nthreads(), length(tasks)), stream_fallbacks, range_fallbacks)
        nothing
    end
    end # independent serial fallback attempt, then delayed ordinary stream error
    end # admitted range errors propagate after unrelated pre-read fallbacks
    result = Dict{String,Any}("run" => total_tasks, "skipped" => nskip)
    streaming.enabled && (result["streaming"] = stream_diagnostics)
    range_requested && (result["event_ranges"] = range_diagnostics; result["event_range_fallbacks"] = range_fallbacks)
    return result
end
