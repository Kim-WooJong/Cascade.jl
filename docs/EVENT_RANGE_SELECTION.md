# Opt-in event-range selection

```toml
[execution]
event_range_selection = true
# Existing stream_* options bound range size, live jobs, metadata and output.
column_readers = 1
decode_threads = 1
streaming_selection = false
memory_handoff = false
```

Default is false. This engine uses one stage-global default-thread-pool worker
set, never a file-worker × range-worker fanout. Distinct files get priority;
remaining same-file ranges share that same pool. Common basket boundaries, not
arbitrary event splits or claimed RDF clusters, define admitted ranges.

Only builtin NanoAOD nominal selection is admitted initially. Custom hooks,
replaced source readers, shapes, theory/weight variants, decode_threads != 1,
column_readers != 1, old streaming and memory_handoff return explicit pre-read
fallback reasons. Handoff retains precedence. Identity proof unavailability
also falls back before Events reads (currently proof requires Linux mapping
information). Once admitted, private-open/read/selection/merge/publication errors
are errors: they never silently rerun the file through ordinary selection.

Each range has an independent ROOTFile, LazyBranches, basket state, incremental
SelectionProgress, object buffers, memo, context and result vectors. There is no
threadid-indexed runtime state. Immutable compiled metadata/kernels are shared.
Original and independently reopened mappings are checked before/after data work;
sources close only after worker join. This detects ordinary replacement/drift,
not adversarial concurrent in-place mutation.

The controller alone merges in original range/event order. Workers return Int
stages and Float64 weights for **all** events, including rejected events. The
owner calls record! per event, not range subtotal merge; this preserves weighted
cancellation and sumw2 operation order. Entry offsets are added once by the
existing ordered append helper. Existing canonical jagged offsets/counter and
masked placeholder checks are reused. Final table metadata/cutflow/regions are
repaired by the owner after every range succeeds. Immediately before replacing
that file's artifact, its old metadata marker is atomically renamed to a unique
same-directory backup. Fresh metadata commits last. Any publication failure
leaves no success marker and preserves the old marker bytes in that backup;
it never restores a stale same-key marker over replaced data. Successful
publication retires only its own backup. No invalidation occurs during analysis.
Failed files have no new checkpoint; already completed unrelated files remain. The original-file skim
continues to own Runs/genEventSumw normalization; no range reads/reduces Runs.

## Memory accounting

Existing stream_queue_windows limits all queued/running/completed-unmerged jobs
and cannot exceed the global worker width. stream_queue_bytes reserves original
metadata plus each private reader's metadata, conservative basket workspace/raw
reservation, progress/objects/memo, all-event ledger and reorder output. A further
metadata slot covers temporary planning. stream_retained_bytes reserves the
**complete checked sum of per-range retained charges for a file before its first
job**. Other files defer until that entire reservation can fit; this prevents
partial tables from fragmenting the budget so no file can finish. A genuinely
oversized whole-file bound is rejected before any of its range readers open.
Merged file tables retain their reservation until publication/discard. No
full-file all-event ledger is built.
These are logical owned-memory/capacity reservations, not a peak RSS guarantee
(Julia runtime, mapped files, compiler and GC are separate). Budget exhaustion
throws explicitly, including a retained table too large to finish; it does not
spill or abandon checkpoint semantics.

Memo admission uses the authoritative cache-owned
Selection.variable_memo_reservation(sel,n)::Int128 for each range: supported
scalar width × node/event count, column-budget cap, headers and registry overhead.
It does not reserve the entire configured memo cap for a small range. Actual
incremental_window_bytes (including memo) must still fit the pre-read bound.

## Integration seams (main-owned)

1. Include Config/event_ranges.jl after AnalysisConfig; export
   event_range_selection. Add execution.event_range_selection to accepted keys
   and validate strict Bool for base config and inactive/merged profiles.
