"""
    ShapePlan

Shape variations of one sample prepared for a compiled selection:
`variations` (in configuration order), `used` (columns read by the
selection), `inputs` (columns to read in addition), `replaces` (columns that
may be varied) and `labels` (`<name>Up`, `<name>Down`, ... in order).
"""
struct ShapePlan
    variations::Vector{ShapeVariation}
    used::Set{String}
    inputs::Vector{String}
    replaces::Vector{String}
    labels::Vector{String}
end
