# Windowed reusable decoder (opt-in prototype)

Status: **opt-in prototype, default off.** It is integrated from the reviewed stage1 A patch,
`cascade-rdf-resume-20261110-2232/parent-native/A-current.patch` (revision 2 plus the
test-only fixture correction).

What has and has not been validated:
- **Not validated:** actual ROOT/XZ inputs, full-pipeline dispatch, science outputs and speed.
- **Ran locally:** only source-free stdlib stubs. These are 1327 passing assertions on macOS
  with Julia 1.12.6, split across an initial run that FAILED on a fixture defect and a
  targeted corrective pass. That is not a clean full-suite run.
- **Required before claiming anything:** the integrated canonical tree still has to be
  validated by the parent's bounded gates (listed below).

## Option

```toml
[execution]
windowed_selection        = true       # required
windowed_reusable_decoder = true       # default false
stream_window_bytes       = 536870912  # the 64 MiB default is below the 66 MiB native bound
```

Rules:
- `execution.windowed_reusable_decoder` is a strict Bool.
- It is validated at the base config, in profile overlays (type only) and in every merged profile (relations).
- It requires `windowed_selection = true`.
- It is rejected together with `event_range_selection = true`. That runner does not implement it, so the combination is refused rather than silently ignored.
- It is **execution-only**. It is not in `section_hash`, the select artifact key or scientific identity.
- Because it is not in the cache key, a warm cache will reuse ordinary artifacts. validation environment runs need a fresh workdir or a forced rerun.

When the option is `false` (the default), the code path is unchanged:
- `select_chunk_results` computes `reusable = false`.
  - Both new `throw`s and the new execution keys are short-circuited.
  - The same `run_windowed_selection` call runs with the same arguments.
- `plan_stream_windows(...; counter_names = post)` defaults to the legacy mapping.
- `reserve_windowed_selection(...; extra_bytes = 0)` adds a checked `Int128` zero.
- The legacy `run_windowed_selection`, `analyze_incremental_selection_window!`, `read_stream_branch_owned`, `windowed_selection_reservation`, `windowed_selection_fallback` and `stream_basket_index` are unchanged.
- The decoder `src/IO/read_reusable_basket.jl` is unchanged (sha256 `fdd595f3…`).

## Mechanism

The option keeps the same serial per-file windowed route as `windowed_selection`:
- persistent ordered Cutflow;
- global entry offsets;
- `finish_stream_selection!(validate = true)`;
- retained-table bound;
- file-level publication.

Only the physical decoder, the counter policy and the resource charges differ.

1. **Admission (metadata only, before any Events payload read).**
   - Planning uses counters for pre∪post.
   - Every branch needs an exact basket index, or a padded index proven by `reusable_padded_index_reason` (2026-11-11 repair; see below).
   - Every jagged branch needs its `n<collection>` counter.
   - Counters must be flat non-Bool integers.
   - No basket may exceed the 8 MiB reusable scratch limit.
   - Every branch must pass the unchanged `_reusable_branch` audit. If the codec audit fails, the reason is `reusable_decode_contract_failed`.
   - Source identity is bound again before the first payload read.
   - The reservation adds the following to every window, before data is read:
     - scratch: min(max decoded basket, 8 MiB);
     - a native decoder bound of 66 MiB;
     - basket-ID metadata.
2. **Decode.**
   - Each file has one task-owned `StreamDecodeState`. Its scratch is reused across baskets, branches and windows, and released in `finally`.
   - Native codec state lives only inside one branch read and is finalized in `finally`.
   - Destinations are fresh, window-owned `Vector{E}` or Jagged buffers. They never alias scratch.
3. **Counters.**
   - Every planned counter is decoded once per window and checked on all rows, with file-cumulative overflow checks.
   - Final coverage requires contiguous windows over `1:n` and that each counter was checked in exactly every window.
   - No full-file raw destination or counter prefix is materialized.
4. **Modern-only.**
   - There is no `catch`, retry, legacy basket reader or ordinary-reader fallback.
   - An unsupported request throws `EventIO.WindowedReusableUnsupported`. This happens before open (window fallback reason), after planning (admission or reservation reason), or per basket (decoder decline).
   - Corruption propagates unchanged.
5. **Padded basket indexes (2026-11-11 repair of `unmaskable_basket_index`).**
   - Cause: ROOT's `TBranch::Streamer` writes `fBasketBytes/fBasketEntry/fBasketSeek` with `fMaxBaskets = max(fWriteBasket+1, 10)` slots, so a branch with fewer than 9 baskets (small files) carries a zero tail. The unchanged classifier `stream_basket_index` marks that shape `maskable=false`, matching the ordinary `read_nanoaod_branch` length check. The ordinary and `streaming_selection` routes then read those branches unmasked through UnROOT's legacy `basketarray`, which is why earlier 107 GB runs (65 files, 1,378 padded branches) succeeded. The modern-only A route had no unmasked path and refused such files before payload work.
   - Admission now accepts a `maskable=false` branch only when `reusable_padded_index_reason` proves all of the following: the copied, validated prefix is strictly `0..n` with an all-zero tail; the plan descriptors equal that prefix; `fWriteBasket` equals the basket count; `fBasketBytes` and `fBasketSeek` have the same length and are zero beyond the count, with matching bytes and nonzero seeks inside it. Any other padded shape is refused with `unproven_padded_basket_index:<branch>:<reason>`. A malformed prefix still throws.
   - A proven padded branch keeps the ORIGINAL unmasked contract: `needed` is ignored and every overlapping basket is decoded by the same modern decoder. Each basket's `TBasketKey` `fNevBuf` and its entry-offset trailer are checked against the prefix-derived entries and the canonical counter offsets, so jagged output equals the basket-reconstructed arrays or the read throws. Exact-index siblings stay masked.
   - Flags, the ordinary reader, the `streaming_selection` route and raw or `LazyBranch.fEntry` arrays are unchanged. `execution.windowed_reusable_decoder` still defaults to false.
   - `finish_reusable_stream!` requires every padded branch to be proven, to have no skipped baskets, and to have decoded every covered basket. The `padded_decoded_*` keys are a subset of the phase decoded totals and must equal `reusable_padded_decoded_baskets`. New diagnostics: `reusable_padded_branches`, `reusable_padded_decoded_baskets`, `reusable_padded_index_policy`.
