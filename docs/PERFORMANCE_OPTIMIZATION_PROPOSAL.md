# Performance strategy: measure the ttbar comparison first

Revision: 2026-11-06 after the owner's19:55 clarification.
Status: DOCUMENT PLAN ONLY. No benchmark/optimization execution, installation,
source release, default change or resumed p11 work is authorized here.

## 1. Immediate objective

Make a small, fair and diagnosable comparison with ROOT RDataFrame:

    TTto2L2Nu MC -> e-mu selection and cuts -> nominal lepton SF/pileup
                -> njet histogram -> one verified PNG

The professor's requested scope does not need the full framework workflow.
Do not make a generic execution-engine rewrite a prerequisite for comparison.

The canonical [benchmark execution plan](TTBAR_EMU_SF_PLOT_BENCHMARK_PLAN.md)
defines exact cuts/payloads, program boundaries, phase clocks, workload ladder,
correctness, resources, repetitions, output schema and bounded execution tickets.
The [implementation roadmap](PERFORMANCE_IMPLEMENTATION_PLAN.md) defines optional
profile-driven changes after a baseline exists.

## 2. Separate three claims

| Claim | Appropriate evidence |
|---|---|
| Faster requested result | Same input/physics/output, external process-to-PNG completion time |
| Faster event computation | Inclusive event-loop plus matched diagnostics, with startup/render excluded explicitly |
| Better repeated-analysis workflow | Preparation plus valid reruns/recovery/storage, with equivalent RDF reuse allowed |

The initial comparison establishes the first two within a narrow workload. It
cannot establish systematic-scaling, cache-turnaround or recovery advantages
because those features are not exercised by one nominal MC histogram.

RDF is optimized C++ execution, including when graph construction uses PyROOT.
It already has lazy actions, shared nodes, filtering, IMT, Cache, Snapshot and Vary.
Compare against an optimized compiled C++ baseline, not Python per-event loops or
a graph forced to execute repeatedly. Do not assume automatic CSE for unrelated
nodes, a universal single SIMD kernel, or absence of competitor persistence.

## 3. Measure parts without inventing additive RDF stage times

RDF I/O, selection, correction and histogram execution are interleaved. Building a
Filter/Define node does not time its event work. Required evidence has three layers:
1. Direct intervals: external total, setup, inclusive Events execution,
   normalization/transport, native rendering and finalization/residual.
2. Cumulative modes: W1 selection, W2+nominal SF, W3+histogram, W4+PNG. Paired
   differences estimate marginal workload-extension costs, not pure/additive CPU.
3. Optional separately labelled profiling/counters or predecoded-kernel experiments
   when additional attribution is needed. Official timing excludes per-event clocks.

Report actual values, null+reason for unavailable metrics, signed/noisy differences,
source-open/decoded-byte/evaluation counts and clock scope. Never fill missing
parts with zero or draw an unjustified read+selection+SF+hist stacked pie.

## 4. Existing strengths and measured risks

Cascade already uses typed compiled selection kernels and an integrated scientific
configuration. Its artifact, normalization and recovery contracts are useful;
they must not be weakened merely to produce a faster number.

Current opportunities needing scoped measurements:
- Repeated correction source opens and branch materialization; source borrowing
  already exists in relevant APIs and should be disclosed in a minimal adapter.
- Repeated object/cut work across shapes: ttbar jet-only variations can share
  invariant leptons only if dependencies/materialization are separated correctly.
- Intermediate selected/weight files and histogram JSON rereads in the staged CLI.
  A minimal in-memory adapter may not pay these costs; do not conflate the two.
- Region/hist/weight repeated bin searches: relevant only if the retained-row and
  member workload makes histogram filling a material fraction.
- Batch wave idle time and fresh-process overhead; in-process task scheduling is
  already dynamic. Large single files also expose missing intra-file parallelism.
- File-sized normal-analysis arrays: exporter streaming is not proof that all
  analysis paths are already bounded memory.
- Verification/canonical hashing/JSON parsing counts. Prior hash-path profiling
  found a localized digest-equivalent improvement; it is not an RDF speed result
  or a reason to disable integrity/drift checks.

## 5. Revised priority

1. Freeze an explicit source candidate and nominal-only workload, preserving the
   owner-stopped p11 checkpoint. Build the equivalent RDF comparator NOW.
2. Validate selections, cutflow n/sumw/sumw2, SF factors, raw/scaled bins and PNG.
3. Measure startup/inclusive loop/render across several fixed sizes and paired
   W1-W4 modes, with equal threads and disclosed build/cache/resource states.
4. Rank actual costs and estimate the maximum benefit before rewriting an engine.
5. Change ONE hotspot, prove the same science, and repeat the same comparison.
6. Extend only if justified: multiweight/shape cases, incremental edits, streaming,
   worker pooling and recovery each need their own declared workload/approval.

The first optimization is not predetermined. M3 in-memory handoff does not depend
on M1; M4a bounded reading does not require a generic M2 graph. M2 must target
useful object-level invariants, not merely a shared trigger prefix. M1 waits for
a measured weight-heavy cost. Dependency precision is useful but bin-edge-only
stage reuse already exists; don't claim to invent it.

## 6. Fairness and correctness

Fix original input bytes/order, four MC triggers, object/cut order, float boundary
rules, correction payload bytes/arguments, original signed Runs denominator,
histogram edges/flow policy and actual output count. No invented b-tag/trigger SF,
PDF/JES/JER/fit work in the primary benchmark. Match weighted cutflows and force
all RDF lazy consumers. Use a common renderer/topology or separate its difference.

Freeze strict membership and numeric-error policy before performance comparisons.
Boundary/libm mismatches are investigated, not removed from the data. Signed
cancellation needs contribution-aware absolute bounds rather than loose relative
tolerances. No clipping or lower precision to make a speed number attractive.

Primary: fresh process, no result-artifact reuse, one compute thread, no custom
sysimage. Distinguish process/JIT, OS cache and application cache. Show optional
warm/sysimage/multithreaded cases under separate IDs. No shared-host cache flush,
service change, hidden nested threading or extrapolation to full3307 files.

## 7. Source and operational status

Accepted milestone9071405/v0.6.0 is distinct from the uncommitted0.6.1 checkpoint.
The p11 integration was stopped by the owner and is NOT a passing RDF baseline.
Source selection and any minimal hash patch are explicitly recorded before work.
Mac stores source/docs; authorized execution/artifacts stay in a new gate area.
No dependency install or long autonomous sweep follows from filing this proposal.
Each bounded ticket has an agreed stop budget and returns completed/pending facts.

A defensible conclusion is: for this workload, source and environment, engine X
used the measured time/memory shown. A benchmark may be successful even if RDF
wins; knowing why is the basis for the next engineering decision.

Official reference: https://root.cern/doc/v640/classROOT_1_1RDataFrame.html . Pin
actual installed versions and optimized C++ build settings in any future run.
