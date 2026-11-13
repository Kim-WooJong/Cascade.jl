"""
    fit_yields(model::HistModel, result::FitResult, channel; edges, groups=nothing,
               label="Postfit unc.") -> FitYields

Adapter from a `Cascade.Fit` result to the postfit plotting interface
[`FitYields`](@ref): the postfit yields of the samples of `channel` summed into
`groups` (vector of `process name => fit sample names`; default one process
per fit sample) and their uncertainties from the fit covariance
(`Fit.group_yields`: per-bin total error, integrated error per process and of
the total, all correlations included). `edges` are the channel's bin edges.
"""
function fit_yields(model::HistModel, result::FitResult, channel::AbstractString; edges::AbstractVector{<:Real},
                    groups = nothing, label::AbstractString = "Postfit unc.")
    g = group_yields(model, result.parameters, result.covariance, channel; groups)
    length(edges) == size(g.yields, 2) + 1 || throw(ArgumentError("edges do not match the bins of channel $channel"))
    yields = Dict(n => g.yields[i, :] for (i, n) in enumerate(g.groups))
    errs = Dict(n => g.integrated_errors[i] for (i, n) in enumerate(g.groups))
    return FitYields(edges, yields, g.total_errors; yield_errors = errs, total_error = g.total_integrated_error, label)
end
