# ttbar e-mu: one analysis, opt-in profiles

`analysis.toml` is the single analysis definition. Its default `baseline` profile
keeps the genWeight-only reference. Choose `--profile sf` for lepton/pileup SFs,
`--profile phase2` for the combined technical demonstration, or
`--profile jer_candidate` for nominal JER smearing. Profiles use separate
`cascade_out/ttbar_emu/<profile>` workdirs. Frozen pre-migration configurations
are test fixtures under `test/config/fixtures/`; they are not production entry points.
Every section (samples, objects, cuts, correctionlib payloads, shape variations,
fit, plot) is written **once**; profiles only flip `[options]` switches
(`corrections`, `shape_variations`, `fit`, `jer_nominal`), so a change to a cut
or SF payload applies to every profile. `cascade check <file> --profile <p>`
prints the resolved setup. See [CONFIG.md](../../docs/CONFIG.md) for the full schema.

## Corrections and official sources

The files themselves, not inferred correction names, define the input schema.
All paths below are relative to
`/cvmfs/cms.cern.ch/rsync/cms-nanoAOD/jsonpog-integration/POG/`.
Official repository: <https://gitlab.cern.ch/cms-nanoAOD/jsonpog-integration>.
Run2022C uses Summer22 (preEE), not Summer22EE.

| File | Correction | Inputs and configured keys |
|---|---|---|
| `MUO/2022_Summer22/muon_Z.json.gz` | `NUM_TightID_DEN_TrackerMuons` | signed `eta`, `pt`, `scale_factors`: nominal/systup/systdown; JSON applies abs(eta) internally |
| same | `NUM_TightPFIso_DEN_TightID` | same inputs/keys |
| `EGM/2022_Summer22/electron.json.gz` | `Electron-ID-SF` | `year="2022Re-recoBCD"`, `ValType=sf/sfup/sfdown`, `WorkingPoint`, `eta`, `pt` |
| same | same | ID `WorkingPoint="Tight"`; reco `Reco20to75` below 75 GeV and `RecoAbove75` at/above 75 GeV |
| `LUM/2022_Summer22/puWeights.json.gz` | `Collisions2022_355100_357900_eraBCD_GoldenJson` | `NumTrueInteractions=Pileup_nTrueInt`, `weights=nominal/up/down` |

Electron eta is supercluster eta, `Electron_eta + Electron_deltaEtaSC`, summed
in the original NanoAOD Float32 precision during selection, then stored in the
event table. Both selected leptons have pt > 35 GeV, so no reco-below-20 term is
needed. Reco pt-range terms share a nuisance name and vary coherently.

The Summer22 MUO file has single-muon trigger corrections, and
`EGM/2022_Summer22/electronHlt.json.gz` has single-electron trigger corrections;
neither supplies the efficiency/SF for the analysis' e-mu cross-trigger OR
single-lepton combination. Single-leg SFs cannot simply be multiplied to model
that OR. `trigger_emu` is therefore an explicitly unresolved flat term:
nominal/up/down = 1, not a measured zero uncertainty. The phase2 and jer_candidate fit sections include its configurable
normsys placeholder (`size=0`, `placeholder=true`). Supply an analysis-specific
measurement and exclude flat templates from histosys to avoid double counting.
No trigger uncertainty is invented.

## Generic schema and API

```toml
[hooks]
correct = "Cascade.Systematics.apply_corrections"

[corrections.sets]
muon = "${jsonpog}/MUO/2022_Summer22/muon_Z.json.gz"

[[corrections.object_sf]]
name = "muon_id"
set = "muon"
correction = "NUM_TightID_DEN_TrackerMuons"
object = "muons"                 # configured object selection/collection
indices = [1]                    # positions in that selection, not raw NanoAOD indices
inputs = { eta = "eta", pt = "pt" }
systematic = "scale_factors"
nominal = "nominal"
up = "systup"
down = "systdown"
```

`object` identifies an `[[objects]]` selection, which in turn specifies its raw
collection. Indices follow its configured ordering (`sort_by` if requested);
index 1 is only leading-pt if that selection is pt-sorted (ttbar keeps exactly
one electron and muon). Every requested position must exist in every kept row.
Expose the referenced selected-object expressions via `[variables]` and
`[output] columns`, e.g. `mu1_pt="muons.pt[1]"`. Missing outputs fail with an
explicit diagnostic; the hook does not silently reselect objects. Products are
taken across `indices`. An optional object `when` gates a term (else factor 1).

