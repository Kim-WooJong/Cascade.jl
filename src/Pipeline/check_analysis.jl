"""
    check_analysis(opts::RunOptions; io = stdout) -> AnalysisConfig

Validate the resolved analysis and print its inputs, selection and enabled model.
File globs are expanded but event files are not opened.
"""
function check_analysis(opts::RunOptions; io::Base.IO = stdout)
    cfg = load_analysis(opts.config; profile = opts.profile)
    spec = Systematics.parse_corrections(cfg)
    for term in vcat(spec.object_sfs, spec.event_weights)
        cs = Systematics.cached_correctionset(term.set)
        haskey(cs, term.correction) || throw(ArgumentError("corrections.$(term.name): missing payload entry $(term.correction)"))
        Systematics.bind_inputs(term.inputs, term.systematic, cs[term.correction]; label = "corrections." * term.name)
    end
    for term in spec.trigger_ors, (side, efficiency) in (("data", term.data), ("mc", term.mc))
        cs = Systematics.cached_correctionset(efficiency.set)
        haskey(cs, efficiency.correction) || throw(ArgumentError("corrections.$(term.name).$side: missing efficiency payload entry $(efficiency.correction)"))
        Systematics.bind_inputs(efficiency.inputs, efficiency.systematic, cs[efficiency.correction];
                               label = "corrections.$(term.name).$side")
    end
    exposure = luminosity_spec(cfg)
    exposure["mode"] == "certified" && load_lumisection_luminosity(exposure["file"])
    shapes = shape_variations(cfg)
    isempty(shapes) || shape_plan(shapes, String[])
    fc = Fit.fit_config(cfg)
    compile_selection(cfg, :mc)
    any(is_data, cfg.samples) && compile_selection(cfg, :data)
    println(io, "Analysis: ", cfg.name, "\nWorkdir: ", cfg.workdir)
    for s in cfg.samples
        println(io, "Sample: ", s.name, " (", s.kind, ") files=", length(expand_files(s.files)))
    end
    for c in cfg.cuts; println(io, "Cut: ", c.name, " [", c.only, "] ", c.expr); end
    for r in cfg.regions; println(io, "Region: ", r.name, " after ", r.after, " where ", r.expr); end
    println(io, "Corrections: ", join(unique([t.name for t in vcat(spec.object_sfs, spec.event_weights, spec.flat, spec.trigger_ors)]), ", "))
    println(io, "Luminosity: ", exposure["mode"], " (configured ", cfg.lumi_pb, " pb^-1)")
    println(io, "Shape variations: ", join([v.name * (v.kind == :jer ? " (nominal=$(v.params["nominal"]))" : "") for v in shape_variations(cfg)], ", "))
    println(io, "Theory weights: ", join([t["name"] for t in theory_weights(cfg)], ", "))
    println(io, "Fit: ", fc === nothing ? "disabled" : "enabled (POI $(fc.poi))")
    return cfg
end
