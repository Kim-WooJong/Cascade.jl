# Reduced skim validation (frozen0.5 milestone)

Current0.6 streaming evidence is separate: STREAMING_REDUCED_SKIM_VALIDATION.md.
All p9 evidence below is historical, not new streaming validation.

## Scope and environment

Owner authorized Step4 only on 2026-11-05 at21:44. The accepted format is a
new opt-in genuine ROOT RNTuple bundle, not NanoAOD TTree output. Version0.5.0;
no push, package installation, scheduler/service/configuration or Stage5
deployment work. Git records the final local milestone commit; runtime checkpoints
below preceded parent staging/commit. Mac holds source/docs only. All execution, ROOT files,
outputs and logs are on gate under ~/analisis/Cascade_dev/p9-skim. Historical
p6/p7/p8 evidence and full3307/10^9-event results were not restarted or modified.

Julia1.12.2, installed UnROOT0.11.11, existing locked dependency snapshot,
ROOTPlots0.2.2 and ~/packages/rootplots-gate.sh. All Julia commands use absolute
project and script paths because the wrapper changes directory. Threads are
bounded (full synthetic2, focused/real1, fresh workers1); OPENBLAS_NUM_THREADS=1.
No product Python or external C++ writer bridge. Independent Python uproot5.7.1
is supplied by the existing LCG environment solely as a validation oracle.

## Phase1 feasibility (frozen)

p9-skim/phase1/probe: ROOT writer34/34 and existing typed columns9/9, exit0.
Independent oracle18 checks, real-probe25/25, real-oracle21 checks and current
NanoAOD-adapter limitation3/3: every corresponding .exit is0. These are feasibility
proofs, not the implementation milestone's complete validation.

Installed writer source matches the official UnROOT v0.11.11 tag:
TFileWriter.jl SHA256
 a99d5d2d82aa551f8e9546bc818e089a3d2dd879a47b19ada346ab0fc71179b8.
Installed tree hash matches the locked Manifest:
13783ae508c50e99ff3bb252f46f6965a57606cb.
API/source: https://github.com/JuliaHEP/UnROOT.jl/blob/v0.11.11/src/RNTuple/Writing/TFileWriter.jl

UnROOT documents ROOT>=6.34 interoperability. Direct independent proof here is
uproot5.7.1 recognizing ROOT::RNTuple, not a C++ ROOT runtime test. ROOTPlots'
plotting executable/spec API was not mistaken for a TTree writer.

## Implementation development evidence

All following logs/exits live in p9-skim/implementation; counts overlap and must
not be added to full-regression totals. Final frozen-snapshot results below
supersede development snapshots.

- real01: **30,805 pass/exit0**, two bounded original files: TT32,853 and
  MuonEG104,057 events. Retained TT1,493 and data45. Original/reduced raw branch
  source-entry/type/value comparisons47,363; raw/scaled/member/templates
  **8,640 bins plus edges/sumw2 bit-identical**. Signed original normalization,
  per-file original cutflows, region yields, technical Asimov fit and fresh
  two-worker batch parity pass. Configured1210pb^-1 retained; exposure unknown.
- oracle03: **206 independent uproot checks/exit0**, all exported real branches,
  original entry order, primitive/jagged element types/bytes/counters and original
  Runs sum. Real TT has no PDF vector; synthetic typed PDF/scale/PS coverage is
  separate and no physical PDF prescription is invented.
- dev04: contracts19, normalization7, certified exposure5, primitive bitwise63,
  nominal-JER/JES/MET/cleaning/sorting/earliest-region92 pass before an unrelated
  original synthetic-fit profile-boundary fixture error.
- dev05: corrected observed fit/overlap fixture11 and lazy correction-only scalar
  dependency4 pass, exit0. Original/reduced fit report/workspace values agree;
  duplicate current observed channels fail from recomputed overlap.

### Preserved failed attempts and fixes

load.log exit1 was a harness setup failure: the new-area Manifest copy was
skipped after namei reported a nonexistent destination under set-e. Copying the
existing approved Manifest (no install/resolve) yielded load2 exit0.
focused01:30 pass/2 failed because the test picked a shape companion rather than
the nominal table; corrected the test filename predicate. focused02:32 pass then
an empty-retained-weight sum error; fixed product accounting with explicit0.0
initial value. focused03:32+5 pass then18 pass/1 error because String(bytes)
consumed the corruption harness's restore buffer; fixed the harness with copy.
The original synthetic fit in dev04 failed boundary profile scanning before any
reduced fit existed; the closure fixture disables that unrelated optional scan.
oracle01/02 exit1 used uproot's unsupported RNTuple single-branch numpy return
path; oracle03 reads awkward then converts, with no product writer change.

