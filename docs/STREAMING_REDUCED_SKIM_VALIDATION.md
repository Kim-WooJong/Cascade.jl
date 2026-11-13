# Streaming reduced skim validation

## Authority, environment and scope

Owner correction 2026-11-06 at08:37 authorized continued Step4 streaming and
automatic splitting, not Stage5. Parent accepted schema2 logical-source ledger
plus bounded physical-shard tasks. Source/docs only on Mac; all Julia execution,
inputs, ROOT files, logs/results on gate under p10-stream-skim. No installs,
product Python/C++ bridge, staging/commit/push, scheduler/service changes or
historical3307-file audit/10^9-event restart. Existing p6/p7/p8/p9 are frozen.

Julia1.12.2, installed UnROOT0.11.11 and existing approved Manifest are used via
/path/to/user/packages/rootplots-gate.sh with ABSOLUTE project AND script paths.
Full synthetic threads2; other validators1; batch workers2/threads1; OpenBLAS1.
Existing LCG110 Python uproot5.7.1 is an independent validation/fixture oracle
only. Product runtime is Julia. Original production inputs are never renamed or
written. Source-offline tests remove/rename only disposable generated fixtures.

## Phase1 (frozen feasibility, not feature completion)

p10-stream-skim/phase1/window01:363 typed/range/oracle +196 lifetime checks, exit0.
native-header01:20, shard03:20, shard-fresh:7, shard-oracle:37, all actual exit0.
Fixture-large has1100017 Events but only3296285 encoded bytes: NOT >256MB proof.
Read first/middle/last/basket-boundary windows of that fixture and two existing
production data/MC files. Native ranges and direct basket reads match independent
uproot raw bytes/types; exact requested spans, empty branch buffers and zero
surviving prior-window arrays demonstrate the bounded IO path.

Preserved harness failures: shard01 exit1 lacked private Shape qualification;
shard02 exit0 executed an EMPTY script after sed failed and is explicitly NOT
validation evidence. Corrected nonempty shard03 passed. No evidence was overwritten.

## Implementation development runs (not final-snapshot evidence)

All paths below are p10-stream-skim/implementation; counts overlap.
- smoke01 failed on an empty typed jagged cols-window constructor. Fixed the
  explicit list element type; smoke02:12 pass/exit0.
- focused01:94 pass/exit0. extras01:42 pass/exit0. Additional primitive, actual
  header/map, original shape-cutflow, atomic/concurrent and normalization guards
  were added afterward; these old counts are not final coverage.
- focused02:347 pass/exit0; partial01:46 pass/exit0. Combined final source test
  entry includes both, but actual final counts must come from its new log.
- legacy01:327 pass/exit0, explicit schema1 eager export/regressions under0.6.
- cli01:16 pass/exit0; native01:9+27+4 pass/exit0. Native proof includes fixed16-byte
  predecode rejection, frozen actual0.5 schema1 readers, ROOT Runs20 + zero-kept5,
  missing/nonfinite/negative/true-zero/empty source and aliased original LS3+7.
- actual01:45681 pass/exit0. Two original files TT32853 + MuonEG104057 Events ->
 1493 +45 retained, six physical shards.47363 raw branch/event source-entry/type/
 byte comparisons.8640 histogram/member/template bins plus edges/sumw2 checked.
 Max absolute histogram difference2.738088369369507e-7; max contribution-scaled
 difference2.8015576640788982e-14, below PREDEFINED2.5579538487363607e-13 bound.
 Technical Asimov fit differences: POI0, error8.326672684688674e-17,
 NLL1.4210854715202004e-14. Same new serial/batch partition is bit-identical.
 Configured1210pb^-1 retained; actual exposure remains unknown.
- large01:30 pass/exit0, entire native small/large sources, not a few-window probe.
 Large source is362554005 encoded bytes AND1100017 Events, fully processed111
 windows ->715011 rows/eight shards. Small source36328422bytes/110017 Events ->
 71511 rows/one shard in12 windows. Production whole-source Events read APIs are
 disabled to throw inside this export harness. Source-offline fresh CLI serial
 and fresh two-worker batch agree bitwise for their identical new partition.
- large-oracle01:2070 independent checks/exit0,58202628 raw branch/event byte
 comparisons, including random Float32 bit patterns/NaNs, UInt64 IDs, jagged lists,
 counters, all fields, complete sparse selection membership/order and Runs20.
 Analytic original-source shape/member sums and sumw2 match product output.

