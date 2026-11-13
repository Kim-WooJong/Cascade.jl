# Documentation index

Start with the [package README](../README.md) and
[development guide](../CONTRIBUTING.md). Guides describe interfaces and limits;
validation records describe only the version, settings, runtime and inputs
actually tested. Older status/proposal language is historical, not a universal
current feature or validation claim. Local/cluster evidence paths are references
to external records, not files promised in a fresh checkout.

The [analysis template](../analyses/TEMPLATE.toml) is the portable starting point.
Reference CMS analyses need external input/calibration paths. The separate
[modern counting profile](../analyses/ttbar_emu/MODERN_COUNTING.md) remains
fail-closed until its required physics evidence is supplied.

## Analysis and configuration

- [Analysis configuration reference](CONFIG.md)
- [Input audit and sample provenance](INPUT_AUDIT.md)
- [Trigger efficiencies and matching](TRIGGERS.md)
- [Regions and independent fit channels](REGIONS.md)
- [Luminosity provenance and yield accounting](LUMINOSITY.md)
- [Theory vector weights](THEORY_WEIGHTS.md)

## Execution and performance

- [Deterministic process batch execution](BATCH_EXECUTION.md)
- [Legacy eager reduced ROOT RNTuple bundles (schema1)](REDUCED_SKIM.md)
- [Streaming reduced ROOT RNTuple bundles](STREAMING_REDUCED_SKIM.md)
- [Fresh runs without intermediate checkpoints (`execution.checkpoints = false`)](NO_CHECKPOINTS.md)
- [Checkpoint-preserving per-file memory handoff](MEMORY_HANDOFF.md)
- [Opt-in event-range selection](EVENT_RANGE_SELECTION.md)
- [Cut-aware column reading and memory traffic](STAGED_COLUMN_READING.md)
- [Staged object materialization](STAGED_OBJECT_MATERIALIZATION.md)
- [Opt-in parallel NanoAOD column reads](PARALLEL_COLUMN_READ_VALIDATION.md)
- [Opt-in lazy named-variable memo](LAZY_VARIABLE_MEMO.md)
- [Incremental ordinary selection and file-local metadata reuse](INCREMENTAL_SELECTION_REUSE.md)
- [Serial per-file windowed incremental selection (phase 1)](WINDOWED_INCREMENTAL_SELECTION.md)
- [Windowed reusable decoder (opt-in prototype)](WINDOWED_REUSABLE_DECODER.md)
- [Ordinary serial NanoAOD reusable basket buffers](REUSABLE_BASKET_BUFFERS.md)
- [Window progress/object buffer reuse](WINDOW_BUFFER_REUSE.md)
- [Reusable window accounting](WINDOW_ACCOUNTING.md)
- [Lightweight skim metadata (opt-in)](LIGHTWEIGHT_SKIM_METADATA.md)
- [Named no-checkpoint stages](NAMED_STAGE_PRECOMPILE.md)
- [Reuse-aware package image coverage](PRECOMPILE_REUSE_COVERAGE.md)
- [Benchmark telemetry v1 (review before real runs)](BENCHMARK_TELEMETRY.md)

## Design and development

- [Cascade.jl — Design Draft (v0)](DESIGN.md)
- [Development conventions](CONVENTIONS.md)
- [Repository scope and publication checklist](REPOSITORY.md)
- [Performance strategy: measure the ttbar comparison first](PERFORMANCE_OPTIMIZATION_PROPOSAL.md)
- [Benchmark-first performance implementation roadmap](PERFORMANCE_IMPLEMENTATION_PLAN.md)
- [ttbar e-mu: Cascade versus RDataFrame benchmark execution plan](TTBAR_EMU_SF_PLOT_BENCHMARK_PLAN.md)

## Historical validation and investigations

These records are retained for traceability; do not combine their timings or
assume their external evidence is distributed with this package.

- [Async streaming 107 GB matched ordinary-production validation](ASYNC_STREAMING_100G_MATCHED_VALIDATION.md)
- [Per-branch maskability: final concrete implementation validation](ASYNC_STREAMING_PER_BRANCH_MASKABILITY_VALIDATION.md)
- [Async streaming selection: narrow remediation and all396 eligibility](ASYNC_STREAMING_SELECTION_REMEDIATION.md)
- [Async streaming selection: concrete implementation validation](ASYNC_STREAMING_SELECTION_VALIDATION.md)
- [Experimental detached basket decoding](BASKET_DECODE_VALIDATION.md)
- [Batch backend: Step3 validation](BATCH_VALIDATION.md)
- [Cold selection and I/O attribution](COLD_SELECTION_IO_ATTRIBUTION.md)
- [Correction chunk source reuse](CORRECTION_SOURCE_REUSE_VALIDATION.md)
- [Input audit / sample provenance: Step 1 validation](INPUT_AUDIT_VALIDATION.md)
- [First >=100GiB ordinary measurement: D0 production default — 2026-11-07](LARGE_INPUT_100G_D0_VALIDATION.md)
- [>=100GiB real-input matched production validation](LARGE_INPUT_100G_MATCHED_VALIDATION.md)
- [Large-input timing audit supplement](LARGE_INPUT_100G_TIMELINE_AUDIT.md)
- [Matched cached ordinary CLI → native PNG — 2026-11-07](MATCHED_CACHED_CLI_PNG_VALIDATION.md)
- [Workload volume and stage-time breakdown](MATCHED_CACHED_CLI_PNG_WORKLOAD_BREAKDOWN.md)
- [Phase 5: reusable analysis-framework helpers](PHASE5_VALIDATION.md)
- [Precompile selection: final review remediation — 2026-11-07](PRECOMPILE_SELECTION_REVIEW_REMEDIATION.md)
- [Primitive interpretation/cache prerequisite review — 2026-11-07](PRECOMPILE_SELECTION_VALIDATION.md)
- [Reduced skim validation (frozen0.5 milestone)](REDUCED_SKIM_VALIDATION.md)
- [Streaming reduced skim validation](STREAMING_REDUCED_SKIM_VALIDATION.md)
- [Theory vector weights: Step2 validation](THEORY_WEIGHTS_VALIDATION.md)
- [Small combined ttbar technical integration](TTBAR_INTEGRATION_VALIDATION.md)
