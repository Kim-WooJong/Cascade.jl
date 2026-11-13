"""
    Cascade.Selection

Compiles the analysis definition (objects, variables, cuts, regions, weights,
histogram values) into type-stable Julia kernels and runs them over one event
chunk, producing a cutflow and an `EventTable` of kept events.

Expressions are plain Julia syntax restricted to a whitelist (see
`parse_expression`). Event scope: branch names (`run`, `genWeight`), builtins
(`trigger`, `lumimask`), variables, `length(obj)` and `obj.field[k]`. Object
scope: collection fields (`pt`, `eta`, ...).
"""
module Selection

using ..Config
using ..IO
import ..IO as EventIO
using ..Objects

include("Kernels.jl")
include("KernelContext.jl")
include("CachedObjectBuffer.jl")
include("ExpressionUsage.jl")
include("VariableMemo.jl")
include("parse_expression.jl")
include("translate_expression.jl")
include("compile_kernel.jl")
include("StableKernel.jl")
include("Cutflow.jl")
include("merge_cutflow.jl")
include("EventTable.jl")
include("region_masks.jl")
include("region_counts.jl")
include("CompiledSelection.jl")
include("SelectionProgress.jl")
include("region_stages.jl")
include("trigger_paths.jl")
include("trigger_column.jl")
include("trigger_match.jl")
include("compile_selection.jl")
include("apply_cuts.jl")
include("event_loop.jl")
include("prefix_pass.jl")
include("selection_context.jl")
include("staged_column_mask.jl")
include("read_selection_columns.jl")
include("select_events.jl")
include("run_selection.jl")
include("read_stream_selection_window.jl")
include("read_reusable_selection_window.jl")
include("run_selection_variations.jl")
include("compile_object_expression.jl")
include("evaluate_object_expression.jl")
include("write_event_table.jl")
include("read_event_table.jl")

export KernelContext, ExpressionUsage, parse_expression, translate_expression, compile_kernel,
       compile_stable_kernel, StableKernel, is_stable_selection, precompile_stable_selection,
       Cutflow, record!, merge_cutflow!, cutflow_dict, cutflow_from_dict,
       EventTable, nrows, region_masks, region_counts, CompiledSelection, compile_selection, region_stages,
       trigger_paths, trigger_column, trigger_match, run_selection, selection_context, read_selection_columns,
       select_events, run_selection_variations, compile_object_expression, evaluate_object_expression,
       write_event_table, read_event_table

end # module
