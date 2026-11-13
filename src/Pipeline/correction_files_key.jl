"""
    correction_files_key(cfg::AnalysisConfig) -> String

Content fingerprint of external `[corrections.sets]` inputs. Resolve paths as
the weights parser does (path substitution, tilde expansion, then relative to
the analysis TOML). Hash once per correct step, not once per event or chunk.
Missing inputs fail before cached artifacts can silently be reused.
"""
function correction_files_key(cfg::AnalysisConfig)
    raw = get(cfg.raw, "corrections", Dict{String,Any}())
    sets = get(raw, "sets", Dict{String,Any}())
    paths = get(cfg.raw, "paths", Dict{String,Any}())
    files = Dict{String,Any}()
    for (name, path) in sets
        path isa AbstractString || throw(ArgumentError("corrections.sets.$name must be a file path string"))
        p = substitute_paths(path, paths)
        p = isabspath(p) ? p : normpath(joinpath(cfg.dir, p))
        isfile(p) || throw(ArgumentError("correction set not found: $p"))
        files[String(name)] = (path = p, sha256 = bytes2hex(open(sha256, p)))
    end
    return canonical_hash(files)
end
