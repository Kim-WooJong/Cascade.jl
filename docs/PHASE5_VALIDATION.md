# Phase 5: reusable analysis-framework helpers

Date: 2026-11-05. Base commit: `5e4661e`. Version: 0.1.0.
Source is authoritative on the Mac; execution/output artifacts remain on gate.
No push or external publication. This report validates framework behavior,
not a precision physics analysis.

## Changes

1. `corrections.trigger_or`: separate data/MC efficiency bindings, stable event
   OR ratio, coherent nominal/up/down reevaluation, strict invalid-probability
   and zero-denominator failures. Scope is explicitly independent objects of
   one single-object HLT path, not arbitrary correlated menus/multi-leg paths.
   Optional `trigger_match` binds selected-object directions to event-local
   TrigObj fields with configurable ID/filter-bit mask/radius.
2. `mass_massive` and `pair_pt`: reusable massive invariant mass and transverse
   vector-sum magnitude. Old `mass_massless` remains unchanged. DY now uses
   the supplied NanoAOD masses and dedicated pair helper.
3. Optional `regions.expr`: persisted actual membership, correct nominal/shape
   region yields and histogram filling. Observed multi-channel fits reject
   contributing-entry overlap (including different histograms in one region).
   Active channel/bin definitions enter provenance validation and merge cache.
4. Luminosity provenance: unknown subset exposure is labelled, never inferred
   from file/event fractions. Optional certified observed run/LS union uses an
   explicit pb^-1 table and mandatory complete-LS assumption. Payload changes
   invalidate coverage; missing entries fail. Default normalization is retained.
5. Canonical base-region-yield versus histogram-integral names, with legacy
   aliases; configurable run/LS branches and explicit `${ENV:NAME}` external
   paths. Default plot labels follow used store luminosity, while an explicit
   configured label remains the user's override.

One analysis TOML still controls the entire pipeline. Features are split into
individual files. See [CONFIG](CONFIG.md), [TRIGGERS](TRIGGERS.md),
[REGIONS](REGIONS.md), [LUMINOSITY](LUMINOSITY.md) and the commented template.

## Targeted validation already completed

| Lane | Gate scratch/log | Result |
|---|---|---|
| Trigger OR, matching, existing weights/pipelines/cache | p5-trigger/trigger-final.log | 496 passed, exit0 |
| Exposure, payload/cache changes, aliases | p5-exposure/exposure-test.log | 56 passed, exit0 |
| Config and branch aliases | p5-final/parent-targeted2.log | exit0 |
| Massive and existing object helpers | p5-kinregions | 23022 passed |
| Region-focused selection, incl early retention | p5-kinregions | 20 passed |
| Fit overlap / Asimov exception | p5-kinregions | 22 passed |
| Region/shape migration/fit/cache integration | p5-kinregions | 19 passed |

These counts overlap with the full suite; do not add them together.
Synthetic tests need neither data storage nor Python at runtime. Gate uses
Julia release 1.12.2 and `~/packages/rootplots-gate.sh` with absolute project,
script and workdir paths (the wrapper changes cwd).

## Final integration gates

### Full suite

`gate:~/analisis/Cascade_dev/p5-final`, `full-suite-final.log` and
`full-suite-final.exit`: **exit0, 50963 passed, one existing skipped assertion**.
The skip is `test/plotting/real_data_tests.jl:11` with `CASCADE_REAL_DATA=0`.

| Area | Passed |
|---|---:|
| config | 186 |
| corrections | 209 |
| fit | 327 |
| histograms | 28 |
| IO | 41 |
| objects | 23022 |
| pipeline | 250 |
| plotting | 191 |
| selection | 151 |
| systematics | 26558 |

Command: `JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 CASCADE_REAL_DATA=0
CASCADE_PYHF_ORACLE=0 nice -n 10 bash ~/packages/rootplots-gate.sh
--project="$PWD" "$PWD/test/runtests.jl"`. Coordinator read back the exit and
all area summaries. Final Mac/gate source SHA256 matches over 309 Julia files:
`7f11a513e29638f76cd307c8aba3c2d739355aa47a25686fd82e4e62fb8738ca`
(sorted relative path + NUL + file bytes + NUL).

Five CLI checks also passed **5/5, exit0** (`final-checks.log` and
`final-checks.exit`): baseline/sf/phase2/jer_candidate ttbar profiles and DY.
The checks execute `Cascade.Pipeline.main(["check", ...])`, including payload
binding, compiled selections and resolved options. Wall time: 23.8 seconds.

### Fresh full-dataset baseline

