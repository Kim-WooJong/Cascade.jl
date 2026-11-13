# Benchmark-first performance implementation roadmap

Revision: 2026-11-06, owner's19:55 selection/SF/histogram scope.
Status: PLAN ONLY. Approval to revise these documents is not approval to implement,
run tests/benchmarks, install dependencies, resume p11 or change product defaults.

## 1. Governing objective

First make Cascade and compiled C++ ROOT RDataFrame quantitatively comparable for
TTto2L2Nu e-mu selection/cuts -> nominal lepton SF/pileup -> njet histogram -> PNG.
Then optimize ONE measured cost and rerun the same correctness and timing contract.
Do not complete a general execution-engine rewrite before building the comparator.

The canonical workload, measurement boundaries, ladder, result schema and physics
specification live in [the benchmark execution plan](TTBAR_EMU_SF_PLOT_BENCHMARK_PLAN.md).
The [proposal](PERFORMANCE_OPTIMIZATION_PROPOSAL.md) is the strategic summary.

Not required for the first comparison: full13-sample pipeline, data/backgrounds,
JES/JER or theory, reduced export, local batch, fit/impacts, installation/deployment,
a generic DataFrame API, or automatic source hot reload.

## 2. Source boundary and preserved work

Accepted source milestone:9071405/v0.6.0. The dirty0.6.1 integration/hash checkpoint
is not an accepted complete release. p11 was owner-stopped; do not finish it as a
prerequisite or reuse its elapsed time as RDF evidence.

Choose a frozen benchmark source with its exact patch and candidate ID. A separately
recorded minimal canonical_hash byte-vector fix may be selected without importing
all p11 harness changes, but its applicable validation status must remain explicit.
Preserve accepted9071405, the dirty working tree, original files and historical logs.
Mac holds source/docs only; any later authorized execution lives on isolated gate.

Before a source change, inspect current git status and ownership. Retain Julia-only
product runtime, English docs/code, one feature/function per file, exported-module
boundaries, legacy readers and existing scientific/recovery contracts. Benchmark
C++ is an external reference, never a Cascade runtime dependency. No installs,
scheduler/multi-host/backend changes or new physics prescriptions by implication.

## 3. Two layers of plans

Existing artifact-stage plan:

    skim -> select -> correct -> histogram -> merge -> systematics -> fit -> plot

Proposed internal computation plan:

    source dependencies -> object/mask/value nodes -> weights -> booked consumers

The first governs durable materialization, identities and independent stages.
The second could share computation and limit lifetime inside one processing unit.
Do not conflate scientific dependency sharing with artifact-cache reuse or with
normalization ownership. Global signed normalization and nonlinear theory reduction
stay outside physical chunk/event kernels.

Typed execution already exists: KernelContext uses typed NamedTuples, cuts are
compiled and short-circuit, and selection kernels are reused by sample kind.
The issue is not a blanket absence of Julia compilation. Measure repeated object
work, I/O, allocations, specialization, source verification and process overhead.

## 4. Roadmap and dependency corrections

| ID | Deliverable | Real prerequisite |
|---|---|---|
| B0 | Frozen benchmark source, input and nominal config; installed-toolchain preflight | Owner-selected scope/source |
| B1 | Two equivalent adapters, common renderer, correctness comparison | B0 |
| B2 | Pilot + direct phase clocks + W1-W4 paired timing and resource report | B1 correctness |
| O0 | Ranked bottleneck report and one bounded optimization decision | B2; more profiling only when needed |
| M3 | In-task handoff/source borrowing while still writing required checkpoints | O0 shows material reopen/reread cost; NOT M1 |
| M2a | Supported per-object/per-value dependencies without execution change | O0 shows repeated invariant work |
| M2b | Share a validated invariant object/cut subgraph | M2a; scope may require explicit CompiledSelection layout versioning |
| M1 | Multi-weight histogram kernel/bin reuse | O0 plus a weight-heavy workload; NOT a nominal-PNG prerequisite |
| M4a | Bounded normal-analysis readers and borrowed window-local access | O0 and agreed local/original row/population contract; NOT generic M2 |
| M4b | Optional omission of eligible checkpoints | Accepted M4a and explicit independent-stage capability contract |
| M6a | Remove batch wave idle barriers with bounded dynamic scheduling | O0 shows imbalance; existing fresh-process isolation retained |
| M6b | Reusable local workers with state reset | Accepted task/identity lifecycle; measured startup benefit |
| M6c | Intra-file bounded tasks | Accepted M4a + complete logical normalization ledger |
| M5 | Fine-grained persistent dependency keys and edit-rebuild proof | Relevant dependency schema accepted; no blanket M4 requirement |
| M7 | Consolidated optimized comparison and controlled rollout | Only milestones actually justified by the chosen workload |

