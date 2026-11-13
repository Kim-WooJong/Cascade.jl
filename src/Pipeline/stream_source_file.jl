"""Stream one original population into ordered physical shards and a logical ledger.

Only per-window arrays, one shard buffer and small accumulators remain live.
Original normalization/coverage/cutflows are owned exactly once by the descriptor.
"""
function stream_source_file(cfg, sample, path, stage, group_path, ordinal, options, coverage;
                            observe_window = nothing)
    before = batch_input_identity(path)
    sample.format == "nanoaod" && validate_stream_metadata(path, options)
    src = open_export_source(sample, path, options)
    try
        src isa NanoAODSource || src isa ColumnFileSource || error("stream export requires original built-in source")
        # Column files are explicitly eager compatibility inputs, not streaming IO.
        if src isa ColumnFileSource
            filesize(path) <= 256_000_000 && nevents(src) <= 1_000_000 || error("cols compatibility input exceeds eager source limits")
        end
        if src isa NanoAODSource
            key = only(k for k in src.file.directory.keys if k.fName == src.tree)
            0 <= key.fObjlen <= options["max_metadata_bytes"] || error("ROOT tree metadata exceeds max_metadata_bytes")
        end
        n = nevents(src); norm = normalization_metadata(src)
        is_mc(sample) && (norm["status"] != "available" || (src isa ColumnFileSource && !haskey(src.meta, "gen_weight_sum"))) && error("missing original MC normalization")
        sel = compile_selection(cfg, sample.kind)
        variations = shape_variations_for(shape_variations(cfg), sample)
        plan = isempty(variations) ? nothing : shape_plan(variations, vcat(sel.columns_pre, sel.columns_post))
        names = reduced_branch_plan(cfg, sample, src, sel, plan, options)
        length(names) + 1 <= 256 || error("reduced schema exceeds 256-column physical writer limit")
        emptywindow = EventWindowSource(src, 1:0, options)
        emptycols = read_columns(emptywindow, names); emptycols["cascade_source_entry"] = Int64[]
        schema, _ = reduced_column_schema(emptycols, 0)
        emptywindow = nothing; emptycols = nothing
        contract = reduced_contract(cfg, sample)
        population = source_population(src)
        group_id = batch_hash(Dict("population" => population, "source" => before, "contract" => contract,
            "schema" => schema, "options" => options, "version" => 2))
        buffer = ReducedShardBuffer(schema); records = Any[]
        accumulators = Dict{String,Cutflow}(); lumis = Set{Tuple{Int,Int}}()
        metrics = Dict("windows" => 0, "max_window_events" => 0, "max_window_bytes" => 0,
            "max_shard_events" => 0, "max_shard_payload_bytes" => 0, "peak_decoded_basket_bytes" => 0,
            "basket_requests" => 0, "compressed_bytes" => 0, "max_buffer_estimate" => 0)
        retained = 0; retained_sum = 0.0; source_begin = 1; retained_begin = 1
        base = splitext(splitext(basename(group_path))[1])[1]
        relative(i) = joinpath(sample.name, base * "-" * lpad(string(i), 8, '0') * ".root")
        lo = 1
        while lo <= n
            window, raw, estimate = load_reduced_window(src, names, lo, min(n, lo + options["window_events"] - 1), options;
                output_columns = length(sel.output_names), variations = plan === nothing ? 1 : length(plan.labels) + 1)
            entries, _ = reduced_retention(cfg, sample, window, sel, plan; accumulators, borrowed = window)
            if is_data(sample) && luminosity_spec(cfg)["mode"] == "certified"
                union!(lumis, ((Int(p[1]), Int(p[2])) for p in source_lumisections(window, cfg)))
            end
            for row in entries
                entry = first(window.range) + row - 1
                rowbytes = 8 + sum(c isa Jagged ? sizeof(eltype(c.content)) * length(c[row]) + 8 : sizeof(eltype(c)) for c in values(raw))
                buffered = length(buffer.columns["cascade_source_entry"])
                if buffered > 0 && (buffered >= options["target_shard_events"] || buffer.bytes + rowbytes > options["target_shard_payload_bytes"])
                    push!(records, flush_reduced_shard(buffer, stage, relative(length(records)+1), group_path, group_id,
                        length(records)+1, source_begin, entry-1, retained_begin, contract))
                    source_begin = entry; retained_begin += buffered; buffer = ReducedShardBuffer(schema)
                end
                append_reduced_row!(buffer, raw, row, entry, options["target_shard_payload_bytes"])
                retained += 1
                haskey(raw, "genWeight") && (retained_sum += Float64(raw["genWeight"][row]))
                metrics["max_shard_events"] = max(metrics["max_shard_events"], length(buffer.columns["cascade_source_entry"]))
                metrics["max_shard_payload_bytes"] = max(metrics["max_shard_payload_bytes"], buffer.bytes)
            end
            metrics["windows"] += 1
            metrics["max_window_events"] = max(metrics["max_window_events"], nevents(window))
            metrics["max_window_bytes"] = max(metrics["max_window_bytes"], window.metrics["live_window_bytes"])
            metrics["peak_decoded_basket_bytes"] = max(metrics["peak_decoded_basket_bytes"], window.metrics["peak_decoded_basket_bytes"])
            metrics["basket_requests"] += window.metrics["basket_requests"]
            metrics["compressed_bytes"] += window.metrics["compressed_bytes"]
            metrics["max_buffer_estimate"] = max(metrics["max_buffer_estimate"], estimate)
            observe_window === nothing || observe_window(window, buffer, metrics)
            lo = last(window.range) + 1
            window = nothing; raw = nothing; entries = nothing
            4096 * Int128(length(records)) * max(1, length(schema)) <= 16 * options["max_metadata_bytes"] || error("shard metadata exceeds conservative metadata budget")
        end
        if n == 0
            window = EventWindowSource(src, 1:0, options)
            reduced_retention(cfg, sample, window, sel, plan; accumulators, borrowed = window)
        end
        push!(records, flush_reduced_shard(buffer, stage, relative(length(records)+1), group_path, group_id,
            length(records)+1, source_begin, n, retained_begin, contract))
        batch_hash(batch_input_identity(path)) == batch_hash(before) || error("original source changed during streaming export")
        metadata = Dict{String,Any}("schema" => 2, "group_id" => group_id, "sample" => sample.name,
            "kind" => String(sample.kind), "population" => population, "source_signature" => source_signature(src),
            "source_options" => get(sample.raw, "source", Dict()), "source_format" => sample.format,
            "original_nevents" => n, "retained_nevents" => retained, "normalization" => norm,
            "retained_gen_weight_sum" => retained_sum, "contract" => contract, "coverage" => coverage,
            "columns" => schema, "shards" => records, "original_cutflows" => Dict(k => cutflow_dict(v) for (k,v) in accumulators),
            "cutflow_population" => "original prefilter; persistent original-event-order accumulators",
            "luminosity_spec" => luminosity_spec(cfg),
            "certified_observed_lumisections" => is_data(sample) && luminosity_spec(cfg)["mode"] == "certified" ? [collect(p) for p in sort!(collect(lumis))] : nothing,
            "original_theory_extraction" => theory_extraction(cfg; samples = [sample]),
            "metrics" => metrics, "input_capability" => src isa NanoAODSource ? "bounded TTree baskets" : "bounded eager cols compatibility",
            "writer" => Dict("unroot" => string(pkgversion(UnROOT)), "julia" => string(VERSION), "format" => "ROOT::RNTuple"))
        bytes = JSON3.write(metadata)
        sizeof(bytes) <= options["max_metadata_bytes"] || error("logical metadata exceeds max_metadata_bytes")
        write(joinpath(stage, group_path), bytes)
        return Dict("sample" => sample.name, "path" => group_path, "group_id" => group_id,
            "population" => population, "sha256" => bytes2hex(sha256(bytes)))
    finally
        close_source(src)
    end
end