## Initial PRE-FIX frozen snapshot

The initial runtime/source/config/Project bytes below are the same PRE-FIX snapshot.
Independent review subsequently found three P1 defects; these old runs are not
proof of their remediation. New review runs and digests are recorded separately.
Full regression runs in p9-skim/implementation. Focused/CLI/real/oracle runs use
an independently copied p9-skim/verification with identical hashes, so existing
batch lifecycle tests that temporarily mutate/restore launchers cannot interfere
with concurrent validators. No package installation or source relaxation occurs.

| Final evidence | Actual result |
|---|---|
| implementation/full-final.log and .exit | **53,753 pass, existing plotting skip1, exit0** |
| verification/focused-final.log and .exit | **245 pass, exit0** |
| verification/cli-final.log and .exit | **11 pass, exit0**, fresh CLI export then fresh CLI analysis with synthetic originals removed |
| verification/real-final.log and .exit | **30,805 pass, exit0**, bounded actual data/MC plus fresh two-worker batch and technical Asimov fit |
| verification/oracle-final.log and .exit | **206 independent uproot checks, exit0** |

Counts overlap; do not add them. Full per-area counts: audit55, batch508,
config202, corrections209, fit327, histograms28, IO62, objects23022,
pipeline2014, plotting191/skip1, reduced245, selection151, systematics26739.
Focused feature counts:34/5/24/7/5/63/92/11/4 in entry-file order.

Final bounded actual inputs: TT32,853 and MuonEG104,057 Events, retaining
1,493 and45 respectively. All57 output branches (including separate provenance
columns) are genuine RNTuple fields. Raw source-entry/type/byte comparisons47,363;
raw/scaled/member/templates **8,640 bins, edges and sumw2 bit-identical** between
original/reduced serial and reduced serial/fresh batch. Original signed Runs,
region yields, original cutflow evidence and fit/workspace values agree.
Reduced prefixes remain explicitly reduced-population values. Actual exposure
stays unknown; configured1210pb^-1 is unchanged. Production originals were never
renamed, modified or copied to Mac.

Frozen **369 source files** SHA256 (sorted per-file SHA256 list):
4b27278b85ace243f50c887f2cf6eee5b1e7421517f23442e58527f4fb0f5875.
Frozen **562 inputs** (src/test/bin/analyses/examples plus Project.toml):
aef245862471a93dc9e712461018319453999189346679ebe73fb21c8f5c7057.
Project.toml SHA256:
499b93fc8074a94caa877b242e8f6c684190d352d09c717417bf6fc734766ae4.
Existing gate-only Manifest.toml SHA256:
00ea56222e1348ebacf895819d7b07d41740e05b4a708ba7ae5e1d34e5e83119.

Mac and both gate copies match. implementation/final-{source,inputs}.{before,full}.sha256
and verification/final-{source,inputs}.{before,focused,real}.sha256 have identical
respective hashes. Tracked AND untracked whitespace was checked before tests;
source/tests/config/Project were not edited during or after these final runs.
Documentation/state updates after runs do not change that runtime snapshot.

The initial Mac SSH/exec wrapper reached its overall timeout while the same
remote full Julia process continued. Its PID/command/log were inspected; a
read-only completion watch collected that original job's real .exit0 and final
summaries/hashes. The full suite was NOT restarted or duplicated.

Exact final Julia invocations (project and script paths are absolute):

~~~sh
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n 10 bash /path/to/user/packages/rootplots-gate.sh --project=/path/to/user/analisis/Cascade_dev/p9-skim/implementation /path/to/user/analisis/Cascade_dev/p9-skim/implementation/test/runtests.jl
JULIA_THREADS=1 OPENBLAS_NUM_THREADS=1 nice -n 10 bash /path/to/user/packages/rootplots-gate.sh --project=/path/to/user/analisis/Cascade_dev/p9-skim/verification /path/to/user/analisis/Cascade_dev/p9-skim/verification/test/reduced/runtests.jl
JULIA_THREADS=1 OPENBLAS_NUM_THREADS=1 nice -n 10 bash /path/to/user/packages/rootplots-gate.sh --project=/path/to/user/analisis/Cascade_dev/p9-skim/verification /path/to/user/analisis/Cascade_dev/p9-skim/verification/cli-validate.jl
CASCADE_REDUCED_REAL=1 CASCADE_REDUCED_AREA=/path/to/user/analisis/Cascade_dev/p9-skim/verification/real-final JULIA_THREADS=1 OPENBLAS_NUM_THREADS=1 nice -n 10 bash /path/to/user/packages/rootplots-gate.sh --project=/path/to/user/analisis/Cascade_dev/p9-skim/verification /path/to/user/analisis/Cascade_dev/p9-skim/verification/test/reduced/test_real.jl
~~~

