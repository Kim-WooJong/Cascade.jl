<!-- Historical validation: former standalone TOMLs are frozen in test/config/fixtures; use analysis.toml with --profile sf, phase2 or jer_candidate now. -->

> Since phase 4 (2026-11-04) the separate ttbar configs are profiles of one
> `analysis.toml` (`baseline`, `sf`, `phase2`, `jer_candidate`); old file names
> below refer to those profiles. Frozen copies: `test/config/fixtures/`.
# Phase-2 integrated validation — 2026-11-04

## Result
Integrated SF, JES/JER, fit/plot and single BinnedHist implementation completed.
Baseline analysis remains unchanged; analysis_phase2.toml is the combined technical demonstration.
Independent review corrected Asimov export observations, postfit fitted-data selection,
and stale correction payload caches. Correct keys include Systematics code and payload SHA256;
shape parsed-cache keys include content SHA256.

## Full integrated suite
Gate `~/analisis/Cascade_dev/p2-integrated/full.log`: **48,013/48,013 passed, EXIT=0**.

| Area | Passed |
|---|---:|
| config | 64 |
| corrections | 209 |
| fit | 305 |
| histograms | 28 |
| io | 47 |
| objects | 20011 |
| pipeline | 503 |
| plotting | 192 |
| selection | 115 |
| systematics | 26539 |

```sh
D=$HOME/analisis/Cascade_dev/p2-integrated
nice -n 10 env JULIA_THREADS=8 OPENBLAS_NUM_THREADS=1 CASCADE_PYHF_ORACLE=0 CASCADE_REAL_DATA=1 CASCADE_REAL_WORKDIR="$D/work_baseline" bash ~/packages/rootplots-gate.sh --project="$D" "$D/test/runtests.jl"
```

Fresh selection processed all 3307 files (765.28 seconds), not just cached artifacts.
`work_baseline/reproduction.tsv`: data 5905/3836; MC
6434.931560809516/4235.210227397772 for >=1/>=2 jets. Maximum MC histogram-bin
and cutflow relative difference is 0.0.

## Combined real-data technical test
`t_real_combined.jl`, `real_combined.log`, `work_combined_subset` under the same gate scratch:
78 ROOT files, 23,279,715 events, six files per each of 13 samples.
SF+JES/JER through fit/plot completed EXIT=0; 79 plot/table output files.
Fit took 31.85 seconds, plot 90.57 seconds. The selected-jet continuous-SF
synthetic regression additionally proves shape migration matches independently
modified raw inputs and recomputed weights, while data/nominal stay unchanged.

Exported workspace pyhf check (`combined_pyhf.log`) EXIT=0:
maximum parameter difference/sigma 4.32956e-5, relative Hesse-error difference
1.88571e-5, NLL difference -1.65651e-9.

```sh
nice -n 10 env JULIA_THREADS=4 OPENBLAS_NUM_THREADS=1 bash ~/packages/rootplots-gate.sh --project="$D" "$D/examples/fit_demo/pyhf_check.jl" "$D/work_combined_subset/fit/workspace.json"
```

The truncated data/full configured luminosity makes the subset fit normalization
unsuitable for physics interpretation. This is integration/numerical proof only.

## Final delta and source delivery
Full-suite snapshot precedes the final shape-cache SHA fix only. That delta was
validated independently in `~/analisis/Cascade_dev/p2-final-shape/shape.log`:
26055 shape-factor, 13 selection-variation and 10 same-path/size/mtime cache
assertions, all passed, EXIT=0. Do not add repeated assertions to the 48013 count.
The earlier correct-cache regression passed 465 assertions in
`p2-cache-integration/cache_final.log`; reviewed fit fixes passed 305 in
`p2-fitplot/log_review_fit.txt`.

Final source/test/analysis delivery to `~/analisis/Cascade` was checked against
Mac: 389 files SHA256-identical, no extra source files. Old duplicate Plotting
histogram files were removed; gate Manifest and runtime outputs were preserved.
Tested snapshot inventories remain in the gate scratch directories.

## Limitations
- Combined all-sample SF+shape processing was bounded to 78 files, not all 3307.
- Full suite skips optional broad pyhf inference and correctionlib oracle tests;
  the combined workspace pyhf check ran separately. Prior SF oracle results are
  recorded separately in VALIDATION.md and were not rerun here.
- Trigger unity/zero-size uncertainty and normalization priors are placeholders.
- JER nominal=false preserves legacy nominal; use consistent nominal smearing
  and validate the final physics systematic model before interpretation.
- No b-tag selection here; generic tagged/untagged efficiency method unvalidated.
- Native plot output is tested; human visual approval is not claimed.
- Source only on Mac; all runtime output remains gate. No remote push.
