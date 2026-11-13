"""
    SignificanceResult

Discovery test result: observed `q0`, p-value `p0` and significance `Z`,
plus the median expected values from the Asimov dataset with POI = 1.
"""
struct SignificanceResult
    q0::Float64
    p0::Float64
    Z::Float64
    q0_expected::Float64
    p0_expected::Float64
    Z_expected::Float64
end

"""
    significance(model, data; fixed=(), bounds=()) -> SignificanceResult

Asymptotic discovery significance `Z = sqrt(q0)`, `p0 = 1 - Phi(Z)`. The
expected values use the Asimov dataset generated with POI = 1 and nuisance
parameters fitted to `data` (pyhf convention).
"""
function significance(model::HistModel, data::Dataset; fixed=(), bounds=())
    q = q0(model, data; fixed=fixed, bounds=bounds)
    asimov = asimov_data(model, 1.0, data; fixed=fixed, bounds=bounds)
    qA = q0(model, asimov; fixed=fixed, bounds=bounds)
    return SignificanceResult(q, _normal_sf(sqrt(q)), sqrt(q), qA, _normal_sf(sqrt(qA)), sqrt(qA))
end