Each invocation redirects stdout/stderr to the named .log and writes its actual
shell status to .exit. The oracle uses the existing LCG110 setup and gate-only
validate-root-oracle.py against verification/real-final/bundle; it never writes
product files. All owned validation executions and completion watches ended.
Frozen p6/p7/p8 logs remain independent historical evidence.

## Discriminating scientific checks

Synthetic Jetpt[29,31,40,10], weights[2,-1,3,4], scaleUp1.1/Down0.9 retains
union[1,2,3]. Original Runs20, lumi100*xsec2 gives norm10, nominal/up/down yields
20/40/30 and sumw2 1000/1400/900. A zero-kept original file with denominator5
retains one separate output and total denominator25. Missing/malformed MC
normalization cannot fall back to retained genWeight; negative/true-zero and
zero aggregate semantics remain distinct.

Raw primitive tests cover Bool, signed/unsigned8/16/32/64, Float32/64, scalar and
jagged/all-empty lists, UInt64 adjacent IDs above2^53 and maximumUInt64, bitwise
negative zero and specific Float32/64 NaN payloads. Unsupported schemas, lengths,
offsets, counters, missing/explicitly dropped dependencies, conservative resource
limits, stale selection contracts, unsafe paths, claim contention, existing
outputs, duplicate derivations and damaged payload/sidecar bytes fail closed.

Certified data fixture uses aliased run/LS branches: original LS1=3pb^-1 and
LS2=7pb^-1, only LS2 retained, normalization coverage remains10 rather than7.
Original cutflows stay separate evidence; reduced all-event prefixes honestly
change. Original files are removed only for disposable synthetic fixtures,
followed by fresh-process batch/CLI reads; production inputs are never renamed.

## Boundaries

One original file/output, no shard denominator copies; conservative eager
limits, no arbitrary streaming/append/multitree support. Exact retained-population
compatibility is enforced; arbitrary changed cuts/shapes require re-export.
Original population identity is not collision/content deduplication, completeness
or measured luminosity. Manifest integrity is consistency, not hostile-producer
attestation. Original large input mutation detection remains identity/size/mtime.
Native ROOT RNTuple consumers must support the format; NanoAOD TTree tools are
not silently promised compatibility. Independent concrete implementation review
is separate from these runtime checks; final re-review acceptance is recorded below.

## Independent review remediation (final review snapshot, 2026-11-06)

1. Canonical original-population identity now prefers device/inode, not the
   entire provenance record containing alias-specific realpath. Persisted inode
   identity also rejects separately exported hardlink derivatives while original
   files are offline; fallback uses persisted canonical path without reopening.
2. Every downstream reduced stage binds persisted skim paths and signatures to
   current selected inputs/max-files before consumption or cached return. A full
   run refreshes skim first; workers use an explicit verified one-file scope.
   This does not promise automatic numerical refresh for arbitrary skipped steps.
3. Unsupported scientific subsets are rejected without pruning declarations.
   Every successful export validates generated TOML, fit references, staged input
   mappings, all reader schemas and retention contracts in a fresh Julia process
   before publication. Planned final paths are checked but never written through.

The metadata wire-hash helper is now in its own feature file. New focused tests
cover hardlinks/raw serial/export/batch, offline derivatives/distinct files, stale
A-to-B partial paths, unchanged reuse, sample/max-files scope, safe rebin/CL-only
updates, supported subsets, explicit theory/shape/fit references and publication
failure. Initial implementation/verification, phase1 and p6/p7/p8 remain frozen.

### New final-snapshot evidence

All five new final invocations completed with actual exit0. Source/test/config/
Project bytes were frozen after targeted03 and tracked AND untracked whitespace
checks, before launch. No runtime input edits followed. Separate copies isolate
full-suite launcher mutation tests from concurrent focused/CLI/real validators.

