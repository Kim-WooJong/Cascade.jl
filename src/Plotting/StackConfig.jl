"""
    StackConfig(groups::Vector{SampleGroup}, data::Vector{String})

Stack definition: `groups` from the bottom of the stack to the top, and the
data sample names summed into the observed histogram (may be empty).
Built from an analysis configuration with [`stack_config`](@ref).
"""
struct StackConfig
    groups::Vector{SampleGroup}
    data::Vector{String}

    function StackConfig(groups::AbstractVector{SampleGroup}, data::AbstractVector)
        isempty(groups) && throw(ArgumentError("at least one sample group is needed"))
        labels = [g.label for g in groups]
        allunique(labels) || throw(ArgumentError("group labels must be unique"))
        members = reduce(vcat, (g.samples for g in groups))
        allunique(members) || throw(ArgumentError("a sample belongs to more than one group"))
        isempty(intersect(members, String.(data))) || throw(ArgumentError("a sample is both data and simulation"))
        return new(collect(groups), String.(data))
    end
end
