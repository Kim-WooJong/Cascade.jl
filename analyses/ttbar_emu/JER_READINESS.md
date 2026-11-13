<!-- Historical validation: former standalone TOMLs are frozen in test/config/fixtures; use analysis.toml with --profile sf, phase2 or jer_candidate now. -->

> Since phase 4 (2026-11-04) the separate ttbar configs are profiles of one
> `analysis.toml` (`baseline`, `sf`, `phase2`, `jer_candidate`); old file names
> below refer to those profiles. Frozen copies: `test/config/fixtures/`.
# Nominal JER readiness review — 2026-11-04

## Decision

The implementation supports a consistently JER-smeared nominal. A separate
**physics-candidate / technical-validation** configuration can enable it without
changing the baseline or the phase-2 demonstration. No blocking code defect was
demonstrated for this analysis's one Jet JER source by this static review.
This is not approval of the final physics model: trigger, normalization priors,
input calibration provenance, and the JES evaluation convention remain open.

## Minimal candidate configuration

Copy `analysis_phase2.toml` to a separately named candidate configuration and:

1. Give `[analysis]` a distinct name and workdir.
2. Change **only the JER shape entry** to `nominal = true`.
3. Replace the comment describing preservation of an unsmeared SF-only nominal;
   retain explicit technical-validation and placeholder labels.
4. Leave JES and JER payload names, match radius 0.2, and match significance 3.0
   unchanged pending independent payload/provenance verification.

Do not substitute a guessed trigger uncertainty or remove placeholder flags.
No MET propagation setting is needed for the current selection: it does not read
MET. If MET cuts or histograms are subsequently introduced, configure and validate
the relevant MET prescription explicitly; generic momentum conservation is not
proof of the complete CMS Type-1 MET recipe.

## Verified implementation behavior (source inspection)

- `src/Systematics/shape/shape_factors.jl`: JER nominal factors are present only
  when enabled; JER directions have `from_raw=true`.
- `src/Systematics/shape/shape_columns.jl`: nominal is computed from original
  input columns once. JERUp/Down replace it using original input times the
  respective absolute factor, **not nominal times another smearing factor**.
  JES directions multiply the nominal-smeared columns.
- `src/Selection/run_selection_variations.jl`: every direction reruns selection
  from the nominal base plus that direction's replacements. Object cuts and
  sorting therefore follow varied kinematics, rather than keeping only the
  originally selected jets.
- `src/Pipeline/step_correct.jl`: correction hook is called independently on
  nominal and each varied selected table. Each shape histogram receives its
  own nominal SF product; shape × weight nuisance cross-products are not built.
- `src/Systematics/shape/shape_variations_for.jl`: data receives no shapes.
- `src/Pipeline/step_select.jl`: shape configuration, payload hashes, and shape
  source participate in MC cache keys; toggling nominal invalidates MC selection.
- `src/Systematics/shape/jer_factors.jl`: the same original kinematics/event seed
  is used for nom/up/down. Existing matching rejects invalid indices and jets
  failing ΔR or resolution matching, then uses stochastic smearing.

## Existing coverage versus new evidence required

Existing tests, inspected and subsequently rerun in the candidate validation:

- `test/systematics/shape/test_shape_factors.jl`: hybrid matching, shared random
  draw across directions, repeated/chunked reproducibility, nominal replacement,
  and equality of JERUp jet pT with nominal smearing on versus off.
- `test/pipeline/test_shape_pipeline.jl`: nominal=true histogram comparison
  against a separate run on manually smeared inputs, with data unchanged.
- `test/pipeline/test_combined_systematics.jl`: SF reevaluation for migrated
  shape selections, currently not a dedicated real-data nominal=true oracle.

The previously reported real combined run used nominal=false. Its result is
not real-data validation of the candidate setting.

Recommended bounded next test, on gate only:

1. Use the same deterministic small file subset for phase-2 and candidate
   configurations, distinct workdirs, and pinned correction payload SHA256.
2. Rerun the existing shape/selection/pipeline regressions.
3. On real MC, compare nominal, JERUp and JERDown per-jet factors with Python
   correctionlib using independently constructed match inputs. Include matched
   and unmatched jets and threshold migrations. Check finite nonnegative
   factors and repeated/chunked reproducibility; do not require bin-by-bin
   Up ≥ nominal ≥ Down, which is not guaranteed after migration.
4. Compare candidate nominal selection/histograms against independently
   pre-smeared inputs with JER disabled, including correct-stage SF weights.
   Check JERUp/Down direct-input equivalence and unchanged data. Jet identity
   and output comparisons should account for deliberate Float32 rounding.
5. Run through merge/systematics/fit/plot and compare the exported workspace
   with pyhf. Record yields and migration counts, not a physical cross section.
6. Only after bounded checks pass, scale the candidate to all files; retain
   a complete file/event inventory and the placeholder qualification.

## Remaining physics and convention checks

