"""
    write_yields_tsv(path, cfg, samples, info)

Per-sample region yields plus data and MC totals. `yield` = norm x cutflow
sumw; `hist_yield` = stored-bin integral (with the histogram flow policy) of the normalised yield-variable histogram,
not necessarily an event yield. Explicit canonical columns are appended; the
original columns remain backward-compatible aliases.
"""
function write_yields_tsv(path, cfg::AnalysisConfig, samples, info)
    open(path, "w") do io
        println(io, "sample\tkind\tregion\tn_raw\tsumw_raw\tnorm\tyield\thist_yield\tselected_event_count\tcutflow_sumw_raw\tcutflow_yield\thistogram_integral\thistogram_variable")
        for r in cfg.regions
            tot = Dict("data" => [0, 0.0, 0.0], "mc" => [0, 0.0, 0.0])
            for s in samples
                d = info[s.name]; y = d["regions"][r.name]
                hy = y["hist_yield"] === nothing ? NaN : y["hist_yield"]
                println(io, join((s.name, d["kind"], r.name, y["n"], y["sumw"], d["norm"], y["yield"], hy, y["selected_event_count"], y["cutflow_sumw_raw"], y["cutflow_yield"], hy, y["histogram_variable"]), '\t'))
                t = tot[d["kind"]]
                t[1] += y["n"]; t[2] += y["yield"]; t[3] += hy
            end
            for k in ("data", "mc")
                t = tot[k]
                println(io, join(("TOTAL_" * uppercase(k), k, r.name, Int(t[1]), "", "", t[2], t[3], Int(t[1]), "", t[2], t[3], ""), '\t'))
            end
        end
    end
end
