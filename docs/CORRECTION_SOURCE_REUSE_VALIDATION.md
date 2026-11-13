# Correction chunk source reuse

## Scope and lifetime

One framework-only step on the uncommitted 0.6.1/p11 checkpoint based on
9071405a6e81437c723e9a3d830c7038d15b0301. No benchmark/RDF adapter, scheduler,
DAG, persistent cache, normalization, version or analysis configuration change.
The pre-existing canonical-hash fix and other dirty files are not part of this
change.

Each uncached correction chunk creates a lazy source owner for the exact
built-in default/apply_corrections hook and unchanged built-in readers. Shape
corrections, nominal corrections and nominal-only theory members borrow the
same handle when they need source branches. Each BranchReader keeps its own
selected-row cache and forwards its original needed mask. No partial column
values or validation results are shared. Duplicates and differently ordered
shape/nominal row subsets remain in original source-entry alignment; reduced
inputs keep their local entry indexing. No shape x theory products are made.

The enclosing helper closes the owner in finally, on success or error; borrower
close never closes it. Closed owners cannot reopen. Data, flat/object/table-only
corrections and empty scalar/theory reads do not open the event source. Empty
scalar BranchReader reads now return empty Float64 vectors without a dependency
open, matching vector_members empty behavior. This global empty scalar contract
applies to every BranchReader path, including custom fallback and streaming
borrowed sources: missing branches and vector/jagged branch names are not
diagnosed for empty entries. Nonempty validation is unchanged.

Custom hook wrappers continue receiving source === nothing. Custom formats and
replaced built-in reader registries use historical per-reader lifecycles for
nonempty reads instead of silently receiving shared state. This is not a claim
of fully historical empty-read behavior; the global empty contract above applies
to these fallback paths too. Reduced-input pinning still rejects custom
hooks/readers where previously required. Reduced group chunks resolve their
physical shard through the existing group reader. The global stage-boundary
reduced inventory/manifest/checksum/extraction checks are unchanged and run
before cache returns. The correction code key now includes IO as well as its
previous areas, so changes to the new IO owner invalidate correction artifacts.
No cross-invocation trust cache was added.

## Environment and evidence

Authoritative source: Mac artifacts/Cascade.jl. Execution/output only on gate,
new isolated directory /path/to/user/analisis/Cascade_dev/framework-source-reuse.
Its absence and absence of a symlink were checked before creation. Historical
p6-p11 jobs and artifacts were not restarted or modified.

Julia 1.12.2 through /path/to/user/packages/rootplots-gate.sh, JULIA_THREADS=2,
OPENBLAS_NUM_THREADS=1. Absolute project and script paths are used because the
wrapper changes directory. The existing candidate03 p11 Manifest was copied,
not resolved/installed:

- Project.toml: b52613ed76a0bebb76dc03c4905c1afdc896311c72378c51707a0dcecd1ec8ad
- Manifest.toml: 00ea56222e1348ebacf895819d7b07d41740e05b4a708ba7ae5e1d34e5e83119
- wrapper: 7d8eca8a88229cde40f106cb8723b446abc75dbef341522884981c1deaddc23d

Gate evidence/ contains starting git status, original source/input lists, final
candidate before/after lists, parity-check logs and environment hashes. Records
use SHA256 + TWO spaces + relative path + LF. Runtime inputs include source,
tests, analyses, examples, bin, tools and Project.toml; the gate-only Manifest is
recorded separately. Docs and operational STATE are outside runtime lists.

- Starting source398 records: 9bc0c6fb3622381a1eb4d3d809b5610b26b3ab38538b0ca51d357256a0104c29
- Final source401 records: 60e661a8ddb7abec272d9100e1348c236a4456ff3c053e8e8750ed88fdb10c48
- Preceding runtime648 records: 949689475374e49528d6357607a56efb5f594dfe9861ae5478c25db1636af583
- Closure runtime648 records: a656324e42189e74956cdc78b611b36763b1b83c3ab9f13c2941d0951c5b240a

The final source has been unchanged since focused03. Later input-list revisions
only enabled the gated actual test include, optional profile selection and the
focused04 empty-fallback regression in the new tests, not production code.
Source and runtime checks match on Mac and gate before/after validation. Original selected-table files and native input
bytes are separately hashed in actual-reference, actual-combined and
native-inputs evidence records. Native hashes were captured after the initial
actual probes and checked again afterward; the earlier saved skims preserve
identity/size/mtime, not an earlier full-byte hash. No stronger before-probe
native-byte freeze is claimed.

