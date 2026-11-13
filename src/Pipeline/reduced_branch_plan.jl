"""Compute required raw branches from the actual compiled selection and lazy weights."""
function reduced_branch_plan(cfg, sample, src, sel, plan, options)
    required = Set(vcat(sel.columns_pre, sel.columns_post))
    "trigger" in sel.builtins && union!(required, trigger_paths(sel.triggers, sample.kind, sample.stream))
    dq = cfg.data_quality
    ("lumimask" in sel.builtins || is_data(sample)) && union!(required, [dq.run_branch, dq.lumi_branch])
    plan === nothing || union!(required, plan.inputs)
    for term in theory_weights(cfg)
        sample.name in term["samples"] || continue
        push!(required, term["branch"])
        haskey(term, "reference_branch") && push!(required, term["reference_branch"])
    end
    if is_mc(sample)
        spec = Systematics.parse_corrections(cfg)
        for term in spec.event_weights
            correction = Systematics.cached_correctionset(term.set)[term.correction]
            bound = Systematics.bind_inputs(term.inputs, term.systematic, correction)
            for input in bound
                input.kind == :expression || continue
                usage = ExpressionUsage()
                translate_expression(input.value, usage; objects = Dict(o.name => o.collection for o in cfg.objects),
                    variables = cfg.variables, builtins = Set{String}())
                union!(required, usage.columns)
            end
        end
    end
    available = Set(column_names(src))
    # Preserve present IDs, generator/theory vectors even when not consumed yet.
    for name in ("run", "luminosityBlock", "event", "genWeight", "LHEScaleWeight", "LHEPdfWeight", "PSWeight")
        name in available && push!(required, name)
    end
    for name in collect(required)
        counter = "n" * first(split(name, '_'))
        counter in available && push!(required, counter)
    end
    isempty(intersect(required, Set(options["drop"]))) || error("explicit drop removes required reduced branch")
    names = setdiff(union(required, Set(options["include"])), Set(options["drop"]))
    missing = setdiff(names, available)
    isempty(missing) || error("missing reduced dependencies: $(join(sort!(collect(missing)), ", "))")
    "cascade_source_entry" in available && error("reserved reduced provenance branch already exists")
    return sort!(collect(names))
end
