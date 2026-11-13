# Cold selection and I/O attribution

Date: 2026-11-07. Scope: owner's 13:59 request to investigate further speed
methods and I/O accounting. Investigation and one diagnostic only; no product,
runtime test, dependency or existing benchmark/planning changes. This is not
performance acceptance, a release, a cold-storage benchmark or a new CLI total.

## Execution provenance and preserved candidate

All native Julia executions were on SSH host validation-host.example, Linux x86_64,
using the existing rootplots-gate.sh wrapper, Julia1.12.2,16 threads and BLAS1.
Mac was used for source/docs/review only. Original ordinary Phase B commands
and selected environment are in basket-decode/candidate/phase-b-final428.

Unchanged sorted SHA256 records (HASH, two spaces, relative path, LF):

- source428:0a0937bf2d98067a01fee8b2c661fe87ee8cfe3b1157363b5ab6e6d42fb19f37
- runtime691:ce449ec70c81a1995b4f170146faaaa07e5a4ee63d8cb19cf19a966ce9d03615
- previous validation document:c4cfe1ff3b2f9d0a7be951483cb762f761f929f14f9128fd00e65bdd52f7d54d

Parent independently checked raw exit/receipt/test summary, current Mac/gate
records, helper hashes and58 preserved Phase B output hashes. Existing native
inputs, Manifest/wrapper and dependency checks passed before and after. No p11
restart, full suite, large scan, install/depot patch, staging, commit or push.

## What the ordinary timings do and do not say

| Existing final-source ordinary envelope | Legacy decode1 | Detached decode16 |
|---|---:|---:|
| Wrapper through normal exit/PNG publication |87.515569s|94.268515s|
| Selection stage |9.37s|16.06s|
| Sum of printed stage clocks |54.07s|60.75s|
| Total less printed stage sum |33.445569s|33.518515s|
| Plot stage |24.85s|25.49s|

The single-pair regression is almost entirely in selection. The residual is
UNATTRIBUTED: wrapper/Julia startup, loading, configuration, inter-stage work,
finalization and exit are possible contributors. It is not33 seconds of proven
JIT. Plot is a large measured envelope, but native renderer startup, transport,
Julia first-use work and drawing were not separately timed here. Native cached
backend binaries predate these runs; repeated C++ compilation is not established.

At fixed observed detached per-file durations, merely overlapping its second
file could remove approximately1.8s, not all6.69s selection regression. This is
a counterfactual bound, not a prediction: changing actor budgets/JIT interactions
can change the durations. An ideal removal of the entire legacy selection stage
would save only about10.7% of its total. Whole-run costs must therefore remain
part of future acceptance; a warm decoder result cannot replace ordinary totals.

## One bounded diagnostic

Evidence directory on gate:
/path/to/user/analisis/Cascade_dev/basket-decode/candidate/cold-selection-attribution428

ONE fresh16T/BLAS1 process, hard120s, sampled group RssAnon16GiB breaker. Actual
blocking-wait4 exit0 in57.551441616s, raw wait status0, no circuit trip or surviving
owned group. Sampled RssAnon peak990027776B.88 parity/ownership assertions passed.
No renderer, new full CLI run,573MB scan, thread matrix or second native process.

Two passes used the same compiled-selection objects but freshly opened/owned
sources for each of the existing MuonEG104057 and TT32853-event files. All four
sources closed; raw22-column types/bits/jagged offsets, masks, selected columns,
entry order/meta/cutflows matched across passes and frozen Phase B references.
MuonEG retained45 entries; TT1493. All scopes had15 workers, no fallback or extra
ROOTFile opens, joined workers and balanced byte/job credits; final counts0.

### Instrumented boundaries

| Diagnostic boundary | First pass | Repeated pass |
|---|---:|---:|
| MuonEG read+prefix |11.049478s|0.201081s|
| MuonEG scientific selection loop/assembly |1.948356s|0.007660s|
| TT read+prefix |1.059051s|0.084660s|
| TT scientific selection loop/assembly |0.508831s|0.015500s|

