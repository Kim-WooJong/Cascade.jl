"""Export one original population exactly once, including a zero-retained file."""
function reduce_source_file(cfg, sample, path, dest, options, coverage)
    filesize(path) <= options["max_input_bytes"] || error("source exceeds reduced max_input_bytes")
    before = batch_input_identity(path)
    src = open_export_source(sample, path, options)
    try
        n = nevents(src)
        norm = normalization_metadata(src)
        if is_mc(sample)
            norm["status"] == "available" || error("missing original MC normalization: $path")
            src isa ColumnFileSource && !haskey(src.meta, "gen_weight_sum") && error("original cols MC requires explicit gen_weight_sum metadata")
        end
        sel = compile_selection(cfg, sample.kind)
        variations = shape_variations_for(shape_variations(cfg), sample)
        plan = isempty(variations) ? nothing : shape_plan(variations, vcat(sel.columns_pre, sel.columns_post))
        names = reduced_branch_plan(cfg, sample, src, sel, plan, options)
        reduced_source_limits(src, names, options; output_columns = length(sel.output_names),
            variations = plan === nothing ? 1 : length(plan.labels) + 1)
        entries, cutflows = reduced_retention(cfg, sample, src, sel, plan; borrowed = src isa ColumnFileSource ? src : nothing)
        cols = reduced_raw_columns(src, names, entries, options["max_payload_bytes"])
        schema, bytes = write_reduced_rntuple(dest, cols; max_payload_bytes = options["max_payload_bytes"])
        lumis = is_data(sample) && luminosity_spec(cfg)["mode"] == "certified" ? source_lumisections(src, cfg) : nothing
        meta = Dict{String,Any}("schema" => 1, "sample" => sample.name, "kind" => String(sample.kind),
            "population" => source_population(src), "source_signature" => source_signature(src),
            "source_options" => get(sample.raw, "source", Dict()), "source_format" => sample.format,
            "original_nevents" => n, "retained_nevents" => length(entries), "normalization" => norm,
            "retained_gen_weight_sum" => haskey(cols, "genWeight") ? sum(Float64, cols["genWeight"]; init = 0.0) : nothing,
            "contract" => reduced_contract(cfg, sample), "retention" => "nominal and all configured shape keep-stage union",
            "original_cutflows" => cutflows, "cutflow_population" => "original prefilter evidence; exact semantic contract only",
            "coverage" => coverage, "luminosity_spec" => luminosity_spec(cfg), "certified_observed_lumisections" => lumis,
            "columns" => schema, "payload_bytes" => bytes, "original_theory_extraction" => theory_extraction(cfg; samples = [sample]),
            "writer" => Dict("unroot" => string(pkgversion(UnROOT)), "julia" => string(VERSION), "format" => "ROOT::RNTuple"))
        batch_hash(batch_input_identity(path)) == batch_hash(before) || error("source changed during reduced export: $path")
        write(dest * ".cascade.json", JSON3.write(meta))
        return meta
    finally
        close_source(src)
    end
end
