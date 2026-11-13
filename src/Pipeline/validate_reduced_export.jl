"""Validate generated final-path TOML through an explicit stage-only input mapping.

Intended for the fresh Julia process invoked before bundle publication. Never
writes through planned final paths or opens original inputs.
"""
function validate_reduced_export(config_path, stage, final)
    stage = abspath(stage); final = abspath(final)
    abspath(config_path) == joinpath(stage, "analysis.toml") || error("unexpected staged config path")
    cfg = load_analysis(config_path)
    manifest = _jsdict(JSON3.read(read(joinpath(stage, "manifest.json"), String)))
    bytes2hex(open(sha256, config_path)) == manifest["analysis_sha256"] || error("generated analysis checksum mismatch")
    records = manifest[manifest["schema"] == 2 ? "groups" : "files"]
    Set(s.name for s in cfg.samples) == Set(r["sample"] for r in records) || error("generated sample inventory mismatch")
    # Fit parsing checks explicit data/signal/group/normsys references without
    # constructing a new model or silently removing any declaration.
    fit = Fit.fit_config(cfg)
    if fit !== nothing
        for channel in fit.channels
            any(r -> r.name == channel.region, cfg.regions) || error("generated fit references an unknown region")
            any(h -> h.name == channel.variable && (isempty(h.regions) || channel.region in h.regions), cfg.histograms) || error("generated fit references an unavailable histogram")
        end
    end
    raw = deepcopy(cfg.raw)
    for (sample, declaration) in zip(cfg.samples, raw["samples"])
        sample.format in ("reduced_rntuple", "reduced_rntuple_group") || error("generated config must use the built-in reduced reader")
        paths = [r["path"] for r in records if r["sample"] == sample.name]
        sample.files == [joinpath(final, p) for p in paths] || error("generated config has incorrect planned final paths")
        declaration["files"] = [batch_safe_path(joinpath(stage, p); root = stage) for p in paths]
    end
    staged = parse_analysis(raw; path = config_path, dir = stage)
    validate_analysis(staged)
    validate_reduced_inputs(staged)
    for sample in staged.samples, path in sample.files
        if sample.format == "reduced_rntuple_group"
            group = read_reduced_group(path)
            group["contract"] == reduced_contract(cfg, sample) || error("generated group retention contract mismatch")
            for record in group["shards"]
                shard = ReducedShardSource(joinpath(stage, record["path"]))
                try
                    reduced_column_schema(read_columns(shard, column_names(shard)), nevents(shard))
                finally
                    close_source(shard)
                end
            end
            continue
        end
        source = open_source(sample.format, path; options = get(sample.raw, "source", Dict()))
        try
            read_reduced_metadata(path)["contract"] == reduced_contract(cfg, sample) || error("generated retention contract mismatch")
            reduced_column_schema(read_columns(source, column_names(source)), nevents(source))
        finally
            close_source(source)
        end
    end
    return nothing
end
