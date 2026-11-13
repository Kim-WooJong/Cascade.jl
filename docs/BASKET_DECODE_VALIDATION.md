# Experimental detached basket decoding

## Status and scope

This is one opt-in framework step, not an accepted release or a promise of
I/O-limited throughput. Default decode_threads=1 retains the original reader,
including the experimental column_readers engine when separately requested.
The old reader, window exporter, corrections/source reuse, shape execution,
Reduced sources and normalization algorithms are not rewritten.

Phase A mandatory remediation passed narrow independent review with no blockers.
The separately authorized Phase B final-source confirmation is recorded at the
end of this document. Earlier427/688 results remain historical. The broad
sustained-throughput/I/O-ceiling goal remains open.
Only Mac source/tests and this new document are edited. Gate execution is under
/path/to/user/analisis/Cascade_dev/basket-decode/candidate, with a separate frozen
baseline/project. Historical parallel-selection and p11 work are not resumed.
No RDF benchmark files, dependency installation/resolve, depot modifications,
staging, commit or push are part of this work.

## Execution configuration

~~~toml
[execution]
decode_threads = 1 # positive integer or "auto"; default preserves old path
decode_queue_jobs = 32
decode_queue_bytes = 67108864
~~~

Booleans/nonpositive values are rejected, including in inactive profiles.
Requested threads are clamped to process Threads.nthreads() and queue job
capacity, not host cores or an arbitrary four/sixteen cap. "auto" means the
process thread budget. Requesting both decode opt-in and column_readers>1 is
rejected rather than nesting pools. A one-thread/one-slot process falls back.

Opt-in selection owns files serially at stage level. Each phase has one
producer/assembler and at most B-1 decoder tasks, total B actors within the
process budget. There is no file-worker times inner-worker fanout. Other
stages and default selection use their old scheduler. A fallback may therefore
retain serial input science but not the old multi-file scheduling when the new
stage mode was explicitly requested. Workers are phase-local and joined before
return, including failure; there is no persistent source or trust cache. The
caller must exclusively lend its source during the scope; concurrent external
use or hot replacement of its reader methods is unsupported.

Eligibility requires unchanged built-in reader registrations, original local
NanoAOD mmap source and Linux mapping identity. Borrowed windows/lazy wrappers,
custom/non-mmap/reduced/cols sources and shape selections stay on existing
read paths. Unknown dependency source contracts fall back before dispatch.
Source identity retains the existing mapping-vs-mapping plus path-stat protocol
and adds /proc/self/map_files readlink binding to realpath(source.path). Without
that additional check a pre-existing old mmap could be paired with a newly
replaced pathname before initial binding. Actual mapping-path drift is an error;
unavailable evidence falls back only before binding, and loss after binding is
an error. No ROOTFile is reopened and no map/stat device-number conversion is
introduced. The rename regression proves rejection even when called without a
previous expected identity. This does not certify hostile in-place modification,
portable macOS identity or untested virtual/stacked filesystem behavior.

## Code map

- Config/decode_options.jl validates the new execution controls; Config.jl and
  validate_keys.jl include/recognize them without canonical_hash changes.
- IO/with_decode_pipeline.jl and decode_dependency_contract.jl establish the
  invocation gate and borrowed ownership; DecodePipeline.jl contains scope/error
  records. decode_source_identity.jl adds mapped-path binding; existing
  column_read_eligibility/column_source_identity remain unchanged and are reused.
- IO/prepare_nanoaod_decode.jl serially builds plans, canonical offsets via the
  existing column_read_jobs, and immutable basket descriptors.
  decode_interpretation_supported.jl restricts eligibility before dispatch.
- IO/validate_decode_blocks.jl, validate_decode_xz_index.jl and
  validate_decode_checksum.jl validate XZ framing, indexed sizes and checked
  transcode coverage; they do not enable a zlib decoder.
- IO/decode_prepared_basket.jl owns mutable decode/offset buffers.
- IO/run_decode_queue.jl and decode_worker_loop.jl implement credited admission,
  detached workers, ordered consumption and join/error handling.
- IO/assemble_decoded_basket.jl and read_decoded_columns.jl allocate/assemble the
  same flat/Jagged columns. IO.jl includes/exports the new entry points.
- Selection/read_selection_columns.jl and run_selection.jl plumb an optional
  decode scope, retaining the original pre/prefix/post/science structure.
- Pipeline/run_decode_file_tasks.jl owns opt-in serial files; step_select.jl and
  Pipeline.jl integrate it. The existing run_tasks scheduler is untouched.
- test/basket_decode contains focused/admission/native/fallback/source-reuse
  checks, the fixed pilot and the post-timing ordinary-output verifier.

## Adapter and ownership

