"""
    AnalysisConfig

Complete analysis definition parsed from a TOML file (see `load_analysis`).
`raw` keeps the parsed TOML (after path substitution) so that sections owned by
other areas (`corrections`, `systematics`, `fit`, `plot`) are available to
their hooks and to `section_hash`.
"""
struct AnalysisConfig
    name::String
    path::String
    dir::String
    lumi_pb::Float64
    samples::Vector{SampleConfig}
    objects::Vector{ObjectConfig}
    variables::Dict{String,String}
    cuts::Vector{CutConfig}
    regions::Vector{RegionConfig}
    histograms::Vector{HistogramConfig}
    weights_mc::Vector{String}
    weights_data::Vector{String}
    variations::Vector{VariationConfig}
    triggers::TriggerConfig
    data_quality::DataQualityConfig
    output_columns::Vector{String}
    workdir::String
    raw::Dict{String,Any}
end
