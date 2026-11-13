"""
    validate_analysis(cfg::AnalysisConfig) -> cfg

Structural checks (names unique, references resolvable, required fields set,
`[[shape_variations]]` via `validate_shape_variations`).
Throws `ArgumentError` listing every problem found. Expression syntax is checked
when the selection is compiled.
"""
function validate_analysis(cfg::AnalysisConfig)
    validate_keys(cfg.raw)
    errs = String[]
    dup(xs) = unique([x for x in xs if count(==(x), xs) > 1])
    for (what, xs) in (("sample", [s.name for s in cfg.samples]), ("object", [o.name for o in cfg.objects]),
                       ("cut", [c.name for c in cfg.cuts]), ("region", [r.name for r in cfg.regions]),
                       ("histogram", [h.name for h in cfg.histograms]),
                       ("variation", [v.name for v in cfg.variations]))
        for d in dup(xs)
            push!(errs, "duplicate $what name '$d'")
        end
    end
    isempty(cfg.samples) && push!(errs, "no samples defined")
    any(is_mc, cfg.samples) && !(isfinite(cfg.lumi_pb) && cfg.lumi_pb > 0) &&
        push!(errs, "analysis.lumi_pb must be a positive number when MC samples are present")
    for s in cfg.samples
        append!(errs, validate_sample_annotations(s))
        s.kind in (:mc, :data) || push!(errs, "sample $(s.name): kind must be mc or data")
        isempty(s.files) && push!(errs, "sample $(s.name): no files")
        if is_mc(s)
            (isfinite(s.xsec_pb) && s.xsec_pb > 0) || push!(errs, "sample $(s.name): xsec_pb must be > 0")
        elseif is_data(s) && !isempty(cfg.triggers.priority)
            s.stream in cfg.triggers.priority ||
                push!(errs, "sample $(s.name): stream '$(s.stream)' not in triggers.priority")
        end
    end
    seen = Set{String}()
    reserved = Set(["trigger", "lumimask"])
    for o in cfg.objects
        o.name in reserved && push!(errs, "object name '$(o.name)' is reserved")
        for a in o.clean_against
            a in seen || push!(errs, "object $(o.name): clean.against '$a' must be defined before it")
        end
        push!(seen, o.name)
    end
    for c in cfg.cuts
        c.only in (:all, :mc, :data) || push!(errs, "cut $(c.name): only must be all, mc or data")
    end
    cutnames = Set(c.name for c in cfg.cuts)
    for r in cfg.regions
        (r.after == "all" || r.after in cutnames) || push!(errs, "region $(r.name): unknown cut '$(r.after)'")
        isempty(strip(r.expr)) && push!(errs, "region $(r.name): expr must not be empty")
    end
    regnames = Set(r.name for r in cfg.regions)
    for h in cfg.histograms
        isempty(h.values) && push!(errs, "histogram $(h.name): no values")
        for r in h.regions
            r in regnames || push!(errs, "histogram $(h.name): unknown region '$r'")
        end
    end
    for v in cfg.output_columns
        haskey(cfg.variables, v) || push!(errs, "output column '$v' is not a defined variable")
    end
    t = cfg.triggers
    for (st, gs) in t.streams, g in gs
        haskey(t.groups, g) || push!(errs, "trigger stream $st: unknown group '$g'")
    end
    for g in t.mc
        haskey(t.groups, g) || push!(errs, "triggers.mc: unknown group '$g'")
    end
    for st in t.priority
        haskey(t.streams, st) || push!(errs, "triggers.priority: stream '$st' has no groups")
    end
    append!(errs, validate_shape_variations(cfg))
    theory_weights(cfg)
    reduced_skim_options(cfg)
    dq = cfg.data_quality
    dq.run_min <= dq.run_max || push!(errs, "data_quality.run_range is empty")
    isempty(dq.run_branch) && push!(errs, "data_quality.run_branch must not be empty")
    isempty(dq.lumi_branch) && push!(errs, "data_quality.lumi_branch must not be empty")
    isempty(dq.golden_json) || isfile(dq.golden_json) ||
        push!(errs, "data_quality.golden_json not found: $(dq.golden_json)")
    isempty(errs) || throw(ArgumentError("invalid analysis config:\n  " * join(errs, "\n  ")))
    return cfg
end
