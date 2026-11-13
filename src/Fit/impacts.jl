"""
    impacts(model, data, result::FitResult; parameters=nothing, fixed=(), bounds=())
        -> Vector{NamedTuple}

Impact of each nuisance parameter on the POI: the parameter is fixed at
`value +- sigma` and all other parameters are refitted; the impact is the
POI shift relative to `result`. Post-fit uses the fitted error, pre-fit the
pre-fit constraint width (`NaN` for unconstrained parameters).
Default `parameters`: all floating non-POI parameters of `result`.
Entries have fields `name, value, error, prefit_up, prefit_down, postfit_up,
postfit_down` (shifts of the POI). Fits run multi-threaded.
"""
function impacts(model::HistModel, data::Dataset, result::FitResult; parameters=nothing,
                 fixed=(), bounds=())
    ip = _poi_index(model)
    muhat = result.parameters[ip]
    idx = parameters === nothing ?
          [i for i in eachindex(model.parameters) if result.floating[i] && i != ip] :
          [_param_index(model, k) for k in parameters]
    out = Vector{NamedTuple}(undef, length(idx))
    Threads.@threads for j in eachindex(idx)
        i = idx[j]
        p = model.parameters[i]
        v, e = result.parameters[i], result.uncertainties[i]
        shift = x -> begin
            x = clamp(x, p.lower, p.upper)
            r = fit(model, data; init=result.parameters, fixed=(collect(fixed)..., p.name => x),
                    bounds=bounds, hesse=false)
            r.parameters[ip] - muhat
        end
        pre_up = pre_dn = NaN
        if p.constraint !== :none
            pre_up, pre_dn = shift(v + p.sigma), shift(v - p.sigma)
        end
        out[j] = (name=p.name, value=v, error=e, prefit_up=pre_up, prefit_down=pre_dn,
                  postfit_up=shift(v + e), postfit_down=shift(v - e))
    end
    return out
end
