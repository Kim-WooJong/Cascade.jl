const _HALF_LOG_2PI = 0.5 * log(2pi)

"""
    nll(model, pars, data::Dataset)

Negative log-likelihood `-log L` including all normalisation constants
(Poisson terms use `loggamma(n+1)`), identical in value to pyhf's
`-logpdf`. Returns `Inf` if an expected yield is negative, or zero with
nonzero observed count.
"""
function nll(model::HistModel, pars::AbstractVector{T}, data::Dataset) where {T<:Real}
    lam = expected_main(model, pars)
    s = zero(T)
    for b in eachindex(lam)
        n = data.main[b]
        l = lam[b]
        if n == 0
            _likelihood_value(l) < 0 && return convert(T, Inf)
            s += l
            continue
        end
        if !(_likelihood_value(l) > 0)
            return convert(T, Inf)
        end
        s += l - n * log(l) + loggamma(n + 1)
    end
    for (i, p) in enumerate(model.parameters)
        if p.constraint === :gauss
            z = (pars[i] - data.aux[i]) / p.sigma
            s += 0.5 * z * z + log(p.sigma) + _HALF_LOG_2PI
        elseif p.constraint === :poisson
            r = pars[i] * p.tau
            a = data.aux[i]
            s += r - (a == 0 ? zero(T) : a * log(r)) + loggamma(a + 1)
        end
    end
    return s
end

# Branch on values rather than Dual partials at empty bins: NLL(n=0) = lambda.
_likelihood_value(x::Real) = x
_likelihood_value(x::ForwardDiff.Dual) = _likelihood_value(ForwardDiff.value(x))
