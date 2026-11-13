# Correction chunk source reuse

Invocation-local reuse avoids reopening a source for each correction reader.
It changes source lifetime, not the correction model, scheduler, normalization
population or analysis configuration. See [architecture](DESIGN.md) and
[validation boundaries](VALIDATION.md).

## Admission and API

There is no new user execution switch. Eligible uncached correction chunks use
this automatically for the exact built-in Pipeline.default_correct or
Systematics.apply_corrections hook and unchanged built-in reader registrations.
Supported built-in formats are nanoaod, cols, reduced_rntuple,
reduced_rntuple_group and reduced_rntuple_shard. Unlike the parallel reader
engines, this lifetime helper does not require Linux mmap identity or an exact
detached-decoder dependency audit; each underlying source keeps its own contract.

Pipeline.correction_chunk_source(f, sample, path) returns a lazy owner or nothing.
Pipeline.with_correction_source(run, f, sample, path) supplies it to the callback
and closes it in finally. CorrectionContext.source and the source keyword of
BranchReader / theory_member_weights carry the borrowed owner.
IO.LazyEventSource(format, path; options=Dict()) opens only on its first source
operation. It forwards reads and each original needed mask; it does not cache
partial columns or validation results. A closed owner cannot reopen.

Custom hooks, including wrappers around a built-in, keep source === nothing.
Custom formats and replaced built-in readers retain their per-reader lifecycle
for nonempty reads, rather than silently acquiring shared state. Reduced-input
pinning continues to reject custom hooks/readers where required. There is no new
platform-wide admission claim or implicit support for concurrent owner use.

## Lifetime, alignment and empty inputs

Each uncached correction chunk owns one lazy handle. Shape corrections, nominal
corrections and nominal-only theory members borrow it if they need source
branches. Each BranchReader retains its **own** selected-row scalar/vector cache
and needed mask. Validation and partial decoded values are not shared between
readers. Differently ordered/duplicate shape and nominal subsets keep original
source-entry alignment; reduced inputs retain local entry indexing. No shape ×
theory products are created.

The enclosing helper closes once in finally on success/error. Borrower close
never closes the owner, and a never-opened owner requires no dependency open.
Data, flat/object/table-only corrections and empty scalar/theory reads do not
open the event source. There are no worker queues, persistent source owners or
cross-invocation trust caches in this feature.

**Global empty scalar contract:** BranchReader(name) returns an empty
Vector{Float64} when entries is empty, without opening or diagnosing the named
branch. A missing branch or vector/jagged name is therefore not rejected for an
empty scalar read. vector_members likewise returns one empty vector per declared
member without opening. This applies to all BranchReader paths, including custom
fallback and streaming borrowed sources; fallback is not a claim of fully
historical empty-read behavior. Nonempty missing/scalar-vs-jagged/range validation
is unchanged.

For nonempty reads, masks select the original source rows and the returned scalar
values follow entries, including duplicates/order. Theory vector access requires
explicit layout and normalization, checks lengths/finiteness and rejects zero
normalization denominators. Signed base weights are not replaced by vector
ratios. Source reuse must not weaken those contracts.

## Reduced inputs, integrity and cache

Reduced-group chunks resolve their physical shard through the existing group
reader. Global stage-boundary inventory, manifest, checksum and extraction checks
are unchanged and precede applicable cache returns. Reusing a handle does not
certify an incomplete reduced population or skip those checks. The correction
code key includes IO in addition to its previous areas so owner implementation
changes invalidate correction artifacts. No configuration/hash normalization,
sample denominator or reduced-entry semantics change.

## Validation scope and commands

~~~sh
julia --startup-file=no --project=. test/source_reuse/runtests.jl
julia --startup-file=no --project=. test/source_reuse/regression.jl
~~~

The focused tests cover ownership/masks, reordered and duplicate rows, failures,
correction/theory/no-source paths, fallback/cache guards and empty reads. Counting
fixtures compare independent readers opening/closing separately with a single
lazy owner; this is structural evidence, not native throughput measurement.
The regression entry covers IO, Systematics, Pipeline and reduced/streaming input
areas, not the complete package suite. Some included reference config checks
still require the authorized certification mask; see [VALIDATION.md](VALIDATION.md).

Optional real correction-table comparison uses CASCADE_SOURCE_REUSE_REAL=1,
CASCADE_SOURCE_REUSE_REFERENCE and optional CASCADE_SOURCE_REUSE_PROFILE. It
reads compatible persisted selection tables and original sources/payloads; it
does not launch a complete selection or full-data pipeline. Historical bounded
comparisons found bit-identical nominal/scalar/SF/theory/shape weight columns for
the tested tables, not an all-sample/current-tree integration pass. Later empty
fallback assertions did not rerun every earlier native/module check.

Warm timing observations reversed between runs, so no speed guarantee,
full-dataset throughput or RDF comparison is claimed. Full-suite, Pkg.test,
fresh-install and supported-version matrix validation remain open.
