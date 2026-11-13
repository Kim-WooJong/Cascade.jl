"""
    illustrative_normfactor(groups, data, signal) -> (mu, sigma)

ILLUSTRATIVE one-parameter "fit" used only to exercise the postfit interface:
the normalisation of the group named `signal` that makes the integrated
prediction equal to the integrated data, `mu = (N - B) / S`, with the data
statistical error `sigma = sqrt(N) / S`. Not a profile-likelihood fit.
"""
function illustrative_normfactor(groups::AbstractVector{SampleTemplates}, data::BinnedHist, signal::AbstractString)
    s = sum(only(filter(g -> g.name == signal, groups)).nominal.sumw)
    b = sum(sum(g.nominal.sumw) for g in groups if g.name != signal)
    n = sum(data.sumw)
    return (n - b) / s, sqrt(n) / s
end
