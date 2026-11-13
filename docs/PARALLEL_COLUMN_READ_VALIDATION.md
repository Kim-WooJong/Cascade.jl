# Opt-in parallel NanoAOD column reads

## Product contract

Normal nominal selection can request concurrent branch read/decode work:

```toml
[execution]
column_readers = 1 # default; integer 1:4, not Bool
```

Profiles may override this table; invalid values in inactive profiles are also
rejected. Unlike options, execution remains in the resolved configuration.
The Selection API accepts run_selection(...; column_readers=1,
execution_diagnostics=Dict{String,Any}()). The IO helpers with_column_readers and
read_parallel_columns support the invocation-local scope used by selection.

Width one keeps the serial read_columns implementation and opens no extra
source or worker task. Pipeline enables the new path only for nominal nanoaod
samples and unchanged built-in reader registries. Actual sources must be local
UnROOT mmap sources whose mapping identity can be bound on Linux using
/proc/self/maps. Other sources/platforms use the serial path. Custom/replaced
readers, cols, reduced inputs, shape selections, EventWindowSource and
LazyEventSource are not promoted to concurrent readers. Correction-source reuse
is unchanged. Registry replacement during an invocation is unsupported; there
is no hot reload.

The per-file width is at most min(requested, floor(threads / min(threads,
uncached_file_tasks))). Existing outer dynamic file scheduling is unchanged;
outer width times inner width does not exceed process threads. No host-core
count is consulted. Each slot consumes one branch job at a time; there is no
branch-future queue explosion. Empty name lists and single unique columns take
the ordinary reader without extra handles. Handles are opened lazily on the
first multi-column phase and reused across pre/post calls.

Slot one borrows the original source only while its owner is idle. Every other
slot owns an independent ROOTFile, stream, metadata cache and branch objects.
Slots belong to tasks, not thread IDs. Clones preserve tree, runs_tree and
gen_sumw. Mapping identity (raw parsed /proc major/minor/inode and mapped
length) and path identity (raw stat device/inode/size/mtime/ctime) are recorded
as separate namespaces. Each clone must match the original mapping tuple AND
the same recorded path tuple; mapped length must also equal path size. Mapping
and path device/inode values need not equal each other on virtual/stacked
filesystems. No manual stat dev_t major/minor decoding is performed. These
checks retain ordinary rename/replacement detection even when replacement bytes
and ROOT UUID match: a new mapping cannot match the old mapped inode. UnROOT
MmapStream exposes no retained descriptor. Missing/unparseable mapping evidence
falls back before extra opens; loss of evidence after binding or a changed
composite is an error. Final source checks retain both identities.
This is not protection against hostile concurrent in-place writes or a new
content-integrity cache. No full-file SHA or per-branch /proc scan is added.

Collection counters and offsets are prepared serially once per collection per
masked phase, then shared read-only. Decoded columns are never cached across
mask phases. Workers call the existing basket reader, preserving primitive
content, jagged offsets, masked placeholders and errors. Results are assembled
serially in original unique-name order. All workers join before an error is
re-thrown or any extra source is closed. Finally closes every successfully
opened owned slot, including partial-open/read failures; it never closes the
borrowed original. UnROOT mmap close itself is a no-op: mapping lifetime still
follows Julia/UnROOT GC, not an asserted immediate OS unmap.

Event/prefix loops, object buffers, cutflows, histogram filling, ordered merge,
original Runs normalization and native rendering remain unchanged and serial
within their existing scopes. This feature does not stream a file, bound RSS,
partition events, fuse stages or remove checkpoints. Full-file decoded arrays
remain eager; simultaneous basket/decode scratch and extra metadata can increase
memory with width. The cap is reader count, not a fictitious byte reservation.

## Cache and generation metadata

Select .meta.json gains an execution object: requested_readers, budget_readers,
effective_readers, fallback, max_active_reads, extra_opens, extra_closes,
branch_jobs and counter_reads. Effective width is the maximum dispatched width
across phases. max_active_reads counts overlapping in-flight branch calls, not
CPU utilization; zero denotes the untouched serial reader. Direct Selection
calls omit Pipeline's budget_readers field.

Execution settings do not enter selection's scientific section hash, so changing
only the width can reuse scientifically identical artifacts. Cached artifacts
retain their original generation diagnostics; no cache hit pretends it ran with
the current width. Full-configuration/batch/reduced-contract hashes still see the
execution table. Nothing strips arbitrary configuration or changes canonical_hash.
Config/IO/Selection/Pipeline source edits naturally invalidate existing folder
code keys and downstream artifacts. Existing integrity/preflight checks remain.

