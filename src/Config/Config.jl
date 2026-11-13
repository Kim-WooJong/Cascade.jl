"""
    Cascade.Config

Analysis definition: TOML parsing into typed configuration objects, structural
validation, binning construction and stable hashing of configuration sections.
Expression strings are stored verbatim; they are compiled by `Cascade.Selection`.
"""
module Config

using TOML
using SHA
using JSON3

include("SampleConfig.jl")
include("ObjectConfig.jl")
include("CutConfig.jl")
include("RegionConfig.jl")
include("HistogramConfig.jl")
include("VariationConfig.jl")
include("TriggerConfig.jl")
include("DataQualityConfig.jl")
include("ShapeVariationConfig.jl")
include("AnalysisConfig.jl")
include("parse_binning.jl")
include("substitute_paths.jl")
include("resolve_config.jl")
include("column_readers.jl")
include("decode_options.jl")
include("windowed_selection.jl")
include("streaming_selection_options.jl")
include("memory_handoff.jl")
include("memoization_options.jl")
include("checkpoint_options.jl")
include("event_ranges.jl")
include("validate_keys.jl")
include("parse_analysis.jl")
include("load_analysis.jl")
include("shape_variations.jl")
include("validate_shape_variations.jl")
include("validate_sample_annotations.jl")
include("theory_weights.jl")
include("theory_extraction.jl")
include("validate_theory_manifest.jl")
include("counting_readiness.jl")
include("validate_analysis.jl")
include("streaming_skim_options.jl")
include("reduced_skim_options.jl")
include("canonical_hash.jl")
include("section_hash.jl")
include("sample_by_name.jl")

export event_range_selection, memoization_options, stable_selection_kernels, checkpoints_enabled, windowed_selection, windowed_reusable_decoder, memory_handoff, streaming_selection_options, decode_options, column_readers, AnalysisConfig, SampleConfig, ObjectConfig, CutConfig, RegionConfig,
       HistogramConfig, VariationConfig, TriggerConfig, DataQualityConfig,
       parse_binning, substitute_paths, parse_analysis, load_analysis,
       counting_readiness, require_counting_ready, reduced_skim_options, theory_extraction, validate_theory_manifest, theory_weights, validate_analysis, canonical_hash, section_hash, sample_by_name,
       resolve_config, validate_keys, is_mc, is_data, ShapeVariationConfig, shape_variations, validate_shape_variations

end # module
