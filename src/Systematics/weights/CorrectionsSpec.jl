"""
    CorrectionsSpec(sets, object_sfs, event_weights, flat[, trigger_ors])

Parsed `[corrections]` section: `sets` (alias -> resolved file path) and the
weight terms. The nominal weight is the base weight times all terms in the
order `object_sfs`, `event_weights`, `trigger_ors`, `flat` (each in TOML order).
The four-argument constructor remains compatible and supplies no trigger ORs.
`CorrectionsSpec()` is the empty specification (base weight only).
"""
struct CorrectionsSpec
    sets::Dict{String,String}
    object_sfs::Vector{ObjectScaleFactor}
    event_weights::Vector{EventWeight}
    flat::Vector{FlatWeight}
    trigger_ors::Vector{TriggerOR}
end

CorrectionsSpec(sets, object_sfs, event_weights, flat) = CorrectionsSpec(sets, object_sfs, event_weights, flat, TriggerOR[])
CorrectionsSpec() = CorrectionsSpec(Dict{String,String}(), ObjectScaleFactor[], EventWeight[], FlatWeight[], TriggerOR[])

Base.isempty(s::CorrectionsSpec) = isempty(s.object_sfs) && isempty(s.event_weights) && isempty(s.flat) && isempty(s.trigger_ors)
