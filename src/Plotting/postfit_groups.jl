"""
    postfit_groups(fit::FitYields, config::StackConfig) -> Vector{SampleTemplates}

Postfit yields summed into the stack groups of `config` (bottom to top). Each
process of `fit` must be either a group label or a sample of exactly one group;
processes not covered by `config` are an error so no yield is dropped. The
resulting templates carry zero `sumw2` (the postfit uncertainty lives in
[`postfit_band`](@ref)).
"""
function postfit_groups(fit::FitYields, config::StackConfig)
    n = length(fit.edges) - 1
    owner = Dict{String,String}()
    for g in config.groups
        owner[g.label] = g.label
        for s in g.samples
            owner[s] = g.label
        end
    end
    sums = Dict(g.label => zeros(n) for g in config.groups)
    used = Dict(g.label => false for g in config.groups)
    for (process, y) in fit.yields
        haskey(owner, process) || throw(ArgumentError("postfit process $process is not in the plotting configuration"))
        sums[owner[process]] .+= y
        used[owner[process]] = true
    end
    for g in config.groups
        used[g.label] || throw(ArgumentError("no postfit yield for group $(g.label)"))
    end
    return [SampleTemplates(g.label, binned_hist(fit.edges, sums[g.label], zeros(n))) for g in config.groups]
end
