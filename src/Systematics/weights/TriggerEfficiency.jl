"""
    TriggerEfficiency(set, correction, inputs, systematic, keys)

One data or MC per-object trigger-efficiency correction. Values are
probabilities, not scale factors; `keys` selects nominal/up/down payloads.
"""
struct TriggerEfficiency
    set::String
    correction::String
    inputs::Dict{String,Any}
    systematic::String
    keys::NTuple{3,String}
end