UnROOT0.11.11 LazyBranch retains ROOTFile and mutable buffers. basketarray(lb,i)
re-enters basketarray(file,branch,i), repeats type/streamer resolution and is not
a detached prepared decoder. No supported public prepare/decode API exists.
The new adapter explicitly depends on package internals; its invocation-local
contract hashes nine relevant UnROOT source files and checks the exact version.
The manifest tree is13783ae508c50e99ff3bb252f46f6965a57606cb; semver compat alone
is not treated as an exact dependency pin. Runtime method replacement/hot reload
is unsupported; source hashes cannot detect arbitrary newly added methods.

Producer-only preparation resolves branch metadata and actual T/J types, builds
canonical counter offsets and validates the phase before any decoder dispatch.
Original needed-mask skipping and zero placeholders are retained. Supported
interpretations are regular UnROOT.TBranch scalar primitives and single-level
primitive Nooffsetjagg only. TBranchElement and Offsetjagg return
unsupported_interpretation before phase dispatch. No new streamer dependency
contract is asserted; streamers.jl was not added to the audited hash set.
Recovered/malformed-index/unsupported custom, nested, fixed-vector or string
encodings fall back before the phase. Structural corruption of supported input
throws rather than being hidden as an unsupported-format reason.

Worker jobs contain only prepared T/J, immutable basket key/numeric block
values, event count and an exclusively owned Vector{UInt8}. There is no ROOTFile,
LazyBranch, stream, branch metadata, source dictionary or mmap view in a job.
Workers never perform file lookup. Decompression/offset interpretation mutation
belongs exclusively to that job. Only producer assembly mutates final columns,
in original unique-branch and basket order. Prefix/event loops, cutflows,
histograms, merges, original entries and Runs normalization remain unchanged.

Compression framing/block totals are checked before native decoding; decoded
basket offsets are checked before interpretation. Single-stream XZ index lengths
are also checked before native decoding: upstream broadcasting could otherwise
repeat a one-byte decoded result into a larger declared output slice. Only
uncompressed baskets and checked single-stream XZ are enabled. ZLIB, LZ4,
Zstd and other compression algorithms return the unsupported-codec signal before
any worker dispatch; the complete phase retains the old serial reader.

An independent Adler checksum does not establish successful DEFLATE termination.
The independent zlib('x') fixture789cab000000790079 validates the old serial
path. Valid ZL, bad Adler and BFINAL ab-to-aa variants are all rejected by the
new fastpath gate. The incomplete/BFINAL variant is NOT passed to the native
legacy decoder in these tests; no codec-status guarantee is inferred from its
output. There is no new deflate parser, transitive LibDeflate binding or dependency.
XZ uses upstream checked transcode and stream/checksum error propagation.
This is not a compressed-input sandbox: codec-native allocation and malformed
stream behavior remain limitations, particularly XZ internal memory/output
allocation before its checked transcode returns.

## Backpressure and failure contract

The ordered sliding window holds at most decode_queue_jobs admitted ordinals,
including queued, running and completed-but-not-assembled jobs. Byte credits
are reserved before compressed payload staging and retained until ordered
assembly drops the result. The charged array-payload estimate per basket is
3*compressed + 3*declared_decoded + 16*(entries+1), covering adapter staging,
block copies, decoded/interpreted payloads and offset intermediates. This is
accounting, not an allocator reservation or a hard live-heap/RSS theorem.
A single reservation over the budget throws before dispatch, not an infinite
wait. Small serial key/header staging is separately bounded metadata (key<=64KiB).

Full-file final columns, counters, masks, metadata/descriptors, append capacity,
codec-native scratch, GC-retained allocations and mmap residency are outside
queue accounting. This step is not windowed ordinary selection. The validation
watchdog's16GiB sampled process-group RssAnon circuit breaker is only a validation
safety stop, never a production memory guarantee.

Producer drains completions when admission is blocked. Bounded input and
completed-result containers share guarded state; separate work/supervisor
conditions avoid result-capacity-dependent fatal publication and unnecessary
worker wakeups for ordinary results. Lifecycle exceptions at input wait/take,
active bookkeeping, decode boundaries and publication become observable fatal
control state and wake the controller. Notifications cannot block on a full
result buffer. No busy-polling monitor or global supervisor is used.

Public Threads.@spawn :default places workers on the compute pool, not the
single main/interactive pool. The protected try/finally retains each returned
Task before releasing its startup Event; controller SIGINT is briefly deferred
through spawn/registration. The Event wait itself is inside worker supervision.
Failures before creation, before startup release or after startup join every
retained task in the tested single-cancellation paths. Repeated asynchronous
interrupts during cleanup can interrupt a join; this is not an uninterruptible
cleanup guarantee. Idempotent Event notification gives any parked startup a
shutdown-only continuation without blocking cleanup. Late failures after
the final result was consumed are inspected after joins before control state is
dropped. Queued/completed/local references are drained; every reserved count/byte
credit is released once, with final active/live/retained counts recorded as zero.
The synthetic tests additionally check finished tasks and released WeakRef payloads.

