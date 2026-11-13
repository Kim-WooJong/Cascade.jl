# Opt-in parallel NanoAOD column reads

Experimental concurrent branch reading for ordinary nominal selection. Default
one preserves the serial reader. No general performance improvement is established;
see [validation and limitations](VALIDATION.md).

## Configuration and API

~~~toml
[execution]
column_readers = 1 # integer 1:4, not Bool; default
~~~

Profiles may override this table; invalid inactive-profile values are rejected.
Selection.run_selection(...; column_readers=1, execution_diagnostics=Dict{String,Any}())
uses IO.with_column_readers(run, src; readers=1, diagnostics=...) and
IO.read_parallel_columns(scope, names; needed=nothing). A fallback supplies
nothing to the callback; ordinary read_columns remains the fallback reader.
Decode and column-reader pools cannot both be enabled.

Width one opens no extra source/task. Pipeline admits only nominal NanoAOD
samples with unchanged built-in readers. Actual sources must be original local
UnROOT mmap sources whose Linux mapping evidence can be bound. Non-Linux or
unbound sources use serial fallback. Custom/replaced registries, non-mmap,
cols/reduced inputs, shapes, EventWindowSource and LazyEventSource are not
promoted to concurrent readers. Registry/method replacement during an invocation
is unsupported. Correction-source reuse is independent.

The Pipeline per-file budget is at most:

~~~text
min(requested, floor(threads / min(threads, uncached_file_tasks)))
~~~

No uncached tasks gives budget one. Existing outer dynamic file scheduling stays;
outer width × inner width does not exceed the process thread budget. No host-core
count is used. A direct IO scope also clamps to process threads. One-thread
execution falls back without extra opens. Each slot handles one branch job at a
time, not an unbounded branch-future queue.

Empty name lists and one unique column use the ordinary reader, without opening
extra handles. Handles open lazily at the first multi-column phase and can be
reused across pre/post reads. All-false and opposite masks retain serial column
values/offsets/placeholders; no decoded columns are cached across masks. Invalid
mask length and missing requested branches retain their errors.

## Source identity and independent ownership

Slot one borrows the original only while its owner is idle. Every other slot owns
an independent ROOTFile, stream, metadata cache and branch objects. Slots belong
to tasks, not thread IDs. Clones preserve tree, runs_tree and gen_sumw.

Linux /proc/self/maps mapping identity (raw major/minor/inode and mapped length)
and path-stat identity (raw device/inode/size/mtime/ctime) are separate namespaces.
Each clone must match the original mapping tuple **and** recorded path tuple;
mapped length must equal path size. Mapping and stat device/inode representations
need not equal on virtual/stacked filesystems. No manual dev_t conversion is used.
This detects ordinary rename/replacement even with identical ROOT bytes/UUID,
since a new mapping cannot match the old mapped inode. UnROOT MmapStream has no
retained descriptor. Missing/unparseable evidence falls back before extra opens;
loss after binding or changed identity is an error, including final source checks.

This is not hostile in-place write protection or a content-integrity cache. No
full-file hash/per-branch mapping scan is added. The parallel path calls the
existing UnROOT basket reader, rather than introducing a detached codec adapter;
the package compatibility range is not proof of every dependency/platform version.

Collection counters/canonical offsets are prepared serially once per collection
per masked phase and shared read-only. Workers preserve primitive content,
jagged offsets, masks/placeholders and errors. Assembly follows original unique
column order. All workers join before rethrow or owned-handle close. Finally
closes every successfully opened extra slot, including partial-open/read failure;
it never closes the borrowed original. UnROOT mmap close is a no-op: eventual
mapping lifetime follows Julia/UnROOT GC, not an immediate OS unmap guarantee.

## Scientific and memory boundaries

Event/prefix loops, object buffers, cutflows, histogram filling, ordered merge,
original Runs normalization and native rendering retain their existing scopes.
This does not partition events, stream a file, fuse stages or remove checkpoints.
Full-file decoded columns remain eager. Concurrent decode scratch and additional
metadata can increase memory with width; the cap is reader count, not a byte
reservation or RSS bound. There is no cross-invocation source/trust cache.

## Cache and diagnostics

Selection sidecars record requested_readers, budget_readers, effective_readers,
fallback, max_active_reads, extra_opens/extra_closes, branch_jobs and counter_reads.
Effective width is the maximum dispatched width across phases; direct Selection
calls omit Pipeline's budget_readers. max_active_reads counts overlapping branch
calls, not CPU utilization; zero identifies the untouched serial reader.

Execution width is outside scientific selection section hashes. Changing only
width may reuse an existing artifact, which retains its original generation
diagnostics. Full-config/batch/reduced-contract hashes still see execution options.
No canonical_hash behavior or arbitrary configuration stripping changes. Relevant
Config/IO/Selection/Pipeline edits invalidate code keys; integrity preflights
remain required.

## Validation scope

Focused tests cover width/config budgets, synthetic barrier overlap, lazy opens,
borrowed/owned close behavior, partial-open/read failures, joins and fallback/cache
guards. Native opt-in tests compare primitive/jagged bytes, masks, selected tables,
cutflows and source replacement. A dedicated one-thread opt-in checks zero extra
opens. The relevant regression runner covers Config/IO/Selection plus selected
source-reuse/reduced guards, not the complete package suite.

Historical native/focused checks followed an identity fix; older broad output,
normalization and plot checks were not all rerun after that fix. They must not be
presented as a current-tree comprehensive pass. No stable speedup or RDF-competitive
end-to-end result is established; do not recommend width four based on the old
small-file workload. Default remains one. Use [VALIDATION.md](VALIDATION.md) for
commands, authorized reference-mask requirements and optional input bindings.