## Source and environment

Authoritative source is Mac artifacts/Cascade.jl. All Julia/native execution used
only /path/to/user/analisis/Cascade_dev/parallel-selection on gate. Its absence and
non-symlink status were checked before creation. The baseline project/evidence
remain frozen; candidate/project is a separately created copy. Explicit input
lists include Project.toml, src, test, analyses, examples, bin and tools; no git,
data, depot or old outputs were transferred. Historical p6-p11 inputs/outputs,
benchmark sources, production analysis configuration and Project.toml were not
edited. No installation, resolve, p11 resume, staging, commit or push occurred.

SHA256 records use digest + two spaces + relative path + LF, sorted by path:

| Snapshot | Records | SHA256 of record list |
|---|---:|---|
| Baseline source |401|60e661a8ddb7abec272d9100e1348c236a4456ff3c053e8e8750ed88fdb10c48|
| Baseline runtime |648|a656324e42189e74956cdc78b611b36763b1b83c3ab9f13c2941d0951c5b240a|
| Pre-fix candidate source |412|041c0c3a0a9e83bf5d9a1053adb79a5ad76c7b77f1388b4b587441ddbe3aec1f|
| First focused runtime |663|c65487941aee07bfe8ef2faf1bfde7c2b95c152efa16abbd802a148b03ea6ea5|
| Expanded guard/total runtime |666|cdeee703b683b806af55bc5ec182d1fae851de9c51c5070bfa99c4d17a72128c|
| Pre-fix closure runtime |667|a49743b19408b58be303a54d594a8cd160cc83f243a7bfd55a62643b0dcdd091|
| Identity-fix source |412|0ce0226d8a7cef5bafe8b27a06fd13ddd46ff1e4f1d7b2cd87211d118bc2ad11|
| Identity-fix runtime |667|b494cb2d98daa9e5a72cf968f03a875c2c6e241115ed94540bca6227be059d88|

Pre-fix production source412 was unchanged through the initial validation and
three total observations. Runtime additions only expanded tests/preparation and
then added the executed post-timing verifier. A subsequent identity-only review
fix changed column_source_identity.jl, open_column_reader.jl, test_scope.jl and
test_actual.jl. Their pre-fix bytes are archived in evidence/pre-identity-fix/;
all earlier logs/measurements are preserved. Post-fix actual03/focused03 below
validate the new412/667 snapshots. The512 regression,109 output verifier and
three ordinary CLI/PNG workloads were NOT rerun after this identity-only fix;
they remain explicitly pre-fix evidence. Source changes naturally change code
keys, so the old total artifacts are not advertised as final-source cache hits.
Docs/operational STATE are outside runtime lists. Before/after/current Mac/gate
checks match; all baseline runtime inputs outside the seven authorized integration
files remain byte-identical. Baseline gate runtime648 and native inputs also
match their frozen checks. Evidence is under candidate/evidence/.

Julia1.12.2, existing /path/to/user/packages/rootplots-gate.sh, BLAS1, at most four
Julia threads, one validation process at a time, hard300s per process. All runs
used --compiled-modules=existing and JULIA_PKG_PRECOMPILE_AUTO=0: no new package
precompilation process or dependency setup was requested.

- Project SHA256: b52613ed76a0bebb76dc03c4905c1afdc896311c72378c51707a0dcecd1ec8ad
- Existing Manifest: 00ea56222e1348ebacf895819d7b07d41740e05b4a708ba7ae5e1d34e5e83119
- Wrapper: 7d8eca8a88229cde40f106cb8723b446abc75dbef341522884981c1deaddc23d
- UnROOT0.11.11: /path/to/user/.julia/packages/UnROOT/wZnTS/src/UnROOT.jl
- ROOTPlots0.2.2: /path/to/user/.julia/packages/ROOTPlots/hvuKg/src/ROOTPlots.jl

## Bounded validation

With b=/path/to/user/analisis/Cascade_dev/parallel-selection/candidate, the
bounded entry points are:

~~~sh
JULIA_THREADS=4 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 \
  timeout --signal=KILL 300s bash /path/to/user/packages/rootplots-gate.sh \
  --compiled-modules=existing --project="$b/project" \
  "$b/project/test/parallel_columns/runtests.jl"
