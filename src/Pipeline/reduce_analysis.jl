"""Export a new opt-in ROOT RNTuple bundle into an unused output directory.

Original serial/index skim behavior is unchanged. No original input is modified.
Publication uses one local POSIX claim and same-filesystem directory rename.
"""
function reduce_analysis(opts::RunOptions; output_dir::AbstractString, _observe_window = nothing)
    opts.force && error("reduce never overwrites outputs")
    opts.max_files >= 0 || error("max_files must be nonnegative")
    isempty(output_dir) && error("reduce requires an unused output directory")
    config_hash = bytes2hex(sha256(read(opts.config)))
    cfg = load_analysis(opts.config; profile = opts.profile)
    options = reduced_skim_options(cfg)
    samples = isempty(opts.samples) ? cfg.samples : [sample_by_name(cfg, n) for n in opts.samples]
    length(unique(s.name for s in samples)) == length(samples) || error("duplicate reduced samples")
    validate_reduced_subset(cfg, samples)
    all(s -> s.format in ("nanoaod", "cols"), samples) || error("reduce accepts original nanoaod/cols inputs, not derivatives")
    batch_validate_names(cfg)
    fingerprint = batch_fingerprint(cfg) # Reject custom hooks/readers before creating output.
    validate_reduced_inputs(cfg, samples)
    final = batch_safe_path(output_dir)
    return batch_lock(final * ".reduce.lock") do
        ispath(final) && error("reduced output directory already exists")
        stage = mktempdir(dirname(final); prefix = ".cascade-reduce-")
        try
            records = Any[]
            inventories = Dict{String,Any}()
            for s in samples
                files = expand_files(s.files)
                isempty(files) && error("no reduced inputs for $(s.name)")
                validate_source_populations(s.format, files; options = get(s.raw, "source", Dict()))
                inventories[s.name] = [Dict("path" => p, "identity" => batch_input_identity(p)) for p in files]
                selected = opts.max_files > 0 ? files[1:min(opts.max_files, length(files))] : files
                coverage = Dict("available_nfiles" => length(files), "selected_nfiles" => length(selected), "truncated" => length(selected) < length(files))
                mkpath(joinpath(stage, s.name))
                for (i, path) in enumerate(selected)
                    if options["mode"] == "streaming"
                        rel = joinpath(s.name, lpad(string(i), 8, '0') * ".source.json")
                        push!(records, stream_source_file(cfg, s, path, stage, rel, i, options, coverage; observe_window = _observe_window))
                        continue
                    end
                    rel = joinpath(s.name, lpad(string(i), 8, '0') * ".root")
                    dest = batch_safe_path(joinpath(stage, rel); root = stage)
                    meta = reduce_source_file(cfg, s, path, dest, options, coverage)
                    push!(records, Dict("sample" => s.name, "path" => rel, "population" => meta["population"],
                        "sha256" => bytes2hex(open(sha256, dest)), "sidecar_sha256" => bytes2hex(open(sha256, dest * ".cascade.json"))))
                end
            end
            for s in samples
                current = [Dict("path" => p, "identity" => batch_input_identity(p)) for p in expand_files(s.files)]
                batch_hash(current) == batch_hash(inventories[s.name]) || error("original inventory changed during export")
            end
            batch_hash(batch_fingerprint(cfg)) == batch_hash(fingerprint) || error("export code/payload contract changed")
            bytes2hex(sha256(read(opts.config))) == config_hash || error("source config changed during export")
            raw = reduced_analysis_config(cfg, samples, records, final)
            open(io -> TOML.print(io, raw), joinpath(stage, "analysis.toml"), "w")
            manifest = Dict{String,Any}("schema" => options["mode"] == "streaming" ? 2 : 1,
                (options["mode"] == "streaming" ? "groups" : "files") => records, "inventory" => inventories,
                "source_config" => cfg.path, "source_config_sha256" => config_hash,
                "profile" => opts.profile, "resolved_config" => cfg.raw, "fingerprint" => fingerprint,
                "analysis_sha256" => bytes2hex(open(sha256, joinpath(stage, "analysis.toml"))),
                "options" => options, "scope" => "consistent derivation, not dataset completeness or producer attestation")
            manifest["id"] = batch_hash(manifest)
            manifest_bytes = JSON3.write(manifest)
            options["mode"] != "streaming" || sizeof(manifest_bytes) <= options["max_metadata_bytes"] || error("bundle manifest exceeds max_metadata_bytes")
            write(joinpath(stage, "manifest.json"), manifest_bytes)
            for r in records
                read_reduced_metadata(joinpath(stage, r["path"]))
            end
            verify_reduced_export(stage, final)
            for sample in samples
                current = [Dict("path" => path, "identity" => batch_input_identity(path)) for path in expand_files(sample.files)]
                batch_hash(current) == batch_hash(inventories[sample.name]) || error("original inventory changed before final publication")
            end
            bytes2hex(sha256(read(opts.config))) == config_hash || error("source config changed before final publication")
            batch_hash(batch_fingerprint(cfg)) == batch_hash(fingerprint) || error("export code/payload changed before final publication")
            batch_safe_path(final)
            ispath(final) && error("reduced destination appeared during export")
            Base.Filesystem.rename(stage, final)
            return manifest
        finally
            isdir(stage) && rm(stage; recursive = true)
        end
    end
end
