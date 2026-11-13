"""
    EventWeight

Per-event weight (`[[corrections.event_weight]]`), e.g. pileup: correction
`correction` of the set file `set`, `inputs` mapping correction inputs to
constants or event expressions (branch names such as `Pileup_nTrueInt`, or
names of `[output] columns` variables), `systematic` input and `keys =
(nominal, up, down)` as for `ObjectScaleFactor`.
"""
struct EventWeight
    name::String
    set::String
    correction::String
    inputs::Dict{String,Any}
    systematic::String
    keys::NTuple{3,String}
end
