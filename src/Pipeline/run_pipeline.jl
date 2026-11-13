"""
    run_pipeline(opts::RunOptions) -> Dict{Symbol,Any}

Load the analysis, then run the planned steps in order on the selected samples.
Steps whose artifact keys are unchanged are skipped unless `opts.force`.
With `execution.checkpoints = false` the plan is checked before any data work or
write and then runs as one fresh in-memory chain (`run_no_checkpoints`).
"""
function run_pipeline(opts::RunOptions)
    cfg = load_analysis(opts.config; profile = opts.profile)
    require_counting_ready(cfg)
    workdir = abspath(isempty(opts.workdir) ? cfg.workdir : opts.workdir)
    samples = isempty(opts.samples) ? cfg.samples : [sample_by_name(cfg, n) for n in opts.samples]
    checkpoints = checkpoints_enabled(cfg)
    if !checkpoints
        reasons = no_checkpoints_unsupported(cfg, samples, opts.steps)
        isempty(reasons) || throw(no_checkpoints_error(reasons))
    end
    validate_reduced_inputs(cfg, samples; max_files = opts.max_files, verify_payloads = false)
    println("cascade: analysis ", cfg.name, ", workdir ", workdir, ", threads ", Threads.nthreads())
    checkpoints || return run_no_checkpoints(cfg, workdir, samples, opts)
    summary = Dict{Symbol,Any}()
    enabled = memory_handoff(cfg)
    reason = enabled ? memory_handoff_fallback(StepContext(cfg, workdir, :select, samples, opts), opts.steps) : ""
    effective = enabled && isempty(reason)
    if enabled && !effective
        summary[:memory_handoff] = Dict{String,Any}("enabled" => true, "effective" => false,
            "fallback_reason" => reason, "file_workers" => 0, "table_handoffs" => 0, "weight_handoffs" => 0,
            "payloadloads" => Dict("table" => 0, "weights" => 0), "diagnostics_scope" => "handoff_only_not_legacy_io")
        println("cascade: memory_handoff fallback: ", reason)
    end
    for step in opts.steps
        if effective && step in (:correct, :histogram)
            continue
        elseif effective && step === :select
            stages, diagnostics = run_memory_handoff(StepContext(cfg, workdir, :select, samples, opts))
            merge!(summary, stages)
            summary[:memory_handoff] = diagnostics
            println("cascade: memory_handoff chain_wall_seconds=", round(diagnostics["chain_wall_seconds"]; digits = 2))
            for phase in (:select, :correct, :histogram)
                r = stages[phase]
                println("cascade: ", rpad(String(phase), 12), " run=", r["run"], " skipped=", r["skipped"],
                    " phase_worker_seconds=", round(r["phase_worker_seconds"]; digits = 2),
                    " timing_kind=", r["timing_kind"])
            end
            println("cascade: memory_handoff ", JSON3.write(diagnostics))
            flush(stdout)
            continue
        end
        t0 = time()
        ctx = StepContext(cfg, workdir, step, samples, opts)
        r = Dict{String,Any}(run_step(step, ctx))
        r["seconds"] = round(time() - t0; digits = 2)
        summary[step] = r
        println("cascade: ", rpad(String(step), 12), " run=", r["run"], " skipped=", r["skipped"],
                " (", r["seconds"], " s)")
        flush(stdout)
    end
    return summary
end
