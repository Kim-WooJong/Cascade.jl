"""
    step_skim(ctx::StepContext) -> Dict

Index the input of every sample: expand file patterns, record file signatures,
event counts and generator-weight sums (`skim/<sample>.json`). Reduced export is the separate reduce command; inputs here are read in place.
"""
function step_skim(ctx::StepContext)
    ctx.input_scope === nothing || error("worker shard scope cannot certify a global stage or complete logical population")
    nrun = 0; nskip = 0
    code = code_hash(["Config", "IO", "Pipeline"])
    exposure_spec = luminosity_spec(ctx.config)
    for s in ctx.samples
        if s.format == "reduced_rntuple_group"
            skim_reduced_groups(ctx, s, code) ? (nrun += 1) : (nskip += 1)
            continue
        end
        files, available_nfiles = skim_inputs(ctx, s)
        sigs = [file_signature(f) for f in files]
        key = artifact_key("skim", s.name, String(s.kind), s.format, get(s.raw, "source", Dict()), sigs, available_nfiles, section_hash(ctx.config, "options"), exposure_spec, code)
        out = skim_path(ctx.workdir, s.name)
        if !ctx.options.force && is_up_to_date(out, key)
            nskip += 1
            continue
        end
        entries = skim_entries(ctx, s, files, exposure_spec)
        mkpath(dirname(out))
        write(out, JSON3.write(skim_record(s, entries, files, available_nfiles, exposure_spec)))
        write_meta(out, key; step = "skim", sample = s.name, nfiles = length(entries))
        nrun += 1
    end
    return Dict("run" => nrun, "skipped" => nskip)
end

# Shared by step_skim and the no-checkpoint route: current input inventory only.
function skim_inputs(ctx, s)
    files = expand_files(s.files)
    isempty(files) && throw(ArgumentError("sample $(s.name): no files match $(s.files)"))
    validate_source_populations(s.format, files; options = get(s.raw, "source", Dict()))
    available_nfiles = length(files)
    if s.format == "reduced_rntuple"
        reduced = [read_reduced_metadata(p) for p in files]
        available_nfiles = max(available_nfiles, maximum(Int(m["coverage"]["available_nfiles"]) for m in reduced))
    end
    mf = ctx.options.max_files
    mf > 0 && length(files) > mf && (files = files[1:mf])
    return files, available_nfiles
end

function skim_entries(ctx, s, files, exposure_spec; lightweight_metadata::Bool=false)
    return run_tasks(files; label = "skim " * s.name) do f
        src = open_source(s.format, f; options = get(s.raw, "source", Dict()))
        try
            signature = source_signature(src) # unchanged: bind identity BEFORE metadata/normalization
            eligible = lightweight_metadata && src isa NanoAODSource && s.format == "nanoaod" &&
                exposure_spec["mode"] == "configured" && isempty(ctx.config.variations) &&
                isempty(get(ctx.config.raw,"shape_variations",Any[])) && isempty(get(ctx.config.raw,"theory_weights",Any[]))
            n = eligible ? EventIO.skim_nanoaod_entrycount(src;
                max_metadata_bytes=Config.streaming_selection_options(ctx.config).stream_metadata_bytes) : nothing
            n === nothing && (n = nevents(src)) # only pre-admission unsupported routes fall back
            entry = Dict{String,Any}("path" => f, "chunk" => chunk_id(f), "signature" => signature,
                             "nevents" => n, "gen_weight_sum" => gen_weight_sum(src))
            if src isa ReducedRNTupleSource
                src.meta["contract"] == reduced_contract(ctx.config, s) || error("stale reduced retention contract")
                entry["original_nevents"] = src.meta["original_nevents"]
                entry["population"] = src.meta["population"]
                entry["original_cutflows"] = src.meta["original_cutflows"]
            end
            if is_data(s) && exposure_spec["mode"] == "certified"
                if src isa ReducedRNTupleSource
                    canonical_hash(src.meta["luminosity_spec"]) == canonical_hash(exposure_spec) || error("cannot reconstruct original certified coverage under changed luminosity contract")
                    src.meta["certified_observed_lumisections"] === nothing && error("original certified coverage unavailable")
                    entry["certified_observed_lumisections"] = src.meta["certified_observed_lumisections"]
                else
                    entry["certified_observed_lumisections"] = source_lumisections(src, ctx.config)
                end
            end
            entry
        finally
            close_source(src)
        end
    end
end

# The exact skim JSON document (the persisted route writes it; read_skim parses it).
skim_record(s, entries, files, available_nfiles, exposure_spec) =
    Dict("sample" => s.name, "kind" => String(s.kind), "files" => entries,
        "available_nfiles" => available_nfiles, "truncated" => length(files) < available_nfiles,
        "exposure_key" => canonical_hash(exposure_spec))
