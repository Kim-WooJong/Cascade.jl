"""
    ObjectScaleFactor

Per-object scale factor (`[[corrections.object_sf]]`): correction `correction`
of the set file `set` evaluated for the selected objects `object` at
positions `indices` (1 = leading selected object) and multiplied over them.
`when` (object expression, `""` = always) restricts the objects that get a
factor (others contribute 1). `inputs` maps correction input names to
constants (numbers, strings) or object expressions (e.g. `"abs(eta)"`).
`systematic` names the string input that selects nominal/up/down with the
keys `keys = (nominal, up, down)` (`""` up/down: no variation).
`name` labels the variation (`<name>Up`, `<name>Down`).
"""
struct ObjectScaleFactor
    name::String
    set::String
    correction::String
    object::String
    indices::Vector{Int}
    when::String
    inputs::Dict{String,Any}
    systematic::String
    keys::NTuple{3,String}
end