On an ordinary decode/preparation failure, admission stops and admitted jobs
settle. Lower ordinal frontier assembly still runs when a higher ordinal decode
has already failed, so a lower assembly failure wins deterministically. Lifecycle
fatals are distinct DecodeWorkerError values with their captured backtraces.
Decoder-thrown InterruptException and cooperative cancellation are cancellation,
not fake corrupt-job errors. cancel_decode_queue! wakes controller/input waiters
without interrupting native code. Primary controller/cancellation errors survive
secondary cleanup failures. Metadata setup errors before admission remain direct
errors; there is no promise to diagnose every unadmitted basket after failure.
No partial phase/table is published on the tested failure paths; normally the
borrowed source closes only in its owner after workers have joined. Asynchronous
interrupts at lock boundaries and failures inside the supervisor catch handler
itself (for example, allocation failure while recording a fatal) remain library
robustness limits. The tests do not establish recovery under out-of-memory or
repeated asynchronous interruption.

## Cache and diagnostics

Execution settings stay outside scientific selection section keys. Full config,
batch and reduced-contract hashes still see them; canonical_hash is untouched.
Source code hashes naturally invalidate affected artifacts. Cache hits retain
original generation diagnostics rather than pretending the new width ran.

Sidecars record requested/effective actors, worker/active-call overlap, queue
job/charged-byte high water, requested compressed payload bytes, declared decoded
bytes, basket requests/skips, phase/job maxima, fallback reasons and dependency
hashes. Compressed counters count logical repeated requests, not unique physical
file bytes. max_active_decoders is overlapping calls, not measured CPU activity.
Task wall-time sums overlap; per-job @timed allocation observations can include
concurrent Julia activity and their sum is NOT unique total allocated bytes.
Use phase-wide allocation observations/counters separately. Credit-reserved/
released and final active/live/retained counters describe the last queue phase;
request totals and high-water fields accumulate across the invocation.

## Validation environment and immutable baseline

Existing Julia1.12.2 wrapper:/path/to/user/packages/rootplots-gate.sh. BLAS1,
JULIA_PKG_PRECOMPILE_AUTO=0 and --compiled-modules=existing; one Julia validation
process at a time, hard300s each. No new precompilation/setup requested.
The initial focused01 used the300s timeout but not the subsequently installed
RssAnon watchdog; the pre-remediation22 JSON-receipted runs totaled1075.459s.
Phase A adds four correctness-only runs totaling180.720s, bringing monitored
wall time to1256.180s across26 runs, with no circuit trips. The initial focused process was
also bounded to300s; PNG/metadata checks were short and outside analysis clocks.

- Frozen baseline source412 record digest:0ce0226d8a7cef5bafe8b27a06fd13ddd46ff1e4f1d7b2cd87211d118bc2ad11.
- Frozen baseline runtime667 record digest:b494cb2d98daa9e5a72cf968f03a875c2c6e241115ed94540bca6227be059d88.
- Manifest:00ea56222e1348ebacf895819d7b07d41740e05b4a708ba7ae5e1d34e5e83119.
- Wrapper:7d8eca8a88229cde40f106cb8723b446abc75dbef341522884981c1deaddc23d.

Records use SHA256 + TWO spaces + sorted relative path + LF. Gate baseline
runtime667 was checked against the frozen list before modification. Source
sync is explicit src/ and test/basket_decode/ only into the isolated candidate;
Project, Manifest, analyses and existing tests remain from the baseline copy.
Final candidate input records and after-parity checks are recorded below.
Codecs used were CodecXz0.7.4, TranscodingStreams0.11.3, XZ_jll5.8.4+0 and
LibDeflate0.4.4/libdeflate_jll1.26.0+1. Relevant codec/transcode source hashes are
in ../evidence/decoder-dependencies.before.sha256, with an after check. The
UnROOT adapter hashes are also embedded in each native execution diagnostic.
No shared/reused transitive codec context or undeclared dependency was added.

### Snapshot boundaries (record-list SHA256)

| Scope | Source records/digest | Runtime records/digest |
|---|---|---|
| Warm pilot |425 /3cb7a3dcda4e8407e59c95b904282402ad6462e48c785337944506b04b6651ef|686 /7c8880f6afb684bd9483411457d66c28c2641447b41b76854db3849127c43250|
| Ordinary CLI, pre-XZ-index hardening |425 /c03415324a15e22d0b0efdf0a50ff4e472804779516c18e48a6a8182cb72c3a7|686 /11b6da1bb0fff41449abdf051d1ea77b098b2f129268e7fffa2cecc6692d552b|
| XZ closure, before mapped-path binding |426 /8690ebeb1f14e74c98f43eeb86dfd4ac743e42cbe8ff11dac2283d34bfaa8352|687 /e62f7c7d60fc60b83da91204646a447961c54983f081e3ae1ef9028bf7f8722d|
| Pre-phase-A ownership closure |427 /b27fd3e7aa4aa8c9ed5bc6c030fb56f619145f729cd4d829a0a10ea162555230|688 /f7a538f637f857c56c5843bdd3af18efd19c8504413665f9b47b1a498a8790c7|

