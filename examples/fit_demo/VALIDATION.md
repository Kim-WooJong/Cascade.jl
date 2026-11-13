# Fit/plot phase-2 validation (2026-11-04)

## Changes

- `src/Fit/`: new configuration types/parser (`FitChannel`, `FitSample`,
  `NormSysSpec`, `FitConfig`, `fit_config`), histogram-store workspace/model
  builders, JSON workspace export, counting cross-check, covariance-aware
  grouped yields, profile interval, JSON report/reconstruction and text summary.
  `nll.jl` now preserves finite derivatives at zero-observation/zero-expectation
  boundaries (Poisson contribution is exactly the expectation).
- `src/Plotting/`: removed the duplicate `BinnedHist`, flow-storage and arithmetic
  implementations. Re-export the Histograms type, provide validated construction
  and ROOTPlots adapters, histogram sum/scale helpers, store adapters, normsys
  templates, fit-result adapter, analysis output orchestration and ranking plots.
- `src/Pipeline/{default_fit,default_plot,step_fit,step_plot}.jl`: real default
  hooks and cache dependencies, preserving registration/CLI and no-fit behavior.
- `test/fit/`: store/config/model/report/covariance/profile/oracle coverage,
  zero-yield derivative regression and nuisance-pruning regression.
  `test/plotting/`: unified histogram contracts, adapters, fit yields, rendering.
  `test/pipeline/test_fit_plot.jl`: synthetic full pipeline, outputs, cache and CLI.
- `examples/plotting/lib/`: adapted examples to the unified histogram API.
- `analyses/fit_demo/analysis.toml`, `examples/fit_demo/`: reproducible synthetic
  inputs, full analysis, external-oracle checker and proposed ttbar TOML snippet.

Complete schemas and API contracts are in `Fit.fit_config`, `Plotting.plot_options`
(and their type/function docstrings) and this directory's `README.md`.
No edits to the Mac `analyses/ttbar_emu/` analysis belong to this lane. Append
`examples/fit_demo/ttbar_fit.toml` to a copy beside that analysis for the demo.

## Design and scope

Channels are explicit region/variable pairs and must represent independent
observations. Default simulated processes are analysis sample groups; explicit
fit groups or individual samples are supported. Signal groups receive the POI
normfactor. Named normsys are configured; histosys come from store variations.
Missing sample-specific variation templates use nominal. One-sided variations
are mirrored and reported. Shared channel `staterror` modifiers implement
Barlow-Beeston lite using summed sample sumw2. Exported observed-data workspaces
are exactly those used for the demonstrated fits. Postfit errors include the
full covariance and bin/sample correlations, not quadrature of process errors.

The Histograms type has no retained flow bins. Plotting's constructor/ROOTPlots
adapter folds supplied flow contents by default, or explicitly drops them.
No Histograms source changes were needed. ROOTPlots adapters remain available.
No Project.toml dependency or Cascade.jl include-order change is required:
phase 1 already declares dependencies and loads Histograms before Fit/Plotting.

## Gate execution

Scratch: `/path/to/user/analisis/Cascade_dev/p2-fitplot`, based on `c7696ba`, with
fit/plot scope overlaid. The integrated copy was not modified. Logs and outputs
are in the scratch, not the Mac source repository. Julia 1.12.2; ROOTPlots gate
wrapper, four Julia threads, nice level 10. Full integration with concurrent
weight/shape/core edits remains the coordinator's responsibility.

Commands (executed on gate; `D=$HOME/analisis/Cascade_dev/p2-fitplot`):

```sh
nice -n 10 env JULIA_THREADS=4 bash ~/packages/rootplots-gate.sh --project=$D $D/t_fit.jl
nice -n 10 env JULIA_THREADS=4 bash ~/packages/rootplots-gate.sh --project=$D $D/t_plotting.jl
nice -n 10 env JULIA_THREADS=4 bash ~/packages/rootplots-gate.sh --project=$D $D/t_pipeline.jl
nice -n 10 env JULIA_THREADS=4 bash ~/packages/rootplots-gate.sh --project=$D $D/examples/fit_demo/make_inputs.jl
nice -n 10 env JULIA_THREADS=4 bash ~/packages/rootplots-gate.sh --project=$D $D/bin/cascade.jl run $D/analyses/fit_demo/analysis.toml --workdir $D/work_demo
# Scratch-only combined ttbar analysis; no source-repository ttbar edit:
cat $D/analyses/ttbar_emu/analysis.toml $D/examples/fit_demo/ttbar_fit.toml > $D/analyses/ttbar_emu/analysis_fit.toml
nice -n 10 env JULIA_THREADS=4 bash ~/packages/rootplots-gate.sh --project=$D $D/bin/cascade.jl run $D/analyses/ttbar_emu/analysis_fit.toml --workdir $D/work_real --from systematics
nice -n 10 env JULIA_THREADS=4 bash ~/packages/rootplots-gate.sh --project=$D $D/examples/fit_demo/pyhf_check.jl $D/work_real/fit/workspace.json
nice -n 10 env JULIA_THREADS=4 OPENBLAS_NUM_THREADS=1 bash ~/packages/rootplots-gate.sh --project=$D $D/examples/fit_demo/pyhf_check.jl $D/work_demo/fit/workspace.json
nice -n 10 env JULIA_THREADS=4 CASCADE_PYHF_ORACLE=1 CASCADE_REAL_DATA=1 CASCADE_REAL_WORKDIR=$D/work_real OPENBLAS_NUM_THREADS=1 bash ~/packages/rootplots-gate.sh --project=$D $D/test/runtests.jl
```