## Commands

With p=/path/to/user/analisis/Cascade_dev/framework-source-reuse/project:

```sh
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 bash /path/to/user/packages/rootplots-gate.sh \
  --project="$p" "$p/test/source_reuse/runtests.jl"
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 bash /path/to/user/packages/rootplots-gate.sh \
  --project="$p" "$p/test/source_reuse/regression.jl"
```

Each execution preserves its own .log and actual .exit outside project/.
The regression runner covers IO, Systematics, Pipeline, schema1 reduced inputs
and schema2 streaming inputs, not the full suite or p11 integration.

## Results and limits

Final documentation/test-only closure: focused04 passed44 checks (23 ownership/
masks,16 correction/theory/no-source,5 stage/artifact/cache fallback), actual
exit0. Exact receipts are focused04.log and focused04.exit at the gate directory
above. Four added assertions pin the unborrowed empty BranchReader contract:
missing and vector-named scalar reads return empty Vector{Float64}; source open/
close counters remain0 before and after finally-close. No production code was
changed and no module/actual validation was rerun for this closure.

evidence/inputs-focused04.before freezes all648 runtime inputs, with
inputs-focused04-parity.before/after and source-focused04.before/after recording
matching gate checks; current Mac bytes match too. The only changed runtime file
relative to the preceding648 snapshot is test/source_reuse/test_source_reuse.jl;
protected existing inputs and Project/Manifest remain unchanged. Source401 keeps
the digest above. The earlier regression01 (29603) and actual03 (4) validate the
same unchanged production401, with the preceding test snapshots, not a claimed
rerun of the new empty-fallback assertions.

Independent concrete review reported no correctness blocker. It was read-only
static review, not a second runtime execution.

focused03 passed40 checks (19 ownership/masks,16 correction/theory/no-source,
5 stage/artifact/cache fallback), actual exit0. regression01 passed29603:
IO62, Systematics26739, Pipeline2014, schema1 reduced327, schema2 streaming461;
actual exit0. These are relevant module regressions, not the full suite. They
cover shape migration, nominal/scalar/member weights, signed denominators,
primitive bytes, reduced checksum/completeness/pinning, cached partial-stage
binding and extraction contracts. Total regression wall time was about35m29s.
A separate read-only wait transport timed out after1200s; the original process
was inspected and retained, not retried, then completed normally. No validation
job remains running. Initial focused01 was retained with exit1:
a new no-source flat test omitted required up/down configuration. It was a test
fixture error, corrected without a production workaround. focused02 passed35
checks, actual exit0, on the preceding candidate. Final source changes add the
testable finally helper and stronger concurrency/error tests.

Initial bounded actual01 passed4 checks, exit0, using the already completed
p10 review02 actual01/original selection tables, read-only. TT source32853 events
has1493 nominal rows; data104057 has45. Current fixture has one nominal table per
sample (shape behavior is synthetic/module-regression tested). Old-style and
shared nominal/theory weights were bit-identical. One warmed observation
was TT0.218736169s old /0.114909866s shared; data0.000056537s /0.000065797s.
Final-source actual02 also passed4, exit0: TT0.114331694s old /0.289254085s
shared, data0.000053002s /0.000047270s. This reversal demonstrates that the single
warm observations are noisy, not a performance guarantee. This profile disables
SFs/shapes, so it establishes actual nominal/theory parity only. Combined actual
SF/scalar/shape/theory parity is tested separately against read-only case02
selection tables. actual03 passed4, actual exit0, using integration_small only
for direct correction calls: TT5 tables (JES/JER Up/Down plus nominal),1487
nominal rows and data1 table/45 rows. All nominal/scalar/SF/theory/shape weight
columns match bit-for-bit. Warm TT correction time was0.375557990s old versus
0.243957764s shared; data0.000281823s versus0.000233190s. This did not rerun or
complete the stopped p11 pipeline and makes no acceptance claim for it. No
full-dataset throughput or RDF comparison is claimed.

Structural counting tests compare three independent masked readers (3 opens,
3 closes) against one lazy shared owner (1 open,1 close), including out-of-order
and duplicate row subsets. Artifacts and histograms are compared against a custom
wrapper that forces the old stage behavior. No full-data run, full p11 closure,
all-sample integration, package installation, commit or push is claimed.
