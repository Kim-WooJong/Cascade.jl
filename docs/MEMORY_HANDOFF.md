# Checkpoint-preserving per-file memory handoff

Opt in with an execution-only setting (default is strictly Boolean false):

```toml
[execution]
memory_handoff = true
column_readers = 1
decode_threads = 1
streaming_selection = false
```

Use a run plan containing exactly one contiguous select → correct → histogram
segment, optionally preceded by skim and followed by merge and other steps.
No existing analysis configuration or profile is changed by this implementation.
Inactive profile values are also validated; 0, 1, strings and null are not Bool.

## Eligibility and compatibility

Only run_pipeline consumes the segment. Direct run_step calls remain staged.
The entire selected chain is checked before chain artifact writes. All samples
must use nanoaod, no selected sample may have active shape variations, no active
theory weights may be configured (conservative initial exclusion), input_scope
must be nothing, source reader identities must remain built-in, and correction
function identity must be exactly default_correct or Systematics.apply_corrections.
An id string of "default" is not sufficient. Wrappers/custom hooks fall back
because they could mutate aliased tables. The built-ins read table columns and
produce correction outputs without mutating the selection table. Reader/decode
width must be one and streaming selection off. Unsupported/missing/reordered/
noncontiguous segments use the complete legacy route with one printed reason.
Errors during an eligible chain propagate; there is no catch-and-rerun fallback.

The default-false print and summary shape remain unchanged. Shared stage bodies
preserve legacy shape and theory processing, source close/finally ownership,
scientific calls, weight ordering and artifact paths. Selection code identity now
includes the full Pipeline area, so this is a documented one-time cache
invalidation for both modes (and Pipeline edits invalidate selection thereafter).
The execution flag is not a key component or a separate artifact namespace.

## Checkpoints, mixed cache states and ownership

Each existing is_up_to_date/force decision is independent. A selection miss
publishes its table and then completion metadata before correction starts. The
same columns and order are retained in RAM; only EventTable metadata is
JSON-round-tripped to match read_event_table semantics. A correction miss uses
that table, or hydrates a cached table once. It executes the shared correction
hook and theory path, converts to the canonical Float64 dictionary, validates,
writes payload then completion metadata, and returns that exact dictionary with
metadata and nominal-first/sorted-other order for histogram filling.

A correction hit uses persisted weights and their persisted manifest, never
reruns the hook or substitutes a newly computed manifest. Fresh and cached
weights use the same metadata/order extraction verifier before the histogram
cache decision. A histogram hit still requires both upstream artifacts and
verifies the cached store. Corrupt artifacts are not silently repaired or
ignored. The current extraction verification reads the saved correction payload
even when histogram is a hit; the chain reads it once and reuses it on a
histogram miss. Thus all-hit is NOT a zero-I/O claim. Table payloads are not
loaded on all-hit. A miss upstream does not unconditionally invalidate downstream
if its computed key is unchanged. Force remains independent at all three stages.

File tasks come from persisted skim inventory and run largest-input-first through
existing run_tasks, at most nthreads concurrent chains. Workers return only small
counts/timings, not dataset-wide tables, weight dictionaries or stores. Live
payload ownership scales with active file chains, not all input files; there is
no RSS byte cap or guarantee (large files and delayed GC can still be expensive).
One public correction-cache reset occurs before workers, never per worker.
Selection sources close before handoff, and correction owners close in the same
finally boundary as staged execution. Partial failure leaves completed stage
checkpoints, skips subsequent stages of that file, attempts other files, and
then propagates the existing aggregate task error. Merge order is unchanged.

## Diagnostics and timing

Opt-in summary[:memory_handoff] reports enabled/effective/fallback_reason,
file_workers, table_handoffs, weight_handoffs, payloadloads (table/weights), and
chain_wall_seconds. Handoffs count reused payload consumer edges: a retained
table can feed correction and histogram (two edges); fresh corrected weights
feed a histogram miss (one edge). Cached payload reuse is not a fresh weight
handoff. Loads count explicit column-file reads in the chain, not ROOT branch
reads, writes or store JSON reads. Fallback zero counters describe handoff work
only, not legacy I/O. Stage run/skipped counts count exact chunks.

Chain phases report phase_worker_seconds with timing_kind explicitly marking
worker sums, not stage wall clocks. Phases overlap across files; do not add those
numbers and report the sum as wall time. Fused stages deliberately do not fake
the old seconds field. Other legacy steps still have their old wall seconds.
Main CLI ignores the returned summary; searched internal consumers use stage
run/skipped fields. External generic consumers iterating every summary value or
requiring seconds on every entry must account for the opt-in diagnostics entry.

## Comparison with ROOT RDataFrame

This is file-eager fusion, NOT an RDF single event loop or lazy action graph.
Selection, correction and histogram remain separate eager scientific passes
within each file chain. Checkpoints are still written in full. Skim and merge
are unchanged; ROOT source reads, correction ROOT reopens, correction payload
lookups and Julia compilation/JIT still occur. Compared with RDF-style fused
actions, the implemented opportunity is avoiding selected-table and corrected-
weight serialization reloads between these existing passes. It does not eliminate
all intermediate allocations, all file opens, checkpoint serialization, or JIT.
There is no measured speed, memory or runtime claim and no benchmark result.

## Verification boundary and next validation environment

Only static diff/hash/grep/manual source review was authorized and performed.
No Julia invocation, parser, build, tests, benchmark, profiler, ROOT input content,
remote operation or dependency installation was performed. An independent fresh
concrete review is required before accepting this implementation. When separately
authorized, verify all eight hit/miss combinations, force, failed-file recovery,
all-hit corrupted extraction/store failures, real baseline and five-SF built-in
hooks, object identity of fresh columns/weight dictionary, bitwise weight and
histogram/metadata parity across modes, shape/theory/custom-reader fallbacks,
inactive-profile strict Bool rejection, direct staged APIs, unchanged merge
ordering, and bounded worker ownership. Static evidence alone does not prove
Julia syntax, runtime correctness, scientific parity or performance.
