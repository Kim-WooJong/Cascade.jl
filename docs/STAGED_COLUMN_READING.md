# Cut-aware column reading and memory traffic

**Superseded implementation note (22:13 request):** the repeated-prefix reader described below is replaced in current source by [incremental selection/data reuse](INCREMENTAL_SELECTION_REUSE.md). The single-run measurements below validate only that preceding candidate, not the new reuse implementation.

2026-11-08, owner request21:05: implement the three previously recommended changes. Implementation was local/source-only with no runtime activity. The later21:39 owner authorization allowed one isolated Julia baseline validation, summarized below. The prior163.530s run tested only the earlier staged-object candidate.

## Later authorized single-run validation (21:39 request)

One 107.392GB/396-file/13-sample, 16-thread ordinary five-stage baseline run completed rc0. All stages ran fresh/skipped0. Compact208hist/3666cells, cutflows and normalization were byte-identical to saved baseline1/4 and previous candidate; unchanged comparator passed. This is not full event-identity or other shape/SF/configuration coverage.

Wall188.910s, select123.81s versus previous163.530s/select97.39s. Sampled anonymous-memory peak6.892GB versus8.479GB. Shared host and warm/mixed page cache were not controlled; no speedup claim. This run is an adverse performance signal, not a reason to adopt the candidate for speed. Extra prefix passes/counter rereads remain possible, unproven causes.

Cascade-only private-cache compile20.833s and post-clock extraction31.210s were excluded from analyzer time. Overall operation~259.4s; no timeout, cap hit, survivors or rerun. Parent verified remote result/hist hashes and preserved canonical source hashes. Evidence: ../cascade-column-plan-20261108/test01/ in the parent workspace.

## Three changes

1. Ordinary masked jagged reads share a collection's read-only canonical offsets within a read phase. Content uses undef storage; every skipped basket's entire canonical content range is zeroed, while every read basket retains the existing event-count/content-length checks and copy path. Invalid basket coverage falls back to complete reading; offsets must start at0 and be nondecreasing before masked allocation. Decode/stream assembly initialization is not changed.
2. Compiled per-column first-use stages delay post columns for ordinary serial NanoAOD selection. Raw cut usages and object predicate/cleaning/sorting columns contribute deadlines; transitive object dependencies settle before column deadlines are assigned. Remaining output/region/variation-only columns are needed for retained events. No hard-coded Jet/mll names.
3. KernelContext column names and values are built together in sorted key order, stabilizing NamedTuple field order for the same schema. Existing offsets equality validation remains, with explicit shared-identity recognition. No measured JIT-saving claim.

## Read-plan contract

- Pre columns (including base weights for all-event cutflow) and builtins remain full-population reads. Existing columns_pre/post and mat_at semantics remain available.
- New CompiledSelection.column_stages maps post column names to their first cut index, after Data/MC filtering. typemax(Int) denotes retained completion. The previous18-argument outer constructor remains available with an empty plan and conservative reading.
- Post columns are read in ascending first-use groups. Before reading groupk, a read-only planning pass evaluates cuts through min(k-1,keep_stage), materializing only objects due before each attempted cut. All group columns arrive together before their dependent cut.
- The minimum with keep_stage protects after=all and other early retained regions. A retained event must have every remaining output/object input even when it fails a later cut.
- Planning does not record cutflow, weights or outputs, and never performs final retained-object completion. The unchanged final selection loop evaluates cuts and records cutflow once using the assembled columns. Full event indices, entry/stage columns, ordering, weights and checkpoint serialization stay unchanged.
- Partial contexts intentionally require no not-yet-loaded collection. Object buffers belong to each planning context; the final context has fresh buffers and keeps the existing retained-event completion.

## Explicit compatibility boundary

Public read_selection_columns defaults to staged=false, keeping its old single-post-phase raw/needed contract. The ordinary run_selection serial path opts in. Eligibility requires native NanoAODSource, no reader/decode scope, !full, empty extra inputs and nonempty compiled metadata.

Shapes explicitly pass staged=false even for an empty-input callback. Decode, active parallel-reader, streaming, custom-source and full-read paths retain conservative reading. A requested parallel reader which already falls back to serial may use the ordinary serial plan. No settings/defaults or old frozen benchmark sources/results were edited.

A statically reviewed edge case is handled conservatively: an object whose predicate is constant (for example cut="true") can require collection offsets without naming a collection field. If any cut-needed object has no own-collection field establishing those offsets, compilation emits an empty read plan and uses the existing complete post-read route. Output-only objects are exempt because final completion already has all columns. The current ttbar definitions remain eligible.

The internal staged route still returns the original prefix mask, not a per-column validity mask. Only its matching final selection is a valid consumer of refined raw data; ordinary run_selection ignores the returned mask.

## Current ttbar schedule (static deduction, not execution)

MC: trigger1, two_leptons2, veto3, charge4, mll5, ge1jet6, ge2jet7. Tight/veto shared lepton fields are read at2; charge at4; additional mass fields at5; Jet predicate/cleaning/sort fields at6, using a mask through mll5. Data adds its initial lumimask cut. Earlier retained regions or earlier explicit Jet references conservatively move the required reads earlier.

## Limits and actual validation

This is deferred basket reading with full-file indexing, NOT compacted event storage or a new bounded-window engine. Arrays still have full canonical lengths; baskets with any passing event are decoded whole, so logical event rejection is not an equal reduction in compressed bytes or physical IO. Basket-to-column copy remains. Offsets are not shared between separate read phases.

Planning can repeat prefix/object work and specialize partial contexts, while guards check offset coverage. These costs may offset savings. No speedup or memory reduction is claimed without later authorization and measurement.

Main inspected exact before/after diff, call sites, ttbar definitions, unchanged final-pass source hashes and whitespace-only git diff check. Independent concrete static review found one missing-offset partial-context crash for constant-predicate objects; the conservative empty-plan fallback above was added. Targeted independent static re-review confirmed the fallback fixes that crash, keeps ttbar eligible, and found no remaining P0/P1 in the reviewed scope. This was static clearance only at implementation completion; the later single-configuration runtime result above supersedes that stage status, not the untested configurations.

Before copies, exact new scoped patch and nine source hashes: artifacts/cascade-column-plan-20261108/ in the parent workspace. Prior unrelated worktree edits were preserved.
