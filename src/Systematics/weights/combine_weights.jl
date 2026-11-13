"""
    combine_weights(base, terms::Vector{WeightFactors}) -> Dict{String,Vector{Float64}}

`"nominal"` = `base` times the nominal factors of all terms (left to right,
in term order). For every varied term name `v` (first-appearance order):
`"<v>Up"`/`"<v>Down"` = the same product with the up/down factors of the
terms named `v`.
"""
function combine_weights(base::AbstractVector{<:Real}, terms::Vector{WeightFactors})
    nominal = Vector{Float64}(base)
    for t in terms
        nominal .*= t.nominal
    end
    out = Dict{String,Vector{Float64}}("nominal" => nominal)
    names = unique([t.name for t in terms if t.up !== nothing])
    for v in names, (dir, sfx) in ((:up, "Up"), (:down, "Down"))
        w = Vector{Float64}(base)
        for t in terms
            w .*= (t.name == v && t.up !== nothing) ? getfield(t, dir) : t.nominal
        end
        out[string(v, sfx)] = w
    end
    return out
end