The first targeted fit run had 290 passes; plotting had 187 passes and one skip.
The initial pipeline attempts exposed invalid sparse synthetic fixtures (no
certified data and a signal-only bin under the null) and the zero-yield AD
boundary defect. The fixtures and likelihood were corrected; final suite
results are recorded below. Python is only the external pyhf 0.7.6 oracle in
an LCG_110 subshell, never a runtime dependency. Export checking requests MLE,
NLL and covariance only; the full test oracle still runs inference checks.

## End-to-end results

Both `cascade run` commands completed through plot with exit 0, producing
prefit/postfit plots, pull/impact ranking, yield/uncertainty/cutflow tables,
JSON/text fit results and exported workspaces. Neither plot output has skip
notes. Native rendering/files were checked by tests; no human visual approval
is claimed.

| Quantity | Synthetic demo | ttbar observed data |
|---|---:|---:|
| POI | 1.2660018793 | 0.8990670063 |
| Hesse error | 0.0542268684 | 0.0218507337 |
| Profile interval | [1.2122, 1.3205] | [0.8774, 0.9212] |
| Counting ratio | 1.1872 | 0.9047 |
| pyhf POI | 1.2660017807 | 0.8990667475 |
| pyhf Hesse error | 0.0545734733 | 0.0218127839 |
| Cascade minus pyhf NLL | -3.47e-11 | -2.24e-10 |
| Maximum parameter difference / fitted sigma | 2.15e-6 | 1.71e-5 |
| Maximum relative Hesse-error difference | 0.636% | 0.174% |

Both exported-workspace checks exit 0, within 2% covariance-error tolerance.
The binned and counting estimators need not coincide: the binned fits use
shape information and profile constrained background/systematic parameters.
Synthetic truth is mu=1.2 with fluctuated pseudo-data. Its observed 95% CLs
upper limit is 1.3558; significance is 140.8148 under this illustrative model.
The tiny background tail makes this synthetic significance non-physical.

The ttbar counting inputs are N=5905, S=5561.458, B=873.474. Luminosity 1.4%,
single-top/diboson 10% and Z+jets 20% priors are clearly marked PLACEHOLDERS.
There is no additional cross-section prior on ttbar: that normalisation is the
free measured POI. This is a technical demonstration, not a validated physics
uncertainty model.

## Limitations

- Exact covariance propagation is linear (Hesse/Jacobian); profile intervals
  describe POI asymmetry separately.
- Independent-channel assumptions must be respected; no overlap covariance.
- Optional null/conditional inference can reject an impossible starting model
  (e.g. data in a structural zero-background bin at mu=0); the integration
  fixture has explicit background support. This is not silently regularized.
- External pyhf cross-check numbers above concern the observed-data mode.
  Asimov report/export consistency is covered by the subsequent integration
  regression tests, not an external pyhf comparison.
- Native plots were generated, but human-facing dashboard delivery and visual
  approval are outside this lane.

## Final checks

The corrected standalone integration test (`t_fitplotonly.jl`, which includes
`test/pipeline/test_fit_plot.jl`) passed **30/30**, exit 0. This exercises the
full chain, workspace export/re-fit, report, native plots, tables, cache,
plot-only invalidation and forced CLI fit/plot rerun.

The optional `CASCADE_PYHF_ORACLE=1` whole-suite attempt was interrupted during
a long-running pre-existing broad inference oracle case (not a fit failure).
It is not reported as passing. Both requested exported-workspace MLE/covariance
cross-checks passed independently. The complete standard suite is rerun with
`CASCADE_PYHF_ORACLE=0`, retaining `CASCADE_REAL_DATA=1` and the same other flags;
its log is `log_full_guarded.txt`.

## Source-file inventory