Scratch: `gate:~/analisis/Cascade_dev/p5-baseline`, fresh `out_baseline` (no
previous cache). **13 samples, 3307 files, 1,027,230,612 indexed input events**.
All 3307 selection/correction/histogram chunks ran, with zero skipped chunks.

The detached wrapper sequentially ran, with `JULIA_THREADS=4`,
`OPENBLAS_NUM_THREADS=1`, `CASCADE_REAL_DATA=1` and
`CASCADE_REAL_WORKDIR="$PWD/out_baseline"`:

```sh
nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/pipeline/test_real_reproduction.jl"
nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/pipeline/test_bitexact_profiles.jl"
```

Results: **350/350** reproduction assertions (22m33.7s), then **50/50**
exact-zero assertions. Both exit sentinels are 0; `baseline.exit=0`, stage
`complete`, completion marker present. Coordinator read the logs/sentinels
and reproduction TSV directly.

| Region | Data | Normalized MC |
|---|---:|---:|
| eμ, ≥1 jet | 5905 | 6434.931560809516 |
| eμ, ≥2 jets | 3836 | 4235.210227397772 |

Reference and new yields, bins and cutflows agree bit-exactly: maximum reported
relative difference **0**. Negative weights remain unchanged.
`baseline-source.sha256` checks all 440 frozen source/config/test files before
and after, both checks passed. Manifest-of-hashes SHA256:
`4f1321c712a611b61b3fe5cf77b4ecb7ba40e7a240dab0515b138e89de7cccaf`.
This capsule predates only the plot-label-only fix; selection through merge is
the final implementation. Final plotting code is covered by the full suite and
DY plot-only refresh, not by this baseline reproduction (which stops at merge).

Operational recovery: monitoring-session hook relays failed while the detached
run remained healthy. The coordinator collected the **existing** run directly;
no duplicate full-dataset execution or source resynchronization was performed.

### Actual DY smoke and independent checks

Scratch: `gate:~/analisis/Cascade_dev/p5-dy`. Commands use
`JULIA_THREADS=2 nice -n 10 bash ~/packages/rootplots-gate.sh`, absolute
`--project`, CLI and config paths, `run ... --max-files 2 --workdir .../out_smoke`.
Original smoke, subsequent `--only plot` refresh, and scratch-only independent
`dy-verify.jl` each exited **0**. The plot refresh resynchronized only
`plot_options.jl` and `plot_analysis.jl`; selection/fit were not repeated.

- 11 samples, **22 ROOT files**, **2,809,785 input events**.
- Wide selection: **43,979** entries (data 8,147; MC 35,832).
- Z window: **17,566** entries (data 7,294; MC 10,272).
- Fit status `ok`, converged; **1,162 templates**.
- **243 nonempty artifacts**, 14,393,306 bytes, including 23 PNG and 23 PDF.

| Region | Data njet integral | Corrected/normalized MC njet integral |
|---|---:|---:|
| Wide | 8147 | 803902.361895373 |
| Z window | 7294 | 730854.481980982 |

The verifier reconstructed all **43,979** persisted pairs from raw ROOT muons:
massive mass and pair-pT match their helper outputs bit-exactly; an independent
Cartesian four-vector mass differs by at most **8.71e-11**. Counts, generator
sums, cross-section/branching/luminosity factors, correction sums and histogram
integrals agree. Detailed evidence: `p5-dy/dy-verification.json` (read back by
the coordinator), logs `dy-smoke.log`, `dy-verify.log`.

All samples are independently truncated, exposure metadata explicitly says
`unknown`, and configured 1210 pb^-1 is retained; the table is not a data/MC
closure or cross-section measurement. The leading-leg trigger approximation
is unchanged. Files generated on gate are not browser-delivery proof.

## Review and failure recovery

Independent concrete-diff review found an observed-provenance guard incorrectly
applying to expected-only Asimov workspaces; fixed with regression coverage.
Luminosity helpers were split to match the requested file convention. Narrow
rereview confirmed both changes and found no remaining blocking defect.
Targeted tests also exposed a closure-local name collision in path parsing and
an incorrect zero-based Jagged trigger-object slice; both were corrected from
the demonstrated cause and their regression tests pass.

## Scientific and verification limits

- No measured trigger efficiencies were created: ttbar retains its placeholder,
  DY its explicitly labelled leading-muon approximation. Generic OR support is
  not a validated eμ menu correction or an automatic matching prescription.
- Observed LS coverage does not establish complete LS processing or common
  trigger-stream exposure; certified mode records the explicit assumption.
- Overlap identity is an entry within a source chunk, not physical collision
  deduplication across files/PDs. Asimov bypass is not independence evidence.
- Baseline and bounded DY are technical runs. No new precision-physics,
  correctionlib-oracle, pyhf-oracle or browser-rendering claim is made here.
