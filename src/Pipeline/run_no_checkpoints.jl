# execution.checkpoints = false: one fresh, no-resume, in-memory full chain.
# See docs/NO_CHECKPOINTS.md for the contract, admitted plans and final outputs.

const NO_CHECKPOINT_FORMATS = ("nanoaod", "cols")
const NO_CHECKPOINT_PROVENANCE = "NO_CHECKPOINTS_PROVENANCE.json"

"""
    no_checkpoints_unsupported(cfg, samples, steps) -> Vector{String}

Every reason why `execution.checkpoints = false` cannot run this plan (empty =
admitted). Pure configuration/registry inspection: it reads no input data and
writes nothing, so a rejected plan fails before any data work or directory write.
"""
function no_checkpoints_unsupported(cfg, samples, steps)
    reasons = String[]
    k = length(steps)
    # Bounds first: a programmatic plan longer than STEPS (e.g. duplicates) must give
    # this aggregate admission error, never a BoundsError from the slice.
    (5 <= k <= length(STEPS) && steps == STEPS[1:k]) || push!(reasons,
        "steps must be one contiguous prefix of $(join(STEPS, " -> ")) that starts at skim and includes merge " *
        "(admitted: skim..merge, skim..systematics, skim..fit, skim..plot); got $(isempty(steps) ? "none" : join(String.(steps), ","))")
    memory_handoff(cfg) && push!(reasons, "execution.memory_handoff=true is a checkpoint-preserving mode and cannot be combined with checkpoints=false")
    column_readers(cfg) == 1 || push!(reasons, "execution.column_readers must be 1")
    decode_options(cfg).threads == 1 || push!(reasons, "execution.decode_threads must be 1")
    streaming_selection_options(cfg).enabled && push!(reasons, "execution.streaming_selection must be false")
    event_range_selection(cfg) && push!(reasons, "execution.event_range_selection must be false")
    bad = [s.name for s in samples if !(s.format in NO_CHECKPOINT_FORMATS)]
    isempty(bad) || push!(reasons, "sample format must be nanoaod or cols (unsupported: $(join(bad, ", ")))")
    builtin_source_readers() || push!(reasons, "source reader identities are replaced")
    f, _ = hook_for(cfg, :correct)
    (f === default_correct || f === Systematics.apply_corrections) ||
        push!(reasons, "custom correction hook (only default_correct or Systematics.apply_corrections)")
    for (step, default) in ((:systematics, default_systematics), (:fit, default_fit), (:plot, default_plot))
        step in steps || continue
        h, _ = hook_for(cfg, step)
        h === default || push!(reasons, "custom $step hook (only the built-in default is admitted)")
    end
    shape = shape_variations(cfg)
    shaped = [s.name for s in samples if !isempty(shape_variations_for(shape, s))]
    isempty(shaped) || push!(reasons, "active shape variations are not implemented in the in-memory route (samples: $(join(shaped, ", ")))")
    isempty(theory_weights(cfg)) || push!(reasons, "active theory weights are not implemented in the in-memory route")
    return reasons
end

no_checkpoints_error(reasons) = ArgumentError("execution.checkpoints=false cannot run this plan; " *
    "nothing was read from or written to the workdir:\n  - " * join(reasons, "\n  - "))

# The JSON semantics a persisted metadata/skim/fit readback would have had.
_json_transport(x) = _jsdict(JSON3.read(JSON3.write(x)))

no_checkpoint_run_id() = string("run-", Libc.strftime("%Y%m%dT%H%M%S", time()), "-", getpid(), "-",
    string(time_ns() % 0xffffffff; base = 16))

"In-memory chunk provider for merge_outputs!: per-file results in exact sample/file order."
mutable struct MemoryMergeChunks
    window::OrderedWindow
    current::Any
    seconds::Vector{Float64}
end

function merge_chunk_store!(c::MemoryMergeChunks, cfg, s, e)
    c.current = nothing # release the previous file's result before waiting
    r = take_next!(c.window)
    (r.sample == s.name && r.chunk == String(e["chunk"])) ||
        error("internal no-checkpoint ordering error: expected $(s.name)/$(e["chunk"]), got $(r.sample)/$(r.chunk)")
    c.current = r
    c.seconds .+= r.seconds
    Systematics.verify_theory_extraction(cfg, r.store)
    return r.store
end