Development complete-export metrics at fixed settings window10000/payload32MB:
| Metric |110017 Events|1100017 Events|
|---|---:|---:|
| Max raw live window bytes |3436772|3436772|
| Max shard payload bytes |24599800|31999928|
| Max shard events |71511|93023|
| Peak declared decoded basket bytes |200008|200008|
| Basket requests |888|8214|
| Surviving previous window caches |0|0|
| Warm post-GC live heap extrema |72700128..91611080|61286784..100195888|

These are not OS memory reservations. The development harness recorded peak RSS;
final harness additionally records current /proc RSS. Whole-file virtual mmap,
resident pages, compilation/allocator/native buffers add memory. Metadata grows
with basket indexes/shards/unique LS, not all-source selected event arrays.

## Discriminating numerical and scientific contracts

Synthetic ROOT Runs20 and zero-retained Runs5 are logical-source evidence once,
not copied shard denominators or first-shard/zero-nonowner accounting. With A only,
norm10 gives nominal/up/down yields20/40/30 and sumw2 1000/1400/900. Including B,
norm8 gives16/32/24 and640/896/576. Missing/malformed original normalization
fails; negative/true-zero remain available, zero aggregate MC fails.

Per-variation original cutflows update persistent accumulators in original event
order; nominal-JER/JES/MET/clean/sort/earliest-region tests compare full original
cutflows and exact union entries. Reduced prefix populations remain separately
reported. Certified original LS1=3 and LS2=7 stays10 when only LS2 is retained;
coverage/cutflow evidence is once per logical group. Current observed fit overlap
is recomputed; zero-weight/multivalue/flow behavior is not weakened.

Primitive tests cover Bool, signed/unsigned8/16/32/64, Float32/64, UInt64 above2^53
and maximum, scalar/jagged/all-empty rows across windows/shards, negative-zero
and specific NaN payload bits. Lazy correction-only scalar and absolute vector
reference values differ by window and remain correct. Exact row/byte minus1,
at and plus1 boundaries, oversized rows/baskets, empty sources and source drift
are discriminators, not nominal-only round trips.

Actual histogram tolerance is predefined, not posthoc:64eps(Float64)*ceil(log2(N))
times a contribution-scale upper bound. Sumw uses max(1,sqrt(N*sumw2)); sumw2 uses
max(1,abs(reference),abs(candidate)). Fit scalar outputs use rtol1e-9/atol1e-8;
region numerical yields use rtol1e-11/atol1e-9. Same new serial/batch stores and
technical POI are checked bitwise. Never claim universal old/new partition bits.
The cancellation discriminator [1e16,1,-1e16,1] has BigFloat truth2, legacy1 and
new two-event-shard result0: absolute error2 but contribution-scaled1e-16. This
is reported explicitly, not hidden behind a near-zero relative tolerance.

Completeness, copied/hardlink ownership, stale A-to-B partial stages/direct APIs,
logical max-files, safe bin/CL-only reuse, custom hooks/readers, unsupported
scientific subsets, intermediate shard/sidecar/fresh-validator failures, active
competing-process claim, unchanged prior outputs and immutable fixture bytes
are checked. Worker scope cannot authorize global normalization even if its
caller supplies a misleading step label.

## Final frozen-snapshot validation

Final runtime/source/test/config/Project bytes were frozen after tracked AND
untracked whitespace checks, before launching any final run. Full-suite source
is p10-stream-skim/full-final; concurrent validators use the independently copied
p10-stream-skim/verification. No runtime inputs changed during or after these runs.
The earlier prelaunch input list was retained as a draft when two exact actual
entry-union assertions were added BEFORE final execution; only the digest below
belongs to the final executed input snapshot.

| New final evidence (.log and actual .exit) | Actual result |
|---|---|
| full-final/full-final | **54228 pass, existing plotting skip1, exit0** |
| verification/focused-final | **393 pass, exit0** |
| verification/cli-final | **16 pass, exit0**, fresh export and original-offline fresh CLI |
| verification/native-final | **59 pass (9+27+4+19), exit0** |
| verification/actual-final | **45683 pass, exit0**, exact original entry union and fresh two-worker batch |
| verification/actual-oracle-final | **670 independent uproot checks, exit0** |
| verification/large-final | **30 pass, exit0**, entire small/large originals and source-offline fresh serial/batch |
| verification/large-oracle-final | **2070 independent uproot checks, exit0** |