The pilot predates the direct-API Bool parity guard and narrow fallback/key/join
hardening. Ordinary CLI observations include those fixes but predate the XZ
index-length and mapping-path guards. The pre-remediation native/focused/guard checks cover
the historical427/688 bytes; neither the warm pilot nor the three full CLI clocks
were rerun after those guards. They are explicitly NOT final-source timing evidence or
current-code cache hits. Source changes naturally change scientific code keys.
The prior variants are preserved/reconstructible from pilot-snapshot and
pre-xz-index/pre-mapped-path overlays in ../evidence; pilot425/686 reconstruction matched every
record. That archived source/runtime pair remains reconstructible. Current Phase A
source/runtime before/after records and Mac/gate parity are listed below.
Both frozen baseline667 and previous parallel-selection candidate667 records
remain unchanged. Only seven authorized existing runtime files differ from that
baseline; all other existing inputs, including Project/analysis/canonical_hash,
and native inputs/Manifest/wrapper/dependency sources remain unchanged.

The producer removes extra ROOTFile opens by construction; the preceding
negative reader-pool timings did not isolate opening cost, so that cost is not
claimed as their measured cause.

## Receipts and development failures

All logs/exit/receipt files are under candidate unless qualified otherwise.

- focused01:127 pass, actualexit0, initial zlib-only adapter.
- actual01:348 native assertions passed but17 failures/one error exposed that
  real fixtures use XZ; preserved failed log/exit1. No speed claim uses this run.
- Initial watchdog launcher had a Python string-escaping syntax error before
  native launch; it was corrected without retrying/overwriting a native receipt.
- actual02:127 focused plus750 native passes, actualexit0; XZ-enabled adapter.
  Widths1/4/8/16 and three16-width correctness repetitions, both frozen inputs.
  Subsequent small worker-reference cleanup is distinguished in final receipts.

OLD427/688 receipts, actual exits0 (scopes overlap; not rerun in Phase A):

| Receipt | Scope | Passes |
|---|---|---:|
|ownership-final|16-thread focused plus both native sources; widths1/4/8/16, three16-width repetitions; XZ and pre-bind replacement guards|899|
|ownership-focused|one-thread focused queue/config/bytes/NaN/XZ regressions|139|
|ownership-guards|cols/shapes/cache fallback16 plus correction-source ownership/parity/cache/custom-hook44|60|
|ownership-verify|stored ordinary selection/SF weights, histogram edges/sumw/sumw2, sample denominators/normalization and regenerated numeric transport|115|
|png-final|three complete PNG CRC/zlib/filter/nonblank decodes|3 images|
|index-final|all three ordinary plot indexes reference exactly one PNG and existing published files|exit0|

The completed-result credit observer also contains two asynchronous assertions;
failures propagate via wait(observer), but they are not included in the two
outer assertions reported by that testset. Barrier tests prove simultaneous
entered detached-job workers, not native instruction-level CPU overlap. Actual
native max_active_decoders reaches15; this remains overlapping-call evidence,
not a CPU utilization claim. No extra ROOTFile opens occur. Both raw and selected
primitive types/bits, high IDs/NaN payloads, jagged storage/offsets, masks and
opposite-mask rereads, original selected order/stages and cutflows agree.

The final XZ guard includes a valid one-byte XZ fixture and inflated decoded-size,
index bounds and corruption regressions. Generic queue tests cover completed
out-of-order results retaining count/byte credits, producer/decode/assembly
failures, deterministic admitted error ordering, cancellation and joins.

Native files are the same original TT32853 and MuonEG104057 paths in
PARALLEL_COLUMN_READ_VALIDATION.md. No dataset restart or full suite was run.

## Bounded throughput pilot

Metadata-only inventory of the existing non-extension TT40000 directory found44
files. The representative file is the size-sorted median of the22 files between
240MB and1GB, chosen before any performance observation:

/path/to/user/nano_slim/mc/Run3Summer22NanoAODv12/TTto2L2Nu_TuneCP5_13p6TeV_powheg-pythia8/NANOAODSIM/130X_mcRun3_2022_realistic_v5-v2/40000/8e19bf87-6db0-43b6-b5df-ccca341ae243.root

Size573816278bytes, inode537543811,
SHA2562a0c66fa29d8c681280bedf8dc091c5a118b923a11c5b72513f4d0adda74d212.
Metadata inventory and stat/SHA/fincore receipts are under ../evidence.
Fincore before SHA reported0 resident pages; after SHA140092 pages were resident.
Thus SHA preflight warmed the entire input: this pilot cannot certify physical
storage saturation. No cache dropping, fadvise/directIO or host tuning was used.

The fixed21-branch alternating-mask workload is test/basket_decode/pilot.jl.
Each fresh process performs one excluded warmup and at most two measured passes.
Threads1/4/8/16 are separate processes, not RDF comparisons. A first1T steady
pass over20s would require reducing/fixing work before the remaining arms;
the original calibration is retained. Phase-boundary CPU/user/sys, GC,
allocations, memory, faults, /proc/self/io and task schedstat are recorded.
Host diskstats are context, not attributed process I/O. Missing counters are null.
Science fingerprints and logical basket inventory must agree across arms.

