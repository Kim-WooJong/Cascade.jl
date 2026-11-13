# Batch backend: Step3 validation

Date: 2026-11-05. Base: eb34a2d (0.3.0); compatible feature version0.4.0.
Owner directly authorized Step3 at17:53 and runtime continuation17:56.
Mac is authoritative source/docs only; all Julia/data/artifacts/logs on gate.
No push/publication, scheduler/service/environment configuration, reduced skim,
deployment or historical3307 audit/billion-event rerun. Git records the final local
milestone commit; runtime checkpoints below preceded parent staging/commit.

## Evidence boundary after independent review

The348-source/526-input hashes and210/53,200/5,237 results below are the
initial PRE-FIX Step3 snapshot. They do not validate review08f94ec9 remediation.
That review accepted the ordered merge/normalization/theory design but required
plot-reference relocation, launcher pinning, output-name containment and stronger
lifecycle evidence. Final remediation results and accepted re-review are recorded
separately below; old Step1/Step2/p8 evidence and outputs remain unchanged.

Development review08-dev exited1 after210 existing checks and41 published-plot
checks passed. A test-only Dict inferred Bool values then received a vector
selector; making that fixture Dict{String,Any} corrects the test construction.
This failed run is not final validation and does not establish remaining cases.

## Frozen source and input parity

Gate area ~/analisis/Cascade_dev/p8-batch was absent (including symlink check)
before provisioning. Existing p7 Manifest copied without dependency resolution.
Established ~/packages/rootplots-gate.sh reports Julia1.12.2. Source transferred
by explicit rsync of Project/src/test/analyses/examples/bin/docs, no --delete,
.git/data/outputs/credentials. Source/test/config frozen before final runs.

-348 Julia source files: d30b53fbb116fb10e5f31ae018e31bf6889832fee90b6f5c48d5792d8dda0511.
-526 full inputs (Project.toml plus all files src/test/analyses/examples/bin):
 a01879edb85980bbec8f04c758c3bc4688c825ebcec69acc6cef74b55b939648.

Algorithm: sorted relative paths (LC_ALL=C), each line path + space +
SHA256(contents), SHA256 of the complete stream. Both identical Mac/gate before
execution; after execution each gate file checked against lifecycle-source.sha256
and lifecycle-fullinput.sha256, zero mismatches. Mac digests unchanged.
Documentation/state edits do not change these frozen input streams.

## Commands, logs, exits

Commands executed from gate p8-batch. Absolute script paths are required because
the established wrapper changes its directory. OPENBLAS_NUM_THREADS=1 throughout.
Batch concurrency capped at two fresh single-thread workers; coordinator full
suite uses two threads. Runs were sequential, not oversubscribed.

~~~sh
JULIA_THREADS=1 OPENBLAS_NUM_THREADS=1 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/batch/runtests.jl" > focused-lifecycle.log 2>&1; echo $? > focused-lifecycle.exit
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/runtests.jl" > full-final.log 2>&1; echo $? > full-final.exit
CASCADE_BATCH_REAL=1 CASCADE_BATCH_AREA="$PWD" JULIA_THREADS=1 OPENBLAS_NUM_THREADS=1 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/batch/test_real.jl" > real-final.log 2>&1; echo $? > real-final.exit
~~~

Gate-only validate-frozen.sh waited for focused exit0, then ran full suite,
then bounded ROOT only on full exit0. Local SSH tool reached600s timeout; remote
run was inspected and remained active. Read-only watchers collected its original
exit markers; no duplicate suite was launched. All validation executions ended.

## Results

- focused-lifecycle: **210 passed, exit0**: wire6, deterministic execution/resume156,
  claim/interruption4, deliberate failure/hooks/readers10, cached preflight13,
  manifest/payload/input/code21.
- full-final: **53,200 passed, one existing plotting guard skip (Broken), exit0**.
  Areas: audit55, batch210, config202, corrections209, fit327, histograms28,
  IO62, objects23022, pipeline2004, plotting191, selection151, systematics26739.
  Pipeline includes1720 new shape-batch checks. No failed assertions/errors.