| New evidence under p9-skim | Actual result |
|---|---|
| review01/targeted03.log and .exit | **82 pass (18+46+18), exit0**, all three new remediation features |
| review01/full-review.log and .exit | **53,835 pass, existing plotting skip1, exit0** |
| review01-verification/focused-review.log and .exit | **327 pass, exit0** |
| review01-verification/cli-review.log and .exit | **11 pass, exit0**, fresh CLI export and original-offline fresh CLI analysis |
| review01-verification/real-review.log and .exit | **30,805 pass, exit0**, bounded actual data/MC, serial and fresh two-worker batch, technical Asimov fit |
| review01-verification/oracle-review.log and .exit | **206 independent uproot checks, exit0** |

Counts overlap, not additive. Full per-area counts are audit55, batch508,
config202, corrections209, fit327, histograms28, IO62, objects23022,
pipeline2014, plotting191/skip1, reduced327, selection151, systematics26739.
Focused features are34/5/24/7/5/63/92/11/4/18/46/18. Expected negative-path
CLI/fresh-validator stack traces appear inside passing testsets; no remediation
validation run failed. Earlier targeted01/02 are preserved development runs,
not substitutes for targeted03 or the frozen final runs.

New actual inputs remain exactly one TT file (32,853 Events) and one MuonEG
file (104,057 Events); retained1,493 and45. Again **47,363 raw source-entry/type/
byte comparisons** and **8,640 raw/scaled/member/template bins plus edges and
sumw2 bit-identical** for original/reduced serial and fresh two-worker batch.
Original signed Runs normalization, original cutflow evidence, region yields,
fit/workspace agree; reduced prefix cutflows remain separately labeled.
Configured1210pb^-1 remains, exposure unknown. Oracle independently recognizes
ROOT::RNTuple and verifies exported branches/source-entry/type/bytes/normalization
with uproot5.7.1. No C++ ROOT interoperability execution is claimed.

Final **376-source** digest:
91938a00172eae0e4a039be296f89277c4366c8fc8ebfbf58e2fc73fcd1f1926.
Final **573-runtime-input** digest (including Project.toml):
11e5404e0c77e63bf71cfb3b488195e4731fbdc8b7a41cb4cbd104e350ac7d0b.
Project and gate-only Manifest hashes remain the values recorded above.
Mac and BOTH gate copies match before/after; each copy's
review-{source,inputs}.{before,after}.sha256 records are identical.

Exact new invocations use the earlier absolute-path commands with
implementation replaced by review01, verification replaced by
review01-verification, and real-final replaced by real-review. Full threads2;
other validators1; worker count2 and worker threads1; OpenBLAS1. Every command
writes its actual status to the corresponding .exit. Oracle sources the existing
LCG110 setup and reads review01-verification/real-review/bundle only.
All owned jobs completed; no duplicate validation launch, historical restart,
install, staging/commit/push or Stage5 work. Documentation/state-only edits after
these runs do not change the frozen runtime snapshot. Final independent re-review
acceptance follows below, rather than being inferred from passing tests.

### Snapshot digest algorithm

Sort repository-relative paths in byte order (LC_ALL=C). For each regular file,
emit its standard SHA256SUM record: 64 lowercase hexadecimal SHA256 characters,
TWO ASCII spaces, the relative path, and a newline. Hash the concatenated record
stream with SHA256. Source snapshots include src files; runtime snapshots include
src/test/bin/analyses/examples plus Project.toml, with gate-only Manifest hashed
separately. This explicitly describes the record stream used for these snapshots,
not a different historical path-then-hash serialization.

## Final independent re-review and parent closure

Final read-only concrete re-review found no remaining material blocker for the
bounded Step4 RNTuple feature. All three P1 findings were resolved: physical
population ownership across aliases, current-inventory binding before partial
consumption/cache reuse, and mandatory fresh-process generated-config/schema/
retention validation before publication. Original scientific safeguards remained
intact. The reviewer independently reproduced both final snapshot digests; no
runtime jobs or writes were performed by that reviewer.

The parent independently inspected actual gate exit files, area counts and
bounded-data summaries, and checked every current source/input file in BOTH
review copies against the frozen SHA256SUM lists. No mismatches were found;
before/after/final record streams and current Mac files agree. Final parent
changes are documentation/state only, leaving tested runtime bytes unchanged.
Git records the local milestone commit. No push, dependency installation or
Stage5 work occurred. Stop for owner review; approval does not imply TTree
compatibility, arbitrary changed-selection reuse or physics certification.
