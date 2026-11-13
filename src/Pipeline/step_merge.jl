"""
    step_merge(ctx::StepContext) -> Dict

Merge chunk stores and cutflows per sample in file order, normalise MC by
`luminosity_scale(xsec_pb, branching_ratio, lumi_pb, sum of gen weights)`
(data unscaled) and write `merge/histograms.json` (normalised),
`merge/histograms_raw.json`, `merge/samples.json` (cutflows, factors, region
yields), `merge/yields.tsv` and `merge/cutflow/<sample>.tsv`. Samples with shape
variations also get `samples.json` entry `shape` (per label: cutflow, region
yields), `merge/cutflow_shape/<sample>/<label>.tsv` and `merge/shape_yields.tsv`.
"""
function step_merge(ctx::StepContext)
    ctx.input_scope === nothing || error("worker shard scope cannot certify a global stage or complete logical population")
    validate_reduced_skim(ctx)
    cfg = ctx.config
    code = code_hash(["Histograms", "Selection", "Pipeline", "Fit"])
    out = joinpath(ctx.workdir, "merge", "histograms.json")
    parts = Any[]
    skims = Dict{String,Any}()
    for s in ctx.samples
        skims[s.name] = read_skim(ctx.workdir, s.name)
        for e in skims[s.name]["files"]
            ms = require_artifact(chunk_path(ctx.workdir, :select, s.name, e["chunk"], ".cols"), "select")
            mh = require_artifact(chunk_path(ctx.workdir, :histogram, s.name, e["chunk"], ".json"), "histogram")
            Systematics.verify_theory_extraction(cfg, read_store(chunk_path(ctx.workdir, :histogram, s.name, e["chunk"], ".json")))
            push!(parts, (s.name, ms["key"], mh["key"], get(e, "gen_weight_sum", get(e, "group_id", nothing))))
        end
    end
    exposure_spec = luminosity_spec(cfg)
    exposure = luminosity_exposure(ctx, skims, exposure_spec)
    key = artifact_key("merge", parts, exposure, section_hash(cfg, "analysis", "samples", "regions", "merge", "fit", "luminosity", "data_quality"), code)
    if !ctx.options.force && is_up_to_date(out, key)
        Systematics.verify_theory_extraction(cfg, read_store(out))
        return Dict("run" => 0, "skipped" => 1)
    end
    merge_outputs!(ctx, skims, exposure, PersistedMergeChunks(ctx.workdir))
    write_meta(out, key; step = "merge", samples = [s.name for s in ctx.samples])
    return Dict("run" => 1, "skipped" => 0)
end

