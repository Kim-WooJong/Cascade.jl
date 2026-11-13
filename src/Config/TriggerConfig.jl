"""
    TriggerConfig

Trigger groups and primary-dataset (stream) overlap removal.

- `groups`: group name -> HLT path branch names (a group fires if any path fires).
- `priority`: data streams in priority order.
- `streams`: stream name -> group names. A data event in stream `S` passes if a
  group of `S` fires and no group of a higher-priority stream fires.
- `mc`: groups OR-ed for simulation.
"""
struct TriggerConfig
    groups::Dict{String,Vector{String}}
    priority::Vector{String}
    streams::Dict{String,Vector{String}}
    mc::Vector{String}
end

TriggerConfig() = TriggerConfig(Dict{String,Vector{String}}(), String[],
                                Dict{String,Vector{String}}(), String[])