Scopes overlap, do not sum these rows. Full per-area: audit55, batch508,
config202, corrections209, fit327, histograms28, IO62, objects23022,
pipeline2014, plotting191/skip1, legacy reduced327, selection151,
streaming393, systematics26739. Focused streaming features in entry order:
40/22/21/7/5/22/6/17/11/181/15/46 (gated actual file adds no synthetic tests).
All negative-path stack traces are expected passing assertions; no final run
failed or was restarted. All owned jobs ended.

### Final actual physics-closure scope

Two bounded original production files only: TT32853 + MuonEG104057 Events,
retained1493 +45, physical shards5+1.47363 raw source-entry/type/byte comparisons,
exact original nominal/all-applicable-shape keep-entry union and original cutflow
evidence pass. Independent uproot670 checks verify actual ROOT::RNTuple fields,
primitive/jagged types/counters/bytes, source entries/order and signed original
Runs normalization, with the same47363 branch/event comparisons.

8640 original/new histogram/member/template bins plus edges/sumw2 were checked
under the bound declared above. Max absolute difference2.738088369369507e-7;
max contribution-scaled difference2.8015576640788982e-14 versus allowed
2.5579538487363607e-13. Technical Asimov POI difference0, error difference
8.326672684688674e-17, NLL difference1.4210854715202004e-14. Identical NEW physical
partition serial/fresh batch stores and POI are bit-identical. Configured1210pb^-1
and unknown exposure remain; no physics luminosity/completeness claim is added.

### Final entire large-source and memory proof

Independent fixture is a real TTree,362554005 bytes AND1100017 Events, not padding
outside the tree or a few-window probe. All74 raw fields, including64 random
Float32 bit-pattern branches, are included. Whole-source legacy Events APIs are
disabled to throw in the export process.111 complete windows produce715011 rows
in eight genuine RNTuples. Original input bytes are checked unchanged after
source-offline fresh CLI serial plus fresh two-worker batch. The small10x source
is36328422bytes/110017 Events, fully processed12 windows to71511 rows/one shard.
Independent uproot2070 checks cover ALL declared fields and sparse membership/
order over both sources:58202628 raw branch/event byte comparisons. Analytic
nominal/up/down and absolute-vector member sums/sumw2 match exactly.

| Final measured quantity | Small110017 | Large1100017 |
|---|---:|---:|
| Max live raw window bytes |3436772|3436772|
| Max window rows |10000|10000|
| Max shard bytes |24599800|31999928|
| Max shard rows |71511|93023|
| Peak decoded basket bytes |200008|200008|
| Basket requests |888|8214|
| Surviving previous window caches |0|0|
| Warm post-GC heap bytes |72891864..91802720|64604944..103515360|
| Warm current RSS KiB |1020696..1063260|1037300..1423328|
| Process peak RSS KiB |1070712|1545432|

Warm samples omit the first four windows. These figures explicitly show that
mapped-page/allocator/compiler RSS is not the3.44MB raw window or a fixed budget
reservation. The product's conservative peak buffer estimate was632188352bytes
for both sources. Window/shard arrays are bounded; total mapped pages/metadata/
runtime memory have the limitations already documented.

A separate product-window allocation/lifetime test reads three10000-row windows
(first/middle/tail after warmup) on these10x source sizes, with whole-source
Events APIs still forbidden. Small allocations51431856..51600416bytes; large
51667472..51836032bytes. Both raw live windows3436772bytes, zero surviving past
cache dictionaries, post-GC heaps about67.3/70.2MB. The PREDEFINED discriminator
large_max <=2*small_max +1000000 passes; full-source-then-slice is not used.
Native allocation inputs are separate read-only copies from the large export's
renamed disposable fixture, avoiding a concurrent source-offline/read race.

### Frozen bytes and exact execution

**393 source files** SHA256:
8dd739306c44800cf4a482b72564d9681c728450445c735881177173b0c7ece2.
**604 runtime inputs INCLUDING Project.toml** SHA256:
5592cbf29f41cf0f2ccc0b61f6123a243f9a96d371daa90b98aec591791e9561.
Project.toml SHA256:
3eca8e3e64dd5fba81d8291c6507d15715504d336fbb32f1e0319c09fd1e3dab.
Existing gate-only Manifest SHA256 (unchanged, no resolve/install):
00ea56222e1348ebacf895819d7b07d41740e05b4a708ba7ae5e1d34e5e83119.

Mac and both gate copies match. Each copy's final-{source,inputs}.{before,after}
SHA256SUM lists agree. verification/final-fixtures.{before,after} and
final-native-inputs.{before,after} match; final-harness.{before,after} match too.
The independent actual oracle's script hash is recorded separately after its
creation/run. Docs/state-only edits after tests do not alter runtime digests.

