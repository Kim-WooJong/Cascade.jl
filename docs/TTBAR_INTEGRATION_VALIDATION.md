# Small combined ttbar technical integration

## Authority and scope

Owner the maintainer authorized this bounded integration on2026-11-06 at14:53, from
clean9071405/v0.6.0. This is NOT Stage5, a full3307-file skim, final physics
adoption or a historical processing restart. Mac holds source/config/tests/docs;
all Julia/native execution, inputs, outputs and logs stay on gate. Existing
p6-p10 evidence is immutable. Parent owns independent review/final local commit.
No staging/commit/push, dependency resolution/install or service changes.

## Opt-in profile, unchanged defaults

Use analysis.toml with --profile integration_small. Existing baseline, sf,
phase2, jer_candidate and theory_example are unchanged. The new profile combines
jer_candidate's existing SF/JES/JER and consistently smeared nominal with the
verbatim TTto2L2Nu-only scale/ISR/FSR declarations from theory_example. The current
resolver deep-merges tables and replaces arrays, so three explicit declarations
are repeated; no new framework API or profile inheritance is introduced.
Nominal JER=true is a technical comparison setting, NOT physics prescription
approval. No invented PDF or background-theory mapping is added. Trigger unity,
placeholder luminosity/background priors, calibration/JEC provenance and absent
validated PDF remain unresolved.

## Predeclared frozen comparison

- All13 samples in original configuration order, first2 lexically ordered
  originals per sample (26 files, subject only to concrete availability).
  Keep the full available inventory semantics and max_files=2 so exposure remains
  unknown under configured1210pb^-1. inventory.json records exact paths/order,
  counts, original signed Runs/status, signatures and original byte SHA256.
- Independent5000-row windows and1000-row/32MB shard targets force multishard
  TT groups and preserve more than one original. Every data zero-kept source is
  a valid logical ledger with an empty carrier, never dropped from normalization.
- Exact original entry union/order for nominal and every configured shape;
  raw primitive/jagged bytes/types, IDs, counters and list lengths; all event-local
  selected values and corrected scalar/member/shape weights. Require real TT
  shape-added entries, not only an isolated synthetic migration test.
- Original signed Runs denominator and original cutflows belong once to each
  logical source. A physical shard normalization call must throw. This analysis
  uses configured luminosity, not a certified per-LS normalization table: no LS
  exposure is invented from retained data. Original cutflow evidence and current
  retained prefixes are deliberately distinguished.
- Compare all samples/regions and every raw/scaled/member/reduced-template
  edges/sumw/sumw2; selected/base yields and shape yields; logical/physical counts,
  group ownership and original provenance. Old/new floating reductions use
  128eps(Float64)*ceil(log2(total original N)) times a contribution upper scale:
  max(1,sqrt(N*max(sumw2))) for sumw, max(1,abs(old),abs(new)) for sumw2.
  This is not relative-to-near-zero tolerance. Same NEW partition serial/fresh
  two-worker batch requires histogram bits and corresponding sample metadata
  equality. No cross-partition universal bit-equality promise is made.
- Original actual histogram bins and observed fit/settings are tried first.
  Preserve failures/nonconvergence and nonpositive nominal sample bins. Never
  clip, hide, or silently change the physics configuration. If necessary, a
  separately named diagnostic scope sums ALL existing njet bins (same extent,
  no clipping) and uses Asimov observations; original results remain intact.
  Compare modifier/observation inventory, full workspaces (absolute1e-9 plus
  relative1e-10), fit POI/error/NLL and all parameter values/errors (absolute1e-6
  plus relative1e-7). Same NEW serial/batch workspace and fit quantities are exact.
- Fit/plot reporting clones skim/merge/systematics into separately named consumers
  for original, reduced and batch. It never mutates an accepted immutable batch
  result. Compare plot index inventory, existence, and PNG/PDF signatures; native
  pre/postfit/tables/impact coverage is recorded rather than assumed.

## Reproducible harness and execution plan

Canonical scripts: test/ttbar_integration/{run_real.jl,validate_gate.sh} and
one-feature helper files. Explicit CASCADE_TTBAR_REAL=1 is required. Independent
phases allow inspecting a failure without restarting completed physics stages.
The shell driver rejects existing log/exit names; never overwrite attempts.

Gate area p11-ttbar-integration was checked absent before provisioning. Use the
installed Julia1.12.2/UnROOT0.11.11, approved p10 Manifest and established
/path/to/user/packages/rootplots-gate.sh. Absolute project AND script paths are
mandatory because the wrapper changes directory. Coordinator Julia2/BLAS1;
fresh batch2 workers with1 thread each; phases run serially, no CPU thrashing.

~~~sh
export CASCADE_TTBAR_PROJECT=/path/to/user/analisis/Cascade_dev/p11-ttbar-integration/candidate01
export CASCADE_TTBAR_AREA=/path/to/user/analisis/Cascade_dev/p11-ttbar-integration/case01
bash "$CASCADE_TTBAR_PROJECT/test/ttbar_integration/validate_gate.sh"
~~~

