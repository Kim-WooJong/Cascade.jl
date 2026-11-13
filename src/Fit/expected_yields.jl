"""
    expected_yields(model, pars) -> Vector{Vector}

Expected yields per sample term (in `model.samples` order) for parameter
vector `pars`. Generic in the element type so it can be differentiated.
"""
function expected_yields(model::HistModel, pars::AbstractVector{T}) where {T<:Real}
    out = Vector{Vector{T}}(undef, length(model.samples))
    for (k, s) in enumerate(model.samples)
        y = collect(T, s.nominal)
        for h in s.histosys
            a = pars[h.par]
            for b in eachindex(y)
                y[b] += histosys_delta(h.code, a, s.nominal[b], h.up[b], h.dn[b])
            end
        end
        f = one(T)
        for p in s.factors
            f *= pars[p]
        end
        for n in s.normsys
            f *= normsys_factor(n.code, pars[n.par], n.hi, n.lo, n.coeffs)
        end
        for b in eachindex(y)
            v = y[b] * f
            for bf in s.binfactors
                v *= pars[bf[b]]
            end
            y[b] = v
        end
        out[k] = y
    end
    return out
end

"""
    expected_main(model, pars) -> Vector

Total expected main-measurement yield per bin (all channels concatenated in
model order) for parameter vector `pars`.
"""
function expected_main(model::HistModel, pars::AbstractVector{T}) where {T<:Real}
    nb = isempty(model.channel_bins) ? 0 : last(model.channel_bins[end])
    tot = zeros(T, nb)
    for (s, y) in zip(model.samples, expected_yields(model, pars))
        tot[s.bins] .+= y
    end
    return tot
end
