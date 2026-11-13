# Plotting examples

Run on gate through the ROOTPlots wrapper (LCG ROOT for the ROOT child processes
only), with the Cascade checkout as the project. The wrapper changes into the
ROOTPlots directory, so pass absolute paths.

    R=$HOME/analisis/Cascade_dev/plotting/repo      # a Cascade checkout with ROOTPlots >= 0.2.2
    bash ~/packages/rootplots-gate.sh --project=$R $R/examples/plotting/synthetic_example.jl <outdir>
    bash ~/packages/rootplots-gate.sh --project=$R $R/examples/plotting/ttbar_example.jl ~/analisis/ttbar_ctrl <outdir>

- `synthetic_example.jl`: every plot and table type from deterministic synthetic
  templates (shape variations, envelope and quadrature groups, a one-sided
  variation, a negative bin, overflow folding, postfit, cutflow with/without data).
- `ttbar_example.jl`: the prior ttbar e-mu outputs (`out_slim`, `out_data`,
  `out_cutflow`, read-only). Grouping, colours, cross sections and variables come
  from `ttbar_ctrl.toml`. It checks the yields against docs/DESIGN.md
  (>= 1 jet: data 5905, MC 6434.9316; >= 2 jets: data 3836, MC 4235.2102) and the
  prior plots log, and exits non-zero if a check fails. The normalisation
  variations and the postfit (one ttbar normalisation from the integrated yields)
  are illustrative only; they are not the analysis' systematic model or fit.

Outputs: PNG/PDF plots and `.txt`/`.md`/`.tex` tables in `<outdir>`.