function _current_chunk(c::MemoryMergeChunks, s, e)
    r = c.current
    (r !== nothing && r.sample == s.name && r.chunk == String(e["chunk"])) ||
        error("internal no-checkpoint error: chunk $(s.name)/$(e["chunk"]) is not current")
    return r
end

merge_chunk_meta(c::MemoryMergeChunks, s, e) = _current_chunk(c, s, e).meta

function merge_chunk_table_summaries(c::MemoryMergeChunks, cfg, s, e, want_counts::Bool, want_provenance::Bool)
    r = _current_chunk(c, s, e)
    (want_counts && r.counts === nothing) && error("internal no-checkpoint error: region counts were not computed")
    (want_provenance && r.provenance === nothing) && error("internal no-checkpoint error: channel provenance was not computed")
    return r.counts, r.provenance
end

merge_shape_table(::MemoryMergeChunks, s, e, label) =
    error("shape variation tables are not supported by the no-checkpoint route")

"""
    run_no_checkpoints(cfg, workdir, samples, opts) -> Dict{Symbol,Any}

Run the admitted full-chain prefix with `execution.checkpoints = false`. Every stage
is computed fresh from the current inputs; no per-file skim/select/correct/
histogram artifact, metadata or temporary is written, no existing workdir file is
read, modified or deleted, and nothing can be resumed. Selected tables and weights
live only inside one file work unit (task-private); per-file histogram stores
cross to the single merge consumer through a bounded ordered window and are merged
in the original sample/file order. Final outputs are written to a fresh staging
directory `<workdir>/no-checkpoints/.<run>.partial` and published by one atomic
rename to `<workdir>/no-checkpoints/<run>` only after every selected stage
succeeded. A failure leaves only the hidden staging directory with FAILED.json.
"""
function run_no_checkpoints(cfg, workdir, samples, opts)
    require_counting_ready(cfg)
    return benchmark_span(() -> _run_no_checkpoints_traced(cfg, workdir, samples, opts),
        :no_checkpoints_run, workdir)
end