```text
analyses/fit_demo/analysis.toml
examples/fit_demo/README.md
examples/fit_demo/VALIDATION.md
examples/fit_demo/lib/pyhf_compare.jl
examples/fit_demo/lib/write_fit_demo_inputs.jl
examples/fit_demo/make_inputs.jl
examples/fit_demo/pyhf_check.jl
examples/fit_demo/ttbar_fit.toml
examples/plotting/lib/load_ttbar_templates.jl
examples/plotting/lib/read_ttbar_tsv.jl
examples/plotting/lib/run_synthetic_example.jl
examples/plotting/lib/synthetic_templates.jl
src/Fit/Fit.jl
src/Fit/FitChannel.jl
src/Fit/FitConfig.jl
src/Fit/FitSample.jl
src/Fit/NormSysSpec.jl
src/Fit/build_workspace.jl
src/Fit/counting_estimate.jl
src/Fit/fit_config.jl
src/Fit/fit_report.jl
src/Fit/fit_summary.jl
src/Fit/group_yields.jl
src/Fit/json_safe.jl
src/Fit/nll.jl
src/Fit/profile_interval.jl
src/Fit/report_model.jl
src/Fit/report_result.jl
src/Fit/store_model.jl
src/Fit/write_workspace.jl
src/Pipeline/default_fit.jl
src/Pipeline/default_plot.jl
src/Pipeline/step_fit.jl
src/Pipeline/step_plot.jl
src/Plotting/BinnedHist.jl
src/Plotting/PlotOptions.jl
src/Plotting/Plotting.jl
src/Plotting/add_norm_variations.jl
src/Plotting/analysis_cutflow.jl
src/Plotting/analysis_stack_config.jl
src/Plotting/binned_hist.jl
src/Plotting/collect_templates.jl
src/Plotting/fit_yields.jl
src/Plotting/fold_flow.jl
src/Plotting/hist_adapters.jl
src/Plotting/hist_arithmetic.jl
src/Plotting/hist_scale.jl
src/Plotting/hist_sum.jl
src/Plotting/impact_rows.jl
src/Plotting/merge_samples.jl
src/Plotting/plot_analysis.jl
src/Plotting/plot_cutflow.jl
src/Plotting/plot_impacts.jl
src/Plotting/plot_options.jl
src/Plotting/plot_postfit.jl
src/Plotting/plot_prefit.jl
src/Plotting/postfit_groups.jl
src/Plotting/postfit_outputs.jl
src/Plotting/prefit_outputs.jl
src/Plotting/present_stack.jl
src/Plotting/store_templates.jl
src/Plotting/total_yield.jl
src/Plotting/write_table.jl
src/Plotting/yield_table.jl
test/fit/pyhf_oracle.py
test/fit/runtests.jl
test/fit/store_fixture.jl
test/fit/test_nll.jl
test/fit/test_store_fit.jl
test/fit/test_store_pyhf.jl
test/pipeline/test_fit_plot.jl
test/plotting/binned_hist_tests.jl
test/plotting/comparison_tests.jl
test/plotting/fit_adapter_tests.jl
test/plotting/postfit_tests.jl
test/plotting/render_tests.jl
test/plotting/runtests.jl
test/plotting/templates_tests.jl
```

### Coordinator-owned integration

Keep `include("test_fit_plot.jl")` in `test/pipeline/runtests.jl` (already present
in the shared worktree); that existing entry file is outside this lane's write
scope. No new dependency or root module edit is needed. Integration review fixed
Asimov workspace observations to match the fitted dataset and counting report.
Postfit drawing/tables now use the fit report's observations, so a distinct
`plot.data` subset only controls prefit plots. Asimov postfit output is labelled.
These changes have targeted regression coverage in `test/fit/test_store_fit.jl`.

### Guarded real-data reproduction

The full guarded run reproduced the phase-1 baseline exactly:

| Region | Data | MC |
|---|---:|---:|
| emu_ge1j | 5905 | 6434.931560809516 |
| emu_ge2j | 3836 | 4235.210227397772 |

Maximum relative difference of MC histogram bins and cutflows against the
reference: **0.0**. The reproduction table is `$D/work_real/reproduction.tsv`.

### Final full-suite result

`log_full_guarded.txt`: **EXIT 0, 21,398 / 21,398 assertions passed**, no broken
or failed assertions:

| Area | Passed |
|---|---:|
| config | 41 |
| corrections | 209 |
| fit | 295 |
| histograms | 28 |
| io | 47 |
| objects | 20011 |
| pipeline (including guarded reproduction and fit/plot integration) | 460 |
| plotting (native ROOT and real templates) | 192 |
| selection | 115 |

Exact final command:

```sh
D=$HOME/analisis/Cascade_dev/p2-fitplot
nice -n 10 env JULIA_THREADS=4 CASCADE_PYHF_ORACLE=0 CASCADE_REAL_DATA=1 CASCADE_REAL_WORKDIR=$D/work_real OPENBLAS_NUM_THREADS=1 bash $HOME/packages/rootplots-gate.sh --project=$D $D/test/runtests.jl
```

The pseudo-inverse Hessian warning is from the intentional zero-observation,
zero-background boundary regression (zero curvature), not the demonstrated
fits. The CLI missing-analysis error is an expected negative test. Correctionlib
external-oracle agreement is not claimed here (no CASCADE_ORACLE_DIR); the
ordinary corrections tests pass. No commit or push was made.
