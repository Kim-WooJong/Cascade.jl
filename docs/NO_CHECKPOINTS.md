# Fresh runs without intermediate checkpoints (`execution.checkpoints = false`)

Status: opt-in experimental full-chain route. Full testing of the current public
snapshot is incomplete; see [validation status](VALIDATION.md). Focused fixtures
and earlier real-input checks do not establish universal correctness or speed.

```toml
[execution]
checkpoints = false      # default true; strict Bool, also validated in inactive profiles
```

`true` (the default; individual configurations/profiles may override it) keeps the existing route unchanged:
per-file skim/select/correct/histogram artifacts with `.meta.json` cache keys,
`--force`, skipping and resume. The only effect on that route is the usual
one-time cache invalidation, because `code_hash` covers the edited source areas.

`false` is for speed tests and cluster runs that must not produce or consume
intermediate products. Its contract (explicitly authorized change):

- every selected stage is computed fresh from the current inputs in this invocation;
- no per-file skim/select/correct/histogram artifact, `.meta.json` or temporary of
  those stages is written, and no cache/checkpoint is read; nothing is resumable;
- existing workdir content (old caches, old final outputs, old fit/plot files) is
  never read, modified, deleted or reused, even if its cache keys would match;
- `--force` has no additional effect (recorded in provenance).

## Admitted plans (checked before any data read or directory write)

The check is pure configuration/registry inspection. A rejected plan raises one
`ArgumentError` listing every reason and leaves the filesystem untouched.

- Steps: one contiguous prefix starting at `skim` that includes `merge`:
  `skim..merge`, `skim..systematics`, `skim..fit` or `skim..plot` (the default
  `cascade run` plan is the full chain). Partial plans such as `--from select`,
  `--only plot` or `--steps skim,select` need checkpoints and are rejected.
- Samples: `nanoaod` or `cols` format. Reduced RNTuple formats are rejected.
- Weights: nominal plus weight variations from `default_correct` or
  `Systematics.apply_corrections` (ttbar `baseline` and `sf` profiles).
- Hooks: built-in correction (above) and built-in systematics/fit/plot hooks for
  the selected steps. Custom/registered/TOML hooks are rejected (they could depend
  on workdir files).
- Execution: `column_readers = 1`, `decode_threads = 1`, `streaming_selection = false`,
  `event_range_selection = false`, `memory_handoff = false` (it is a
  checkpoint-preserving mode). Other selection execution options (for example
  `windowed_selection`) keep their existing in-selection meaning.
- NOT implemented, rejected with a diagnostic: active `shape_variations` (ttbar
  `phase2`, `jer_candidate`, `integration_small`) and active `theory_weights`
  (`theory_example`, `integration_small`).
- `cascade batch` and direct `run_step` calls refuse `checkpoints = false`
  (batch tasks/receipts are checkpoints). `audit` and `reduce` are unaffected.
  Unexported `step_*` functions called directly are not guarded (internal API).

Operational limitation: "cluster use" means one standalone full-chain job per
analysis/config (`cascade run` with this option), not `cascade batch`, worker
shards or per-file task splitting. Such jobs cannot be split, retried per file or
resumed; a failed job is rerun from scratch.

## Data flow and memory ownership

1. Skim in memory: the same inventory, population, source-signature, event-count,
   normalisation and certified-lumisection code as `step_skim`; the skim document
   is JSON-transported in memory so downstream sees read_skim semantics.
2. One work unit per input file (`select_chunk_results` ->
   `execute_correct_chunk(...; persist=false)` -> `execute_histogram_chunk(...;
   persist=false)`). The selected table and weights exist only inside that unit and
   are dropped when it returns. The table metadata uses the memory-handoff JSON
   normalisation; weights are the same `Vector{Float64}` dictionary the persisted
   route writes. The correction-extraction check runs on the in-memory payload.
3. The unit returns only small results: the JSON-transported histogram store
   (`Histograms.transport_store` = in-memory `read_store(write_store(...))`), the
   JSON-transported cutflow, and (when needed) region counts and fit-channel
   overlap provenance.
4. `OrderedWindow` schedules units in the original sample/file order with at most
   `4 x file_workers` claimed-but-unmerged results; the single consumer runs the
   shared `merge_outputs!` body (also used by `step_merge`) and merges every store,
   cutflow, region count and normalisation sum in exactly the original order. No
   subtotal/batch reassociation. The first failure stops new claims (fail fast).