All invocations use this exact pattern, capturing stdout/stderr and REAL status:
~~~sh
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n10 bash /path/to/user/packages/rootplots-gate.sh --project=/path/to/user/analisis/Cascade_dev/p10-stream-skim/full-final /path/to/user/analisis/Cascade_dev/p10-stream-skim/full-final/test/runtests.jl > /path/to/user/analisis/Cascade_dev/p10-stream-skim/full-final/full-final.log 2>&1
rc=$?; printf '%s\n' "$rc" > /path/to/user/analisis/Cascade_dev/p10-stream-skim/full-final/full-final.exit
~~~
Other final Julia runs use JULIA_THREADS=1, absolute verification project and
absolute scripts test/streaming/runtests.jl, cli-stream-validate.jl,
native-validate.jl, large-final-validate.jl and test/streaming/test_actual.jl.
Actual uses CASCADE_STREAM_REAL=1 and CASCADE_STREAM_AREA=absolute
verification/actual-final. Large harness uses verification/large-final. Existing
LCG110 setup supplies Python for large-oracle.py and actual-oracle.py only.
All logs/exits and numerical summaries stay on gate; old evidence is untouched.

This earlier snapshot was runtime-validated before independent concrete review.
Review and the separate remediated snapshot are recorded below.

Snapshot algorithm: byte-sort repository-relative paths (LC_ALL=C). Emit each
standard SHA256SUM record: HASH, TWO ASCII spaces, relative/path, LF. SHA256 the
concatenated record stream. Source scope is src; runtime scope is src/test/bin/
analyses/examples plus Project.toml. Gate-only approved Manifest is hashed
separately; no resolve/install is performed.

## Independent review P1 remediation (new frozen snapshot, validation complete)

Review6d57c4c0 accepted the scientific/window/ledger/sharding contracts but found
that eager cols payload allocation happened before its compatibility limits.
The original frozen results above do NOT validate the subsequent remediation.

An export-only same-handle opener now checks file size before parsing and caps
header bytes, validates descriptors/types/nonnegative integral counts, uses
Int128 arithmetic and verifies actual payload availability before allocation.
Jagged offsets and Bool bytes are checked with fixed-size workspaces first.
Streaming and legacy exports both use it; legacy correction/theory reads borrow
the already-validated cols source. Generic serial cols IO and native ROOT window
logic are unchanged. One function/feature per source file is preserved.

New test coverage includes a sparse256000001-byte invalid input, tiny headers
declaring typemax(Int) rows/content, truncated million-row payloads, malformed
types/counts/schema/offsets/Bool/header sizes, bounded warmed rejection allocations,
both export entrypoints with no final/staging publication, and valid typed exports.
All Julia runs/fixtures/logs remain on gate. review01 is development evidence
(its initial tar transfer included AppleDouble metadata); review02 is the clean
Mac-matching frozen snapshot. Original full-final/verification evidence is untouched.
Clean review02 snapshot:398 source files SHA256
**aade1746c7c195e41b5a3ba1b82441b4fb82eb9e6f561ae0d1f3b45f0caafdbe**;
610 runtime inputs SHA256
**2d23b83ddcaf98b0ed3c07fb22b37afb214b0ae09bed89a9a7dafceece6b9b38**.
Project.toml and approved gate Manifest hashes remain as recorded above.

Completed review02 runs (each corresponding .log/.exit on gate; counts overlap):
- full01:54296 pass/existing plotting skip1/actual exit0; all14 areas completed.
- focused01:461 pass/exit0, including68 new cols preflight/atomic-validity checks.
- legacy01:327 pass/exit0, including schema1 export/theory/shape regressions.
- cli01:16 pass/exit0, fresh CLI export and original-offline analysis.
- native01:59 pass/exit0, real TTree/legacy byte-reader/normalization/LS guards
  and renewed10x-source window allocation/lifetime discrimination.
- no-reopen01:4 pass/exit0; generic read_column_file is redefined to throw in this
  separate process, and both exporters still succeed with theory/shape weights.
- actual01:45683 pass/exit0; fresh original/reduced serial/two-worker batch and
  technical Asimov fit. TT32853→1493 rows/five shards, data104057→45/one shard.
 47363 raw branch/event comparisons,8640 histogram bins. Max contribution-scaled
 difference2.8015576640788982e-14 vs2.5579538487363607e-13 predefined bound;
 POI difference0, error8.326672684688674e-17, NLL1.4210854715202004e-14.

