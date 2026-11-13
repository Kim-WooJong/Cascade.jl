# Modern Summer22 counting candidate

`modern_counting.toml` is independent of `analysis.toml` and all its profiles.
It selects OS e-mu, >=2 jets, no b-tag selection/SF, one counting region.
The public run entry and direct no-checkpoints entry fail before event discovery
or output creation while any required evidence is missing. No final number is
produced. Reference luminosity/xsecs/BRs and absent corrections are NOT approved.

## Readiness

On an approved validation environment runtime, inspect without executing events:

```julia
using Cascade, TOML
cfg = Cascade.Config.load_analysis("analyses/ttbar_emu/modern_counting.toml")
TOML.print(stdout, Cascade.Config.counting_readiness(cfg))
```

Six required TOML evidence records: trigger_or, luminosity, calibration,
backgrounds, signal_normalization, theory_acceptance. Each needs `status="validated"`,
`kind`, nonempty `method`, the returned `configuration_sha256`, and nonempty
`[[files]]` records containing path + sha256. The configuration hash excludes
only the evidence-path mapping to avoid circular binding. Changes to selection,
corrections, theory, MC roles or normalization invalidate the records. Evidence
file hashes prove provenance, not the truth of an analyst's validation claim.
Do not put unvalidated source documents into records marked validated.

## Extraction API

`Cascade.Fit.counting_measurement(cfg, rows; observed, nuisances, lumi_relative)`
requires ready evidence. Each row is `(name, sumw, sumw2)` for exactly one configured
MC sample in the one counting region, after L*xsec*BR/signed-generation-sum
scaling. Supply integer data count. TTto2L2Nu alone is signal (including its tau
feed-down); TTtoLNu2Q is nonprompt background. Validate decay filters/card/BR
before inference. Never multiply the branching ratio again in extraction.

Each nuisance is a dictionary of ALL MC names to (up_yield, down_yield), including
unchanged samples. Names denote independent nuisance sources; effects across
samples sharing a name are correlated and combined before the estimator. This
API uses independent-source envelope quadrature, NOT arbitrary covariance or
profile-likelihood intervals. MC statistical sumw2 uses independent sample
moments. Signal theory templates must use member-specific preselection sums.
External luminosity rescales signal AND MC backgrounds and is never also passed
as a nuisance. Negative subtracted estimates are not clipped to zero.

`member_acceptance(selected, generated; decay_fraction)` computes memberwise
signed acceptance, not an absolute cross-section variation. Runs ratio sums must
first become sumw_nominal[file]*ratio[file,member] then sum across original
sources once. Validate full-input coverage, weight convention and cancellations;
selected skim sums cannot serve as denominators.

## Current limits

`Cascade.Fit.counting_from_store(cfg, histogram_path, samples_path; nuisances,
lumi_relative)` connects existing normalized `merge/histograms.json` and
`merge/samples.json` to extraction. It checks one-fill histogram definition,
sample inventory, binning, cutflow/integral closure, integer unweighted data and
configuration-bound provenance stamped by modern-counting merge. Historical
unbound baseline stores are refused, not silently relabelled. Readiness runs
before reading either file. A typed HistogramStore/Dict overload is also exposed.
There is no new profile-likelihood model or automatic final publication.
No full dataset rerun is justified while trigger/lumi remain unresolved. Unit
fixtures marked synthetic are never evidence for the real configuration.

## Focused integration validation

Run `test/modern_counting/fullmodule.jl` only as a separate approved validation environment process
with the current full Cascade project/dependencies. It imports real Cascade and
JSON3, calls the public `check`/`run` dispatcher, installs a test-only discovery
trap and round-trips synthetic merged files through the typed adapter. Do not
include it in a shared test process: the deliberately installed discovery trap
is process-local and intentionally not restored. The portable `runtests.jl` is
separate and retains its explicitly stubbed JSON3 boundary coverage.
