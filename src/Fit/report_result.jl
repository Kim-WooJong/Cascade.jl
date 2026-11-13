"""
    report_result(report::AbstractDict, model::HistModel) -> FitResult

Best-fit [`FitResult`](@ref) of a [`fit_report`](@ref) dictionary (also after a
JSON round trip) for `model` (see [`report_model`](@ref)); parameters are
matched by name.
"""
function report_result(report::AbstractDict, model::HistModel)
    ps = report["parameters"]
    names = [String(p["name"]) for p in ps]
    sort(names) == sort([p.name for p in model.parameters]) ||
        throw(ArgumentError("fit report parameters do not match the model"))
    perm = [findfirst(==(p.name), names) for p in model.parameters]
    num(x) = x === nothing ? NaN : Float64(x)
    vals = [num(ps[j]["value"]) for j in perm]
    errs = [num(ps[j]["error"]) for j in perm]
    cov = [num(report["covariance"][a][b]) for a in perm, b in perm]
    floating = [Bool(ps[j]["floating"]) for j in perm]
    nll = num(report["nll"]); edm = num(report["edm"])
    return FitResult(vals, errs, cov, [p.name for p in model.parameters], floating, nll, edm,
                     Int(report["iterations"]), Bool(report["converged"]))
end
