# Profile-likelihood test statistics (arXiv:1007.1727), pyhf conventions.

"""
    tmu(model, data, mu; fixed=(), bounds=()) -> Float64

`-2 log lambda(mu)` = `2*(nll(mu, conditional) - nll(global))`, clipped at 0.
"""
tmu(model::HistModel, data::Dataset, mu::Real; fixed=(), bounds=()) =
    _teststat(model, data, mu, :t; fixed=fixed, bounds=bounds).value

"""
    qmu(model, data, mu; fixed=(), bounds=()) -> Float64

One-sided upper-limit statistic: `tmu` if `muhat <= mu`, else 0. Uses the
model POI bounds unchanged (pyhf `qmu`).
"""
qmu(model::HistModel, data::Dataset, mu::Real; fixed=(), bounds=()) =
    _teststat(model, data, mu, :q; fixed=fixed, bounds=bounds).value

"""
    qmu_tilde(model, data, mu; fixed=(), bounds=()) -> Float64

Like [`qmu`](@ref) with the POI lower bound forced to 0 (pyhf `qmu_tilde`).
"""
qmu_tilde(model::HistModel, data::Dataset, mu::Real; fixed=(), bounds=()) =
    _teststat(model, data, mu, :qtilde; fixed=fixed, bounds=bounds).value

"""
    q0(model, data; fixed=(), bounds=()) -> Float64

Discovery statistic: `tmu(0)` if `muhat >= 0`, else 0.
"""
q0(model::HistModel, data::Dataset; fixed=(), bounds=()) =
    _teststat(model, data, 0.0, :q0; fixed=fixed, bounds=bounds).value

function _poi_index(model::HistModel)
    model.poi > 0 || throw(ArgumentError("model has no parameter of interest"))
    return model.poi
end

function _stat_bounds(model::HistModel, kind::Symbol, bounds)
    kind === :qtilde || return bounds
    p = model.parameters[_poi_index(model)]
    return (collect(bounds)..., p.name => (0.0, p.upper))
end

# Returns (value, free, cond). `free` may be passed to reuse a global fit.
function _teststat(model::HistModel, data::Dataset, mu::Real, kind::Symbol;
                   fixed=(), bounds=(), free=nothing)
    ip = _poi_index(model)
    poi = model.parameters[ip].name
    b = _stat_bounds(model, kind, bounds)
    free === nothing && (free = fit(model, data; fixed=fixed, bounds=b, hesse=false))
    cond = fit(model, data; init=free.parameters, fixed=(collect(fixed)..., poi => mu),
               bounds=b, hesse=false)
    t = max(2 * (cond.nll - free.nll), 0.0)
    muhat = free.parameters[ip]
    value = if kind === :t
        t
    elseif kind === :q || kind === :qtilde
        muhat > mu ? 0.0 : t
    elseif kind === :q0
        muhat < 0 ? 0.0 : t
    else
        throw(ArgumentError("unknown test statistic $kind"))
    end
    return (value=value, free=free, cond=cond)
end