function _run_no_checkpoints_traced(cfg, workdir, samples, opts)
    started = time()
    steps = opts.steps
    reasons = no_checkpoints_unsupported(cfg, samples, steps)
    isempty(reasons) || throw(no_checkpoints_error(reasons))
    root = joinpath(workdir, "no-checkpoints")
    run_id = no_checkpoint_run_id()
    final_dir = joinpath(root, run_id)
    stage = joinpath(root, "." * run_id * ".partial")
    (ispath(final_dir) || ispath(stage)) && error("no-checkpoint run directory already exists: $final_dir")
    # Final outputs and hooks see the private staging directory as their workdir;
    # all other StepContext consumers below use only config/samples/options.
    ctx = StepContext(cfg, stage, :skim, samples, opts)
    timing = Dict{String,Any}()

    # Skim (in memory): current inventory, source identities, counts, normalisation.
    t = time()
    exposure_spec, skims, exposure = benchmark_span(:skim, workdir) do
        local exposure_spec, skims, exposure
        exposure_spec = luminosity_spec(cfg)
        skims = Dict{String,Any}()
        for s in samples
            files, available_nfiles = skim_inputs(ctx, s)
            entries = skim_entries(ctx, s, files, exposure_spec; lightweight_metadata=Config.lightweight_skim_metadata(cfg))
            skims[s.name] = _json_transport(skim_record(s, entries, files, available_nfiles, exposure_spec))
            # In-memory counterpart of validate_reduced_skim's persisted-skim binding check.
            any(e -> get(get(e, "signature", Dict()), "format", "") in ("reduced_rntuple", "reduced_rntuple_group"), skims[s.name]["files"]) &&
                error("reduced input binding in a no-checkpoint skim for $(s.name)")
        end
        exposure = luminosity_exposure(ctx, skims, exposure_spec)
        (exposure_spec, skims, exposure)
    end
    timing["skim_wall_seconds"] = time() - t

    tasks, psel, pcor, phist, compiled, lmask, plans, has_region_expr, check_overlap, workers, window =
        benchmark_span(:preparation, workdir) do
            local tasks, psel, pcor, phist, compiled, lmask, plans, has_region_expr, check_overlap, workers, window
        tasks = Any[(s, e) for s in samples for e in skims[s.name]["files"]]
        psel = prepare_select(ctx)
        pcor = prepare_correct(ctx)
        phist = prepare_histogram(ctx)
        compiled = Dict{Symbol,Any}()
        lm = nothing
        for (s, _) in tasks
            haskey(compiled, s.kind) || (compiled[s.kind] = compile_selection(cfg, s.kind))
            if is_data(s) && lm === nothing
                dq = psel.dq
                lm = load_lumimask(dq.golden_json; run_min = dq.run_min, run_max = dq.run_max)
            end
        end
        lmask = lm # single binding captured by the work closure
        plans = Dict{String,Any}() # shape variations are rejected above
        has_region_expr = any(r -> r.expr != "true", cfg.regions)
        check_overlap = length(get(get(cfg.raw, "fit", Dict()), "channels", Any[])) > 1
        workers = max(1, min(Threads.nthreads(), length(tasks)))
        window = 4 * workers

        (tasks, psel, pcor, phist, compiled, lmask, plans, has_region_expr, check_overlap, workers, window)
    end

    # One file work unit: select -> correct -> histogram, all payloads task-private.
    # Named callable (no_checkpoint_file_work.jl) holding the same read-only references
    # the former closure captured; its body is the unchanged closure body.
    work = NoCheckpointFileWork(cfg, workdir, ctx, psel, pcor, phist, compiled, plans, lmask,
        has_region_expr, check_overlap)

    mkpath(root)
    mkdir(stage) # create-new: never reuses or overwrites an existing directory
    try
        t = time()
        isempty(tasks) || reset_correction_cache!()
        ow = OrderedWindow(work, tasks; window, workers, label = "no-checkpoints chain")
        chunks = MemoryMergeChunks(ow, nothing, zeros(Float64, 3))
        scaled = try
            benchmark_span(:chain_merge, workdir) do
                merged = benchmark_span(:merge, workdir) do
                    merge_outputs!(StepContext(cfg, stage, :merge, samples, opts), skims, exposure, chunks)
                end
                window_completed(ow) || error("internal no-checkpoint error: not every file result was merged")
                merged
            end
        finally
            chunks.current = nothing
            shutdown_window!(ow)
        end
        timing["chain_wall_seconds"] = time() - t
        timing["phase_worker_seconds"] = Dict("select" => chunks.seconds[1], "correct" => chunks.seconds[2],
            "histogram" => chunks.seconds[3])
        timing["timing_kind"] = "select/correct/histogram/merge overlap; phase values are worker sums, not stage walls"

        fit_json = nothing
        if :systematics in steps
            t = time()
            templates = benchmark_span(:systematics, workdir) do
                local templates
                f, _ = hook_for(cfg, :systematics)
                merged = Systematics.reduce_theory(cfg, Histograms.transport_store(scaled))
                templates = Base.invokelatest(f, StepContext(cfg, stage, :systematics, samples, opts), merged)
                write_store(joinpath(stage, "systematics", "templates.json"), templates)
                templates
            end
            timing["systematics_seconds"] = time() - t
            if :fit in steps
                t = time()
                fit_json = benchmark_span(:fit, workdir) do
                    local fit_json
                    f, _ = hook_for(cfg, :fit)
                    tstore = Histograms.transport_store(templates)
                    Systematics.verify_theory_extraction(cfg, tstore)
                    result = Base.invokelatest(f, StepContext(cfg, stage, :fit, samples, opts), tstore)
                    text = JSON3.write(result)
                    out = joinpath(stage, "fit", "result.json")
                    mkpath(dirname(out))
                    write(out, text)
                    fit_json = _jsdict(JSON3.read(text)) # exactly what step_plot would read back
                    fit_json
                end
                timing["fit_seconds"] = time() - t
            end
        end
        if :plot in steps
            t = time()
            # Capture one immutable binding, not the conditionally reassigned fit_json.
            plot_fit_json = fit_json
            benchmark_span(:plot, workdir) do
                f, _ = hook_for(cfg, :plot)
                store = Systematics.reduce_theory(cfg, Histograms.transport_store(scaled))
                files = Base.invokelatest(f, StepContext(cfg, stage, :plot, samples, opts), store, plot_fit_json)
                published = String[]
                for p in files
                    rel = relpath(abspath(p), stage)
                    (rel == ".." || startswith(rel, "../") || isabspath(rel)) && error("plot output outside the run directory: $p")
                    isfile(abspath(p)) || error("missing plot output: $p")
                    push!(published, joinpath(final_dir, rel))
                end
                out = joinpath(stage, "plot", "index.json")
                mkpath(dirname(out))
                write(out, JSON3.write(Dict("files" => published)))
            end
            timing["plot_seconds"] = time() - t
        end

        runs = benchmark_span(:publication, workdir) do
            local runs
            inventory = Dict{String,Any}()
            for (dir, _, names) in walkdir(stage), name in names
                p = joinpath(dir, name)
                islink(p) && error("symlink in no-checkpoint output: $p")
                inventory[relpath(p, stage)] = Dict("sha256" => bytes2hex(open(sha256, p)), "bytes" => filesize(p))
            end
            nfiles = length(tasks)
            runs = Dict(:skim => length(samples), :select => nfiles, :correct => nfiles, :histogram => nfiles,
                        :merge => 1, :systematics => 1, :fit => 1, :plot => 1)
            timing["total_wall_seconds"] = time() - started
            provenance = Dict{String,Any}("schema" => 1, "mode" => "no_checkpoints",
                "checkpoints" => false, "resume" => false, "fresh_compute" => true,
                "per_file_checkpoint_reads" => 0, "per_file_checkpoint_writes" => 0,
                "per_file_checkpoint_io_basis" => "contract declaration by construction of this route (no per-file checkpoint " *
                    "read/write call exists on it); NOT measured I/O counters",
                "statement" => "Every selected stage was computed from the current inputs in this invocation. " *
                    "No per-file skim/select/correct/histogram artifact, metadata, cache or temporary was read or written; " *
                    "existing workdir content was not read, modified or deleted. These outputs carry no cache keys and cannot be resumed.",
                "run_id" => run_id, "published_dir" => final_dir, "workdir" => workdir,
                "config" => abspath(opts.config), "config_sha256" => bytes2hex(open(sha256, opts.config)),
                "config_sha256_scope" => "bytes of the main analysis TOML only, re-read when provenance is written; " *
                    "correction/golden/luminosity payloads, input files and environment are NOT covered by this hash",
                "profile" => opts.profile, "steps" => String.(steps), "samples" => [s.name for s in samples],
                "max_files" => opts.max_files, "force_flag" => opts.force,
                "force_note" => "no effect: every stage is always computed fresh",
                "files_per_sample" => Dict(s.name => length(skims[s.name]["files"]) for s in samples),
                "stages" => Dict(String(step) => Dict("run" => runs[step], "skipped" => 0) for step in steps),
                "execution" => Dict("file_workers" => workers, "ordered_window" => window,
                    "max_claimed_unconsumed" => ow_max(chunks), "threads" => Threads.nthreads(), "timing" => timing),
                "source_code_sha256" => code_hash(["Config", "IO", "Objects", "Selection", "Corrections", "Systematics",
                    "Histograms", "Fit", "Plotting", "Pipeline"]),
                "julia" => string(VERSION),
                "final_outputs" => inventory)
            ppath = joinpath(stage, NO_CHECKPOINT_PROVENANCE)
            write(ppath * ".tmp", JSON3.write(provenance))
            mv(ppath * ".tmp", ppath)
            ispath(final_dir) && error("no-checkpoint run directory appeared concurrently: $final_dir")
            Base.Filesystem.rename(stage, final_dir)
            runs
        end
        println("cascade: checkpoints=false fresh run (no resume) published ", final_dir)
        summary = Dict{Symbol,Any}()
        for step in steps
            summary[step] = Dict{String,Any}("run" => runs[step], "skipped" => 0)
            println("cascade: ", rpad(String(step), 12), " run=", runs[step], " skipped=0")
        end
        summary[:checkpoints] = Dict{String,Any}("enabled" => false, "resume" => false, "fresh_compute" => true,
            "published_dir" => final_dir, "provenance" => joinpath(final_dir, NO_CHECKPOINT_PROVENANCE),
            "file_workers" => workers, "ordered_window" => window, "max_claimed_unconsumed" => ow_max(chunks),
            "timing" => timing)
        flush(stdout)
        return summary
    catch e
        try
            isdir(stage) && write(joinpath(stage, "FAILED.json"), JSON3.write(Dict("status" => "failed",
                "published" => false, "error" => sprint(showerror, e), "note" => "incomplete outputs; never published")))
        catch
        end
        rethrow()
    end
end

ow_max(c::MemoryMergeChunks) = lock(() -> c.window.max_retained, c.window.lock)
