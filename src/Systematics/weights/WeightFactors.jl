"""
    WeightFactors(name, nominal, up, down)

Per-row factors of one weight term. `up`/`down` are `nothing` when the term
has no variation.
"""
struct WeightFactors
    name::String
    nominal::Vector{Float64}
    up::Union{Nothing,Vector{Float64}}
    down::Union{Nothing,Vector{Float64}}
end