Wrapper launch to driver entry0.706772s; using Cascade6.828724s; diagnostic-only
imports1.964671s; config loading6.476120s; constructing both compiled selections
2.514878s; lumimask loading0.297855s. First MuonEG source open/metadata costs
0.246618/0.534562s; subsequent opens about0.002s and metadata0.022–0.024s.
These scopes are not an additive decomposition of an ordinary CLI. The57.55s
process wall also includes helper setup, profiling, symbolization and verification.

Cold MuonEG profile stacks include compiler/type-inference/LLVM frames and
compilation waits around decode_prepared_basket and UnROOT.interped_data. One
jl_compile_method_internal line has1362 inclusive samples, compared with68 in
first TT. No corresponding rows appeared in the very short repeated profiles;
that absence does not prove zero compilation. Four bounded profile buffers were
not full; warnings about unsampled groups are retained. Idle/waiting threads and
inclusive overlapping frames mean counts are NOT CPU fractions or exact seconds.

MuonEG preparation/assembly1.222790/1.432695s became0.089174/0.001813s; TT
0.033320/0.125166s became0.028908/0.001055s. The cold-minus-repeat read envelope
11.822788s includes compilation, profiling, GC, allocation and other first-use
or cache effects. It is neither a promised saving nor a transferable CLI speedup.
Exact JIT seconds remain unknown.

## Ranked further speed methods

1. **Recommended next bounded implementation: cache-valid precompile coverage and
   type/function barriers for decoder/assembly primitives.** Targets:
   IO/decode_prepared_basket.jl, IO/assemble_decoded_basket.jl and the supported
   UnROOT primitive interpretation signatures. Evidence for cold compilation is
   stronger than evidence that per-job instrumentation dominates. Cache build
   must be measured/disclosed separately; verify a fresh ordinary launch really
   consumes a valid cache. Do not pre-read native input to manufacture a warm
   startup. Runtime Core.eval selection kernels remain a separate limitation.
2. **Make heavyweight per-basket profiling diagnostic rather than unconditional.**
   IO/decode_worker_loop.jl uses @timed for every basket; run_decode_queue.jl
   aggregates it. Julia1.12.2 enables global allocation/compiler/lock profiling;
   the lock counter is reference-counted. Overlapping allocation/compiler windows
   are not exclusive per-job quantities (summed job allocation can exceed whole
   phase allocation). Lightweight elapsed timing is a candidate; saving is
   unmeasured. Preserve error/cancellation/ownership diagnostics.
3. **Then recover file-level overlap with one global actor/byte budget.**
   Pipeline/run_decode_file_tasks.jl and step_select.jl currently serialize whole
   file tasks in opt-in mode. Never compose independent16-actor pools. This is
   important for many-file production, but is not alone supported as the cause
   of the small two-file regression. Package/plot lazy loading or a separately
   disclosed resident-worker execution model are further candidates, not measured
   improvements or substitutes for fresh-CLI comparisons.

No listed optimization is implemented by this investigation. Default1 remains.
Any cache generation, package changes or next performance matrix needs the next
bounded implementation decision.

## I/O accounting: quantities and formulas

From the PREVIOUS573MB warm pilot (not the new two-file diagnostic):

| Quantity | Value / status |
|---|---|
| Whole input file size |573816278B|
| Logical requested compressed payload per pass |52728780B /3260 descriptors|
| Declared decoded payload per pass |139267463B|
| Mean legacy/detached read phase |3.704176479 /0.9215668265s|
| Compressed logical rate |14.235 /57.216 decimal MB/s|
| Declared decoded rate |37.597 /151.120 decimal MB/s|
| Decoded/requested compressed ratio |2.641204|
| Unique physical byte/page union |UNKNOWN; ranges not retained|
| Measured phase read_bytes/major-fault delta |0 /0, page-cache warm|

Logical rate = requested payload bytes / measured phase seconds. The file size
must NOT be divided by phase time and labeled read bandwidth: only a branch
subset was requested, and counter/metadata/key traffic is additional. Decoded
bytes are an output-size declaration, not measured DRAM bus traffic. No device
bandwidth follows from the logical rates. No physical-I/O time is derivable from
these counters alone. A conditional lower bound U/B requires actual bytes U and
an explicitly justified maximum bandwidth B; neither is available for cold input.

### New direct-process measurements

