"""
    asimov_data(model, pars::AbstractVector) -> Dataset

Asimov dataset for parameter vector `pars`: main counts are the expected
yields and auxiliary data the expected auxiliary measurements (Gaussian:
parameter value; Poisson: value * tau).

    asimov_data(model, mu::Real) -> Dataset

Pre-fit Asimov: all parameters at their initial values, POI set to `mu`.

    asimov_data(model, mu::Real, data::Dataset; fixed=(), bounds=()) -> Dataset

Profiled Asimov (pyhf `generate_asimov_data`): nuisance parameters are fitted
to `data` with the POI fixed to `mu`.
"""
function asimov_data(model::HistModel, pars::AbstractVector{<:Real})
    aux = [p.constraint === :poisson ? pars[i] * p.tau :
           p.constraint === :gauss ? Float64(pars[i]) : p.aux
           for (i, p) in enumerate(model.parameters)]
    return Dataset(Float64.(expected_main(model, pars)), aux)
end

function asimov_data(model::HistModel, mu::Real)
    pars = [p.init for p in model.parameters]
    pars[_poi_index(model)] = mu
    return asimov_data(model, pars)
end

function asimov_data(model::HistModel, mu::Real, data::Dataset; fixed=(), bounds=())
    poi = model.parameters[_poi_index(model)].name
    r = fit(model, data; fixed=(collect(fixed)..., poi => mu), bounds=bounds, hesse=false)
    return asimov_data(model, r.parameters)
end