All four arms exited0. The1T calibration was5.169s for its first measured pass,
so the originally fixed workload/passes were not reduced. Warmup was excluded
in each fresh process; measured compile_seconds was0 throughout.

| Process threads | Measured seconds, passes1/2 | Logical compressed payload MB/s | CPU user seconds, passes1/2 | GC seconds, passes1/2 |
|---|---|---|---|---|
|1, original serial reader|5.1691 /4.1609|10.20 /12.67|5.047 /4.085|0.737 /0.588|
|4, producer+3 decoders|1.8900 /1.8203|27.90 /28.97|4.780 /4.792|0.195 /0.187|
|8, producer+7 decoders|1.2905 /1.1306|40.86 /46.64|5.917 /5.392|0.190 /0.160|
|16, producer+15 decoders|0.9663 /0.8895|54.57 /59.28|7.272 /6.630|0.172 /0.130|

Every pass read the same3260 decode-job baskets, requested52728780 compressed
payload bytes and declared139267463 decoded bytes over526347 Events. The
serial canonical counter reads and metadata are additional work in every arm;
these payload counters are not all OS traffic. All raw column/offset/type
fingerprints equal379a5840d97165f9686d6ef7f53dbe104a71c8e97d40bbc9e8b77c36e3dd56bb.

Parallel queue high water was32 jobs and at most16395088 charged bytes, with
max_active_decoders3/7/15. Phase allocations were approximately1.339GB serial
and1.310–1.311GB parallel, not the queue-byte estimate. End-phase RssAnon ranged
650356–975884KiB; VmHWM reached1402576KiB. All measured phases had0 major faults
and read_bytes delta0. Complete before/after counters, minor faults, schedstat,
per-job observations and raw diskstats are in pilot-t*.log / ../evidence;
pilot-summary.json extracts numeric phase evidence.

The16-thread arm was the fastest tested with diminishing returns in these short
warm observations: its two times were below both8-thread observations. This is
not a useful-thread-capacity or sustained-throughput determination.
There are only two passes per arm, with appreciable spread, particularly1T;
there is no statistical guarantee,80-thread extrapolation or long-duration scan
proof. An arbitrary0.25 efficiency slope is neither a mandatory rule nor an
approval criterion. Serial preparation/counter work was about0.35–0.39s and assembly about
0.03–0.05s in the parallel arms. CPU work rises with width; producer work and
GC remain visible. The counters support CPU/decode/coordination limitations,
not a physical-storage ceiling. No larger arm or input scan was launched.

## Fresh ordinary CLI totals

At most three fresh --force workdirs:16T old serial-reader control,4T detached4,
16T detached16. Same small two-input nominal SF/ge1j/njet/one-PNG config copied
from the preceding validation candidate; no production analysis edits. Timers
cover wrapper start through ordinary process exit after plot/index publication.
Output/SF/histogram/normalization/transport and full PNG checks run afterward.
Only16T control versus16T new is an equal-resource algorithm observation;
4T versus16T is not. Historical412-source totals are not pooled.

All three ordinary CLI cases exited0; each published its normal index and one
native PNG before process exit. GNU time clocks below cover the ordinary wrapper
and children; the watchdog receipts include an additional polling tail of at
most roughly0.2s. These are single observations, not a stable speed estimate.

| Case | GNU elapsed seconds | Watchdog wall seconds | Select stage seconds | GNU maxRSS KiB |
|---|---:|---:|---:|---:|
|16T original serial-reader control|91.51|91.682|9.70|1437728|
|4T detached4|99.70|99.927|15.68|1427572|
|16T detached16|90.04|90.235|15.20|1536808|

The equal16-thread total observation is1.47s lower with detached decoding,
but selection itself is slower in these fresh processes and plot/startup/JIT/
other costs vary. One observation cannot establish stable total-time benefit
or attribute it to the reader. The4T/16T resource change is not an algorithm
speedup comparison. Keep the new feature experimental/default1; no new release
or recommendation to enable it for ordinary small-file totals is established.

All science, SF-weight bits, histogram values, signed generator denominator
2646014.7375000003, data norm1 and regenerated BIN transport match. PNGs are
596x692 RGB, fully decoded,36 distinct pixel values; all three happened to have
SHA2568036e6bb63d3e9398e08ac430e6716898ad0fcd4a34421c36b5fca02b151ec5d.
Byte equality is observed, not the renderer's required scientific contract.

Exact commands/actual exits/time/CPU/maxRSS are total-*.command/.log/.exit and
.receipt.json; total-summary.json records stage clocks and published indexes.
The three configuration copies differ only in execution.decode_threads; their
origin/hashes are configs/origin.json. The timer does not include post-timing
verification or transport regeneration. No renderer adapter was substituted.

