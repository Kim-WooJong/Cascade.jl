"""
    illustrative_postfit(groups, signal, mu, sigma) -> FitYields

ILLUSTRATIVE postfit yields: the `signal` group scaled by `mu`, others
unchanged; per-bin uncertainty `sigma × S_i ⊕ MC stat_i`. Only a stand-in for
the fit result interface, not a fit.
"""
function illustrative_postfit(groups::AbstractVector{SampleTemplates}, signal::AbstractString, mu::Real, sigma::Real)
    yields = Dict(g.name => (g.name == signal ? mu : 1.0) .* g.nominal.sumw for g in groups)
    sig = only(filter(g -> g.name == signal, groups)).nominal
    stat = sqrt.(reduce(+, (g.nominal.sumw2 for g in groups)))
    errors = hypot.(sigma .* sig.sumw, stat)
    yerr = Dict(g.name => g.name == signal ? hypot(sigma * sum(sig.sumw), sqrt(sum(sig.sumw2))) : sqrt(sum(g.nominal.sumw2))
                for g in groups)
    total = hypot(sigma * sum(sig.sumw), sqrt(sum(stat .^ 2)))
    return FitYields(sig.edges, yields, errors; yield_errors=yerr, total_error=total,
                     label="Postfit unc.")
end