These are options, not a mandatory sequence or all-at-once approval. In particular:
- RDF baseline and correctness arrive at B1, NOT only at M7.
- M3 is independent of M1. Keeping checkpoint writes initially reduces risk.
- M4a does not require a generic dependency graph; it needs correct bounded IO,
  row identity, ownership and borrowed-source semantics.
- A one-PNG nominal adapter does not exercise multi-weight or cache-rerun benefits.
- Full systematics and iterative workflows require their own later benchmark cases.

## 5. B0-B2: first comparison, not the full pipeline

Follow the canonical benchmark plan exactly: MC-only, four actual trigger paths,
ordered e-mu/veto/OS/mll/jet cuts, nominal muon ID/iso + electron reco/ID + pileup,
original signed Runs normalization, one njet PNG, no variations/fit/data stack.
Restrict samples/regions/histograms and REMOVE correction up/down declarations.

Measurement has three layers:
1. Direct disjoint intervals: external total, setup, inclusive Events execution,
   fresh Runs read, normalization/transport, analyzer normal exit, common chained
   renderer and driver finalization/residual; report missing/unattributed gaps.
2. W1 selection, W2+SF, W3+histogram, W4+PNG. Their differences are marginal
   workload-extension costs, NOT additive isolated stage CPU times.
3. Optional separately run profiling/counters or predecoded kernels to explain
   inclusive costs. No per-event stopwatch in official timing.

Do not time RDF Filter/Define construction as selection/SF event processing.
Consume lazy results once after booking the whole graph. Match per-stage n/sumw/
sumw2 cutflow and final yields; do not give RDF less work. Record event-loop counts.
Show several fixed input sizes and fresh versus warm process state separately.
A small PNG workload can be startup/render dominated; do not infer general engine
speed from it. Match cores and disclose single-file parallelism limitations.

Prefer tools/benchmarks/ for timers/adapters. Any modification under src/Pipeline
changes existing folder-level code_hash and legitimately invalidates correction/
histogram/merge cache keys. Either stay outside src or declare the new source/key
boundary; never promise unchanged keys after inserting source timers.

## 6. O0: use measured costs to select one optimization

Record at least: setup/first-versus-warm behavior, inclusive decode/event time,
source-open count, verification/hash/JSON parse calls and bytes, selected rows,
correction evaluations, histogram fills, checkpoint bytes when used, and resource
scope. Attribute physical disk versus decoded bytes honestly.

The known canonical SHA String-dispatch pathology and its digest-equal byte-vector
fix are separate prior profiling evidence, not an RDF speedup. Use a declared fixed
source; do not spend a broad rewrite compensating for an already localized defect.
Repeated full-manifest verification/source reopening can remain after that fix;
measure counts and scaling rather than weakening integrity checks.

Stop if no cost is significant above noise or if correctness fails. Estimate the
maximum possible whole-job gain from the affected fraction before a major rewrite.
If fraction f is improved by factor s, the idealized bound is1/((1-f)+f/s), before
new overhead. This is a planning model, not a measured prediction.

## 7. M3: narrow handoff and source reuse

First pass EventTable/weights directly between existing kernels in a task, while
still writing required checkpoints and metadata. Do not clone the physics logic.
The initial benchmark K0 keeps the current correction source-open default; a
borrowed-source K1 is a separately labelled variant, not an implicit CLI speedup.
For an approved handoff optimization, borrow a valid source for compatible inputs;
current staged correction can otherwise reopen per chunk/shape. Keep owner-close
semantics, cache reset, source/payload validation and empty-population handling.

Compare parsed science and numeric order, not JSON key order/timestamps. Keep
independent stage requests valid. Do not claim whole-analysis bounded memory or
zero rereads for arbitrary custom hooks. Unsupported hooks use the staged path or
fail explicitly. Measure actual removed open/decode/read/parse costs and retained
write costs. Benchmark-adapter borrowing is disclosed separately from CLI changes.

## 8. M2: useful invariant sharing, not a trigger-only prefix

M2a records supported per-object and per-expression dependencies plus lifetimes.
Do not assume equal expression strings or arbitrary hooks are interchangeable.

Current materialization builds all configured objects together before the first
object cut. For ttbar MC the existing pre-materialization prefix is effectively
the trigger; sharing only that prefix is unlikely to remove the expensive lepton
rebuilds under jet-only JES/JER. A useful M2b must separate invariant lepton/veto
objects and lepton-only cuts from jet building/cleaning/njet-dependent consumers.
This may require a deliberately scoped CompiledSelection layout change; do not
advertise it as a no-layout-change optimization.

Invalidate shared values transitively when a variation touches an input. Preserve
nominal-failing/varied-passing events, distinct masks, named cutflow stages once
per variation, raw object order, stochastic event identity, and branch-cache
completeness. Never use nominal acceptance as a universal prefilter. Test actual
node evaluation counts and counterexamples before claiming sharing.

## 9. M1: conditionally fuse histogram weight consumers

