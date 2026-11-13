# Ordinary serial NanoAOD reusable basket buffers

Status: implemented, source-reviewed only. No Julia invocation, parser/build,
tests, benchmark/profiler, ROOT input-content read or remote operation was run
for this change. No performance improvement or numerical validation is claimed.
The earlier incremental baseline is not validation of this implementation.

## Ownership and path

`NanoAODReadCache` now owns `_NanoAODScratch`: one raw byte vector, bounded to
8 MiB retained per cache, plus a once-per-cache dependency audit result. Existing
callers without a cache retain the old reader. Counter reads share the same
scratch. A decoder is lazy, branch-local and deterministically finalized in
`finally`; its liblzma memory limit is 66 MiB (a 64 MiB dictionary plus
bounded decoder bookkeeping). No global mutable state, tasks,
parallel scheduler, streaming switch, reader/decode count, outer file-worker
count, selection state or scientific kernel is changed. The existing serial-only
cache contract remains mandatory. Retire caches before closing their sources.
Growing scratch replaces it with an exact-size vector, never geometric growth;
a replacement may temporarily coexist with the old vector until GC. These are
logical buffer/native-decoder bounds, not a bound on allocator retention/RSS.

For admitted flat primitives and canonical masked primitive jagged baskets,
compressed bytes are read through local mmap views, decompressed directly into
scratch and endian-converted directly into the owned final typed vector. No
interpreted basket vector or compressed/block payload copy is produced. All
borrowed views stay within the call; returned columns never alias scratch.
Jagged canonical offsets remain the same shared, read-only cache metadata.

## Compatibility and conservative fallback

Admission requires local `UnROOT.MmapStream`, a single-leaf regular `TBranch`,
primitive Bool/integer/Float32/Float64, `Nojagg`/`Nooffsetjagg`, validated basket
indexes and the existing audited UnROOT 0.11.11 source contract. Additional
private gates check the inspected CodecXz 0.7.4 and TranscodingStreams 0.11.3
versions/source hashes. Existing dependency contract/whitelist files are untouched.
No dependencies are added, resolved or installed.

Uncompressed baskets and framed single-stream XZ blocks are admitted. XZ must
have exactly one XZ block, a supported CRC32/CRC64/SHA256 check and a regular single-LZMA2-filter
header with dictionary within the native budget. Other codecs, sources, layouts,
source versions, recovered baskets, missing jagged offsets, larger baskets and
unsupported XZ headers/checks/dictionaries use the original `basketarray` path
before modifying that basket's destination. Unmasked jagged reads and absent
canonical-offset full-read fallback remain unchanged. Unsupported fallback
retains upstream behavior; it is not a promise to validate unsupported codecs.

## Corruption and ordering invariants (static review)

- Existing skipped-basket zero fills execute before admission, unchanged.
- Basket source bounds, key/index/entry agreement and content/trailer lengths
  are checked before decoding. Existing ROOT block framing/XZ index validation
  is reused; no exception-catching fallback hides malformed supported input.
- Fixed native output windows cannot grow. Each block must consume exactly its
  compressed bytes, produce exactly its declared bytes and reach `:end`, thus
  invoking the native decoder's stream/checksum validation. Error, no-progress,
  truncated/overlong stream and descriptor mismatch throw, never fallback.
- Offset starts are zero-based, monotone, aligned and bounded by content. For
  canonical jagged input, every stored event start and final content length must
  agree with counter offsets before destination conversion (stronger than the
  previous flat-basket aggregate-length check).
- Flat entry count, destination bounds, primitive width and Bool representations
  are checked before any typed destination write. Per-basket destination order
  and final branch-length check remain unchanged. Scratch views never escape.
- Decoder cleanup covers branch success and exceptions, without relying on GC.

## Intentionally remaining allocations / limitations

Final columns, canonical counter vectors, LazyBranch metadata, small key/header
reads, immutable compression descriptors, temporary views/decoder error state,
and per-branch native decoder creation remain. Scratch growth allocates.
Unmasked jagged and unsupported cases retain all existing basket allocations.
Additional source hashes are read once per cache, not every basket.

Evidence: sibling `../cascade-reusable-decode-20261108/` contains exact dirty
preimages, incremental patch, scoped postimages/hashes, inspected dependency
source hashes, plan and static-review record. `git diff --check` is the permitted
mechanical check; runtime compatibility and numerical equivalence are unverified.
Any later runtime verification requires separate owner authorization.

## Offset validation function barrier (2026-11-10, owner-authorized promotion)

`_read_reusable_basket!` now calls `_validate_basket_offsets(raw, content, keylen, trailer,
entries, canonical, lo, E)` for the per-entry offset checks. The loop text and every check
(zero start, monotonic bounds, element alignment, Int128 canonical agreement, `trailer == 0`
skip) are unchanged; only the dispatch boundary is new. Reason: the caller's basket metadata
(`lb.b.fBasketSeek/fBasketBytes`, `lb.f.fobj.mmap_ary` and everything derived from them,
including `keylen`, `content`, `off`) is inferred as `Any`, which made the per-entry loop
allocate a view, a reinterpret wrapper and boxed integers per entry.

Evidence (diagnostic, isolated rdf-equivalent source with the same reader helper bytes; not a
run of this main tree): ../cascade-reader-causal-20261110/BARRIER_RESULT_KO.md and
FULL_RESULT_KO.md — bit-identical outputs; small MC select 1.009 → 0.252 s, 1.1 GB MC file
29.76 → 7.86 s; full 396-file no-checkpoint compact run 354.91 → 179.39 s (one pair, shared
host). Focused tests: test/reusable_basket_offsets/runtests.jl (semantics/messages, optimized
IR without Any values or dynamic calls, no per-entry allocation growth, caller uses barrier).
Validation on this promoted main tree completed on pinned Linux Julia 1.12.2: **583 assertions
passed** (80 focused offsets, 354 supplementary decoder checks, 149 real-input integration),
with 12 recorded optimized-IR specializations. Two exact-index files exercised every basket
of 8 branches each against upstream results, including masks, repeats, non-aliasing, non-first
`lo` and 8 canonical-corruption/no-destination-write cases. Real Float64 admission was absent;
Float64 helper checks were synthetic. Padded-index input did not establish reusable admission.
This is not a full package-suite pass. The strict-cache optional Accessors Test extension
logged an error; that optional extension is not validated and is not used by the production path.

The ordinary stock CLI (`checkpoints=false`, no compact/padded diagnostic extensions) then
completed all 396 files in **179.10562615300296 s**, launch to exit, with 17/17 final files
byte-identical to the pinned F_on reference. One shared-host observation is a baseline, not a
matched speedup estimate against the historical diagnostic times above. Receipts and exact
identities: `../cascade-speed-round2-20261110/remote-mirror-r2f/{tests_main,full_base}/`.
The remaining basket-key/metadata code in the caller is still dynamic per basket (not per
entry) and is not changed here. Follow-up counter/metadata/codec boundary candidates were
not promoted: C1 had an invalid allocation-control model, C2 did not meet advancement gates,
and C3 had an unstable zero-exposure control. Production-only post-fix attribution and the
scoped independent review are recorded in `../cascade-speed-round2-20261110/REPORT_KO.md`
and `ATTRIBUTION_POSTRUN_QA.md`. Sampled bottleneck exposure is workload-dependent and
is not a new ordinary full-run speedup claim.