6. **Diagnostics.** Requested runs merge these keys into the file's execution record:
   - `windowed_reusable_decoder_requested/effective`;
   - `reader_engine = reusable_decoder_window_owned_copy`;
   - decoded/skipped basket IDs and counts, with `reusable_fallback_baskets = legacy_decoded_baskets = 0`;
   - scratch, native, live and owned high-water marks, and `reusable_live_within_bound`;
   - counter totals.

   A default run adds none of these keys.

### Bounded diagnostic seams (not used by production)

- `IO.stream_window_prefix(reader, m)`
- `Pipeline.prepare_reusable_windowed_selection(...; max_windows)`

These serve only the two-window actual diagnostic. Production calls
`prepare_reusable_windowed_selection` without `max_windows`, which keeps the whole plan.

## Files

| file | change |
|---|---|
| src/Config/windowed_selection.jl | `windowed_reusable_decoder(raw; validate_relations)` and the cfg method |
| src/Config/validate_keys.jl | execution key, overlay check and merged-profile check |
| src/Config/Config.jl | export |
| src/IO/StreamWindowReader.jl | `plan_stream_windows(...; counter_names = post)` |
| src/IO/IO.jl | include `stream_reusable_decoder.jl` |
| src/IO/stream_reusable_decoder.jl (new) | state, admission, reservation, branch/counter decode, coverage, prefix seam, release |
| src/Selection/Selection.jl | include `read_reusable_selection_window.jl` |
| src/Selection/read_reusable_selection_window.jl (new) | window read that mirrors the legacy staged/unstaged reads |
| src/Pipeline/stream_selection.jl | `extra_bytes` keyword; reusable window loop, prepare and run |
| src/Pipeline/memory_chunk_helpers.jl | opt-in dispatch and explicit unsupported errors |
| test/windowed_reusable_decoder/runtests.jl (new) | stdlib-only adversarial stub harness |
| test/windowed_reusable_decoder/test_actual.jl (new) | validation environment-only bounded two-window actual diagnostic |

`src/Pipeline/Pipeline.jl` is not changed. The new files are included from `IO.jl` and `Selection.jl`.

## Tests

- **Focused stub** (stdlib, no Cascade/ROOT load):
  `julia --startup-file=no test/windowed_reusable_decoder/runtests.jl`
  - Leave `CASCADE_WINDOWED_REUSABLE_REAL` unset.
  - `test/runtests.jl` also picks this file up automatically as area `windowed_reusable_decoder`.
- **Compatibility stubs:**
  - `test/windowed_selection/runtests.jl`
  - `test/window_io/runtests.jl`, with `CASCADE_WINDOW_IO_BEFORE` set to a pre-A baseline tree
  - `test/execution_options/runtests.jl`
  - `test/event_ranges/runtests.jl`
- **Bounded actual diagnostic** (validation environment only; Linux `/proc`; pinned TTto2L2Nu and Muon inputs; first two windows only):
  `CASCADE_WINDOWED_REUSABLE_REAL=1 julia --project=. test/windowed_reusable_decoder/test_actual.jl`
  - Freeze the frozen parameters before launch and never retune them after a failure.

## Known limits

- **Stricter than ordinary reads.** Every mapped counter is decoded and checked in every window. A file with inconsistent counters can fail here even though it passes ordinary reads.
- **Budget.** The default `stream_window_bytes` (64 MiB) fails closed at reservation, so it must be raised.
- **Window plan.** Adding pre-column counters can reduce the number of common boundaries. The result can be `no_bounded_common_boundary`, which raises an explicit error.
- **Late failures.** These are discovered only per basket and raise explicit errors, with no fallback: non-XZ codec, multi-block XZ, a dictionary over 65 MiB, a jagged basket without an offset table, or a recovered basket.
- **Duplicate decode.** A post column that is itself a counter is decoded twice. This is reported in `reusable_duplicate_basket_decodes`.
- **Unmeasured cost.** Per-read `_reusable_branch` overhead has not been measured, and no speed claim is made.
- **Coverage gaps.**
  - No XZ/CRC corruption coverage (deferred).
  - No `select_chunk_results` or effective-dispatch coverage, which belongs to a separate tiny validation environment.
  - The actual diagnostic covers two windows per file and makes no full-file science claim.