5. Systematics/fit/plot use the built-in hooks on JSON-transported copies, i.e.
   exactly what the persisted route reads back from its final files; plot receives
   the fit result of this run only (never a stale `fit/result.json`).

No forced GC, `@inbounds`, casts or thread-id state. There is no RSS cap: live memory
scales with active work units plus the bounded window, not with the number of files.

## Failure semantics

Fail fast, schedule-first: the first error recorded by any worker stops new file
claims; in-flight files finish and the error is rethrown to the caller. That first
recorded error may belong to a later file than one still in flight, so the
reported file can differ between runs with identical inputs. The worker backtrace
is printed to stderr as `task <k> (no-checkpoints chain) failed: ...`; the rethrown
exception does not carry it. Already merged results exist only in discarded memory;
nothing is published. Unlike staged `run_tasks`, remaining files are not attempted
(there is no checkpoint to keep). On failure the call waits for in-flight files.

## Final outputs (the only files written)

Staging: `<workdir>/no-checkpoints/.<run-id>.partial/`; published by one atomic
rename to `<workdir>/no-checkpoints/<run-id>/` only after all selected stages pass.

- `merge/histograms.json`, `merge/histograms_raw.json`, `merge/samples.json`,
  `merge/yields.tsv`, `merge/cutflow/<sample>.tsv`
- `systematics/templates.json` (when selected)
- `fit/result.json` and, from the default fit with a `[fit]` section,
  `fit/workspace.json`, `fit/result.txt` (when selected)
- `plot/index.json` (paths point into the published directory), `plot/yields.txt`
  and the default plot tables/images (when selected)
- `NO_CHECKPOINTS_PROVENANCE.json`: `checkpoints=false`, `resume=false`,
  `fresh_compute=true`, zero per-file checkpoint reads/writes (a contract
  declaration by construction, labelled `per_file_checkpoint_io_basis`; NOT measured
  I/O counters), config path and SHA-256 (main analysis TOML bytes only, re-read
  when provenance is written; correction/golden/luminosity payloads, inputs and
  environment are not covered, see `config_sha256_scope`), profile, steps, samples, files per sample, stage counts, worker/window
  settings and the observed maximum claimed window, timing (worker sums are not
  stage walls), source-code SHA-256 and a SHA-256/size inventory of every output.

Final files keep their existing atomic writes (`write_store` temp+rename) inside
the private staging directory. They carry no `.meta.json` cache keys, so no later
checkpoint run can resume from them. The default plot hook reads
`merge/samples.json` from the same staging directory (this run's final output).
Plot code may create its own transient files exactly as in the default route.

On failure nothing is published; the hidden staging directory remains with
`FAILED.json` (it is never deleted automatically, and neither is anything else;
failed `.partial` directories accumulate until removed by the user).

Known low-level limits (documented, not redesigned): publication uses
`Base.Filesystem.rename` (unexported, same precedent as batch/reduce); an empty
directory created concurrently at the final path between the existence check and
the rename would be replaced by POSIX rename. Up to `4 x file_workers` transported
per-file stores are retained, with no RSS cap; files are claimed in original order
(not largest-first), so a slow head-of-line file can idle workers. Performance is
unmeasured.

## Verification still required (none performed)

Proposed order, each step needing its own approval: run `test/no_checkpoints` and
the existing pipeline/config/batch/windowed/execution_options suites; then a small
real NanoAOD ttbar baseline and sf comparison of `checkpoints=true` (fresh
workdir, `--force`) versus `false`, with a workdir file-inventory audit.
Comparison criteria: exact bytes for every JSON/TSV/text table and store;
`plot/index.json` by normalised relative paths plus existence of every entry;
images by the existing validation contract (full PNG decode: signature, chunk
CRCs, zlib, filters, IEND, nonblank pixels, same dimensions; PDF header) with
byte identity only observed. A pixel-equality criterion for images is not defined
in this repository and must be fixed before those tests are counted as passing.

Remaining gaps with no test claim: cross-process consistency for 1 vs N threads
(different processes), certified-luminosity mode, windowed selection combined
with this option, SF/correctionlib (`apply_corrections`) inputs, real NanoAOD.
