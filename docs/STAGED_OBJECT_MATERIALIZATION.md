# Staged object materialization

Subsequent source changes at21:05 are documented in [STAGED_COLUMN_READING.md](STAGED_COLUMN_READING.md). The single-run result below belongs to the earlier object-staging candidate and does not validate those later IO/read-plan changes.

Date: 2026-11-08. Owner initially authorized source changes and prohibited tests.
**Implemented and independently statically reviewed (no P0/P1).** At 20:16 the owner superseded the prohibition for one Julia-only baseline analysis. That run completed rc0 in163.530s (select97.39s), with208hist/3666cell compact output byte-identical to both saved baseline arms. This validates the tested workload only, not all configurations/edge cases or an established performance improvement.

Single-run report and preparation-deviation disclosure: `../../cascade-lazy-objects-20261108/test01/REPORT.md`. Cascade-only compilation19.980s in a copied private depot and postclock extraction30.713s were outside analysis timing. No RDF, repeated analysis, profiler or broad unit suite ran. No further tests are scheduled.

## Scope

The canonical Mac source changes four files under `src/Selection`: `compile_selection.jl`, `CompiledSelection.jl` (documentation only), `apply_cuts.jl`, and `event_loop.jl`. Existing unrelated worktree changes are preserved. Frozen `CascadeRDFBenchMT/framework`, old benchmark results and remote runtime copies are untouched. No commit or push is performed.

The change defers object selection, overlap removal and sorting until the first cut needing that object. It is general configuration-driven scheduling, not a ttbar/jet special case. Full-file input reading, column materialization/copies, reader/decode/stream settings and SF evaluation are **not** changed.

## Scheduling contract

1. Each object receives its first dependent cut index, counted after the MC/Data `only` filter. Objects not used by cuts receive `typemax(Int)` for retained-event completion.
2. The minimum stage propagates backward through cleaning dependencies. Definitions remain in validated dependency order, so an object used to clean another is fresh no later than that dependent object.
3. One compiled kernel `materialize(ctx, i, lo, hi)` emits object selection/sorting only for stages in `(lo, hi]`. The `CompiledSelection` field layout and type parameters are unchanged.
4. `apply_cuts` returns `(passed, built_through)` with integer readiness. A failing cut is included in `built_through`, because its objects were built before its predicate was checked. No per-event heap readiness container is added.
5. Every retained event unconditionally completes `(built_through, typemax(Int)]` before outputs. This covers output-only objects and early-region retention after failure of a later cut, avoiding stale indices from a previous event. Already-built objects are not rebuilt.

For the current ttbar cut order, static scheduling puts selected electrons/muons at `two_leptons`, veto objects at `extra_lepton_veto`, and jets at `njet_ge1` after mll. This is a source-level deduction, not an executed observation.

## Preserved interfaces and deliberate internal change

`mat_at`, `columns_pre/post`, `keep_stage`, prefix masking, cut predicates/order, cutflow accumulation, base weights, output expressions/columns, shape and stream selection entry points remain unchanged. Selection code hashes already include these source files, so a future fresh process changes artifact identity rather than accepting old selection artifacts as the new implementation. No cache was invalidated or rebuilt during editing.

The internal kernel callable changes from `(ctx, i)` to `(ctx, i, lo, hi)`, and the internal `apply_cuts` second result changes from Bool to Int. Both in-source callers were updated. External code manually calling the old kernel field must adapt; old frozen source copies retain their own old callers/kernel together. No serialization-format or TOML change is introduced.

## Review-only reasoning

The source was read for: transitive cleaning dependencies; first/failed cut readiness; early retained regions; output-only objects; no cuts; no objects; MC/Data filtered cut indices; prefix/read masks; and the shared shape/stream consumers. These are manual/static review cases, **not executed tests**. Independent review run `494cb2d7-2d63-4d4f-8c8b-dd66d9e43282` found no blocking P0/P1, with medium confidence because the generated kernel was not executed.

`git diff --check` reports no whitespace errors in the four edited source files. This is not syntax validation, compilation or a unit test. At that initial static-review milestone runtime behavior was unverified. The later single baseline run above establishes compact numerical agreement for its workload only; wider runtime coverage and a reliable speed conclusion remain unverified. Do not launch tests automatically on resume.

Before copies and the scoped patch are saved in `artifacts/cascade-lazy-objects-20261108/` in the parent workspace. Historical 107GB timings apply to the frozen pre-change code, not this candidate.
