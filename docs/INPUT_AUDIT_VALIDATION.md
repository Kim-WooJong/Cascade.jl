# Input audit / sample provenance: Step 1 validation

Date: 2026-11-05. Base commit `580578d`; feature version 0.2.0.
Scope: **Step 1 only** of the owner-approved sequence. Theory-vector weights,
batch execution, reduced skims and deployment work were not started. Stop for
owner review after this change.

## Delivered

- Separate `cascade audit` command and `Cascade.Audit` API; fresh inventory and
  metadata inspection with JSON/Markdown reports, including failed checks.
- Per-pattern discovery, missing/unmatched inputs, path/realpath/device-inode
  identity, aliases, shared-sample files and all independent source failures.
- Optional sample declarations and expected path/count/event/signed-sum contracts
  in the single analysis TOML; provenance is not invented or endorsed.
- IO normalization inspection distinguishes missing metadata from true zero,
  validates scalar finite Runs entries, and preserves existing reduction order.
- Complete/partial totals and explicit unknown inventory/exposure states.
- Declared sample metadata retained in merge output, without changing weights.
- No audit cache, input rewriting, event-ID deduplication, physics calibration,
  or changes to normal analysis selection/normalization semantics.

Usage and schema: [INPUT_AUDIT.md](INPUT_AUDIT.md), [CONFIG.md](CONFIG.md),
`analyses/TEMPLATE.toml`.

## Full regression suite

Gate scratch `~/analisis/Cascade_dev/p6-audit`, `full-suite.log` and
`full-suite.exit`: **exit0, 51050 passed, one existing skipped assertion**.
The skip is the preexisting plotting real-data guard with real-data mode off.

| Area | Pass |
|---|---:|
| audit | 50 |
| config | 202 |
| corrections | 209 |
| fit | 327 |
| histograms | 28 |
| IO | 62 |
| objects | 23022 |
| pipeline | 250 |
| plotting | 191 |
| selection | 151 |
| systematics | 26558 |

Command: `JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n 10 bash
~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/runtests.jl"`.
Execution uses Julia release 1.12.2 and the established gate environment.

This suite snapshot predates the final expected-path error/report formatting
and identity-fingerprint refinements. The affected audit area, new metadata
cache test and ROOT negative fixtures were exercised separately afterward;
counts below overlap and must not be added to the full-suite total.

## Focused checks

`final-targeted.log` / `final-targeted.exit`: **144 passed, exit0**:

- normalization provenance/invalid/signed/overflow cases: 21;
- tiny actual ROOT headers/Runs, missing tree/branch, vector/bool/nonfinite
  values and configured tree/branch aliases: 29;
- optional Config annotation schema and invalid types/keys: 16;
- inventory/identity/expected contracts/failure reports: 34;
- signed/partial sums, input mutation, data N/A, no-Events custom source: 19;
- existing CLI parsing regressions: 15;
- declared metadata passthrough and cache-local update behavior: 10.

The metadata-only custom source throws if Events columns are read. A metadata
edit keeps skim/select/correct/histogram cached, updates merge metadata, and
leaves histogram contents identical. Wrong expected file identities with an
unchanged count fail. Missing source files do not prevent reports or examination
of other files. Negative sums remain signed; zero files are distinguished from
zero aggregate normalization.

The initial native ROOT fixture writer stalled in CVMFS I/O and was terminated.
Nine tiny TTrees were instead generated in an isolated gate-only uproot test
fixture environment; all reading/checking remained Julia. This adds no Python
runtime or package dependency to Cascade.

Final frozen audit-only regression: **55 passed, exit0**
(`frozen-audit-tests.log` / `.exit`), covering the final expected-path failure,
physical-identity fingerprints, report escaping/formatting, and existing audit
failure cases. Source SHA256 verified equal on Mac/gate over321 Julia files:
`79d78a620ecdf9c2b1602b8f9a356b1168d989c094a989875a2e20f008119068`
(sorted relative path + NUL + contents + NUL). Final frozen inventory CLI also exited0, errors0/warnings0/unknown61
(`frozen-inventory.log` / `.exit`, `out_inventory_frozen/audit/`). The coordinator
read back JSON/Markdown, confirmed all3307 file identities, event counts and
normalization records match the independently verified first report, and
confirmed the declared-provenance table exists. Actual exposure remains unknown.

## Actual full inventory and bounded numerical equivalence

Fresh real audit: **13 samples / 3307 files / 1,027,230,612 Events entries**.
CLI **exit0**, errors0, warnings0, unknown61. Unknowns are undeclared dataset,
era/campaign/cross-section references and expected file inventories. There is
no authoritative completeness claim; actual exposure remains unknown.

The audit's file order, per-file event counts and signed MC Runs sums were
compared against the prior frozen Phase-5 full inventory. Every file matched.
No one-billion-event selection rerun was launched.

Independently archived `580578d` and new code each ran the same first file per
sample through skim/select/correct/histogram/merge in isolated workdirs:

- **13 ROOT files / 2,200,037 input events**, both pipelines exit0;
- identical file identities, sample counts/events, generator sums, normalization
  factors, region yields, sequential cutflows and canonical/legacy yield fields;
- **7332 raw/scaled histogram bins** (plus edges and sumw2) compared by Float64
  bit patterns: **zero differences**;
- configured luminosity retained and subset exposure explicitly unknown.

`real-verification.log` / `.exit`: **10837 passed, exit0**.
Structured summary: `p6-audit/real-verification.json`.
Reference workdir: `p6-audit-reference/out_bounded`; new: `p6-audit/out_bounded`.
The metadata audit/report refinements after these runs do not change the
selection, weight calculation or merge normalization used in that comparison.

## Review and limits

Design and failure-mode reviews were completed before implementation. Attempts
to obtain delegated implementation/concrete-diff review failed authentication
before any implementation work began. Main implemented the change and executed
the validations above; **an independent post-implementation review was not
completed**. This limitation is explicit for the owner's step review.

A first test incorrectly expected ArgumentError rather than the existing
sample lookup API's documented KeyError; corrected to the established contract.
No source change to lookup behavior was made.

Passing this audit does not certify physical dataset completeness, common
trigger-stream exposure, xsec validity, calibration correctness, event-ID
uniqueness or copied-content identity. Config declarations and file signatures
are provenance, not measured physics. Audit reports/paths are internal runtime
artifacts. No push or external publication.
