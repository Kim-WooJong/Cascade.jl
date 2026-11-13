"""
    batch_plan(opts::RunOptions) -> Dict

Freeze an immutable discovered inventory with one stable task per serial file chunk.
The work directory must be unused; planning is atomic and serialized. This is not
an independent certificate of dataset completeness.
"""
function batch_plan(opts::RunOptions)
    isempty(opts.workdir) && throw(ArgumentError("batch plan requires explicit workdir"))
    opts.force && throw(ArgumentError("batch plan does not overwrite manifests"))
    opts.max_files >= 0 || throw(ArgumentError("max_files must be nonnegative"))
    work = abspath(opts.workdir)
    batch_safe_path(work)
    cfg = load_analysis(opts.config; profile = opts.profile)
    checkpoints_enabled(cfg) || throw(ArgumentError("batch execution requires execution.checkpoints=true: tasks, receipts and resume are checkpoint artifacts"))
    batch_validate_names(cfg)
    return batch_lock(work * ".plan.lock") do
        ispath(work) && throw(ArgumentError("batch workdir already exists: $work"))
        fingerprint = batch_fingerprint(cfg)
        config_hash = bytes2hex(open(sha256, opts.config))
        samples = isempty(opts.samples) ? cfg.samples : [sample_by_name(cfg, n) for n in opts.samples]
        length(unique(s.name for s in samples)) == length(samples) || error("duplicate batch samples")
        validate_reduced_inputs(cfg, samples; max_files = opts.max_files, verify_payloads = false)
        settings = get(cfg.raw, "batch", Dict())
        workers = get(settings, "workers", 1); threads = get(settings, "threads", 1)
        all(x -> x isa Integer && !(x isa Bool) && x > 0, (workers, threads)) ||
            throw(ArgumentError("batch workers/threads must be positive integers"))
        for s in samples
            !isempty(s.name) && all(c -> isletter(c) || isdigit(c) || c in ('_', '-', '.'), s.name) &&
                !(s.name in (".", "..")) || error("unsafe sample path: $(s.name)")
            s.format in ("nanoaod", "cols", "reduced_rntuple", "reduced_rntuple_group") || error("batch supports built-in sources only")
        end
        stage = mktempdir(dirname(work); prefix = ".cascade-plan-")
        try
            op = RunOptions(opts.config; profile = opts.profile, workdir = stage,
                samples = [s.name for s in samples], max_files = opts.max_files, force = true)
            step_skim(StepContext(cfg, stage, :skim, samples, op))
            skims = Dict{String,Any}(); inventory = Dict{String,Any}(); tasks = Any[]
            for s in samples
                all(c -> isletter(c) || isdigit(c) || c in ('_', '-', '.'), s.name) &&
                    !(s.name in (".", "..")) || error("unsafe sample path: $(s.name)")
                s.format in ("nanoaod", "cols", "reduced_rntuple", "reduced_rntuple_group") || error("batch supports built-in sources only")
                skims[s.name] = read_skim(stage, s.name)
                inventory[s.name] = [Dict("path" => p, "identity" => batch_input_identity(p)) for p in expand_files(s.files)]
                chunks = Set{String}()
                for e in skims[s.name]["files"]
                    e["chunk"] in chunks && error("chunk collision for $(s.name)")
                    push!(chunks, e["chunk"])
                    if s.format == "reduced_rntuple_group"
                        task = Dict{String,Any}("sample" => s.name, "entry" => e, "identity" => batch_input_identity(e["path"]))
                        task["id"] = batch_hash(task); push!(tasks, task)
                        continue
                    end
                    source = open_source(s.format, e["path"]; options = get(s.raw, "source", Dict()))
                    normalization = try
                        normalization_metadata(source)
                    finally
                        close_source(source)
                    end
                    is_mc(s) && normalization["status"] != "available" &&
                        error("batch requires verified nominal normalization for $(s.name): $(normalization["status"])")
                    e["normalization"] = normalization
                    task = Dict{String,Any}("sample" => s.name, "entry" => e,
                        "identity" => batch_input_identity(e["path"]))
                    task["id"] = batch_hash(task)
                    push!(tasks, task)
                end
            end
            for s in samples
                current = [Dict("path" => p, "identity" => batch_input_identity(p)) for p in expand_files(s.files)]
                batch_hash(current) == batch_hash(inventory[s.name]) || error("inventory changed during planning")
                for e in skims[s.name]["files"]
                    signature = file_signature(e["path"])
                    all(get(e["signature"], k, nothing) == v for (k, v) in signature) || error("input changed during planning")
                end
            end
            m = Dict{String,Any}("schema" => 1, "host" => batch_host(),
                "config" => abspath(opts.config), "profile" => opts.profile,
                "config_sha256" => config_hash,
                "resolved" => cfg.raw, "config_dir" => cfg.dir,
                "samples" => [s.name for s in samples], "max_files" => opts.max_files,
                "workers" => workers, "threads" => threads, "fingerprint" => fingerprint,
                "inventory" => inventory, "skims" => skims, "tasks" => tasks,
                "coverage" => "discovered inventory only; dataset completeness not certified")
            m["id"] = batch_hash(m)
            batch_hash(batch_fingerprint(cfg)) == batch_hash(fingerprint) || error("source/payload changed during planning")
            bytes2hex(open(sha256, opts.config)) == m["config_sha256"] || error("config changed during planning")
            batch_atomic_json(joinpath(stage, "manifest.json"), m)
            Base.Filesystem.rename(stage, work)
            return m
        finally
            isdir(stage) && rm(stage; recursive = true)
        end
    end
end