No physical-I/O ceiling, RDF competitiveness or blanket performance acceptance
is established. No larger scan, old full suite/data job/p11 restart, installation,
staging/commit/push or benchmark edit followed. Those executions ended; ../evidence/completion.json records their old closure.
The current Phase A completion/quiescence receipt is phase-a-completion.json.
The parent retains the open performance goal and the implementation acceptance
and next-step decision.

## Phase A concrete-review remediation

Pre-remediation427/688 is preserved byte-for-byte under
../evidence/pre-phase-a/project, checked against ownership-*.before.sha256.
The focused/native Phase A receipts and new source/runtime digests below replace
that snapshot for code correctness only. No new performance, old full suite,
renderer, guard60 or stored-output115 run is part of this fix phase; those older
receipts/PNGs/timings retain their original source labels. Default1 and the broad
open performance goal are unchanged.

### Exact remediation delta

- Enabled compressed fastpath is XZ only; uncompressed remains supported. ZL
  valid/bad-Adler/BFINAL and multiblock fixtures return unsupported before phase
  dispatch. Only the independent valid legacy zlib fixture is natively decoded.
- Regular TBranch plus scalar Nojagg or primitive Nooffsetjagg only; TBranchElement
  and Offsetjagg are excluded before dispatch. Source hash set stays at nine
  UnROOT files; streamers.jl and dependency/configuration changes were not added.
- Higher decode failure no longer suppresses lower frontier assembly. A slow
  job1 assembly failure beats a fast job2 decode failure as ordinal1.
- Entire worker lifecycle, startup and late publication are supervised using
  guarded fatal/cancel state and independent control/work conditions. Partial
  creation/startup failures, capacity-one fatal publication, input/result parked
  interruption, decoder cancellation, secondary cleanup and payload release are
  explicitly tested. No asynchronous interruption of actual native decoding occurs.
- The credit observer releases its gate in finally even if an assertion fails.

The first frozen Phase A variant passed286 focused /1052 combined native
assertions, but its native diagnostics exposed serialized execution from plain
Task scheduling (max active1). It is NOT accepted as a concurrent implementation
or performance observation. Its files/records are preserved in
phase-a01-scheduling and phase-a-*.before.sha256. The corrective public
@spawn :default/startup-Event implementation is the final Phase A snapshot.

| Final receipt | Process / limit | Passes | Actual exit | Validation wall seconds |
|---|---|---:|---:|---:|
|phase-a-focused02|1 thread;60s watchdog|302|0|27.679|
|phase-a-native02|16 threads;300s watchdog; both frozen inputs;1/4/8/16/16/16 widths|1078|0|62.007|

Both use BLAS1, the existing wrapper/Manifest and16GiB sampled RssAnon safety
stop. The first two Phase A01 receipts are retained too:27.305s and63.729s,
actual exits0. All four are correctness/resource receipts, NOT new throughput
measurements. Final native overlap is3 at width4,7 at width8 and14–15 at width16;
all tasks finish, active/live/retained counts are0, and reserved/released credits
and bytes agree. Generic finished-task/WeakRef tests also pass.

Current source428 record digest:
0a0937bf2d98067a01fee8b2c661fe87ee8cfe3b1157363b5ab6e6d42fb19f37.
Current runtime691 INCLUDING Project.toml record digest:
ce449ec70c81a1995b4f170146faaaa07e5a4ee63d8cb19cf19a966ce9d03615.
Standard TWO-space sorted relative records are
../evidence/phase-a02-{source,runtime}.{before,after}.sha256; all records and
current Mac/gate bytes match. Pre427/688 and first Phase A01 reconstruct exactly.
Baseline412/667, the old parallel-selection candidate667, both native sources,
Manifest/wrapper and recorded dependency source bytes remain unchanged.
../evidence/phase-a-completion.json records no owned Julia process and the exact
file delta/receipts. No new guard60, verify115, PNG, CLI pair, scaling matrix,
large input scan, p11 job, installation, staging, commit or push followed.

No performance acceptance is inferred for source428. Remaining monitored
headroom against1500s is about243.820s; the initial pre-watchdog focused run is
still separately excluded as previously disclosed. Any further performance
work requires the parent's narrow re-review/acceptance and explicit budget
approval. Correctness is not traded for a faster result. Default1 and the parent
performance goal remain unchanged/open.


## Phase B: final-source confirmation (428/691)

After Phase A acceptance, the parent explicitly authorized at most300 additional
monitored seconds. No product, runtime test, project, dependency or existing
analysis configuration changed. Measurement/verification helpers and copied
configurations are outside the frozen project in:

/path/to/user/analisis/Cascade_dev/basket-decode/candidate/phase-b-final428

All three Julia subjects were fresh16-thread processes with BLAS1, one at a
time, existing Julia1.12.2 wrapper/Manifest and compiled-modules=existing.
There was no1/4/8 scaling repeat. A sampled16GiB process-group RssAnon stop and
per-process wall limit were active; neither fired. The two ordinary cases were
prioritized before the ABBA process; post-timing science verification then ran
in that same ABBA process to avoid another Julia startup. Every raw exit is0.

### Fresh ordinary CLI totals, same16-thread allocation

