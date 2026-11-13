"""
    profile_scan(model, data, name, values; fixed=(), bounds=()) -> NamedTuple

Profile-likelihood scan of parameter `name` over `values`: for each value the
parameter is fixed and all other floating parameters are refitted.

Returns `(values, delta_twice_nll, fits, best)` where
`delta_twice_nll[i] = 2*(nll_i - nll_best)` and `best` is the global fit.
"""
function profile_scan(model::HistModel, data::Dataset, name, values; fixed=(), bounds=())
    best = fit(model, data; fixed=fixed, bounds=bounds, hesse=false)
    fits = FitResult[]
    start = best.parameters
    for v in values
        r = fit(model, data; init=start, fixed=(collect(fixed)..., name => v), bounds=bounds, hesse=false)
        push!(fits, r)
        start = r.parameters
    end
    d = [2 * (r.nll - best.nll) for r in fits]
    return (values=collect(Float64, values), delta_twice_nll=d, fits=fits, best=best)
end