Driver runs profile/config resolution and synthetic shape+SF+theory checks,
then prepare/original/export/reduced/batch/events/compare/fitplot/final. Actual
per-command statuses go to integration-logs/*.exit, not inferred from a running
status or timeout. Inspect live jobs/logs before retry. Freeze source/runtime
inputs before tests and recheck after, including Project.toml and all files under
src/test/bin/analyses/examples, with byte-sorted standard SHA256SUM records
(HASH, TWO spaces, relative path, LF), then SHA256 the record stream. Existing
Manifest is recorded separately. Tracked AND untracked whitespace checks and
current Mac/gate parity are required. Docs/state-only completion edits are not
runtime validation. Full suite is required if core/config-code changes become
necessary; profile-only composition uses mandatory profile/focused integration.

## Results

### Preserved producer and measured interruption (not final acceptance)

candidate01/case01 uses frozen398-source aade1746c7c195e41b5a3ba1b82441b4fb82eb9e6f561ae0d1f3b45f0caafdbe
and624 runtime-input a4b24b4e46bbc5829b7a86232e9042b16f1adbbf9b17a8592b30b7af2c967610.
Synthetic and prepare exit0; original26files/4751632Events completed1m27.7s,
export completed38m37.6s with26 groups/46 shards/21807 retained rows/964 windows.
The original producer fingerprint and bundle remain unchanged, not relabeled0.6.1.

| Sample | Original events | Retained | Physical shards |
|---|---:|---:|---:|
| TTto2L2Nu |39843|1813|3|
| TWminusto2L2Nu |44888|2196|4|
| TbarWplusto2L2Nu |363448|17388|19|
| WWto2L2Nu |23892|333|2|
| WZto3LNu |3585|9|2|
| WZto2L2Q |7777|0|2|
| DYto2L_MLL50 |6473|0|2|
| DYto2L_MLL10to50 |1179445|1|2|
| TTtoLNu2Q |184175|16|2|
| MuonEG |272192|47|2|
| SingleMuon |248207|3|2|
| Muon |708052|0|2|
| EGamma |1669655|1|2|

All13 samples have exactly2 originals. Four data zero-kept originals (SingleMuon2,
Muon1/2, EGamma1) retain their carriers. Signed per-original Runs, source paths/
SHA256, TT branch titles/first32 layouts and all payload hashes are in inventory/
payload JSON; producer-summary.json records the complete sample table.

The old reduced skim/select/correct/histogram completed424.66/1217.89/2352.23/
811.46seconds. Parent-authorized cooperative SIGINT stopped only its global merge
after the cause was measured. Actual reduced/driver exit130 is retained, not an
assertion failure and not a completed end-to-end run. No successful physics stage
was restarted. parent-handoff01.json records the exact owned process and action.

perf01 probe/metadata/sha all exit0: warm group validation~16.2s, of which hashing
2,290,449 canonical String bytes costs16.1..16.4s. ROOT object/schema operations
are sub-millisecond; all raw branch decoding~0.008..0.020s. codeunits alone is
also slow. Vector UInt8 SHA costs0.0175s with exactly the same digest
9ec0367e74e52dd3dd46c5d54b517b29384d0a8a417a3d2cf63e0db672c80274.
The one-line0.6.1 fix materializes the same canonical bytes in a byte vector;
no verification, canonical rendering, digest, cache acceptance or reader contract
is weakened.18 Unicode/golden/type/order fixtures cover the wire behavior.
Independent hashfix01 configuration251 and actual manifest11 checks exit0.
Warm complete canonical times0.063..0.095s and group metadata0.213..0.506s are
that narrow fixed snapshot's evidence, not timings invented for the new full run.

### Fixed consumer validation in progress

full02 runs the mandatory full suite for Config-core changes: source398
9bc0c6fb3622381a1eb4d3d809b5610b26b3ab38538b0ca51d357256a0104c29,
runtime628 21c86dee5d0c2e5877a7df1c60d33139d26cc81bad85f457adf50b427b6cb6ab.
candidate02 synthetic passed; prepare-reuse stopped after144 passes with an
unqualified private API name error. It did not execute any global/event stages;
its copied view/logs are preserved. candidate03 corrects that test harness and
adds the concrete review acceptance checks; source core/Project/ordinary suite
and profile tests are byte-identical to full02. Current runtime631 is
014ac2f667e0ef9a9de4301289104bfc0538ca3125d495e810370d80ac4a026d.

Explicit reuse-bindings preserve producer fingerprints and exact completed-file
checksums, distinguish the consumer fingerprint/commands and permit ONLY the
one canonical SHA line plus Project0.6.0→0.6.1. All non-source runtime/input/
payload identities must agree. Existing bundle selection-code contracts are
checked normally. New consumer view case02 runs only unfinished merge/systematics,
fresh fixed-source batch and subsequent verification/fit/plot; original/export/
completed selection/correction/histogram artifacts are copied unchanged, not
retroactively stamped as new computations. Immutable batch results are never
edited by reporting consumers. No unrelated performance-proposal work is included.

Final actual exits, numerical/fit/plot results and frozen after-lists remain
pending. Prior p10 results do not validate this new combined scope.

## Owner-requested stop — 2026-11-06 18:00 KST

The owner requested quick closure before a major redesign. No additional tests,
fixes or reviews are to be launched. This checkpoint is NOT an accepted complete
integration or0.6.1 release; HEAD remains9071405 and changes are uncommitted.

Verified completed: original13-sample/26-file analysis and export of4751632Events
to21807 rows/46 shards; candidate03 prepare-reuse, hash-probe and reduced-continue
(merge/systematics) actual exit0. Hash-fix lane18/config251/manifest11 checks passed.
The fresh batch had10 receipt files of46 planned tasks when stopped. Complete
fresh-batch, final event/numerical comparisons, fit/plot and full regression remain
unfinished; no result from them is promoted to a pass. candidate02 prepare-reuse
exit1 and candidate01 intentional130 evidence remain intact.

At18:01 the parent verified owned process identities and stopped orchestration
with TERM and Julia processes with INT; one sleeping full02 worker required TERM.
A subsequent process check found no remaining full02/candidate03 Julia processes.
Records: gate p11-ttbar-integration/parent-owner-stop-1800*.json. Existing artifacts,
logs, original inputs and unrelated README/PERFORMANCE_* documents are preserved.
The delegated run was cancelled. Do not resume or install/deploy without new
owner instructions. Prior in-progress wording above is historical, not active work.
