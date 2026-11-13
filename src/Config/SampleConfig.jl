"""
    SampleConfig

One input sample (dataset). `kind` is `:mc` or `:data`. `files` holds path
patterns (globs allowed) after `\${name}` substitution. For MC the cross section
used for normalisation is `xsec_pb * branching_ratio` (pb). For data `stream`
names the trigger stream used for primary-dataset overlap removal.
`format` selects the event-source implementation (see `Cascade.IO.open_source`).
"""
struct SampleConfig
    name::String
    kind::Symbol
    files::Vector{String}
    format::String
    xsec_pb::Float64
    branching_ratio::Float64
    stream::String
    group::String
    raw::Dict{String,Any}
end

"""
    is_mc(s::SampleConfig) -> Bool

True for simulated samples.
"""
is_mc(s::SampleConfig) = s.kind === :mc

"""
    is_data(s::SampleConfig) -> Bool

True for collision-data samples.
"""
is_data(s::SampleConfig) = s.kind === :data
