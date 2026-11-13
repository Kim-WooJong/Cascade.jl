"""
    FlatWeight(name, nominal, up, down)

Constant factor with constant up/down factors (`[[corrections.flat]]`), e.g.
a normalisation uncertainty placeholder for a scale factor that is not
available as a correction set. All factors multiply the event weight.
"""
struct FlatWeight
    name::String
    nominal::Float64
    up::Float64
    down::Float64
end
