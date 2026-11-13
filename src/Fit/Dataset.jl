"""
    Dataset(main, aux)

Data entering the likelihood: `main` are the observed counts per bin
(model bin order); `aux` holds one auxiliary measurement per model
parameter (only entries of constrained parameters are used).
"""
struct Dataset
    main::Vector{Float64}
    aux::Vector{Float64}
end

"""
    Dataset(model, main)

Dataset with main counts `main` and the nominal auxiliary data of `model`.
"""
Dataset(model::HistModel, main::AbstractVector{<:Real}) =
    Dataset(Float64.(main), [p.aux for p in model.parameters])

"""
    observed_data(model) -> Dataset

Observed counts stored in the workspace together with nominal auxiliary data.
"""
function observed_data(model::HistModel)
    isempty(model.observations) && throw(ArgumentError("model has no observations"))
    return Dataset(model, model.observations)
end
