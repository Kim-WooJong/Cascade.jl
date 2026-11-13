# Fit and plot demonstrations

Run on gate (native ROOT through the ROOTPlots wrapper for the plots; pass absolute paths).

    R=<Cascade checkout>; W=<work directory>
    RUN="bash ~/packages/rootplots-gate.sh --project=$R"

## Synthetic end-to-end demo (`analyses/fit_demo`)

    $RUN $R/examples/fit_demo/make_inputs.jl                       # analyses/fit_demo/inputs/*.cols
    $RUN $R/bin/cascade.jl run $R/analyses/fit_demo/analysis.toml --workdir $W/fit_demo
    $RUN $R/examples/fit_demo/pyhf_check.jl $W/fit_demo/fit/workspace.json

Two simulated processes (`signal`, `background`) and pseudo-data generated with the
signal scaled by mu = 1.2 (see `lib/write_fit_demo_inputs.jl`). The chain runs
skim -> select -> correct -> histogram -> merge -> systematics -> fit -> plot:

- `fit/result.json` (fit report: POI, Hesse error, profile interval, pulls, impacts,
  CLs upper limit, significance, pre/post-fit yields, counting cross-check, the fitted
  pyhf workspace), `fit/result.txt` (text summary), `fit/workspace.json` (pyhf);
- `plot/prefit/<region>/<variable>.{png,pdf}` with the stat ⊕ syst band (variation
  histograms plus the `[fit]` normsys), `plot/postfit/<channel>.*`, `plot/impacts.*`,
  `plot/cutflow.*` and `plot/tables/*.{txt,md,tex}`.

## ttbar e-mu normalisation fit

Append `ttbar_fit.toml` to `analyses/ttbar_emu/analysis.toml` (or to a copy next to it, so
relative paths still resolve) and run from the systematics step on an existing merged
store:

    $RUN $R/bin/cascade.jl run <analysis with [fit]> --workdir <ttbar workdir> --from systematics

The luminosity and cross-section uncertainties of `ttbar_fit.toml` are placeholders
(flagged in the fit result and summary), not the analysis' systematic model.

## Integration API and contracts

- `Fit.fit_config(::AnalysisConfig)` reads `config.raw["fit"]` (returns `nothing`
  without that section). Its docstring contains the complete TOML schema.
- `Fit.build_workspace(store, config)` returns `(workspace, channels, notes)`;
  `Fit.HistModel(store, config)` builds the same model directly, and
  `Fit.write_workspace(path, workspace)` exports schema-1.0.0 pyhf JSON.
- `Fit.fit_report(store, config)` runs the fit and optional inference;
  `Fit.report_model`, `Fit.report_result` reconstruct the model/result after JSON
  round-trip. `Fit.group_yields` propagates the full covariance, including
  correlations between bins and samples. `Plotting.fit_yields` adapts it to
  `Plotting.FitYields`.
- `Plotting.plot_analysis` produces the analysis plots and tables;
  `Plotting.plot_options` documents `[plot]`. Missing sample-specific shape
  templates contribute nominal in both model building and grouped plot bands.
- `Plotting.BinnedHist === Histograms.BinnedHist`: the duplicate type was removed.
  For validated plotting inputs use `Plotting.binned_hist(edges, sumw, sumw2)`;
  ROOTPlots `Hist1D` adapters remain. The store type cannot retain flow bins:
  adapters fold supplied flows by default, or discard them when folding is
  disabled. Once discarded, flows cannot be recovered.

Fit channels are assumed statistically independent. Do not simultaneously fit
nested/overlapping selections (such as >=1 jet and >=2 jets) as independent
channels. The ttbar example fits only >=1 jet. The free ttbar normalisation is
the measured POI; the example assigns cross-section priors to background groups,
not an additional prior to that same free normalisation. One-sided histogram
variations are mirrored around nominal and explicitly noted in the report.
