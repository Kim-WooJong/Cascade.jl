"""Fingerprint fresh source, runtime, payloads and supported hook identities."""
function batch_fingerprint(cfg)
    isempty(HOOKS) || throw(ArgumentError("batch rejects registered hooks; fresh workers cannot reproduce registry state"))
    builtin_source_readers() ||
        throw(ArgumentError("batch rejects replaced built-in source readers"))
    allowed = Dict(:correct => Set(["", "Cascade.Systematics.apply_corrections"]),
        :systematics => Set([""]), :fit => Set([""]), :plot => Set([""]))
    hooks = Dict{String,Any}()
    for step in (:correct, :systematics, :fit, :plot)
        name = String(get(get(cfg.raw, "hooks", Dict()), String(step), ""))
        name in allowed[step] || throw(ArgumentError("batch cannot verify hook $step=$name"))
        _, id = hook_for(cfg, step)
        hooks[String(step)] = id
    end
    root = dirname(dirname(@__DIR__))
    sources = Dict{String,String}()
    for (dir, _, names) in walkdir(joinpath(root, "src")), name in sort(names)
        p = joinpath(dir, name)
        sources[relpath(p, root)] = bytes2hex(open(sha256, p))
    end
    # Pin every repository launcher as well as the loaded source tree.
    for (dir, _, names) in walkdir(joinpath(root, "bin")), name in sort(names)
        p = joinpath(dir, name)
        sources[relpath(p, root)] = bytes2hex(open(sha256, p))
    end
    for name in ("Project.toml", "Manifest.toml")
        p = joinpath(root, name)
        sources[name] = isfile(p) ? bytes2hex(open(sha256, p)) : "absent"
    end
    environment = Dict(k => get(ENV, k, "") for k in ("JULIA_CPU_TARGET", "OPENBLAS_NUM_THREADS", "JULIAROOT_CHILD_LD_LIBRARY_PATH", "ROOT_CONFIG"))
    return Dict("julia" => string(VERSION), "machine" => Sys.MACHINE, "environment" => environment,
        "source" => batch_hash(sources), "hooks" => hooks,
        "corrections" => correction_files_key(cfg), "shape" => shape_key(shape_variations(cfg)),
        "luminosity" => luminosity_spec(cfg), "extraction" => theory_extraction(cfg))
end
