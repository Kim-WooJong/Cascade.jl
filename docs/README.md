# Documentation

Start with the [README](../README.md), [configuration reference](CONFIG.md) and
[validation/support limits](VALIDATION.md). Experimental options do not become
default merely by installing the package. Examples require the explicitly listed
external inputs; no dataset completeness or calibrated exposure is inferred.

## Analysis configuration

- [Input auditing](INPUT_AUDIT.md)
- [Triggers and matching](TRIGGERS.md)
- [Regions and fit-channel overlap](REGIONS.md)
- [Luminosity provenance](LUMINOSITY.md)
- [Theory vector weights](THEORY_WEIGHTS.md)

## Execution and storage

- [Process batches and resume](BATCH_EXECUTION.md)
- [Fresh full chains without intermediate checkpoints](NO_CHECKPOINTS.md)
- [Legacy eager reduced bundles](REDUCED_SKIM.md)
- [Streaming reduced export](STREAMING_REDUCED_SKIM.md)
- [Checkpoint-preserving memory handoff](MEMORY_HANDOFF.md)
- [Event-range selection](EVENT_RANGE_SELECTION.md)

## Opt-in reader and selection contracts

- [Parallel column reads](PARALLEL_COLUMN_READ_VALIDATION.md)
- [Detached basket decoding](BASKET_DECODE_VALIDATION.md)
- [Correction-source reuse](CORRECTION_SOURCE_REUSE_VALIDATION.md)
- [Cut-aware column reads](STAGED_COLUMN_READING.md)
- [Staged object materialization](STAGED_OBJECT_MATERIALIZATION.md)
- [Lazy variable memo](LAZY_VARIABLE_MEMO.md)
- [Incremental selection reuse](INCREMENTAL_SELECTION_REUSE.md)
- [Windowed incremental selection](WINDOWED_INCREMENTAL_SELECTION.md)
- [Windowed reusable decoder](WINDOWED_REUSABLE_DECODER.md)
- [Reusable basket buffers](REUSABLE_BASKET_BUFFERS.md)
- [Window buffer reuse](WINDOW_BUFFER_REUSE.md)
- [Window memory accounting](WINDOW_ACCOUNTING.md)
- [Lightweight skim metadata](LIGHTWEIGHT_SKIM_METADATA.md)

## Development and optional validation

- [Architecture and data flow](DESIGN.md)
- [Development conventions](CONVENTIONS.md)
- [Validation requirements and current limitations](VALIDATION.md)
- [Named stage precompilation](NAMED_STAGE_PRECOMPILE.md)
- [Reuse-aware image coverage](PRECOMPILE_REUSE_COVERAGE.md)
- [Optional diagnostic runner/report](BENCHMARK_TELEMETRY.md)
- [External correctionlib oracle](../tools/oracle/README.md)
- [Optional ttbar integration](TTBAR_INTEGRATION_VALIDATION.md)

Past run ledgers, approval notes and superseded design proposals are not the
maintained user manual. Their historical results must not be substituted for a
complete test of the current checkout. No general speed or physics claim follows
from this documentation index.
