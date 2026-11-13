"""
    step_histogram(ctx::StepContext) -> Dict

Per chunk, fill the (unnormalised) histogram store: every region x weight
variation x histogram (`histogram/<sample>/<chunk>.json`). Shape-variation
tables of the chunk are filled with their nominal weights under their label
(`<name>Up`/`<name>Down`), alongside the weight variations.
"""
function step_histogram(ctx::StepContext)
    validate_reduced_skim(ctx)
    prepared = prepare_histogram(ctx)
    cfg = prepared.cfg
    tasks = Any[]; nskip = 0
    for s in ctx.samples
        for e in read_skim(ctx.workdir, s.name)["files"]
            sel = chunk_path(ctx.workdir, :select, s.name, e["chunk"], ".cols")
            cor = chunk_path(ctx.workdir, :correct, s.name, e["chunk"], ".cols")
            ms = require_artifact(sel, "select")
            mc = require_artifact(cor, "correct")
            verify_correct_extraction(cfg, s, cor)
            (; key, out) = histogram_chunk_spec(ctx, prepared, s, e, ms, mc)
            if !ctx.options.force && is_up_to_date(out, key)
                Systematics.verify_theory_extraction(cfg, read_store(out))
                nskip += 1
                continue
            end
            push!(tasks, (s, sel, cor, out, key, e["chunk"], String.(get(ms, "shape", String[]))))
        end
    end
    run_tasks(tasks; label = "histogram") do (s, sel, cor, out, key, chunk, labels)
        execute_histogram_chunk(ctx, prepared, (s, sel, cor, out, key, chunk, labels))
        nothing
    end
    return Dict("run" => length(tasks), "skipped" => nskip)
end

# Region masks and histogram value columns of an event table.
function _fill_inputs(cfg::AnalysisConfig, table::EventTable)
    regions = collect(region_masks(table))
    hc = table.meta["hist_columns"]
    values = Dict{String,Any}(h.name => Vector{Float64}[table[c] for c in hc[h.name]] for h in cfg.histograms)
    return regions, values
end
