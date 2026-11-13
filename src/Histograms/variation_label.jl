"""
    NOMINAL

Variation label of the nominal histograms (`"nominal"`).
"""
const NOMINAL = "nominal"

"""
    variation_label(name, direction::Symbol) -> String

Label of a systematic variation, `"<name>Up"` or `"<name>Down"` (combine/ROOT
convention). `direction` is `:up` or `:down`.
"""
function variation_label(name::AbstractString, direction::Symbol)
    direction === :up && return string(name, "Up")
    direction === :down && return string(name, "Down")
    throw(ArgumentError("direction must be :up or :down"))
end