# Relevant module subset: replace the final entry with regression.jl.
# Native parity: CASCADE_PARALLEL_REAL=1, plus CASCADE_PARALLEL_MC/DATA
# pointing to exactly the two frozen paths listed below.
# One-thread guard: JULIA_THREADS=1, CASCADE_PARALLEL_ONE_THREAD=1,
# CASCADE_PARALLEL_MC pointing to the same TT file.
~~~

Actual02's additional fixture preparation is recorded in candidate/run-actual02.jl.
The three exact timed commands are candidate/total-<case>.command. They invoke
project/bin/cascade.jl through the existing wrapper, not a benchmark adapter.
Verification uses verify_total.jl with CASCADE_PARALLEL_CANDIDATE set to b;
PNG verification is candidate/evidence/check_png.py, outside timed execution.
Do not rerun the preparation into existing configs or overwrite these receipts.

All receipts below are candidate/<name>.log and <name>.exit, with actual exit0:

| Run | Coverage | Passed |
|---|---|---:|
| Pre-fix focused01,4 threads | config/budget; barrier-proven overlap; ownership/partial-open/read-error joins |694|
| Pre-fix focused02,1 thread | expanded config/ownership; cols/shapes fallback, cached generation; native one-thread fallback |705|
| Pre-fix actual01,4 threads | earlier focused tests plus native raw/selection parity |882|
| Pre-fix actual02,4 threads | expanded focused/cache guards plus native parity and fixture preparation |910|
| Pre-fix regression01,4 threads | Config/IO/Selection, unchanged canonical-hash tests, source-reuse and reduced lazy-correction guards |512|
| Pre-fix verify01,4 threads | ordinary pipeline artifacts, SF weights, exact histogram/normalization/transport comparisons |109|
| Pre-fix png01 | full PNG CRC/zlib/filter decoding and nonblank pixel checks |3 images|
| Post-fix actual03,4 threads | full focused runner plus same native mask/selection/race checks and strengthened rename rejection |927|
| Post-fix focused03,1 thread | config/budget, namespace/ownership/cache guards and native one-thread fallback |720|

Native checks use only these existing inputs, read-only:

- /path/to/user/nano_slim/mc/Run3Summer22NanoAODv12/TTto2L2Nu_TuneCP5_13p6TeV_powheg-pythia8/NANOAODSIM/130X_mcRun3_2022_realistic_v5-v2/2520000/66b834d6-61f7-4109-b5ae-54a150d4814b.root
- /path/to/user/nano_slim/data/Run2022C/MuonEG/NANOAOD/22Sep2023-v1/2520000/6c474b9d-4e5c-44ea-b95a-45d21840ea4b.root

Original counts32853/104057; baseline nominal retained1493/45. Widths1/2/4
were compared; width4 ran three times per input for race checking, not timing.
All raw-column types/primitive bits/jagged content and offsets matched, as did
selected entries/stages/output bits, cutflow sums/counts and region totals.
All/none/alternating masks, counter-offset sharing/dedup/order, opposite-mask
rereads, empty/single-column names, malformed masks/missing branches and
independent handles were checked. Native max_active_reads reached2 and4;
extra opens/closes matched1 and3 respectively. Barrier tests independently
require simultaneous entered calls and prove workers finish before cleanup,
including read failure and partial opening. Original sources remain borrowed.
Replaced readers, non-mmap sources and borrowed window/lazy wrappers fall back.
A private copied ROOT file tested rename replacement without changing originals.
Post-fix tests preserve rejection against the recorded pre-rename composite and
also rebind the current path metadata while retaining the original mapping:
the newly opened clone still fails its different mapped inode. Fifteen pure
identity assertions simulate stable mapping-vs-stat device/inode disagreement,
changed mapping major/minor/inode, changed path metadata, length/size mismatch,
and unavailable mapping before versus after binding. This is synthetic virtual-
filesystem coverage; no actual btrfs/overlayfs host validation was performed.
Default remains1; larger widths remain experimental opt-in, not a promotion.

The relevant-regression runner is not the full suite or full reduced/streaming
regression. Actual direct-reader checks use the existing baseline profile, not
the separate benchmark W4 configuration; their retained counts are not an RDF
comparison. No fit/theory/shape workflow performance was measured.

## Pre-fix ordinary fresh-checkpoint total observations

These observations use pre-fix source412 digest041c0c3a... above, NOT the final
identity-fix source. No new performance phase or additional CLI repetition was
run for the fix. Extra reader opens remain serial, and their setup cost is not
hidden behind a parallel-open claim.

