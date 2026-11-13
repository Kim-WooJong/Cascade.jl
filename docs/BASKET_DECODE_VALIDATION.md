# Experimental detached basket decoding

This opt-in nominal NanoAOD reader separates serial preparation/assembly from
bounded detached decode jobs. It is experimental, not a throughput or release
acceptance claim. The default remains the existing reader. See
[validation boundaries](VALIDATION.md) and [configuration](CONFIG.md).

## Configuration and API

~~~toml
[execution]
decode_threads = 1 # positive integer or "auto"; default
decode_queue_jobs = 32
decode_queue_bytes = 67108864
~~~

Booleans/nonpositive values are rejected, including in inactive profiles.
"auto" uses the process thread budget. Effective actors are bounded by the
requested width, Threads.nthreads() and queue job capacity; there is no host-core
or arbitrary four/sixteen cap. A one-thread/one-slot budget falls back. Enabling
decode together with column_readers > 1 is rejected, not nested.

Selection.run_selection accepts decode_threads, decode_queue_jobs,
decode_queue_bytes and execution_diagnostics. IO.with_decode_pipeline(run, src;
threads=1, queue_jobs=32, queue_bytes=64*1024^2, diagnostics=...) borrows a source;
IO.read_decoded_columns(scope, names; needed=nothing) reads each phase. A fallback
passes nothing to the callback so the caller can use read_columns.
Width one performs no dependency inspection, metadata preparation or spawning.
Empty name lists return an empty mapping; invalid mask length and missing
nonempty requested branches retain errors. All-false masks retain canonical
jagged alignment and zero placeholders, not arbitrary omitted validation.

Opt-in selection owns files serially at stage level. Each phase has one
producer/assembler and at most B−1 decoder tasks, total B actors within the
process budget; no outer-file × inner-worker fanout is introduced. Default
selection and other stages retain their scheduler. An explicitly requested mode
can therefore retain serial science on fallback without restoring the default
multi-file scheduling. Workers are phase-local and joined before return/error.
The caller exclusively lends its source; concurrent external use and reader
method/registry replacement during an invocation are unsupported.

## Admission, dependency and source identity

Eligibility requires unchanged built-in reader registrations, an original local
NanoAOD mmap source, and bindable Linux mapping evidence. Event-window/lazy wrappers,
custom/non-mmap sources, reduced/cols inputs and shape selections retain their
existing paths. Unknown source/dependency contracts fall back before dispatch.

The adapter uses UnROOT internals: exact UnROOT 0.11.11 plus hashes of nine
relevant source files are checked per invocation by decode_dependency_contract.
A semver range alone is not this pin. Hot reload/new runtime methods cannot be
certified by source hashes. Streamer-dependent layouts are not newly admitted.

Mapping and pathname identities stay separate: mapping-to-mapping and path-stat
tuples are checked without translating stat device numbers. The additional
/proc/self/map_files readlink must bind the mapping to realpath(source.path),
including before initial binding. Actual mapped-path drift is an error; missing
evidence permits fallback only before binding, and evidence loss after binding
is an error. No ROOTFile is reopened. This does not certify hostile in-place
writes, portable non-Linux identity or untested virtual/stacked filesystems.

Producer-only preparation resolves branch metadata and actual interpretation
types, canonical counter offsets and immutable basket descriptors before any
worker dispatch. Only regular TBranch scalar primitives and single-level
primitive Nooffsetjagg are admitted. TBranchElement, Offsetjagg, custom/nested,
fixed-vector/string or recovered/unsupported layouts fall back for the entire
phase before dispatch. Structural corruption of supported input throws rather
than being hidden as an unsupported-layout result.

Only uncompressed baskets and checked single-stream XZ are enabled. Compression
framing, block totals, XZ indexed lengths and decoded offsets are checked. ZLIB,
LZ4, Zstd and other codecs cause whole-phase legacy fallback before dispatch;
there is no new zlib/DEFLATE decoder. An Adler checksum alone cannot establish
successful DEFLATE termination, and unsupported legacy decoding has no new
codec-status guarantee. XZ uses upstream checked transcode/checksum errors.
This is not a compressed-input sandbox: native allocation and malformed-stream
behavior, including XZ allocation before transcode returns, remain limitations.

