"""
    write_shape_yields_tsv(path, cfg, samples, info)

Region yields per MC sample and shape-variation label (`nominal` included for
reference) plus the MC total per label: `sample  region  variation  n_raw
sumw_raw  yield` (`yield` = norm x cutflow sumw). Canonical selected-event and
cutflow-yield columns are appended; old columns remain compatibility aliases.
"""
function write_shape_yields_tsv(path, cfg::AnalysisConfig, samples, info)
    labels = sort!(unique(reduce(vcat, (collect(keys(info[s.name]["shape"])) for s in samples
                                         if haskey(info[s.name], "shape")); init = String[])))
    open(path, "w") do io
        println(io, "sample\tregion\tvariation\tn_raw\tsumw_raw\tyield\tselected_event_count\tcutflow_sumw_raw\tcutflow_yield")
        for r in cfg.regions
            tot = Dict{String,Vector{Float64}}(l => [0.0, 0.0] for l in vcat(NOMINAL, labels))
            for s in samples
                d = info[s.name]
                d["kind"] == "mc" || continue
                rows = Any[(NOMINAL, d["regions"][r.name])]
                for l in labels
                    sh = get(d, "shape", Dict{String,Any}())
                    # samples without this variation contribute their nominal yield
                    push!(rows, (l, haskey(sh, l) ? sh[l]["regions"][r.name] : d["regions"][r.name]))
                end
                for (l, y) in rows
                    println(io, join((s.name, r.name, l, y["n"], y["sumw"], y["yield"], y["selected_event_count"], y["cutflow_sumw_raw"], y["cutflow_yield"]), '\t'))
                    tot[l][1] += y["n"]; tot[l][2] += y["yield"]
                end
            end
            for l in vcat(NOMINAL, labels)
                println(io, join(("TOTAL_MC", r.name, l, Int(tot[l][1]), "", tot[l][2], Int(tot[l][1]), "", tot[l][2]), '\t'))
            end
        end
    end
end
