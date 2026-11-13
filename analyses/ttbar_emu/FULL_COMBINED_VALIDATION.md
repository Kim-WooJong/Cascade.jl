# Full-dataset combined technical run — 2026-11-04

> Since phase 4 the configuration is `analysis.toml` with profile `phase2`
> (formerly `analysis_phase2.toml`, JER nominal=false).

validation environment scratch `~/analisis/Cascade_dev/p3-full-technical` (source of commit 115436b,
hashes in `p3-source.sha256`), Julia 1.12.2, 8 threads. **full.exit = 0, pyhf.exit = 0.**

## Steps (all 3307 files, 13 samples)

| Step | Run | Time (s) |
|---|---:|---:|
| skim | 13 | 30.5 |
| select (nominal + JES/JER Up/Down) | 3307 | 2040.8 |
| correct (SF on every variation table) | 3307 | 219.9 |
| histogram | 3307 | 11.3 |
| merge | 1 | 87.1 |
| systematics | 1 | 3.5 |
| fit | 1 | 34.5 |
| plot | 1 | 94.6 |

Select is about 2.9× the baseline (765 s): three extra selections per MC chunk.

## Yields (emu >= 1 jet)

| | Raw-normalised (no SF) | With SFs (hist_yield) |
|---|---:|---:|
| MC total | 6434.931560809517 | 6010.88601778692 |
| Data | 5905 | 5905 |

The no-SF column equals the bit-exact baseline; the SF column equals the
phase-2 SF-lane value 6010.88601778692 (now including JES/JER templates).
Data/MC with SFs: 0.9824 (>=1 jet).

## Fit (technical; placeholder priors)

mu_ttbar = 0.980 ± 0.034 (Hesse), profile interval [0.947, 1.014]; counting
cross-check (N−B)/S = 0.980 ± 0.015 (data stat.). JES_Total pull −0.59,
all other nuisances |pull| < 0.13. Status ok, 5 iterations.

pyhf 0.7.6 on the exported workspace: POI 0.97997487 vs 0.97997466,
max |Δθ|/σ 9.2e-6, max relative error difference 4.3e-4, ΔNLL −5.7e-11 →
AGREEMENT WITHIN TOLERANCES.

## Not established

Trigger SF is unity with zero-size placeholder; luminosity (1.4%) and background
priors are placeholders (published luminosity uncertainty 2.3%); no theory or
nonprompt systematics; nominal JER is not applied in this profile. The fitted
normalisation is a framework/numerics check, **not** a cross-section result.
