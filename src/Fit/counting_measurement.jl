"""
    counting_measurement(cfg, rows; observed, nuisances, lumi_relative)

One-region yield-subtraction cross-check, not a low-count likelihood interval.
Rows contain name, sumw and sumw2 AFTER luminosity and decay-BR normalization.
Each correlated nuisance supplies complete sample => (up, down) yield templates;
correlations are preserved by recomputing the total estimator before quadrature.
Luminosity is external and rescales ALL MC, not just signal. No additional BR
factor is accepted. All six evidence classes must pass before any result exists.
"""
function counting_measurement(cfg, rows; observed, nuisances, lumi_relative)
    get(require_counting_ready(cfg), "status", "") == "ready" || throw(ArgumentError("counting configuration required"))
    c = cfg.raw["counting"]
    observed isa Integer && !(observed isa Bool) && observed >= 0 || throw(ArgumentError("observed must be a nonnegative unweighted integer"))
    lumi_relative isa Real && !(lumi_relative isa Bool) && isfinite(lumi_relative) && 0 <= lumi_relative < 1 || throw(ArgumentError("invalid luminosity uncertainty"))
    names = [r.name for r in rows]
    length(unique(names)) == length(names) || throw(ArgumentError("duplicate sample rows"))
    expected = Set(vcat(c["signal_samples"], c["background_samples"]))
    Set(names) == expected || throw(ArgumentError("missing/foreign sample rows"))
    all(r -> isfinite(r.sumw) && isfinite(r.sumw2) && r.sumw2 >= 0, rows) || throw(ArgumentError("invalid weighted moments"))
    signals = Set(c["signal_samples"])
    s = sum(r.sumw for r in rows if r.name in signals)
    b = sum(r.sumw for r in rows if !(r.name in signals))
    vs = sum(r.sumw2 for r in rows if r.name in signals)
    vb = sum(r.sumw2 for r in rows if !(r.name in signals))
    s > 0 || throw(ArgumentError("nonpositive signed signal yield"))
    sigma = c["sigma_ref_pb"]
    mu = (observed - b) / s
    shifts = Dict{String,Tuple{Float64,Float64}}()
    for (name, templates) in nuisances
        occursin("lumi", lowercase(name)) && throw(ArgumentError("luminosity cannot be counted twice"))
        Set(keys(templates)) == expected || throw(ArgumentError("nuisance $name must explicitly cover all sample rows"))
        up = down = 0.0
        for side in 1:2
            sy = by = 0.0
            for row in rows
                pair = templates[row.name]
                length(pair) == 2 && all(isfinite, pair) || throw(ArgumentError("invalid nuisance yield"))
                row.name in signals ? (sy += pair[side]) : (by += pair[side])
            end
            sy > 0 || throw(ArgumentError("nonpositive varied signal yield"))
            shift = sigma * ((observed - by) / sy - mu)
            side == 1 ? (up = shift) : (down = shift)
        end
        shifts[String(name)] = (up, down)
    end
    # External luminosity changes background subtraction as well as signal scale.
    lu = sigma * ((observed - b * (1 + lumi_relative)) / (s * (1 + lumi_relative)) - mu)
    ld = sigma * ((observed - b * (1 - lumi_relative)) / (s * (1 - lumi_relative)) - mu)
    return (status = "validated_inputs_crosscheck", region = c["region"], sigma_pb = sigma * mu,
            mu = mu, data = observed, signal = s, background = b,
            data_stat_pb = sigma * sqrt(observed) / s,
            mc_stat_pb = sigma * sqrt(vb / s^2 + (observed - b)^2 * vs / s^4),
            nuisance_shifts_pb = shifts,
            nuisance_envelope_quadrature_pb = sqrt(sum(max(abs(u), abs(d))^2 for (u,d) in values(shifts); init=0.0)),
            lumi_shifts_pb = (lu, ld), interval_method = "delta_method_not_profile_likelihood")
end