Both ordinary --force invocations ran skim,select,correct,histogram,merge,
systematics,plot on the same frozen32853-event TT and104057-event MuonEG files,
same SF/ge1j/njet configuration and existing ROOTPlots renderer. Each used a
new configuration filename and unique work directory. The byte-for-byte copied
configuration hashes are unchanged from the previous decode1/decode16 copies.
No cached output was reused. Both set column_readers=1.

The timer starts immediately before launching the wrapper and stops at blocking
wait4 return following normal exit, AFTER native PNG and index save/close.
Watchdog thread join is outside this clock (0.000157/0.000138s). These timings
are not pooled with pre-remediation totals.

| Current-source case | Full wrapper seconds | Selection seconds | User/sys CPU seconds | maxRSS KiB | Minor/major faults |
|---|---:|---:|---:|---:|---:|
|16T process, legacy decode1|87.515569|9.37|105.934946 /1.651484|1380620|475678 /5|
|16T process, detached decode16|94.268515|16.06|112.226945 /1.853720|1426836|458659 /3|

The detached total is6.752946s (7.72%) slower in this single matched pair.
Selection is also slower. No stable end-to-end superiority is established;
keep default1 and the feature experimental. This negative observation is not
replaced by the warm phase improvement below. Both process wait4 block-input
counters are0; per-CLI /proc read_bytes was not captured and is unknown, not
inferred from that block counter. Sampled group RssAnon peaks are1200951296
and1253093376 bytes. Actual command argv, selected environment, clocks and exits
are total-t16-d{1,16}.{command,command.json,log,exit,receipt.json}.

Post-timing verification on THESE new outputs passed75 assertions (exit0):
selection/correction column types and bits, event order, metadata, SF weights,
cache keys, cutflows, histogram edges/sumw/sumw2, sample normalization and signed
generator denominator2646014.7375000003, MuonEG norm1, regenerated numeric BIN
transport and detached ownership diagnostics. Both detached samples used15
workers, overlapped15 decoders, no fallback, no extra ROOTFile opens/closes,
joined all workers and ended with zero active/live/retained payloads and
balanced byte/job credits. Default1 retained its original file-stage scheduler;
opt-in files were serial at that stage, as documented above.

Separate post-timing Python verification fully decoded BOTH new PNGs, checked
all chunk CRCs/filter reconstruction/nonblank pixels and both indexes and index
sidecars. Each index publishes its own existing yields.txt and exactly one PNG.
Both images are596x692 RGB with36 distinct pixel values and observed SHA256
8036e6bb63d3e9398e08ac430e6716898ad0fcd4a34421c36b5fca02b151ec5d.
PNG byte equality is an observation, not an assumed renderer science contract.
See scan-abba-verify.log and verify-png-index.log.

### Warm phase-only ABBA, same16-thread process

The single fixed TT pilot remains573816278 bytes, inode537543811, SHA256
2a0c66fa29d8c681280bedf8dc091c5a118b923a11c5b72513f4d0adda74d212.
Its exact path is ../evidence/pilot.path. This is the same21-branch,
alternating-event-mask workload; common serially prepared metadata inventory is
3260 requested baskets,52728780 requested compressed payload bytes and139267463
declared decoded bytes. These are logical requests, not unique physical bytes;
serial counter/metadata traffic is additional. The legacy default diagnostic
counters intentionally remain0, not newly instrumented. Detached diagnostics
match this inventory on every warm/measured pass.

Both product paths were warmed first and excluded (legacy5.897771s,
detached5.172553s). Measured ABBA order is legacy,detached,detached,legacy, with
T=16 for the PROCESS in every row. Thus legacy does NOT mean a1T allocation.
Only the product read phase is timed; resource snapshots, raw bit fingerprints,
assertions and GC between passes are outside the phase clocks. Every fingerprint
is379a5840d97165f9686d6ef7f53dbe104a71c8e97d40bbc9e8b77c36e3dd56bb.

| Order / decoder | Phase seconds | GC seconds | User/sys CPU delta | Allocated bytes | Minor faults |
|---|---:|---:|---:|---:|---:|
|A /legacy1|3.698930|0.244502|5.670495 /0.072569|1338716880|20416|
|B /detached16|0.952644|0.143821|7.132049 /0.120559|1310134344|23654|
|B /detached16|0.890490|0.123542|6.905808 /0.069989|1310213032|9832|
|A /legacy1|3.709423|0.233786|5.637080 /0.055708|1338723952|28382|

Measured compile-time is0 on all four. Major faults, read_bytes and write_bytes
deltas are all observed0. Mean phase times3.704176s versus0.921567s give a
4.019x ratio for this warmed phase only, or14.235 versus57.216 decimal MB/s of
logical requested compressed payload. The pair spreads are0.010493s legacy
and0.062154s detached; two short passes do not prove sustained capacity.