## Ownership, ordering and science

A worker receives only prepared types, immutable basket key/numeric block values,
event count and an exclusively owned byte vector. It receives no ROOTFile,
LazyBranch, stream, branch metadata, source dictionary or mmap view and performs
no file lookup. Decode/offset scratch belongs to that job; only the producer
mutates final columns, in original unique-branch/basket order. No decoded columns
or trust results persist across mask phases/invocations.

Needed-mask basket skipping, placeholders, primitive bits/types, jagged offsets,
original entry order, prefix/event loops, cutflows, histogram filling, merge and
original Runs normalization remain scientific invariants. Corrections/source
reuse, shapes, reduced-source semantics and export are not rewritten by this
engine. Full-file output columns remain eager; this is not windowed selection.

## Queue accounting and failure lifetime

The ordered sliding window counts all admitted ordinals, including queued,
running and completed-but-unassembled jobs. Byte credits are reserved **before**
compressed payload staging and held through ordered assembly. The per-basket
charged array-payload estimate is:

~~~text
3 × compressed bytes + 3 × declared decoded bytes + 16 × (entries + 1)
~~~

A single reservation above budget throws before dispatch, rather than waiting
forever. Small serial key/header staging is separately bounded (key ≤ 64 KiB).
This is accounting, not an allocator reservation or hard live-heap/RSS theorem.
Final columns, counters/masks, metadata/descriptors, append capacity, native
codec scratch, GC-retained allocations and mmap residency are outside credits.

The producer drains completions when admission blocks. Guarded input/results
and separate supervisor conditions publish lifecycle fatals without waiting for
result capacity. Workers use the default compute pool; startup registration is
protected before release, and cleanup releases parked startup continuations.
All retained tasks join on tested ordinary failures and single-cancellation
paths, including a late failure after final-result consumption. References drain
and count/byte credits release once. The borrowed source closes only in its owner
after workers have joined.

Ordinary prepare/decode/assembly failures stop admission and settle admitted
jobs. Lower-ordinal assembly still executes when a higher decode already failed,
so the lower admitted error wins deterministically. Metadata setup errors before
admission remain direct errors. DecodeWorkerError retains lifecycle fatal
backtraces; decoder InterruptException/cooperative cancellation stays cancellation.
cancel_decode_queue! wakes waiters without interrupting native code. Primary
controller/cancellation errors survive secondary cleanup failures. No partial
phase/table is published on tested failure paths.

Repeated asynchronous interrupts can interrupt cleanup joins; lock-boundary
interruptions, OOM and failure while recording a supervisor fatal are not proven
recoverable. This is not uninterruptible cleanup or exhaustive diagnosis of
unadmitted baskets.

## Cache, diagnostics and validation scope

Execution controls stay outside scientific selection section keys; full-config,
batch and reduced-contract hashes still see them. Source edits invalidate code
keys. Cache hits keep original generation diagnostics, not a fictitious new run.

Diagnostics include requested/effective actors, overlapping calls, job/charged
byte high water, logical compressed requests/declared decoded bytes, basket
requests/skips, fallback reasons, dependency fingerprints and join/credit state.
Logical repeated requests are not unique physical bytes; overlapping decode calls
are not CPU utilization. Task wall times overlap. Per-job allocation counters can
include concurrent Julia activity and must not be summed as unique total bytes.
High waters/request totals accumulate across an invocation; final live/retained
and credit state describe the last queue phase.

Focused tests cover admission, ordering, completed-result credits, cancellation,
supervision and codec gates; native opt-in tests additionally compare raw and
selected bits/types/offsets/order/cutflows and source replacement. Historical
bounded output checks included correction weights, histograms, normalization and
plot publication. They are not a rerun of this exported tree or the full suite.

A historical warm decode phase improved, but a matched ordinary CLI pair was
slower with detached decoding. No stable total-time improvement, physical-I/O
ceiling, sustained scan capacity, RDF competitiveness or useful thread maximum
is established. Keep default one. Commands and external-input requirements live
in [VALIDATION.md](VALIDATION.md), not a site-specific execution ledger.
