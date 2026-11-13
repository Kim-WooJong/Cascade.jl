# DY / Z to two muons: configuration-only technical control

Run2022C, 2022 preEE, nominal luminosity 1210 pb^-1. This is a framework
generality exercise, not a validated physics analysis or measurement.
The configuration uses the original schema, without options or profiles, and
requires no analysis-specific Julia code or framework modifications.

## Selection and inputs

- Data: SingleMuon and Muon primary datasets, same Muon stream. Their run
  coverage is disjoint in the reference input; no MuonEG/EGamma data is used.
- Trigger: HLT_IsoMu24 for data and simulation; same Golden JSON and inclusive
  run interval 356309–356615 as the ttbar configuration.
- Exactly two selected muons: tightId, PF relative isolation R=0.4 < 0.15,
  pT > 15 GeV, |eta| < 2.4, sorted by descending pT. Leading pT > 26 GeV;
  opposite charge. No electron veto or jet multiplicity requirement.
- `mumu_wide`: all such pairs; `mumu_z`: strictly 70 < m_mumu < 110 GeV.
  The mass helper includes the saved NanoAOD muon masses; `pair_pt` supplies
  the dimuon transverse vector sum. The wide mass histogram
  spans 0–200 GeV, with overflow folded into its last bin.
- Jets: pT > 30 GeV, |eta| < 2.4, tight jet ID bit, dR > 0.4 from both muons.
- DY MLL50/10to50, ttbar dilepton/semileptonic, tW/anti-tW, WW and WZ.
  Every cross section and branching ratio is copied unchanged from
  `analyses/ttbar_emu/analysis.toml`, including both DY cross sections; these
  inherited pre-validation values are not independent recommendations.

## Corrections and fit limitations

MUO `2022_Summer22/muon_Z.json.gz`: TightID and TightPFIso on both selected
muons. LUM `2022_Summer22/puWeights.json.gz`: the same BCD pileup correction
as ttbar. Up/down templates are correlated by correction name across muons.
The MUO payload does contain
`NUM_IsoMu24_DEN_CutBasedIdTight_and_PFIsoTight`; it is applied **once to the
leading muon**, not multiplied over both. This is a technical leading-leg
approximation: it is not the event-level OR SF when either muon can trigger.
The framework now supports optional trigger-object matching and an explicitly
scoped independent-single-path OR built from separate data/MC efficiencies
([trigger configuration](../../docs/TRIGGERS.md)). Neither is enabled in this
control configuration: the supplied per-muon SF alone cannot reconstruct that
OR, and path/era matching inputs have not been validated.

The fit POI `mu_DY` scales the `zjets` group in `mumu_z`, using the mass
histogram; statistical and correction templates are enabled. All explicit
normalization priors are labelled placeholders. The two nested regions are
not jointly fitted (their observations overlap). Plots include both regions.
No shape/theory/nonprompt treatment or physics interpretation is supplied.

## Running on validation environment

From the scratch directory (absolute paths required because the wrapper changes
its working directory):

```sh
JULIA_THREADS=4 nice -n 10 bash ~/packages/configured-julia-root-runner.sh \
  --project="$PWD" "$PWD/bin/cascade.jl" run \
  "$PWD/analyses/dy_mumu/analysis.toml" --max-files 2 --workdir "$PWD/out_smoke"
# Repeat with --max-files 6 --workdir "$PWD/out_bounded".
```

The Golden JSON remains an external input; edit `paths.certification` or bind
it explicitly to `${ENV:CASCADE_GOLDEN_JSON}`. Sample globs and POG payloads
also require validation environment storage/CVMFS.
`--max-files` truncates each sample independently and normalizes MC using only
that subset's generator sum. Truncated data is not luminosity-complete at the
configured luminosity. Therefore neither yield ratios nor the fitted POI are
closure/physics statements. The default luminosity metadata records this unknown
exposure; optional certified-LS tracking requires a per-LS luminosity table and
an explicit completeness assumption ([details](../../docs/LUMINOSITY.md)).
See [VALIDATION.md](VALIDATION.md) for the historical Phase-4 runs (massless),
and [Phase-5 validation](../../docs/VALIDATION.md) for the current helpers.
