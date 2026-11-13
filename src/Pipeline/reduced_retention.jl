"""Evaluate actual keep-stage entries for nominal and all applicable shapes."""
function reduced_retention(cfg, sample, src, sel, plan; accumulators = nothing, borrowed = nothing)
    lm = is_data(sample) ? load_lumimask(cfg.data_quality.golden_json;
        run_min = cfg.data_quality.run_min, run_max = cfg.data_quality.run_max) : nothing
    accumulator = accumulators === nothing ? nothing : get!(accumulators, "nominal") do
        Cutflow(vcat("all", sel.cut_names))
    end
    results = plan === nothing ? ["nominal" => run_selection(sel, src; stream = sample.stream, lumimask = lm, sample = sample.name, cutflow = accumulator)] :
        run_selection_variations(sel, src, (raw, needed) -> shape_columns(plan, raw, needed);
            inputs = plan.inputs, replaces = plan.replaces, stream = sample.stream, lumimask = lm, sample = sample.name, cutflows = accumulators)
    correct, _ = hook_for(cfg, :correct)
    for (label, (table, _)) in results
        weights = _correct_weights(correct, CorrectionContext(cfg, sample, src.path, table, label, borrowed), nrows(table))
        label == "nominal" && Systematics.theory_member_weights(cfg, sample, src.path, table, weights; source = borrowed)
    end
    entries = sort!(unique!(reduce(vcat, (Vector{Int}(last(r)[1]["entry"]) for r in results); init = Int[])))
    cutflows = Dict(first(r) => cutflow_dict(last(r)[2]) for r in results)
    return entries, cutflows
end