**Input provenance:** the configured campaign is Run3Summer22NanoAODv12 with
AK4 PUPPI payloads, but these files live under `nano_slim`. Before physics use,
confirm from production/slimming provenance that `Jet_pt` is calibrated with
the intended JEC and is not already JER-smeared. The shape code applies a
resolution correction; it does not undo old JEC/reapply a full JEC chain or
detect pre-smeared inputs. Enabling nominal twice upstream and here would
double-smear even though the internal implementation itself does not.

**JES evaluation point:** `shape_columns.jl` computes all factor arrays from
original input before assembling smeared nominal columns. Therefore the
current convention is `(pT × JER_nom) × (1 ± JES_unc(eta, original_pT))`, not
`(pT × JER_nom) × (1 ± JES_unc(eta, smeared_pT))`. This distinction matters for
pT-dependent JES payloads. It is an explicit review question, not a proven
bug: compare with the adopted CMS/reference implementation before choosing a
different convention or changing code. Tests currently establish the former.

**Final model:** the analysis uses a total JES source, not a validated source
decomposition/correlation model; theory/background/luminosity priors and the
trigger term are still demonstrations. Full-data processing does not resolve
these missing physics inputs. There is no b-tag requirement here, so adding
an unrelated b-tag SF is not part of this change.

## Review scope

The initial read-only review was extended to create
`analysis_jer_candidate.toml` and run bounded gate validation. Baseline and
phase-2 configurations remain unchanged. Confidence is high in the documented
code ordering; physics applicability remains conditional on the provenance and
reference checks above. No commit or push is performed by this reviewer.

## Candidate validation execution

Gate scratch: `~/analisis/Cascade_dev/p3-jer-candidate`. Source/test/analysis
transfer verified: 392 files SHA256-identical (excluding this evolving report),
no extra files. The run uses the established gate Project/Manifest and ROOTPlots
wrapper with four Julia threads and one BLAS thread.

`t_candidate.jl` runs shape, shape-pipeline and combined-SF regressions before
the candidate pipeline (`max_files=6` per sample). It then compares data and
JERUp/Down histograms with the earlier phase-2 subset, requires a changed
nominal MC histogram, checks matching file/event counts and finite histogram
weights/variances, and records per-sample selected-count/yield migrations.

### Results

Completed successfully: `candidate.exit = 0`, `pyhf.exit = 0`.

- Synthetic regressions: **26,121 / 26,121 passed**.
- Candidate real-subset comparisons: **5,405 / 5,405 passed**.
- **78 ROOT files, 23,279,715 events**, six files per sample across 13 samples.
  Exact input path lists match the preceding phase-2 subset (not merely counts).
- Data histograms are bit-identical; JERUp/Down MC histograms are bit-identical
  to the nominal=false run, confirming the switch does not compound their
  smearing. Nominal MC changes as expected. All histogram sumw are finite and
  sumw2 finite/nonnegative. Negative weighted MC bins remain allowed.
- Pipeline reached fit and plot; **79 output files**. Fit took 35.27 seconds;
  plot 95.23 seconds. Human visual inspection is not claimed.
- Exported-workspace pyhf check passed: max parameter difference / sigma
  `6.08242664e-5`, max relative Hesse-error difference `2.62077550e-5`,
  NLL difference `-3.22444293e-9`.

| Subset quantity | ≥1 jet | ≥2 jets |
|---|---:|---:|
| Data (unchanged) | 745 | 475 |
| Prior nominal=false MC weighted yield | 5960.935199547372 | 3924.707300770065 |
| Candidate nominal=true MC weighted yield | 5954.517320268444 | 3916.469712371213 |
| TTto2L2Nu selected events, before → after | 37850 → 37788 | 26321 → 26277 |

The selected-count changes are **net** migrations, not counts of all individual
entering/leaving events. Complete per-sample counts and yields are in
`candidate.log`. The subset data versus configured full luminosity makes this
fit normalization unsuitable as a physics measurement; only numerical
agreement is reported.

Commands (absolute scratch resolved through `D`):

```sh
D=$HOME/analisis/Cascade_dev/p3-jer-candidate
nice -n 10 env JULIA_THREADS=4 OPENBLAS_NUM_THREADS=1 bash ~/packages/rootplots-gate.sh --project="$D" "$D/t_candidate.jl"
nice -n 10 env JULIA_THREADS=4 OPENBLAS_NUM_THREADS=1 bash ~/packages/rootplots-gate.sh --project="$D" "$D/examples/fit_demo/pyhf_check.jl" "$D/work_candidate_subset/fit/workspace.json"
```

Final candidate TOML SHA256, verified identical on Mac/gate:
`aefb4bde3f65f246cdc75f2899fa4df49d9a88f2a4a068f4f082f0d573a927b7`.
A stale inherited header comment was corrected after launch, without changing
TOML semantics; that comment-only version was resynchronized and hashed.

Still unperformed: independent Python per-jet JER-factor oracle on real inputs,
real-input presmear replay (the independently altered-input check here is
synthetic), confirmation of upstream calibration provenance/JES convention,
and full-dataset nominal=true processing. The independent pyhf check validates
the likelihood, not the JER prescription. These bounded results do not close
the scientific prerequisites listed above.