"""
    merge_outputs!(ctx, skims, exposure, chunks) -> HistogramStore

Merge body shared by step_merge (persisted chunks) and the no-checkpoint route
(in-memory chunks delivered in the same sample/file order). Writes the final merge
outputs under ctx.workdir/merge and returns the normalised store it wrote.
Chunk payloads are obtained only through the `chunks` provider.
"""
function merge_outputs!(ctx, skims, exposure, chunks)
    cfg = ctx.config
    out = joinpath(ctx.workdir, "merge", "histograms.json")
    lumi_used = exposure["lumi_used_pb"]
    exposure_summary = Dict(k => v for (k, v) in exposure if !(k in ("samples", "certified_observed_lumisections")))
    yvar = String(get(get(cfg.raw, "merge", Dict{String,Any}()), "yield_variable", ""))
    raw = HistogramStore(); scaled = HistogramStore()
    info = Dict{String,Any}()
    has_region_expr = any(r -> r.expr != "true", cfg.regions)
    fit_channels = get(get(cfg.raw, "fit", Dict()), "channels", Any[])
    check_overlap = length(fit_channels) > 1
    provenance = Dict{String,Any}()
    for s in ctx.samples
        st = HistogramStore()
        cf = nothing
        scf = Dict{String,Cutflow}()
        region_totals = Dict{String,Any}()
        shape_region_totals = Dict{String,Any}()
        groups = get(skims[s.name], "groups", nothing)
        gsum = groups === nothing || !is_mc(s) ? 0.0 : foldl((value, g) -> value + Float64(g["normalization"]["value"]), groups; init = 0.0)
        nev = 0
        subtotal = HistogramStore(); active_group = nothing
        for e in skims[s.name]["files"]
            chunkstore = merge_chunk_store!(chunks, cfg, s, e)
            if groups === nothing
                merge_store!(st, chunkstore)
            else
                if active_group !== nothing && active_group != e["group_id"]
                    merge_store!(st, subtotal); subtotal = HistogramStore()
                end
                active_group = e["group_id"]
                merge_store!(subtotal, chunkstore)
            end
            m = merge_chunk_meta(chunks, s, e)
            c = cutflow_from_dict(m["cutflow"])
            cf === nothing ? (cf = c) : merge_cutflow!(cf, c)
            if has_region_expr || (check_overlap && is_data(s))
                counts, chunk_provenance = merge_chunk_table_summaries(chunks, cfg, s, e, has_region_expr, check_overlap && is_data(s))
                has_region_expr && merge_region_counts!(region_totals, counts)
                check_overlap && is_data(s) &&
                    Fit.merge_channel_provenance!(provenance, chunk_provenance)
            end
            for (label, d) in get(m, "shape_cutflows", Dict{String,Any}())
                c = cutflow_from_dict(d)
                haskey(scf, label) ? merge_cutflow!(scf[label], c) : (scf[label] = c)
                if has_region_expr
                    varied = merge_shape_table(chunks, s, e, label)
                    totals = get!(shape_region_totals, label, Dict{String,Any}())
                    merge_region_counts!(totals, region_counts(varied))
                end
            end
            groups === nothing && (gsum += Float64(e["gen_weight_sum"]))
            nev += Int(e["nevents"])
        end
        groups === nothing || merge_store!(st, subtotal)
        norm = is_mc(s) ? luminosity_scale(s.xsec_pb, s.branching_ratio, lumi_used, gsum) : 1.0
        merge_store!(raw, st)
        is_mc(s) && scale_store!(st, norm)
        merge_store!(scaled, st)
        rs = region_stages(cfg, s.kind)
        regions = Dict{String,Any}()
        for r in cfg.regions
            k = rs[r.name] + 1
            hy = nothing
            v = ""
            vars = [x.variable for x in keys(st) if x.region == r.name && x.sample == s.name && x.variation == NOMINAL]
            if !isempty(vars)
                v = yvar in vars ? yvar : first(sort(vars))
                hy = integral(st[r.name, s.name, NOMINAL, v])
            end
            counts = has_region_expr ? region_totals[r.name] : Dict("n" => cf.n[k], "sumw" => cf.sumw[k])
            regions[r.name] = region_yield_record(counts["n"], counts["sumw"], norm;
                histogram_integral = hy, histogram_variable = v)
        end
        info[s.name] = Dict("kind" => String(s.kind), "stream" => s.stream, "group" => s.group,
                            "nfiles" => groups === nothing ? length(skims[s.name]["files"]) : length(groups),
                            "physical_nfiles" => length(skims[s.name]["files"]), "nevents" => nev,
                            "gen_weight_sum" => gsum, "norm" => norm, "cutflow" => cutflow_dict(cf),
                            "regions" => regions, "metadata" => get(s.raw, "metadata", Dict{String,Any}()), "luminosity" => exposure_summary,
                            "input_coverage" => exposure["samples"][s.name])
        if s.format == "reduced_rntuple_group"
            info[s.name]["cutflow_population"] = "reduced retained events; original logical-source evidence below"
            info[s.name]["original_sources"] = [Dict("population" => g["population"], "original_nevents" => g["original_nevents"],
                "original_cutflows" => g["original_cutflows"]) for g in groups]
        elseif s.format == "reduced_rntuple"
            info[s.name]["cutflow_population"] = "reduced retained events; original all-event evidence below"
            info[s.name]["original_sources"] = [Dict("population" => e["population"], "original_nevents" => e["original_nevents"],
                "original_cutflows" => e["original_cutflows"]) for e in skims[s.name]["files"]]
        end
        write_cutflow_tsv(joinpath(ctx.workdir, "merge", "cutflow", string(s.name, ".tsv")), s.name, cf, gsum)
        if !isempty(scf)
            shape = Dict{String,Any}()
            for (label, c) in scf
                regs = Dict{String,Any}()
                for r in cfg.regions
                    counts = has_region_expr ? shape_region_totals[label][r.name] :
                             Dict("n" => c.n[rs[r.name]+1], "sumw" => c.sumw[rs[r.name]+1])
                    regs[r.name] = region_yield_record(counts["n"], counts["sumw"], norm)
                end
                shape[label] = Dict("cutflow" => cutflow_dict(c), "regions" => regs)
                write_cutflow_tsv(joinpath(ctx.workdir, "merge", "cutflow_shape", s.name, string(label, ".tsv")),
                                  string(s.name, ":", label), c, gsum)
            end
            info[s.name]["shape"] = shape
        end
    end
    raw.meta["luminosity"] = exposure
    if check_overlap
        raw.meta["fit_channel_provenance"] = provenance
        scaled.meta["fit_channel_provenance"] = provenance
    end
    raw.meta["normalised"] = false
    scaled.meta["luminosity"] = exposure
    scaled.meta["lumi_pb"] = lumi_used
    scaled.meta["normalised"] = true
    if haskey(cfg.raw, "counting")
        scaled.meta["counting_configuration_sha256"] = require_counting_ready(cfg)["configuration_sha256"]
    end
    write_store(joinpath(ctx.workdir, "merge", "histograms_raw.json"), raw)
    write(joinpath(ctx.workdir, "merge", "samples.json"),
          JSON3.write(Dict("lumi_pb" => lumi_used, "luminosity" => exposure, "samples" => info, "order" => [s.name for s in ctx.samples])))
    write_yields_tsv(joinpath(ctx.workdir, "merge", "yields.tsv"), cfg, ctx.samples, info)
    any(haskey(d, "shape") for d in values(info)) &&
        write_shape_yields_tsv(joinpath(ctx.workdir, "merge", "shape_yields.tsv"), cfg, ctx.samples, info)
    write_store(out, scaled)
    return scaled
end

"Persisted per-file checkpoints of the staged route (the original merge reads)."
struct PersistedMergeChunks
    workdir::String
end

function merge_chunk_store!(c::PersistedMergeChunks, cfg, s, e)
    chunkstore=read_store(chunk_path(c.workdir, :histogram, s.name, e["chunk"], ".json"))
    Systematics.verify_theory_extraction(cfg,chunkstore)
    return chunkstore
end

merge_chunk_meta(c::PersistedMergeChunks, s, e) = read_meta(chunk_path(c.workdir, :select, s.name, e["chunk"], ".cols"))

function merge_chunk_table_summaries(c::PersistedMergeChunks, cfg, s, e, want_counts::Bool, want_provenance::Bool)
    table = read_event_table(chunk_path(c.workdir, :select, s.name, e["chunk"], ".cols"))
    counts = want_counts ? region_counts(table) : nothing
    chunk_provenance = want_provenance ? Fit.channel_overlap_provenance(table, cfg) : nothing
    return counts, chunk_provenance
end

merge_shape_table(c::PersistedMergeChunks, s, e, label) =
    read_event_table(shape_chunk_path(c.workdir, :select, s.name, e["chunk"], label, ".cols"))
