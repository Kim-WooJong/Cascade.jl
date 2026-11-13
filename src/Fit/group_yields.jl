"""
    group_yields(model, pars, cov, channel; groups=nothing) -> NamedTuple

Yields of the samples of `channel` (name) at parameters `pars`, summed into
`groups` (vector of `group name => sample names`; default: one group per
sample), with uncertainties linearly propagated from `cov` through the exact
Jacobian (correlations between bins, samples and parameters included).

Returns `(groups, yields, errors, integrated, integrated_errors, total,
total_errors, total_integrated, total_integrated_error)`: `yields`/`errors`
are `groups x bins` matrices, `integrated*` per group, `total*` for the sum
of all samples of the channel.
"""
function group_yields(model::HistModel, pars::AbstractVector{<:Real}, cov::AbstractMatrix{<:Real},
                      channel::AbstractString; groups = nothing)
    ci = findfirst(==(channel), model.channels)
    ci === nothing && throw(ArgumentError("unknown channel $channel"))
    terms = [k for (k, s) in enumerate(model.samples) if s.channel == ci]
    names = [model.samples[k].name for k in terms]
    gs = groups === nothing ? [n => [n] for n in names] : [String(first(g)) => String.(last(g)) for g in groups]
    for (g, members) in gs, m in members
        m in names || throw(ArgumentError("group $g: sample $m is not in channel $channel"))
    end
    flat = x -> reduce(vcat, expected_yields(model, x))
    x = Float64.(pars)
    y = flat(x)
    J = ForwardDiff.jacobian(flat, x)
    C = Matrix{Float64}(cov)
    nb = length(model.channel_bins[ci])
    rows = Dict(model.samples[k].name => _sample_rows(model, k) for k in terms)
    Y = zeros(length(gs), nb); E = zeros(length(gs), nb)
    I = zeros(length(gs)); IE = zeros(length(gs))
    for (r, (g, members)) in enumerate(gs)
        Jg = zeros(nb, size(J, 2))
        for m in members
            Y[r, :] .+= y[rows[m]]
            Jg .+= J[rows[m], :]
        end
        E[r, :] .= sqrt.(max.(diag(Jg * C * Jg'), 0.0))
        jg = vec(sum(Jg; dims = 1))
        I[r] = sum(Y[r, :])
        IE[r] = sqrt(max(dot(jg, C * jg), 0.0))
    end
    Jt = zeros(nb, size(J, 2))
    for k in terms
        Jt .+= J[_sample_rows(model, k), :]
    end
    tot = reduce(+, (y[_sample_rows(model, k)] for k in terms))
    jt = vec(sum(Jt; dims = 1))
    return (groups = first.(gs), yields = Y, errors = E, integrated = I, integrated_errors = IE, total = tot,
            total_errors = sqrt.(max.(diag(Jt * C * Jt'), 0.0)), total_integrated = sum(tot),
            total_integrated_error = sqrt(max(dot(jt, C * jt), 0.0)))
end