- real-final: **5,237 passed, exit0**. Counts overlap test scopes; do not add
  focused or real totals to the whole regression total.

Synthetic proof includes serial vs two-worker reversed launch vs independent
one-worker plans with stable IDs, exact nominal/raw/scaled/member/sumw2/templates,
samples/cutflows/yields and fit workspace. Signed nominal Runs=-4 is preserved
and normalized globally once; same file shared by data/MC is retained. The
nonlinear cancellation fixture gives complete-merge down4, not taskwise down3.
Shape batch reproduces scalar+shape+theory labels, shape cutflows/yields and
metadata exactly. Existing metadata-only audit cache/fit-overlap tests pass.

Exclusive flock claim test rejects a concurrent holder, kills only its owned
test process, then reacquires after OS release. Invalid/missing/corrupt/extra/
foreign/partial receipts reject merge; retry preserves verified receipts and
redoes only unverified chunks without double counting. Deliberate malformed
vector task exits nonzero and retains failed state/log. Manifest checksum,
duplicate task, wrong code/extraction/task contract, config bytes, payload and
input inventory/signature edits reject before work. Registry/TOML unverifiable
hooks and replaced built-in readers reject rather than substitute defaults.

Cached histogram/merge now preflight upstream and cached-output extraction
contracts before skipped returns.13 focused checks cover stale same-label
relative-to-central edits, missing cached provenance, compatible reduction/CL-only
reuse and member-free identity. Historical Step2 snapshots remain unchanged.

## Bounded actual ROOT evidence

New baseline serial and process backend:13files/2,200,037 Events (one per sample),
raw/scaled/templates exact;10,998 compared bins across those three stores, with
edges and sumw2 bit-equal. Raw/scaled also compare bit-exact to frozen p7 baseline
(7,332 bins); samples/cutflows/yields/normalization metadata match new serial.
Configured1210pb^-1 retained; truncated coverage and actual exposure unknown.
No dataset completeness or event-ID deduplication certificate is implied.

Actual TT1file/32,853 Events theory_example scale/ISR/FSR: raw/scaled/templates
bit-equal new serial and process backend, and raw members/scaled bins match frozen
p7 out_theory. Existing p7 direct selected-member arithmetic/sumw2 evidence remains
frozen; this run compares that behavior, not a new physical prescription. Real
PDF branch/CL closure remains unavailable. batch-real-summary.json records counts.

## Corrected development attempts

- Relative CLI script path failed because wrapper changes directory; absolute
  paths fix invocation, not product code.
- JSON3 decodes integral1.0 as Int1; a discriminating canonical-probe reproduced
  scalar/array behavior. New batch_hash normalizes the wire representation;
  existing physics/cache canonical hashes are unchanged.
- mktemp(parent;prefix=...) is unsupported; corrected to mktemp(parent).
- Fresh workers originally used mktempdir default cleanup=true, removing attempt
  artifacts on process exit after valid receipt publication. Persistent
  receipt-probe reproduced missing attempt with child exit0. Persistent attempt,
  merge staging and launch logs now explicitly cleanup=false. Lifecycle-focused
  and full suite prove receipt reuse after child exit.
- Development attempts/logs are not counted as final validation. Initial hashes
  fa0164.../a13814... preceded these final safeguards and are superseded above.

## Limits and independent review

POSIX local-host backend only; filesystem must implement flock and atomic rename.
No multi-host/NFS assurance, scheduler adapter, TTL lock stealing or unrelated-job
killing. Fresh-process startup per file adds overhead. Inputs use physical
identity/size/mtime signatures, not full ROOT hashes; same-signature malicious
rewrites are outside scope. Hashes are consistency fingerprints, not attestations.
No power-loss fsync guarantee. Existing corrupt final result fails closed.
Exact equality is for unchanged file partition/runtime/config/dependencies;
changed partition/reduction tree/platform is not promised bit-equal.

