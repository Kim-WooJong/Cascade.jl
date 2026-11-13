"""
    profile_interval(model, data, result::FitResult; parameter=POI, level=1.0) -> (lo, hi)

Profile-likelihood interval of `parameter` (name or index): the values where
`2 (NLL_profiled - NLL_min) = level` (1 = 68.3% CL for one parameter), found
with Brent's method on each side of the best fit. A side whose bound is reached
before the crossing returns the bound.
"""
function profile_interval(model::HistModel, data::Dataset, result::FitResult; parameter = nothing,
                          level::Real = 1.0, fixed = (), bounds = ())
    i = parameter === nothing ? _poi_index(model) : _param_index(model, parameter)
    p = model.parameters[i]
    best, sigma = result.parameters[i], result.uncertainties[i]
    sigma > 0 || (sigma = max(abs(best), 1.0) * 0.1)
    f = x -> 2 * (fit(model, data; init = result.parameters, fixed = (collect(fixed)..., p.name => x),
                      bounds = bounds, hesse = false).nll - result.nll) - level
    function side(dir)
        limit = dir > 0 ? p.upper : p.lower
        step = sigma
        x = best
        for _ in 1:30
            xn = clamp(best + dir * step, p.lower, p.upper)
            fn = f(xn)
            fn > 0 && return _brent(f, min(x, xn), max(x, xn); rtol = 1e-6)
            xn == limit && return limit
            x, step = xn, 2 * step
        end
        return limit
    end
    return (side(-1), side(+1))
end
