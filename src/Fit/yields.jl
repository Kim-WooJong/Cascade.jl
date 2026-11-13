"""
    ChannelYields

Per-channel yield table for plotting: `yields`/`yield_errors` are
(samples x bins) matrices, `total`/`total_errors` the per-bin sum over
samples with its uncertainty (correlations included), `data` the observed
counts (empty if unknown).
"""
struct ChannelYields
    channel::String
    samples::Vector{String}
    yields::Matrix{Float64}
    yield_errors::Matrix{Float64}
    total::Vector{Float64}
    total_errors::Vector{Float64}
    data::Vector{Float64}
end

"""
    yields_with_uncertainty(model, pars, cov; data=Float64[]) -> Vector{ChannelYields}

Expected yields at `pars` with linearly propagated uncertainties
`sqrt(diag(J * cov * J'))`, `J` the exact Jacobian of the yields.
"""
function yields_with_uncertainty(model::HistModel, pars::AbstractVector{<:Real},
                                 cov::AbstractMatrix{<:Real}; data=Float64[])
    flat = x -> reduce(vcat, expected_yields(model, x))
    y = flat(Float64.(pars))
    J = ForwardDiff.jacobian(flat, Float64.(pars))
    out = ChannelYields[]
    offset = 0
    for (ci, ch) in enumerate(model.channels)
        terms = [k for (k, s) in enumerate(model.samples) if s.channel == ci]
        nb = length(model.channel_bins[ci])
        Y = zeros(length(terms), nb)
        E = zeros(length(terms), nb)
        Jtot = zeros(nb, size(J, 2))
        for (r, k) in enumerate(terms)
            rows = _sample_rows(model, k)
            Js = J[rows, :]
            Y[r, :] .= y[rows]
            E[r, :] .= sqrt.(max.(diag(Js * cov * Js'), 0.0))
            Jtot .+= Js
        end
        tot = vec(sum(Y; dims=1))
        terr = sqrt.(max.(diag(Jtot * cov * Jtot'), 0.0))
        d = isempty(data) ? Float64[] : Float64.(data[model.channel_bins[ci]])
        push!(out, ChannelYields(ch, [model.samples[k].name for k in terms], Y, E, tot, terr, d))
    end
    return out
end

function _sample_rows(model::HistModel, k::Int)
    start = sum((length(model.samples[j].nominal) for j in 1:(k - 1)); init=0)
    return (start + 1):(start + length(model.samples[k].nominal))
end

"""
    prefit_yields(model; data=model.observations) -> Vector{ChannelYields}

Pre-fit yields (parameters at `init`) with uncertainties from the pre-fit
widths of the floating constrained parameters (uncorrelated).
"""
function prefit_yields(model::HistModel; data=model.observations)
    ps = model.parameters
    cov = Diagonal([(p.constraint !== :none && !p.fixed) ? p.sigma^2 : 0.0 for p in ps])
    return yields_with_uncertainty(model, [p.init for p in ps], Matrix(cov); data=data)
end

"""
    postfit_yields(model, result::FitResult; data=model.observations) -> Vector{ChannelYields}

Post-fit yields at the best fit with uncertainties from the fit covariance.
"""
postfit_yields(model::HistModel, result::FitResult; data=model.observations) =
    yields_with_uncertainty(model, result.parameters, result.covariance; data=data)