The initial snapshot preceded independent concrete review of tracked/untracked
files. That review required the remediation below; final independent re-review
acceptance is recorded at the end. Do not treat this initial snapshot as coverage
of later publication, launcher, isolation or lifecycle fixes.
Whitespace: git diff --check plus each untracked file via
 git diff --no-index --check /dev/null FILE; no whitespace errors. Parent owns commit.

## Final review remediation snapshot (review08c)

All requested P1 fixes and lifecycle regressions are implemented and accepted
by the final independent concrete-diff re-review recorded below. No source/test/config
edits occurred after this frozen run. Documentation/state updates are outside
the input streams. Tracked and every untracked file passed whitespace checks
before validation; no staging, commit or push occurred.

### Final Mac/gate parity

-351 source files: 521b00f6737dffc10fdd456358762e69d3364af70a0c5aa48e514a50aef0bc5d.
-533 full inputs, INCLUDING Project.toml and all src/test/analyses/examples/bin
 files: 558c5467ae8c9a4144a4064d45287960b039a519d70aaa0f9badce0cc5ba468d.

Same sorted path-space-content-SHA256 stream algorithm as above. Gate records
review08c-source.sha256 and review08c-fullinput.sha256 match Mac; .focused, .full
and .after records are byte-identical to them. Source/full inputs were therefore
unchanged through all three phases. Fingerprints now also pin every bin launcher,
including the actually executed bin/cascade.jl, as well as Project/Manifest/src.

### Exact commands and results

Gate p8-batch/review08c-final.sh ran these sequentially, advancing only on exit0;
OPENBLAS_NUM_THREADS=1 and at most two fresh single-thread workers throughout.
review08c-focused.jl includes fixture.jl, test_launcher.jl,
test_order_recovery.jl and test_finalizers.jl using absolute joinpath(@__DIR__,...)
paths. The full suite independently includes all batch and shape regressions.

~~~sh
JULIA_THREADS=1 OPENBLAS_NUM_THREADS=1 nice -n 10 bash "$HOME/packages/rootplots-gate.sh" --project="$PWD" "$PWD/review08c-focused.jl" > review08c-focused.log 2>&1
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n 10 bash "$HOME/packages/rootplots-gate.sh" --project="$PWD" "$PWD/test/runtests.jl" > review08c-full.log 2>&1
CASCADE_BATCH_REAL=1 CASCADE_BATCH_AREA="$PWD/review08c-real" JULIA_THREADS=1 OPENBLAS_NUM_THREADS=1 nice -n 10 bash "$HOME/packages/rootplots-gate.sh" --project="$PWD" "$PWD/test/batch/test_real.jl" > review08c-real.log 2>&1
~~~

Each command's actual exit is recorded in the corresponding .exit file:
- review08c-focused: **161 passed, exit0** (launcher6, nonassociative order56,
  actual worker kill/retry77, duplicate substitution7, global finalizers15).
- review08c-full: **53,508 passed, one existing plotting Broken/skip, exit0**.
  Areas: audit55, batch508, config202, corrections209, fit327, histograms28,
  IO62, objects23022, pipeline2014, plotting191, selection151, systematics26739.
- review08c-real: **5,237 passed, exit0**; fresh review08c-real output area,
  not reuse of pre-fix real_batch receipts. All executions ended; a subsequent
  process inspection found no Julia/validation process still running.
These scopes overlap and must not be added together.

### Discriminating coverage and corrected contracts

- --through plot tables-only publication: every persisted index entry exists
  inside result after rename; repeat finalization verifies/reuses unchanged
  bytes. Only plot output references are rebased, not scientific input provenance.
  Other persisted paths were inspected: skim/select source paths are inputs;
  metadata uses artifact basenames; fit reports embed workspace content.
- Isolated gate SOURCE COPY: plan, edit ONLY bin/cascade.jl, then status,
  worker API, run and command construction all reject. The changed entrypoint
  carries an execution sentinel, which is not created; no attempts/launches
  appear. Authoritative Mac/gate source is never mutated by this test.
- Traversal/absolute region, histogram, fit-channel and plot-selector names
  reject at the batch boundary before workdir/plan-lock creation, even with
  tables-only settings. A rechecksummed unsafe manifest also fails finalization.
  Outside sentinel files and directory listings remain unchanged. Serial parsing
  retains its existing naming contract. Shape names are also batch-validated.