Renewed native allocation ranges: small51431824..51600384bytes,
large51667440..51836000bytes; live raw window3436772bytes for both;
post-GC heaps67450536..67532264 and70451144..70452344bytes. The predefined
large_max<=2*small_max+1000000 discriminator passes; previous cache dictionaries
are not retained. The earlier entire large-source715011-row export/oracle is
historical frozen-snapshot evidence, NOT rerun evidence for these edits.

Independent actual-oracle:670 pass/exit0,47363 raw branch/event comparisons,
uproot5.7.1. actual01/oracle-summary.json and the Julia summary.json preserve
numerical evidence separately. The full suite's expected invalid-generated-fit
child errors are rejection tests, not suite failures; full01.exit is0.

The first launcher/watcher exceeded its tool timeout; inspection verified the
original remote suite/exit collector remained active, so no successful/running
job was restarted. A subsequent wait also exceeded its deadline. The original
full suite completed and its retained remote collector wrote actual exit0;
completion was then retrieved, not inferred from a timeout or running status.
The independent oracle had not started through the expired watcher, so it was
run once after checking its log/exit were absent. All owned Julia jobs have ended.

review02 snapshot-{source,inputs}.{before,after} compare byte-identically and
match the current Mac398/610 digests above. Project/Manifest remain unchanged.
native-fixtures.{before,after} agree with SHA256
b05093ea54b89f843b391832980390256a25569fd986e0dc75205ef1f3676da8.
harness.before and additional-harness.before checksums all revalidate, including
the no-reopen and independent oracle scripts. Tracked AND untracked whitespace
checks pass on Mac. Documentation/state changes after tests do not alter the
runtime snapshot. No source/test/config edits occurred while these jobs ran.

Exact review02 commands use the launcher pattern above with absolute project
/path/to/user/analisis/Cascade_dev/p10-stream-skim/review02. full01 uses threads2
and test/runtests.jl. All others use threads1 and focused01.jl, legacy01.jl,
cli-stream-validate.jl, native-validate.jl, no-reopen01.jl or
CASCADE_STREAM_REAL=1 CASCADE_STREAM_AREA=absolute review02/actual01 with
absolute test/streaming/test_actual.jl. OPENBLAS_NUM_THREADS=1 and nice -n10 remain.
Each wrapper writes the REAL command status to its corresponding .exit.
The existing LCG110 setup supplies Python only for actual-oracle.py.
full-summary.json and completed-summary.json provide machine-readable counts. Original large/full-final
and verification evidence is preserved. No dependencies were installed.

Independent bounded read-only re-review found the P1 resolved with no remaining
material blocker. It checked preparse rejection, bounded header/count/byte/offset/
Bool validation, same-handle materialization and both export modes, and independently
reproduced the current398-source/610-input digests. No reviewer runtime rerun occurred.
Parent separately verified every review02 actual exit, per-area totals (54296 pass,
existing skip1), focused/legacy/CLI/native/no-reopen/actual/oracle logs and numerical
summaries. Each current source/input file matches the unchanged before/after lists
and Mac. The original large-source evidence remains explicitly earlier-snapshot
proof, not a rerun of these edits. The supported Step4 refinement is accepted;
final closure edits are docs/state only, followed by a local milestone commit.
No deployment, package installation, remote push or Stage5 is authorized.
An incorrectly delimited optional no-reopen00.invalid harness was preserved and
never executed; corrected nonempty no-reopen01 is the passing run above.

## Limits and interpretation

Genuine single-cluster RNTuple shards, not TTree output, append or multicluster.
Conservative physical bounds remain64MB typed payload/1M rows/256 columns and
encoded <256MB. Window/basket/buffer/metadata budgets and unsupported/recovered
basket layouts can fail clearly with no final publication. cols is bounded eager
compatibility, not streaming. No fixed RSS/arbitrary metadata-size claim.
Trusted local POSIX filesystem only: no hostile replacement/NFS/multihost/fsync
promise. Checksums prove consistency, not malicious-producer authenticity.
Original input drift detection is identity/size/mtime, not full content hashing.
0.5 byte reader compatibility does not rewrite old semantic/code fingerprints.
ROOT>=6.34 interoperability is upstream-documented; independent executed proof
is uproot5.7.1, not C++ ROOT. Independent concrete/re-review and parent runtime
verification are complete for the bounded scope. Stage5 remains unauthorized.
