# Input audit and sample provenance

`cascade audit` inspects input inventory and source normalization metadata before
analysis. It is read-only with respect to inputs, independently reruns on every
invocation, and does not modify selection, weights, skims or histogram caches.
A **pass** means no hard operational errors were found. It is **not** a physics
readiness certificate or evidence of an authoritative complete dataset.

## Running

```sh
cascade audit analyses/ttbar_emu/analysis.toml --profile baseline --workdir audit_run
cascade audit analysis.toml --samples signal,data --workdir audit_run
```

Outputs: `audit_run/audit/report.json` and `audit_run/audit/report.md`.
Exit status is 1 when audit errors exist, **after writing the reports**; 0 means
no errors, even if warnings or unknowns remain. Syntax/configuration failures
may occur before an audit can begin and therefore before reports exist.
`--max-files`, pipeline step switches and `--force` are deliberately unsupported:
audit always inspects every discovered file of the selected samples and uses no
cache. `--samples` limits source reads; cheap inventories of all configured
samples still participate in cross-sample physical-file overlap checks.

Reports record paths and local provenance and should be treated as internal
artifacts. Source code remains local; run outputs belong in the execution host.

## One TOML: optional sample annotations

The normal sample fields keep their existing meanings and defaults. These two
optional nested tables add declarations and explicit audit expectations:

```toml
[[samples]]
name = "signal"
kind = "mc"
format = "nanoaod"
files = ["${input}/signal/*.root"]
xsec_pb = 2.0
branching_ratio = 0.5

[samples.metadata]
dataset = "/Primary/Processed/NANOAODSIM"
era = "2022"
campaign = "Summer22"
xsec_source = "reference identifier or URL"
xsec_note = "inclusive cross section; branching_ratio is separate"
branching_ratio_source = "reference identifier"
provenance = "input production description"

[samples.audit]
expected_nfiles = 2
expected_nevents = 123456
expected_sumw = -1200.5
sumw_rtol = 1e-8
sumw_atol = 0.0
expected_files = ["${input}/signal/a.root", "${input}/signal/b.root"]
inventory_source = "authoritative catalog/version identifier"
```

Every annotation is optional. Missing metadata is **unspecified**, never guessed
from filenames. Supplied metadata values must be nonempty strings. Counts must
be nonnegative integers; expected sums finite signed numbers; tolerances finite
and nonnegative. `expected_files` are literal paths, not globs, resolved relative
to the analysis TOML, with the usual `[paths]`/`${ENV:NAME}` substitutions.

Inventory equality means equality with those **declared paths**, not independent
verification that the declaration is complete. Expected counts alone establish
only count agreement: an absent file replaced by another file can have the same
count. Exact file identity therefore remains unknown unless `expected_files`
is supplied. `inventory_source` documents the user's catalog provenance; it is
not fetched or endorsed automatically.

Sample metadata also passes through into `merge/samples.json` for traceability.
It does not change the normalization formula or weight factors.

## Checks and severity

| Observation | Outcome |
|---|---|
| Unmatched configured glob, missing literal/directory, source open/read failure | Error; continue examining other files |
| Declared file set, file count, event count or signed sum disagrees | Error |
| Same path matched repeatedly by patterns | Warning; existing production expansion counts that identical path once |
| Distinct production paths alias the same realpath/device-inode | Error; audit does not silently rewrite/deduplicate production inputs |
| Physical input shared between samples | Error; report every owner |
| MC normalization tree/branch unavailable or nonfinite/nonscalar values | Error |
| Zero aggregate MC generator sum | Error: normalization undefined |
| Zero sum in one file but nonzero sample total | Warning, not automatic sample rejection |
| Finite negative MC generator sum | Valid signed sum; never replaced by its absolute value |
| No declared metadata or expected inventory | Unknown, not an operational error |
| Custom source without normalization inspection support | Unknown normalization provenance, not fabricated as verified |
| Data generator normalization | Not applicable |
| Input size/mtime changes during metadata reading | Error; complete totals withheld |

All source failures are retained, not only the first failure. Reports distinguish
files discovered, attempts to open existing paths, readable files, complete
totals and partial successful-file totals. Full expected event/sum comparisons
become **unknown**, not a mismatch, when the measured total is incomplete.
Signed sum agreement uses `abs(observed-expected) <= atol + rtol*abs(expected)`.

## Source and exposure boundaries

For NanoAOD, the audit reads the Events entry count and configured Runs branch,
validates each scalar Runs value, and preserves the established reduction.
It does not read Events columns or compare skimmed event weights to full Runs
sums. Missing Runs is distinct from an available zero sum. Reader aliases in
`samples.source` are honored. For `.cols`, metadata sums take precedence;
otherwise the configured generator column is summed sequentially. Column-file
sources materialize their contents, so their I/O is not ROOT-header-only.

A custom `AbstractEventSource` may implement `IO.normalization_metadata`.
Without that method, provenance is explicitly unsupported/unknown.

Actual data exposure remains **unknown** in this metadata-only audit, including
when certified mode is configured: no event run/LS coverage is scanned here.
The configured mode, luminosity, run bounds, Golden JSON hash and completeness
assumption are recorded, not promoted to a measured integrated luminosity.
Use the separately configured exposure workflow described in [LUMINOSITY.md](LUMINOSITY.md).

Realpath/device-inode identity finds aliases/hard links, not copied contents or
repeated collisions inside distinct files. `(run,lumi,event)` duplication is
**not assessed**, and no event-level deduplication is performed. Path/size/mtime
fingerprints are not content checksums. Reports include configuration, code and
input-signature hashes; a report is a snapshot, not a permanent certificate.

## Reduced RNTuple sources

The built-in `reduced_rntuple` reader verifies mandatory payload/sidecar/manifest
checksums and original entry mapping without opening original ROOT inputs. Audit
Events counts describe retained rows; `original_nevents`, original population
identity and original signed normalization are recorded separately. Same-sample
repeated original populations fail even for copied derivative bundles.

The legacy top-level signature-policy description concerns cheap original-file
signatures. Reduced signature records additionally contain verified payload,
sidecar and manifest SHA256 fields. Reduced opening is not header-only: it
validates provenance mapping and bytes. No event run/LS exposure is measured or
completeness inferred by audit. An operational audit pass is not a certificate
of retention/selection compatibility; pipeline preflight enforces that separate
contract. See REDUCED_SKIM.md and VALIDATION.md.

Schema2 reduced_rntuple_group inputs are logical descriptors. Audit validates
the complete ordered shard set/checksums and actual bounded headers/maps before
using the one original signed denominator. Physical counts are separate; failed
ownership makes verified normalization unavailable. Original paths are not opened.
See STREAMING_REDUCED_SKIM.md for group completeness and logical max-files scope.