Inputs are matched by the correction's declared name/type, not TOML order.
String-typed inputs take literal constants (year, WP); numeric inputs take
numbers or whitelisted expressions (`abs(eta)`, arithmetic, comparisons, etc.).
A whole expression matching an output variable reuses that column, preserving
selection-time precision. Expressions are not arbitrary Julia code and vector
conditions are eager, not short-circuit guards for missing columns.

`[[corrections.event_weight]]` uses the same name/set/correction/inputs and
systematic keys, without object/indices/when. It reads event-level source
branches through the event table's 1-based `entry` indices; e.g.
`inputs={NumTrueInteractions="Pileup_nTrueInt"}`. Output variables are also
available. `[[corrections.flat]]` takes `name`, numeric `nominal` (default 1),
`up`, `down`. Corrections are MC-only; data keeps its base weights.

`Systematics.apply_corrections(ctx)` implements the existing CorrectionContext
hook; `correction_weights(cfg,sample,path,table)` is its direct API.
`parse_corrections(cfg)` returns `CorrectionsSpec`; absent configuration is
identity. `ObjectScaleFactor`, `EventWeight`, `FlatWeight` describe terms;
`combine_weights(base,terms)` builds the output columns. Supporting public
binding/evaluation APIs have docstrings alongside their implementation.

Nominal is base weight times every nominal factor. Each `<name>Up/Down` replaces
only the factors with that name, leaving all other terms nominal. Equal names
are fully correlated (used for the reco pt split). Expression-weight variations
multiply the corrected nominal. Products are rebuilt rather than divided by
nominal factors, so zero/negative base weights remain valid. Histogram consumers
receive `nominal`, `<name>Up`, `<name>Down`.

## Validation

See `tools/oracle/sf_README.md` for the independent Python correctionlib oracle
and `test/systematics/weights/` for synthetic, integration and guarded real-data
tests. Python is oracle-only; no runtime dependency was added. The oracle
reselects leptons from raw NanoAOD branches and checks per-event products, not
only integrated yields.

Gate artifacts/logs: `~/analisis/Cascade_dev/p2-weights/`. The SF run processed
3307 chunks; 12436 selected TTto2L2Nu and TWminusto2L2Nu events from six raw files were checked
against correctionlib 2.8.0: all 161668 values (13 columns) were bit-identical.
The full baseline reproduction had maximum relative difference 0 for MC
histograms/sumw2/cutflow and exact data histograms. Detailed run results and
remaining integration limitations are in `VALIDATION.md`.


## Combined phase-2 demonstration

`analysis.toml` remains the bit-exact genWeight-only reference;
`analysis.toml --profile sf` adds measured lepton/pileup correction payloads;
`analysis.toml --profile phase2` additionally enables JES/JER, the observed-data fit,
and prefit/postfit output. Run on gate with the established ROOTPlots wrapper:

```sh
JULIA_THREADS=8 bash ~/packages/rootplots-gate.sh --project=. bin/cascade.jl run analyses/ttbar_emu/analysis.toml --profile phase2
```

The combined configuration is a technical demonstration, **not a finalized
physics uncertainty model**. Trigger SF is unity and its normalization
uncertainty is an explicitly unresolved zero-size placeholder. Luminosity and
background normalization priors are demonstration assumptions. JER uses
`nominal=false` to preserve the SF-only nominal: Up/Down both smear relative
to an unsmeared nominal and need not bracket it. Set `nominal=true` when
adopting a consistently smeared nominal for physics use and revalidate.

This analysis has no b-tag selection or discriminator observable; applying
per-tagging SFs to its inclusive jets would not be justified. BTV payload
parsing/oracle support is not equivalent to a validated tagged/untagged event
weight method. A future tagged analysis needs its working point, efficiencies,
and correlation prescription before that method can be validated.

Shape selections run again on shared input columns. The corrections hook is
re-evaluated on each shape-selected table, so its nominal SF products accompany
migrated events. Only separate one-at-a-time shape and weight templates are
stored, not all combinations of nuisances.

## Nominal-JER candidate and physics readiness

`analysis.toml --profile jer_candidate` is a separate technical candidate with nominal JER
smearing enabled; baseline and phase-2 configurations remain unchanged. Its
78-file validation passed through fit/plot and the exported pyhf cross-check;
see [JER_READINESS.md](JER_READINESS.md) for exact counts and limitations. This
is not full-dataset nominal-JER validation or a finalized physics prescription.

[TRIGGER_READINESS.md](TRIGGER_READINESS.md) records the official trigger
evidence and missing numerical OR correction. The published luminosity
uncertainty is 2.3%; the current 1.4% model remains an explicitly labelled
demonstration placeholder, not the published uncertainty. Upstream jet
calibration provenance, the JES evaluation convention and final priors remain
open before physics interpretation.
