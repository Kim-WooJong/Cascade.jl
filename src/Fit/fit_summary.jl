"""
    fit_summary(report::AbstractDict; max_impacts=20) -> String

Human-readable text summary of a [`fit_report`](@ref) dictionary: POI with
Hesse error and profile interval, the counting cross-check per channel,
optional upper limit and significance, the parameter table (value, error, pull,
constraint), the impact ranking (first `max_impacts` entries), placeholder
normalisation uncertainties and build notes.
"""
function fit_summary(report::AbstractDict; max_impacts::Integer = 20)
    f(x, d = 4) = x === nothing ? "n/a" : x isa Real ? (isfinite(x) ? string(round(Float64(x); digits = d)) : "n/a") : string(x)
    io = IOBuffer()
    println(io, "Fit summary (", report["dataset"], " data): status=", report["status"], " nll=", f(report["nll"], 6),
            " edm=", f(report["edm"], 12), " iterations=", report["iterations"])
    println(io, "POI ", report["poi"], " = ", f(report["poi_value"]), " ± ", f(report["poi_error"]), " (Hesse)")
    if haskey(report, "poi_interval")
        lo, hi = report["poi_interval"]
        v = report["poi_value"]
        println(io, "    profile interval [", f(lo), ", ", f(hi), "] = ", f(v), " -", f(v - lo), " +", f(hi - v))
    end
    for c in get(report, "counting", Any[])
        println(io, "Counting cross-check ", c["channel"], ": N=", f(c["data"], 1), " S=", f(c["signal"], 3),
                " B=", f(c["background"], 3), " mu=(N-B)/S=", f(c["mu"]), " ± ", f(c["mu_stat_error"]), " (data stat.)")
    end
    if haskey(report, "upper_limit")
        u = report["upper_limit"]
        println(io, "95% CLs upper limit: observed ", f(u["observed"]), ", expected ", join(f.(u["expected"]), " / "))
    end
    if haskey(report, "significance")
        s = report["significance"]
        println(io, "Significance: Z=", f(s["Z"]), " (p0=", f(s["p0"], 8), "), expected Z=", f(s["Z_expected"]))
    end
    println(io, "\nParameters:")
    rows = [["name", "kind", "value", "error", "pull", "constraint"]]
    for p in report["parameters"]
        push!(rows, [p["name"], p["kind"], f(p["value"]), p["floating"] ? f(p["error"]) : "fixed", f(p["pull"], 3),
                     f(p["constraint"], 3)])
    end
    _print_rows(io, rows)
    if haskey(report, "impacts") && !isempty(report["impacts"])
        println(io, "\nImpacts on ", report["poi"], " (postfit ±1σ, prefit ±1σ):")
        rows = [["name", "postfit up", "postfit down", "prefit up", "prefit down"]]
        for x in report["impacts"][1:min(end, max_impacts)]
            push!(rows, [x["name"], f(x["postfit_up"], 5), f(x["postfit_down"], 5), f(x["prefit_up"], 5),
                         f(x["prefit_down"], 5)])
        end
        _print_rows(io, rows)
    end
    ph = [n for n in get(report, "normsys", Any[]) if n["placeholder"]]
    if !isempty(ph)
        println(io, "\nPLACEHOLDER normalisation uncertainties (assumed values, not validated):")
        for n in ph
            println(io, "  ", n["name"], ": hi=", f(n["hi"]), " lo=", f(n["lo"]), " on ", join(n["samples"], ", "))
        end
    end
    notes = get(report, "notes", Any[])
    isempty(notes) || println(io, "\nNotes:\n", join(("  " * n for n in notes), "\n"))
    return String(take!(io))
end

function _print_rows(io, rows)
    w = [maximum(length(string(r[j])) for r in rows) for j in eachindex(rows[1])]
    for r in rows
        println(io, "  ", join((j == 1 ? rpad(string(c), w[j]) : lpad(string(c), w[j]) for (j, c) in enumerate(r)), "  "))
    end
end