Detached serial preparation takes0.381397/0.360253s and serial assembly
0.041767/0.031785s; summed overlapping decode task times are7.044376/6.435457s.
Each phase reached15 simultaneously active decoders, queue highwaters32 jobs
and16395088 accounted bytes, and released all3260 admitted job credits.
Max job durations are0.043796/0.043997s; reported max job allocated bytes are
15836744/16120592 (concurrent Julia allocation-counter diagnostics, not an
exclusive native scratch or RSS bound). End-of-phase tasks are done and
active/live/retained counts are0. Full-file output columns, counters/masks,
metadata/mmap, codec/GC scratch remain outside credit accounting.

Measured phase-end RssAnon KiB is930312,945756,981648,894988; RssFile is426020
KiB throughout. Raw VmHWM/VmRSS and per-thread schedstat snapshots are retained
without rewriting their observed kernel values. Schedstat aggregate run deltas
are5.743115,7.252607,6.975798,5.692787s and wait deltas1.003347,0.368577,
0.638415,0.453216ms, respectively. These unprivileged per-process snapshots
are observations, not host-wide utilization attribution. Other uncollected
counters are unknown; no pidstat/perf/tool installation was performed.

Pre/post SHA validation warmed the OS cache; fincore shows resident cached input.
Zero physical read_bytes therefore cannot establish a storage ceiling. This
observation supports improved warm CPU/decode phase throughput, with a sizable
serial preparation cost, not I/O saturation, sustained scan capacity, largest
useful thread count, RDF competitiveness or a general total-time improvement.
No new scaling slope or hardware-wide thread recommendation is inferred.

### Evidence closure and unchanged bytes

Phase B monitored walls: ordinary control87.515568553s, ordinary detached
94.268514848s, ABBA plus science verifier62.222669431s, PNG/index verifier
1.394120036s; total245.400872868s under the additional300s allowance.
Cumulative monitored wall is1501.580655043s (previous1256.179782175s plus B).
The initial pre-watchdog focused run remains separately excluded as disclosed;
this is not a claim that every earlier setup/oracle second is in that total.
No more native/performance job followed these bounded receipts.

All Phase B helpers are outside candidate/project. Standard two-space sorted
relative helper/config hashes are evidence/helpers.before.sha256 and identical
helpers.after.sha256. An external index-check helper's initial assumption about
PNG-sidecar location was corrected to the actual index-sidecar contract before
it was run; its original bytes and control-launch helper record are retained in
evidence/check_outputs.initial.py and helpers.total-control-launch.sha256.
No failed scientific execution is suppressed. Full raw commands/scripts,
receipts, diagnostics and phase boundaries are retained, not only this table.

Key helper SHA256 values:

- run_b.py:522f2ede2809e3c1d72a877c3dc7572c566c84bacc04f8a2a2b13fb3f15714f7
- scan_abba_verify.jl:15eb414ed79e2422cec36a72781f7058dcd715d3e24e42d85e05408d5ee0dd81
- verify_final_pair.jl:a51469aeee8e3d8b8214fc53a7fc2ce11d83cd8fedb8eb9fc8d4f5cc0c94476f
- final-decode1.toml:55082cc6dcc1727de944e2951a3f52ea85dad41afd95f9af20d394f90b74ed77
- final-decode16.toml:147c1a05ce93a9216b5faf4b145aee6c2d132d7aedea114d4260c26c8fb42233

Blocking wait4 is the normal-exit boundary; watchdog joins are recorded outside
it. No interrupted owned Julia job existed before any launch. All recorded
owned groups are empty after exit; no owned Julia process remains. Frozen691
runtime and428 source records match before/after and Mac/gate byte-for-byte:
source0a0937bf2d98067a01fee8b2c661fe87ee8cfe3b1157363b5ab6e6d42fb19f37,
runtimece449ec70c81a1995b4f170146faaaa07e5a4ee63d8cb19cf19a966ce9d03615.
Baseline412/667 and the separate parallel-selection candidate667, both native
inputs/pilot, original Manifest/wrapper and dependency records remain unchanged.
Project/analysis/canonical_hash, existing README/PERFORMANCE documents, source
reuse and experimental reader controls remain preserved. See evidence/
protected.{before,after}.json, baseline-protection.after.json and results-summary.json.
Only this NEW validation document changes after the product freeze. No stage,
commit, push, dependency modification, benchmark edit, p11/full-suite restart or
physical-I/O/RDF success claim is made. The parent's performance goal stays open.


## Parent closure

Final concrete static rereview b442093c found no blocking issue in428/691.
The parent independently inspected raw Phase A/B exits, focused/native/output
counts, ABBA timing boundaries, matched ordinary configurations and commands,
PNG/index receipts, current Mac/gate records and protected baseline inputs.
The bounded implementation/correctness checkpoint is accepted as experimental
only. Default1 remains; whole-process performance acceptance is explicitly NOT
granted. Current CLI totals regress in one pair despite faster warm decoding.
The broad owner goal remains open; no next optimization or larger scan starts
without the owner's next decision. Parent STATE/memory updates are outside the
frozen runtime; no product bytes or timing subjects changed after freeze.
