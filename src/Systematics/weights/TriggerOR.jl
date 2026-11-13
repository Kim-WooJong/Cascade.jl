"""
    TriggerOR(name, path, object, indices, when, data, mc)

OR of independent objects satisfying one single-object trigger path. Separate
data and MC efficiencies determine the event SF. This is not a product of
object SFs and does not model correlated paths or multi-object trigger legs.
"""
struct TriggerOR
    name::String
    path::String
    object::String
    indices::Vector{Int}
    when::String
    data::TriggerEfficiency
    mc::TriggerEfficiency
end
