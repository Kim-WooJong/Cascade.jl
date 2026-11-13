"The unique certified observed run/LS pairs, before any physics selection."
function source_lumisections(src, cfg::AnalysisConfig)
    dq = cfg.data_quality
    cols = read_columns(src, unique([dq.run_branch, dq.lumi_branch]))
    runs, lumis = cols[dq.run_branch], cols[dq.lumi_branch]
    length(runs) == length(lumis) || throw(DimensionMismatch("exposure run/lumi length mismatch"))
    mask = load_lumimask(dq.golden_json; run_min = dq.run_min, run_max = dq.run_max)
    observed = Set{Tuple{Int,Int}}()
    for (run, ls) in zip(runs, lumis)
        run isa Integer && ls isa Integer || throw(ArgumentError("exposure run/lumi columns must contain integers"))
        in_lumimask(mask, run, ls) && push!(observed, (Int(run), Int(ls)))
    end
    return [collect(p) for p in sort!(collect(observed))]
end
