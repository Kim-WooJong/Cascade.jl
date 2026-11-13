"""
    impact_rows(report::AbstractDict) -> Vector{NamedTuple}

Rows for [`plot_impacts`](@ref) from a `Cascade.Fit.fit_report` dictionary
(also after a JSON round trip): for each impact entry (in ranking order) the
parameter `name`, its `pull` and `constraint` (`NaN` when unconstrained) and
the POI shifts `postfit_up`, `postfit_down`, `prefit_up`, `prefit_down`
(`NaN` when not available).
"""
function impact_rows(report::AbstractDict)
    num(x) = x === nothing ? NaN : Float64(x)
    pars = Dict(String(p["name"]) => p for p in report["parameters"])
    rows = NamedTuple[]
    for x in get(report, "impacts", Any[])
        p = pars[String(x["name"])]
        push!(rows, (name = String(x["name"]), pull = num(p["pull"]), constraint = num(p["constraint"]),
                     postfit_up = num(x["postfit_up"]), postfit_down = num(x["postfit_down"]),
                     prefit_up = num(x["prefit_up"]), prefit_down = num(x["prefit_down"])))
    end
    return rows
end
