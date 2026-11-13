"""
    present_stack(config::StackConfig, available) -> Union{StackConfig,Nothing}

The part of `config` whose samples are `available` (collection of sample
names): groups without any available sample are dropped, unavailable members
and data samples removed. `nothing` when no group remains.
"""
function present_stack(config::StackConfig, available)
    groups = SampleGroup[]
    for g in config.groups
        ms = [s for s in g.samples if s in available]
        isempty(ms) || push!(groups, SampleGroup(g.label, g.color, ms))
    end
    isempty(groups) && return nothing
    return StackConfig(groups, [d for d in config.data if d in available])
end
