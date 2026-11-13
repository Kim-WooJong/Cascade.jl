"""
    postfit_band(fit::FitYields) -> UncertaintyBand

Band of the postfit prediction: the summed postfit yields with the fit's total
per-bin uncertainty (`fit.errors_high`, `fit.errors_low`) stored as the
total and as the systematic part (the statistical part is zero because MC
statistics are part of the fitted model). No per-nuisance breakdown is kept.
"""
function postfit_band(fit::FitYields)
    n = length(fit.edges) - 1
    prediction = reduce(+, values(fit.yields))
    return UncertaintyBand(fit.edges, prediction, zeros(n), fit.errors_high, fit.errors_low,
                           fit.errors_high, fit.errors_low, String[], Tuple{Vector{Float64},Vector{Float64}}[],
                           fit.label)
end