Three fresh CLI invocations ran the same validation-only two-input configuration:
existing sf-profile lepton/pileup nominal corrections, one emu_ge1j region and
njet histogram; no shape/theory/fit; one native PNG through the ordinary plot
hook. Up/down SF declarations were omitted. The exactly-unity trigger placeholder
was omitted because the flat API requires up/down columns; nominal physics is
unchanged. Production analysis.toml was not edited. configs/readers1.toml and
readers4.toml differ only in execution.column_readers. Each invocation used a
new workdir, --force and steps skim,select,correct,histogram,merge,systematics,plot.

Time covers wrapper start through ordinary process exit after native render,
output save/move and plot index publication. Input hashing, parity checks,
numeric transport verification and full PNG decoding were outside timing.
All three exited0, produced exactly the requested njet PNG, and preserved exact
selection/SF-weight bits, histogram edges/sumw/sumw2, generator denominator,
normalization and merged sample summaries. The original renderer's private TSV
is cleaned normally; verification regenerated the same product transport after
timing, checked BIN data/prediction against merged histograms and required all
three transports to match. It did not replace or adapt the renderer.
All596x692 RGB PNGs fully decoded, with36 distinct pixels/colors. PNG byte
identity was not the correctness criterion.

| Case | Julia threads | Requested readers | Effective/file | Total seconds | GNU time maxRSS KiB |
|---|---:|---:|---:|---:|---:|
| total-t1-r1 |1|1|1|93.54|1229604|
| total-t4-r1 |4|1|1|88.31|1502524|
| total-t4-r4 |4|4|2|90.37|1555028|

Two uncached file tasks cap the last case at two readers/file, four total;
metadata confirms actual overlapping calls and one extra open/close per file.
The direct reader tests separately establish width4. maxRSS is GNU time's
reported high-water metric including child accounting, not a sum of simultaneous
process RSS or a bounded-memory guarantee.

Rounded ordinary stage clocks (seconds):

| Case | skim | select | correct | histogram | merge | systematics | plot |
|---|---:|---:|---:|---:|---:|---:|---:|
| t1-r1 |2.98|11.39|11.05|1.73|4.84|1.04|25.73|
| t4-r1 |2.92|8.87|9.25|1.59|5.49|1.19|25.23|
| t4-r4 |3.09|9.81|9.21|1.70|5.00|1.13|25.36|

Stage clocks do not exhaust process total: startup/loading/JIT/setup/finalization
and residual remain outside their sum. Plot time includes its ordinary Julia
preparation/native subprocess/output handling, not an isolated renderer timer.
File caches were not cold; native before-hash checks warm them, and installed
package/native cache state was not reset.

The equal-CPU observation with concurrent readers was2.06s slower than readers1.
One observation per case cannot establish a stable speed difference; there is
no measured benefit or speedup claim. Keep the feature opt-in/default1. This
small-file result does not complete the RDF-competitive total-time goal, does
not compare different core budgets to RDF, and says nothing about full13sample,
fit or systematic workflows. Checkpoint IO, source setup/JIT, corrections and
plot costs remain substantial. No automatic enlargement/repetition followed.

The pre-fix validation process wall receipts sum to about11minutes. Identity-fix
actual03 took67.48s (maxRSS1229936KiB), focused03 took47.53s
(maxRSS929732KiB):115.01s additional validation wall, one process at a time,
BLAS1 and hard300s caps. No full suite,512 subset, native renderer, timing matrix
or p11 rerun followed the fix. All jobs ended; final process checks found no
active Julia analysis. Performance benefit remains unestablished; default1 and
opt-in experimental status are unchanged.

## Review and parent closure

Independent concrete review and the narrow identity-remediation re-review found
no remaining correctness, ownership or integrity blocker for this experimental
opt-in scope. Both were read-only static reviews, not second runtime executions.
Parent independently inspected final actual03/focused03 logs, actual exit0 and
927/720 summaries, all current Mac/gate source412/runtime667 bytes, before/after
record equality, and unchanged baseline648/native/environment bytes. Reconstructing
the pre-fix667 snapshot using the four archived files matched every recorded hash.
Tracked/untracked whitespace checks passed. Final closure edits affect only docs
and operational state, not the validated runtime inputs.

No measured performance improvement or RDF-competitive total-time acceptance is
established. Keep default1; do not recommend enabling readers4 for the measured
small-file case. Parallelism is currently eligible only on Linux with bindable
mapping evidence; this feature uses the serial fallback on the Mac Studio.
Next optimization requires its own bounded evidence and the owner's next-step
decision; no automatic full-suite, timing matrix or historical p11 restart.
