"""
    Cascade.Pipeline

Step graph `skim -> select -> correct -> histogram -> merge -> systematics -> fit
-> plot`, per-file chunk execution on threads, make-like artifact cache (each
artifact has a `.meta.json` with a key hashing inputs, configuration and code),
step hooks for the corrections/systematics/fit/plotting areas, and the
`cascade` command line.
"""
module Pipeline

using JSON3
using SHA
using TOML
import UnROOT
using ..Config
using ..IO
import ..IO as EventIO
using ..IO: COLFILE_TYPES, reduced_safe_path
using ..Selection
using ..Histograms
using ..Systematics.Shape: shape_variations_for, shape_plan, shape_columns
import ..Systematics
import ..Audit
using ..Systematics: reset_correction_cache!

include("benchmark_telemetry.jl")
include("STEPS.jl")
include("RunOptions.jl")
include("StepContext.jl")
include("parse_cli.jl")
include("plan_steps.jl")
include("code_hash.jl")
include("artifact_key.jl")
include("write_meta.jl")
include("read_meta.jl")
include("is_up_to_date.jl")
include("chunk_id.jl")
include("artifact_paths.jl")
include("shape_key.jl")
include("correction_files_key.jl")
include("read_skim.jl")
include("require_artifact.jl")
include("run_tasks.jl")
include("hooks.jl")
include("default_correct.jl")
include("default_systematics.jl")
include("default_fit.jl")
include("default_plot.jl")
include("luminosity_spec.jl")
include("source_lumisections.jl")
include("load_lumisection_luminosity.jl")
include("lumisection_luminosity.jl")
include("luminosity_exposure.jl")
include("region_yield_record.jl")
include("group_shard_signature.jl")
include("reduced_group_inventory.jl")
include("skim_reduced_groups.jl")
include("validate_reduced_skim.jl")
include("step_skim.jl")
include("attach_reduced_provenance.jl")
include("column_reader_budget.jl")
include("run_decode_file_tasks.jl")
include("run_window_pipeline.jl")
include("stream_selection.jl")
include("run_event_range_pool.jl")
include("event_range_selection.jl")
include("memory_chunk_helpers.jl")
include("step_select.jl")
include("correction_chunk_source.jl")
include("with_correction_source.jl")
include("step_correct.jl")
include("verify_correct_extraction.jl")
include("step_histogram.jl")
include("write_cutflow_tsv.jl")
include("write_yields_tsv.jl")
include("write_shape_yields_tsv.jl")
include("step_merge.jl")
include("merge_region_counts!.jl")
include("step_systematics.jl")
include("step_fit.jl")
include("step_plot.jl")
include("run_step.jl")
include("run_memory_handoff.jl")
include("ordered_window.jl")
include("no_checkpoint_file_work.jl")
include("run_no_checkpoints.jl")
include("run_pipeline.jl")
include("check_analysis.jl")
include("audit_analysis.jl")
include("init_analysis.jl")
include("batch_hash.jl")
include("batch_safe_path.jl")
include("batch_validate_names.jl")
include("batch_rebase_outputs.jl")
include("batch_fingerprint.jl")
include("batch_files.jl")
include("batch_lock.jl")
include("batch_atomic_json.jl")
include("batch_input_identity.jl")
include("batch_host.jl")
include("batch_plan.jl")
include("batch_load.jl")
include("batch_receipt.jl")
include("batch_task_sample.jl")
include("batch_worker.jl")
include("batch_status.jl")
include("batch_command.jl")
include("batch_run.jl")
include("batch_merge.jl")
include("batch_main.jl")
include("reduced_contract.jl")
include("validate_reduced_inputs.jl")
include("reduced_branch_plan.jl")
include("reduced_source_limits.jl")
include("reduced_retention.jl")
include("reduced_raw_columns.jl")
include("ReducedShardBuffer.jl")
include("append_reduced_row!.jl")
include("flush_reduced_shard.jl")
include("load_reduced_window.jl")
include("validate_stream_metadata.jl")
include("stream_source_file.jl")
include("open_export_source.jl")
include("reduce_source_file.jl")
include("reduced_analysis_config.jl")
include("validate_reduced_subset.jl")
include("validate_reduced_export.jl")
include("verify_reduced_export.jl")
include("reduce_analysis.jl")
include("reduce_main.jl")
include("main.jl")

export STEPS, RunOptions, StepContext, CorrectionContext, parse_cli, plan_steps, code_hash,
       artifact_key, write_meta, read_meta, is_up_to_date, chunk_id,
       batch_plan, batch_worker, batch_run, batch_status, batch_merge,
       reduce_analysis, validate_reduced_export, run_tasks, register_hook!, hook_for, run_step, run_pipeline, run_no_checkpoints, check_analysis, audit_analysis, init_analysis, main

# Generation-only training workload for opt-in stable selection kernels (no runtime effect).
include("stable_selection_workload.jl")
# Image-generation-only precompile declarations (no runtime effect).
include("precompile_pipeline.jl")

end # module
