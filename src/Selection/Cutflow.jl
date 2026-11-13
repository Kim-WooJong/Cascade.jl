"""
    Cutflow(names)

Sequential cutflow: `n[k]`, `sumw[k]`, `sumw2[k]` accumulate the events that
passed the first `k-1` cuts (`names[1] == "all"`).
"""
struct Cutflow
    names::Vector{String}
    n::Vector{Int}
    sumw::Vector{Float64}
    sumw2::Vector{Float64}
end

Cutflow(names::AbstractVector{<:AbstractString}) =
    Cutflow(String.(names), zeros(Int, length(names)), zeros(length(names)), zeros(length(names)))

"""
    record!(cf::Cutflow, passed::Integer, w::Real) -> cf

Record one event that passed `passed` sequential cuts with weight `w`
(stages `1:passed+1` are incremented, in order).
"""
@inline function record!(cf::Cutflow, passed::Integer, w::Real)
    for k in 1:passed+1
        cf.n[k] += 1
        cf.sumw[k] += w
        cf.sumw2[k] += w * w
    end
    return cf
end

"""
    cutflow_dict(cf::Cutflow) -> Dict{String,Any}

JSON-friendly representation (inverse: `cutflow_from_dict`).
"""
cutflow_dict(cf::Cutflow) = Dict{String,Any}("names" => cf.names, "n" => cf.n, "sumw" => cf.sumw, "sumw2" => cf.sumw2)

"""
    cutflow_from_dict(d) -> Cutflow

Rebuild a `Cutflow` from `cutflow_dict` output.
"""
cutflow_from_dict(d) = Cutflow(String.(d["names"]), Int.(d["n"]), Float64.(d["sumw"]), Float64.(d["sumw2"]))
