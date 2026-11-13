# Standalone synthetic harnesses include CompiledSelection directly; keep the
# new memo implementation available there without changing their include list.
if !isdefined(@__MODULE__, :VariableMemoRegistry)
    isdefined(@__MODULE__, :ExpressionUsage) || include("ExpressionUsage.jl")
    include("VariableMemo.jl")
end

"""
    CompiledSelection

Result of `compile_selection` for one sample kind. `cuts` is a tuple of
`(ctx, i) -> Bool` kernels. `materialize(ctx, i, lo, hi)` builds objects whose
first dependent cut lies in `(lo, hi]`, in dependency order. Output-only objects
use `typemax(Int)` and are completed for kept events. `mat_at` remains the first
object-dependent cut (0: none), for the input prefix mask. `weight` gives the base
nominal weight, `outputs` the tuple of output values of a kept event.
`columns_pre` are read for all events. `column_stages` records the first cut
requiring each post column (including object cleaning/sort dependencies);
`typemax(Int)` means retained-event completion. The ordinary serial NanoAOD
reader may refine masks by those stages. Other readers keep the original
`columns_post` prefix-mask contract.
"""
struct CompiledSelection{C,M,W,O,V}
    kind::Symbol
    cut_names::Vector{String}
    cuts::C
    mat_at::Int
    materialize::M
    weight::W
    outputs::O
    output_names::Vector{String}
    hist_columns::Dict{String,Vector{String}}
    object_names::Vector{String}
    collections::Vector{String}
    columns_pre::Vector{String}
    columns_post::Vector{String}
    builtins::Vector{String}
    region_stage::Dict{String,Int}
    keep_stage::Int
    triggers::TriggerConfig
    data_quality::DataQualityConfig
    column_stages::Dict{String,Int}
    variable_nodes::V
    memoize_max_bytes::Int
end

# Preserve the previous constructor for manually assembled selections. An empty
# plan deliberately uses the conservative, single post-read phase.
function CompiledSelection(kind, cut_names, cuts, mat_at, materialize, weight, outputs,
                           output_names, hist_columns, object_names, collections,
                           columns_pre, columns_post, builtins, region_stage, keep_stage,
                           triggers, data_quality)
    return CompiledSelection(kind, cut_names, cuts, mat_at, materialize, weight, outputs,
                             output_names, hist_columns, object_names, collections,
                             columns_pre, columns_post, builtins, region_stage, keep_stage,
                             triggers, data_quality, Dict{String,Int}())
end

# Also preserve the staged-reader constructor introduced before variable memo.
function CompiledSelection(kind, cut_names, cuts, mat_at, materialize, weight, outputs,
                           output_names, hist_columns, object_names, collections,
                           columns_pre, columns_post, builtins, region_stage, keep_stage,
                           triggers, data_quality, column_stages)
    return CompiledSelection(kind, cut_names, cuts, mat_at, materialize, weight, outputs,
                             output_names, hist_columns, object_names, collections,
                             columns_pre, columns_post, builtins, region_stage, keep_stage,
                             triggers, data_quality, column_stages, (), 268435456)
end