- Symlinked attempts/merges/launches/receipts/locks and nested task parents reject
  before temporary creation or process launch. All pending task write paths
  preflight before any group starts; an unsafe second task launches no first
  child. Planning/atomic-output ancestor links also reject without outside writes.
- Three MC chunks [1e16,-1e16,1] complete in strictly reversed receipt order,
  with one/two actual child limits (owned SIGSTOP/SIGCONT establishes ordering).
  Raw/scaled/template bins, edges, sumw2, denominator1, weighted cutflow and
  sample metadata equal serial exactly; raw nominal1/scaled4 discriminate a
  reversed reduction, whose nominal is0.
- An OWNED actual CLI worker is killed after partial attempt skim artifacts,
  before receipt publication. Its task lock releases; no partial result/success
  is published. Retry creates one fresh attempt, retains the old evidence and
  matches serial without double counting.
- Equal receipt-file count cannot hide substituting one task's receipt for a
  missing expected task. Missing selected SHAPE companion and corrupt corrected
  SHAPE companion invalidate receipts with nominal/main metadata intact; retry
  repairs both and the final scalar/shape/theory/cutflow parity remains exact.
- Two actual finalization attempts conflict on the coordinator lock. Deliberate
  GLOBAL fit failure occurs after staged merge/systematics outputs exist, but
  publishes no result/batch-result.json. Task receipts remain reusable. A later valid publication
  is preserved byte-for-byte against an incompatible phase-prefix request.
  This backend rejects phase upgrades rather than replacing published results.
- Existing custom hook/reader rejection and cached extraction-preflight cases
  remain included in the final full suite; the historical cached-preflight caveat
  is resolved, with compatible reduction/CL reuse and no-theory identity intact.

### Fresh bounded ROOT reproduction

review08c-real/batch-real-summary.json records13files/2,200,037 Events and
10,998 serial/batch raw/scaled/template bins; all edges/sumw2 are bit-identical.
Frozen p7 raw/scaled7,332 bins remain exact. TT32,853 Events scale/PS checks
also pass. Configured1210pb^-1 and unknown actual truncated exposure are retained.
No additional dataset completeness, deduplication, PDF-branch/CL closure or
full-billion-event selection evidence is claimed. Old p6/p7/initial p8 artifacts
and validation logs were preserved, not overwritten.

### Intermediate attempts, not final evidence

review08-focused stopped on a test-generated launcher probe quoting error;
review08b-focused then passed the launcher test but stopped because Julia does
not expose Base.SIGSTOP/SIGCONT. Tests now use explicit Linux/macOS native signal
values and only signal their own Process objects. These are test harness fixes,
not physics changes; the successful review08c snapshot above supersedes those
failed candidates. The full/ROOT phases did not run for failed candidates.

### Remaining isolation limits / re-review targets

Local trusted POSIX workspace only. Preexisting symlinks are rejected, but no
hostile simultaneous filesystem race defense or fsync/power-loss guarantee is
claimed. Plot indexes use absolute final paths: moving a published result needs
an explicit relocation procedure, not supplied here. The new publication test
is tables-only; ordinary renderer coverage remains in the existing plotting
suite. Final re-review covered batch_safe_path, batch_validate_names,
batch_rebase_outputs, launcher fingerprints and all tracked/untracked tests.
Final independent concrete-diff re-review completed: no remaining material
blocker was found for bounded Step3 reporting. The reviewer inspected all new
tracked/untracked source and discriminating regressions, verified the corrected
publication/launcher/name/symlink contracts, and independently reproduced both
final hashes. This was read-only STATIC review, not an independent runtime rerun.
The parent separately verified actual gate exit files/area counts, fresh bounded
ROOT summary and every current gate source/input hash against the frozen streams;
all agree with the Mac snapshot above. Parent closure edits only documentation
and state, not the frozen executable/test/config inputs. Local commit is recorded
in Git; no push or later milestone work. Stop for owner review before reduced skim.
