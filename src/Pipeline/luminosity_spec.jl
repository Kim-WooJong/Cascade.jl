"""
    luminosity_spec(cfg)

Resolve the optional explicit per-lumisection luminosity table. Event-file
coverage alone does not establish that a complete luminosity section was read;
certified mode therefore requires an explicit completeness assumption.
"""
function luminosity_spec(cfg::AnalysisConfig)
    d = get(cfg.raw, "luminosity", Dict{String,Any}())
    mode = String(get(d, "mode", "configured"))
    mode in ("configured", "certified") || throw(ArgumentError("luminosity.mode must be configured or certified"))
    unit = String(get(d, "unit", "pb^-1"))
    unit == "pb^-1" || throw(ArgumentError("luminosity.unit must be pb^-1"))
    complete = get(d, "assume_complete_lumisections", false)
    complete isa Bool || throw(ArgumentError("luminosity.assume_complete_lumisections must be boolean"))
    file = String(get(d, "file", ""))
    if !isempty(file)
        file = substitute_paths(file, get(cfg.raw, "paths", Dict{String,Any}()))
        file = isabspath(file) ? file : normpath(joinpath(cfg.dir, file))
    end
    if mode == "certified"
        complete || throw(ArgumentError("certified luminosity requires luminosity.assume_complete_lumisections=true; observed event run/LS pairs do not prove complete LS exposure"))
        isempty(file) && throw(ArgumentError("certified luminosity requires luminosity.file"))
        isfile(file) || throw(ArgumentError("luminosity.file not found: $file"))
        isempty(cfg.data_quality.golden_json) && throw(ArgumentError("certified luminosity requires data_quality.golden_json"))
    end
    payload = mode == "certified" ? bytes2hex(sha256(read(file))) : nothing
    golden = cfg.data_quality.golden_json
    return Dict{String,Any}("mode" => mode, "file" => file, "unit" => unit,
        "assume_complete_lumisections" => complete, "table_sha256" => payload,
        "golden_sha256" => isempty(golden) ? nothing : bytes2hex(sha256(read(golden))),
        "run_branch" => cfg.data_quality.run_branch, "lumi_branch" => cfg.data_quality.lumi_branch,
        "run_range" => [cfg.data_quality.run_min, cfg.data_quality.run_max])
end
