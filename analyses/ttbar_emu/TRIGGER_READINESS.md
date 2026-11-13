<!-- Historical validation: former standalone TOMLs are frozen in test/config/fixtures; use analysis.toml with --profile sf, phase2 or jer_candidate now. -->

> Since phase 4 (2026-11-04) the separate ttbar configs are profiles of one
> `analysis.toml` (`baseline`, `sf`, `phase2`, `jer_candidate`); old file names
> below refer to those profiles. Frozen copies: `test/config/fixtures/`.
# eμ trigger correction readiness

Reviewed: 2026-11-04. Scope: the current Run2022C control analysis, not all
2022 datasets. No correction values or configuration were changed by this review.

## Decision

**Not ready to replace the trigger placeholder with a measured correction.**
The inspected POG payloads contain single-lepton corrections, but no demonstrated
correction for this analysis's complete trigger OR. The published analysis
supports negligible *dilepton-trigger uncertainty* on its high-pT plateau; it
does not establish that the complete OR has exactly unit data/MC efficiency ratio.
Keep nominal/up/down unity explicitly unresolved, not as a measured result.

## Exact target

`analysis_phase2.toml` uses certified run range 356309–356615, 1.21 fb^-1,
one tight isolated electron and muon, each pT >35 GeV and |η|<2.4, with the
electron ECAL gap removed. The MC trigger requirement is the OR of:

- `HLT_Mu8_TrkIsoVVL_Ele23_CaloIdL_TrackIdL_IsoVL_DZ`
- `HLT_Mu23_TrkIsoVVL_Ele12_CaloIdL_TrackIdL_IsoVL`
- `HLT_IsoMu24`
- `HLT_Ele32_WPTight_Gsf`

Data priority is MuonEG → Muon → EGamma, removing overlaps. The desired
event correction is ε_data(OR)/ε_MC(OR), with matching run coverage, offline
selection and trigger versions. Single-leg SF products are not that ratio;
an OR also depends on overlaps/correlations and, where applicable, DZ efficiency.

## Evidence and applicability

| Source | Established fact | Boundary |
|---|---|---|
| [CMS TOP-22-012 publication](https://cms-results.web.cern.ch/cms-results/public-results/publications/TOP-22-012/) and [paper §3](https://arxiv.org/html/2303.10680#Ch0.S3) | The 1.21 fb^-1 analysis uses single/dilepton triggers at the corresponding thresholds. Data/MC trigger efficiencies are measured in pT and |η| bins with Z tag-and-probe, and simulation is corrected. | The paper does not provide numerical efficiency maps or the exact OR combination implementation. |
| [Paper §4](https://arxiv.org/html/2303.10680#Ch0.S4) | Both dilepton candidates have pT >35 GeV. | This supports threshold compatibility, not a numerical closure test of this implementation. |
| [Paper §6](https://arxiv.org/html/2303.10680#Ch0.S6) | Single-lepton SF uncertainty is <1%; additional electron/muon uncertainties are 1.0%/0.5% for jet-multiplicity dependence. It states: “The uncertainty in the dilepton trigger efficiency is negligible due to offline lepton pT requirements that are much larger than the trigger requirements.” | Do not transplant the single-lepton percentages onto the full eμ OR, or infer an exactly unit nominal SF from negligible uncertainty. |
| Paper §6 uncertainty table | Trigger efficiency contributes 0.3% to the **combined cross-section uncertainty**. | This is a post-combination impact, not a 0.3% eμ normsys prior. |
| [Prior direct payload inspection](VALIDATION.md#source-snapshots), [official POG repository](https://gitlab.cern.ch/cms-nanoAOD/jsonpog-integration) | Summer22 MUO has single-muon trigger SFs. EGM `electronHlt.json.gz` has `Electron-HLT-SF`, `Electron-HLT-DataEff`, `Electron-HLT-McEff` with `(year,ValType,Path,eta,pt)`. Hashes are recorded in the validation report. | These inspected files do not establish an eμ OR correction. This is not a claim that no relevant CMS-internal measurement exists. Payloads were not freshly reinspected in this review. |

The paper also reports a **2.3% luminosity uncertainty** for this measurement.
The demonstration's 1.4% prior is labelled a placeholder and must not be cited
as the paper's value. Replacing it requires choosing and documenting the intended
luminosity calibration/model; it is separate from obtaining a trigger correction.

## Smallest next step

1. Obtain the original analysis's trigger efficiency maps and combination recipe
   (AN-22-103 supporting material or an analysis-approved equivalent), including
   run validity, leg/DZ treatment, statistical/systematic variations and correlations.
   This is the shortest route to reproducing the published treatment.
2. If unavailable, measure/validate the OR in an appropriate independent control
   sample. The denominator must not already require the target OR. Existing
   lepton-trigger-selected samples alone cannot determine its absolute efficiency.
   Specify the reference-trigger selection and its bias/correlation corrections;
   compare data and MC versus both leptons' pT/η and jet multiplicity.
3. Encode the resulting ε_data/ε_MC correction and variations, validate plateau
   closure and stream-overlap handling, and only then replace the placeholder.
   Do not represent the same uncertainty in both histosys and normsys.

Full-data SF+shape processing can still serve as a technical validation while
this input is unresolved; it does not make the fitted normalization a final
physics measurement.

## Retrieval limits

The CMS publication page and arXiv HTML were fetched directly and read on the
review date. The configured web-search tool had no registered handler.
The public GitLab raw payload URL returned an authentication HTML page, not JSON;
the existing recorded CVMFS payload inspection was used instead. The linked
[HEPData record](https://doi.org/10.17182/hepdata.135832) could not be inspected
(HTTP 403). No absence claim is made about those inaccessible resources or
CMS-internal analysis material. Confidence is high in the published prescription
and the incompatibility of naïvely multiplying single-leg SFs; the availability
of a transferable numerical OR payload remains unresolved.