/proc/self/io brackets all threads of this single diagnostic process (no renderer
children). It measures process storage-read accounting, not ROOT-input-only I/O.

| read+prefix window | read_bytes delta | write_bytes delta | major-fault delta |
|---|---:|---:|---:|
| First MuonEG |1503232B|0|27|
| First TT |0|0|1|
| Repeated MuonEG |0|0|0|
| Repeated TT |0|0|0|

The enclosing first MuonEG profiled selection scope had5029888 read bytes: scopes
are nested, so DO NOT sum it with the inner read+prefix value. Runtime/compiler/
profile pages can contribute. Final self counters90959872 read bytes and6258688
write bytes include profile symbolization/output and reference verification, so
are not input volume or analysis bandwidth. cancelled_write_bytes was0. Repeated
phase zero reads indicate cache hits, not zero copying/decompression cost.

All29 named before/after boundaries, CPU/GC/fault/RSS and rchar/syscr values are
in evidence/phases.csv and results-summary.json. The profile sampler/unwinder,
/proc reads and output alter syscall counters and timings; do not turn them into
ordinary production throughput. No inode-specific attribution or cold-I/O ceiling.

### Counter semantics and honest unknowns

- read_bytes: process-attributed bytes fetched from storage, useful for local
  block-backed filesystems. Other processes can populate cache for us; this is
  not device-wide I/O. rchar/syscr count syscall traffic and miss mmap payload.
- write_bytes: estimated caused storage-write accounting at dirtying time, not
  a device writeback stopwatch. cancelled_write_bytes records canceled writes;
  final writeback timing, latency and I/O wait are unmeasured.
- Old ordinary CLI /proc read_bytes/write_bytes and per-stage values are UNKNOWN.
  ru_inblock0 is a coarse reaped-task count, not an exact byte counter. Do not
  convert it into an asserted read_bytes0. ru_oublock616 similarly is not an exact
  device-byte/time measurement. maxrss is a maximum, not a process-tree sum.
- /proc/pid/io includes waited-for children; wait4 includes descendants reaped
  through that child. Do not add dead-child last samples to a parent's later
  counters, or add root wait4 to RUSAGE_CHILDREN (which already includes root).
  A future monitor must use one accounting hierarchy, identify PID/starttime and
  treat reaping races/unavailable counters explicitly. Zombie final /proc reads
  and an unprivileged subreaper design require their own validation before use.
- Host diskstats is shared-host context only. Gate lacks delegated I/O cgroup
  accounting, PSI and enabled I/O delay accounting for this user; no direct I/O
  wait seconds are available. Cold storage bandwidth cannot be inferred from
  warm scans. No cache flushing, direct I/O, new tools or host tuning was used.

Authoritative semantics references (upstream behavior; gate RHEL kernel backports
may differ):
- https://man7.org/linux/man-pages/man5/proc_pid_io.5.html
- https://man7.org/linux/man-pages/man2/getrusage.2.html
- Linuxv5.14 Documentation/filesystems/proc.rst and
  include/linux/task_io_accounting_ops.h; fs/proc/base.c; kernel/exit.c/sys.c.

## Evidence and closure

attribution.command(.json), attribution.log/.exit/.receipt.json, events.jsonl,
profile-*.jls and flat/tree exports remain in the gate evidence directory.
Helper hashes:
- attribute_selection.jl:71dd919ce72d268fa914e5a7cb4ed8c6cf6c16301ec5c82957b75f7b325f8ab2
- run_diagnostic.py:eb4c62492f0d70bac00ce6f99c50b4d7c572a3d17202e38702d8da289273f546
- helpers2 record:329eab8a044bc52db871574a32589175c50c8fc93bd1b43de5252cd5a1f6cc3a
- preserved output58 record:f3f4706f05a144d6453c53ea4f8729dca14f71c27b5d0e11d4169884ce47fc6a

Initial read-only reports and the independent I/O-accounting correction were
synthesized by the parent; unmeasured CLI physical bytes, unique range unions and
unattributed residuals were not promoted to measurements. All native jobs ended.
This completes investigation only; whole-run speed/RDF parity/I/O ceiling remain
open. No additional native work or product implementation is running/promised.