2. memory_chunk_helpers.jl: pass range_fallbacks (default empty Dict) into
   execute_select_chunk, and annotate execution event_range_selection_requested,
   event_range_selection_effective=false, event_range_selection_reason using
   the per-output map. Handoff calls without a map use memory_handoff_enabled.
   Suppress serial window execution whenever event_range_selection is requested
   but unsupported; ordinary fallback must not enter a different opt-in engine.
   prepare_select must suppress old streaming dispatch for a range request,
   including conflict combinations. step_select itself already suppresses async.
3. Selection API must accept all_event_stage::Vector{Int},
   all_event_weight::Vector{Float64}, record_cutflow=false with progress or without.
   Fill ledger exactly once/event and skip record! when disabled; final owner
   repairs local table metadata. No Selection files were edited in this lane.

## Focused verification (parent runs)

```sh
julia --startup-file=no --threads=1 test/event_ranges/runtests.jl
julia --startup-file=no --threads=2 test/event_ranges/runtests.jl
julia --startup-file=no --threads=4 test/event_ranges/runtests.jl
```

Scheduler tests use real supervised worker/controller code with stub data IO.
They cover scrambled completion, 1-vs-2 exact tables/cutflow including rejected
cancellation weights, global bounds, independent context, empty/single/multiple
files, cleanup, cancellation, worker lifecycle failure, no failed-file publish,
retained/queue refusal and deferred unsupported fallbacks. selection.jl adds real
incremental SelectionProgress/select_events ledger tests with scalar/jagged input
and a stub physical reader. No ROOT integration or speed claim follows from
these synthetic tests. Full package load/config profile tests and a controlled
local NanoAOD fixture are integration gates. This implementation lane did not
run Julia, builds, tests or ROOT reads, per assignment.

### Exact shared-helper patch checklist

- execute_select_chunk keyword signature: add
  `range_fallbacks = Dict{String,String}()` (step_select now passes it).
- Immediately after destructuring p, compute
  `ranges = event_range_selection(cfg)`. Set
  `window_reason = ranges ? "event_range_selection_requested" :
   (windowed ? windowed_selection_fallback(cfg,s,plan) : "disabled")`.
  This leaves both `if windowed && isempty(window_reason)` guards false for any
  explicit range request.
- Add to execution Dict:
  `"event_range_selection_requested" => ranges`,
  `"event_range_selection_effective" => false`,
  `"event_range_selection_reason" => ranges ?
    get(range_fallbacks,out,event_range_selection_fallback(cfg,s,plan)) : "disabled"`.
  For handoff cfg.memory_handoff is true and therefore reports its reason.
- In prepare_select, make async suppression
  `(windowed || event_range_selection(cfg)) &&
   (streaming = merge(streaming,(enabled=false,)))`.
- Existing optional async diagnostic should prefer range conflict when ranges:
  `"event_range_selection_conflict"` rather than an inaccurate unsupported_path.
- Config helper does not own stream budgets: keep streaming_selection_options
  available when disabled. Its metadata/queue-capacity validation should also
  run for an event-range request; pool independently enforces capacity too.

## P1 remediation regression cases

- Two files × three retained charges of 1000, pool width 2, retained ceiling
  4000: reserve one complete 3000-byte file, safely defer the other, publish both.
  Ceiling 2999 rejects the genuinely oversized file before any private open.
- Seeded same-key marker + unrelated checkpoint: fail fresh metadata after
  replacing data; real is_up_to_date predicate must be false for the target,
  unrelated bytes/marker remain unchanged, old target marker backup remains.
  Tests use stdlib-only key-byte metadata codec stubs, not JSON3 serialization.
- A held reader receives a controller interrupt and first-join interruption;
  cleanup retries the identical worker before any original/private source closes.
- Worker lifecycle fatal after its completed result AND file checkpoint are
  published is observed after join; completed checkpoint remains preserved.

Pre-remediation source snapshots are retained as .txt files under
`../cascade-julia-event-engine-20261109/lane-start-backups/event_range_remediation/`; existing failure logs were untouched.
Focused test commands above include these regressions. This lane performed only
static source/diff inspection, not Julia/tests/ROOT execution.
