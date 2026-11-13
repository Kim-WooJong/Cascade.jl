"""
    pulls(model, result::FitResult) -> Vector{NamedTuple}

Pulls of the floating parameters. For constrained parameters
`pull = (value - center)/sigma_prefit` and `constraint = error/sigma_prefit`
(center is the nominal auxiliary value, 1 for Poisson-constrained gammas);
unconstrained parameters get `NaN` pull/constraint. Each entry has fields
`name, kind, value, error, prefit_center, prefit_sigma, pull, constraint`.
"""
function pulls(model::HistModel, result::FitResult)
    out = NamedTuple[]
    for (i, p) in enumerate(model.parameters)
        result.floating[i] || continue
        v, e = result.parameters[i], result.uncertainties[i]
        if p.constraint === :none
            push!(out, (name=p.name, kind=p.kind, value=v, error=e, prefit_center=NaN,
                        prefit_sigma=NaN, pull=NaN, constraint=NaN))
        else
            c = _prefit_center(p)
            push!(out, (name=p.name, kind=p.kind, value=v, error=e, prefit_center=c,
                        prefit_sigma=p.sigma, pull=(v - c) / p.sigma, constraint=e / p.sigma))
        end
    end
    return out
end

_prefit_center(p::ParameterInfo) = p.constraint === :poisson ? p.aux / p.tau : p.aux
