# Incremental ordinary selection and file-local metadata reuse

Owner request2026-11-08 22:13: carry data and selection results forward instead of replaying prefixes. That implementation phase used static review only, without Julia/tests/builds or remote execution. The later22:34 request authorized the bounded baseline validation below. Previous188.910s/123.81s-select results belong to the preceding replaying candidate.

## Later authorized baseline validation (2026-11-08 22:34 request)

One Julia-only ordinary analysis completed rc0 on107.392GB/396files/13samples/16threads. Analyzer160.260s, select91.29s, CPU702.17s. Saved compact208hist/3666cells are byte-identical to both baseline arms and both preceding candidates; unchanged comparator passes all4, every stage skipped0. No retry, RDF, trace, profiler or full unit suite. Cascade-only compile21.232s and extraction31.681s were outside the analysis clock.

Previous replaying candidate:188.910s total/123.81s select; earlier lazy-object candidate:163.530s/97.39s. This is one observation on a shared host with warm/mixed page cache, not an established speedup. Memory increased: sampled anonymous peak10.254GB/maxRSS13.070GB versus replaying6.892GB/9.751GB and lazy-object8.479GB/10.604GB. Full per-event identity and other shape/SF/variation configurations remain unverified.

Evidence: parent-workspace artifacts/cascade-incremental-reuse-20261108/test01/REPORT.md and remote/run01/result.json. Parent verified37 manifest entries,11 canonical source pins, remote result/hist hashes, and no remaining Julia processes.

## State carried between reads

- One raw dictionary retains all already-read column arrays, without copying/replacing them when another group arrives. Column first-use/dependency scheduling remains unchanged.
- SelectionProgress owns passed cut stage, terminal-failure flags, one stable-order active-event list and one persistent needed mask. An advance evaluates only cuts in (previous_stage, next_limit], compacts surviving indices in place and refines the existing mask on failure. No repeated full-event mask rebuild and no reset to cut1. The initial object-free prefix is the first advance, not an additional selection pass.
- The same NamedTuple of CachedObjectBuffer instances is shared by every partial KernelContext and the final context. Each buffer appends selected flat indices once and stores an isbits span per event. Later cuts, cleaning and outputs access that span directly; no object predicate reevaluation, snapshot copy or restore is required. A shared current-event reference is set by the driver before kernels.
- Unbuilt spans have marker0:-1; built-empty spans have a positive start. Reading an unbuilt object or rebuilding an existing event/object throws. Cached sort operates on a view of its own appended span and extends the same Objects helper generic imported by generated kernels.
- Spans are event-indexed, not append-order indexed. A retained earlier event can complete a late/output-only object after other events have already appended their objects without corrupting either event.

## Final selection and scientific ordering

Final event processing runs in original entry order. Failed events do not rerun cuts. Alive events resume after their saved passed stage. The failing cut counts as attempted for object materialization, as before. Base weight and cutflow record happen once for every original event, preserving accumulation order. Retained events complete later/output-only objects and emit the same table columns. No cutflow/weight/output recording occurs during reading advances.

Read limits remain min(first_use-1, keep_stage). The persistent mask equals the set still alive or already retained by an early region; failures below keep clear their mask, retained failures do not. Full flat indexing is preserved. Context construction checks selection/raw ownership and stable per-collection offsets before reusing cached object indices.

## Metadata ownership

EventIO.NanoAODReadCache(source) is an optional, single-owner scope for exactly that NanoAODSource. read_columns(...; cache) reuses available names and lazily constructed canonical nCollection offsets across groups. The same vector identity reaches sibling and later-group Jagged columns. Counters reject negative values/overflow; an internal validated-offset type carries one-time validation. Direct Vector offset callers retain validation. Basket coverage checks and skipped-basket zeroing remain.

No global/disk cache, no extra source opens/closes, no sharing across file workers or concurrent readers. Offsets remain read-only and cache lifetime ends before source close. Column contents are retained by raw; the metadata cache does not duplicate them.

## Compatibility boundary

The new path is internal ordinary serial NanoAOD selection only, with nonempty compiled column plan, no extra shape inputs and no full read. Active parallel/decode, stream, custom sources, shape callbacks, and empty-plan compatibility constructors retain conservative behavior. Requested readers that already fall back to a serial scope can use it.

Public read_selection_columns always retains its two-value conservative raw/needed contract. The previously internal staged keyword is still accepted, but cannot return refined raw without its progress. Only _read_selection_columns(reuse=true) returns the additional bound progress for the matching run_selection/select_events consumer. Existing CompiledSelection fields/constructors, compiler dependencies, public event-table/checkpoint formats and settings are unchanged.

## Costs and verification limits

This removes the proven repeated prefixes/builders and repeated counter construction structurally, not by a measured speed claim. Cached spans cost about16bytes/event/object on a64-bit host, plus selected index payloads; passed/active/mask state is additional. Failed events' built indices also remain until this file finishes. Indirect object access, guards, and remaining partial-context specialization may cost time. Whole-file branch arrays and basket-level skip limitations remain. Peak memory and end-to-end speed must be measured separately when authorized.

Parent inspections: exact scoped diff, include/call paths, original final-loop branch preservation, compatibility gating, and whitespace/hash checks. Fresh independent concrete static review found no concrete P0/P1 in the reviewed11-file candidate and confirmed that state/object indices are carried forward rather than replayed. All11 source hashes and the exact scoped patch were rechecked. This describes the implementation-stage static reasoning; the later authorized baseline runtime validation is reported above.

Immediate before copies, exact scoped patch and source hashes: artifacts/cascade-incremental-reuse-20261108/ in the parent workspace. Frozen benchmark source and previous evidence/results are untouched.