Current fill_store loops region/hist/weight/event/value. A candidate can move the
weight loop inside the event/value loops, compute destination once and retain
each histogram's own addition order. Bound weight blocks rather than allocating
an unlimited events-by-members matrix. Keep signed sumw, sumw2, edges, NaNs,
underflow drop/overflow fold, multi-fill ordering and shape-specific destinations.

Only target this if retained-row/member/observable costs are material. Selection
runs over all originals; histogram filling runs on retained rows. A nominal
one-histogram result is not a stress test for this milestone. Synthetic many-member
cases must not be presented as a real PDF layout in the actual TT sample.

## 10. M4: reader lifetime before persistence omission

M4a can reuse the exporter's basket/window ideas but not assume its API solves
normal analysis. Distinguish actual bounded ROOT reads from eager cols. Bound
basket/column/selected/weight buffers and queues, release prior windows, preserve
local row versus original entry and full object lists. needed-mask placeholders
are not complete cache entries for a wider mask or another variation.

Original signed Runs population belongs once to a complete logical source, never
each window/shard. Preserve zero-kept groups, coverage/provenance and offline
reduced-input behavior. Normal analysis borrowers cannot reopen full sources
implicitly. Windows with differing partitions use versioned numerical contracts.

M4b follows only after reader correctness: omit optional checkpoints with explicit
materialization/capability metadata. Independent downstream requests rebuild valid
prerequisites or fail; no dummy success/cache artifacts. Preserve receipts, checksums,
source drift/inventory checks and atomic publication. Test failure/recovery and
compatibility before default changes.

## 11. M6: scheduling and lifecycle

In-process run_tasks already pulls tasks dynamically. Batch uses fresh processes
in waves; distinguish those mechanisms. M6a removes the batch wave barrier without
changing worker isolation. M6b resets per-task correction/config/RNG state in a
persistent worker and pins loaded source/runtime identity: no implicit hot reload.
M6c adds intra-file tasks only with validated M4a identity/normalization semantics.

Retain exclusive claims, immutable completed attempts, checksum receipts, logs,
launcher fingerprints and atomic results. Merge in declared source/chunk order,
not completion order. Version manifests/receipts if task scope changes. Verify
per-writer temporary names, stdout isolation, simultaneous memory and nested threads.
A persistent pool is not justified solely by saying Julia always recompiles everything.

## 12. M5: incremental dependencies, not fictitious missing features

Bin-edge-only edits already reuse selection at stage level. The opportunity is
per-histogram/weight/input granularity and avoiding unnecessarily broad code/config
invalidation, NOT inventing basic edge-change reuse. Current fit config affects
merge; separate channel/overlap dependencies from minimizer-only options safely.
Folder-level source hashing can over-invalidate but cannot simply be removed.

Define schema migration and explicit scientific code dependencies. Compare every
reuse result to a forced correct rebuild, including changed payloads/cuts/regions/
values/channels/styles, appended/removed inputs and code. Negative stale-reuse tests
are mandatory before a cache hit can count as a turnaround improvement.

## 13. Cross-cutting release gates

Contract A: unchanged partition and per-target accumulation order preserve current
numeric bits, memberships/cutflows/weights/IDs, w^2 expression and RNG behavior.
Contract B: explicitly changed partition permits only declared reassociated
reductions to use predeclared contribution-scaled error bounds; raw event semantics,
selection identity, integer counts and original denominator ownership stay exact.
Do not relax existing regressions to accept a faster but wrong candidate.

Mandatory discriminators: signed cancellation/zero/nonfinite values, edge/overflow,
multiple fills, shape-entering events, high UInt64 IDs, jagged/basket boundaries,
zero-kept originals, original Runs once, post-merge-only nonlinear theory reduction,
stale payload/code/reader bindings, unsupported hooks, worker death and receipt/
publication integrity. Applicability determines focused/full/fresh-process tests.

Each accepted implementation needs frozen input/source provenance, focused checks,
applicable regression evidence, independently reviewed changes and a scoped measured
benefit (or a clearly reported lack of benefit). Benchmark-only docs need local-link/
consistency checks, not a restarted full suite. Keep the old backend selectable
until a migration has its own review. Never switch scientific defaults for speed.

## 14. First tickets and reporting

First approval requested after this document: B0+B1 only, with a bounded one-file
correctness comparison and pilot if explicitly included. Report before enlarging
files, repeats or implementation scope. See canonical P0-P4 ticket table and stop
budgets; no automatic all-milestone run or hours-long wait.

Every report separates correctness, actual exits/skips, direct clocks, marginal
extension estimates, startup/steady behavior, resources, compiler/build cost,
source/input/payload IDs and remaining uncertainty. A slower Cascade result is
still useful if it identifies a concrete, reproducible bottleneck. Universal RDF
superiority or guaranteed Julia speedups are not conclusions of this roadmap.
