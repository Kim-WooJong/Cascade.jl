# Configuration-only DY control: technical validation

Date: 2026-11-04. Source snapshot: `115436badf22fe513af6cb00ebad3592f27df6b7`.
Scratch: `gate:~/analisis/Cascade_dev/p4-dy`. No framework source changes,
commits, or pushes were made for this analysis. This report makes no physics
claims. In particular the truncated data is not the full 1.21 fb^-1 dataset.

## Files and API

The only repository additions are `analysis.toml`, `README.md`, and this file
under `analyses/dy_mumu/`. The original TOML schema suffices: samples, data
quality, triggers, objects, variables/output, cuts/regions, histograms, weights,
correction hook and object/event SF terms, fit, and plot. There is no dependency
on the parallel options/profiles implementation. The archived framework source
was not resynchronized after setup; only this analysis directory was overlaid.
Config SHA256:
`074624f9514e28a8988d84a880da5785054b171d04a58270bdff9808015677e7`.

## Input inventory

These are available ROOT file counts on gate, not all processed files:

| Config sample | Available files |
|---|---:|
| DYto2L_MLL50 | 899 |
| DYto2L_MLL10to50 | 213 |
| TTto2L2Nu | 386 |
| TTtoLNu2Q | 841 |
| TWminusto2L2Nu | 77 |
| TbarWplusto2L2Nu | 97 |
| WWto2L2Nu | 117 |
| WZto3LNu | 109 |
| WZto2L2Q | 68 |
| SingleMuon | 35 |
| Muon | 124 |

No additional diboson/single-top sample absent from this inventory was invented.
All MC xsec_pb and branching_ratio values are reused unchanged from the ttbar
baseline, checked by sample name. The certification payload is the same external
file used by that baseline. Both requested DY mass samples are present.

The MUO payload was inspected directly with `gzip -dc .../muon_Z.json.gz`.
It contains `NUM_IsoMu24_DEN_CutBasedIdTight_and_PFIsoTight` (and a separate
Medium-ID/ISO version). The Tight/Tight correction is bound to eta, pt and
scale_factors nominal/systup/systdown. Both pipeline runs evaluated it
successfully. Tight ID and isolation are applied to indices [1,2], trigger
only to [1], and the BCD pileup term is the same as ttbar.

## Executed commands

From the Mac repository:

```sh
git archive HEAD | ssh gate 'mkdir -p ~/analisis/Cascade_dev/p4-dy && tar -x -C ~/analisis/Cascade_dev/p4-dy'
rsync -az analyses/dy_mumu/ gate:analisis/Cascade_dev/p4-dy/analyses/dy_mumu/
ssh gate 'cp ~/analisis/Cascade/Manifest.toml ~/analisis/Cascade_dev/p4-dy/Manifest.toml'
```

Each run was launched through SSH with nohup, the following command inside a
`bash -c` wrapper, logs redirected, and its exit code saved in `<name>.exit`:

```sh
cd ~/analisis/Cascade_dev/p4-dy
/usr/bin/time -p nice -n 10 bash ~/packages/rootplots-gate.sh \
  --project=$PWD $PWD/bin/cascade.jl run $PWD/analyses/dy_mumu/analysis.toml \
  --max-files 2 --workdir $PWD/out_smoke > smoke.log 2>&1
/usr/bin/time -p nice -n 10 bash ~/packages/rootplots-gate.sh \
  --project=$PWD $PWD/bin/cascade.jl run $PWD/analyses/dy_mumu/analysis.toml \
  --max-files 6 --workdir $PWD/out_bounded > bounded.log 2>&1
```

The wrapper invokes `~/.juliaup/bin/julia +release` with 4 threads. Smoke was
launched first; bounded started after smoke selection/corrections/merge had
succeeded, while its fit/plot completed (maximum 8 Julia threads across the two).
Monitoring used separate bounded polls, with sleep <=30 seconds; no persistent
polling loop was installed.

## Pipeline outcomes and timing

Both runs exited **0**, through all eight steps. No failed pipeline attempt or
framework patch was needed.

| Step | Smoke: 2 files/sample | Bounded: 6 files/sample |
|---|---:|---:|
| skim | 11 samples, 6.82 s | 11 samples, 7.35 s |
| select | 22 chunks, 15.46 s | 66 chunks, 27.53 s |
| correct | 22 chunks, 11.46 s | 66 chunks, 14.26 s |
| histogram | 22 chunks, 2.27 s | 66 chunks, 2.69 s |
| merge | 4.66 s | 4.95 s |
| systematics | 1.05 s | 0.96 s |
| fit | 35.74 s | 33.82 s |
| plot | 83.96 s | 77.57 s |
| wall including startup/compilation | 181.76 s | 178.59 s |
| CPU user / system | 201.54 / 11.31 s | 247.28 / 11.82 s |

### Z-window yields

Strictly 70 < m_mumu < 110. Base MC is luminosity-scaled genWeight cutflow;
corrected MC is the integral of the nominal corrected njet histogram. Both
count each accepted event once (njet includes zero, overflow folded). Data is
unchanged by the SF hook.

| Run | Data before/after | MC before SF | MC after ID + ISO + trigger + pileup |
|---|---:|---:|---:|
| Smoke | 7294 | 777438.8828299613 | 730854.4819809819 |
| Bounded | 73526 | 849094.3461361566 | 786078.7484608929 |

These numbers are *not* data/MC closure tests: each data PD is independently
truncated, whereas each MC subset is independently scaled to the full nominal
luminosity. Changing from two to six files is not a luminosity extrapolation.

Both technical fits report `status=ok`, `converged=true`; the bounded fit used
13 iterations, smoke 150. The POIs are deliberately not interpreted as a DY
measurement. The low-mass DY sample has one negative-weight Z-window event in
both subsets (corrected yields -24.03915 / -10.24657); it is retained, not clipped.
The fit groups both DY samples into `zjets`.

## Outputs

Under each of `out_smoke/` and `out_bounded/`:

- skim indexes and per-chunk select/correct/histogram artifacts;
- merge/histograms.json, histograms_raw.json, samples.json, yields.tsv, cutflows;
- systematics/templates.json;
- fit/result.json, result.txt, workspace.json (profile interval, pulls, impacts);
- plot/index.json, prefit plots for all seven observables in both regions,
  postfit fitted-channel plot, impacts, cutflow and tables.

Each run produced 23 PNG and 23 PDF files. This is artifact generation evidence,
not proof of delivery/rendering in a user's browser.

## Framework gaps, assumptions, and configuration workarounds

1. **Trigger event SF is not solved.** HLT_IsoMu24 is an event-level OR over
   possible muons. The payload supplies a per-muon SF, not the separate data/MC
   efficiencies needed for an exact OR. Object-SF products cannot turn this into
   the correct OR. A leading-leg-only SF is explicitly labelled an approximation.
   No trigger-object matching is configured; leading pT >26 does not prove that
   the leading muon fired the trigger. This remains a physics-readiness blocker.
2. **External Golden JSON.** The baseline refers to a relative mask not present
   in a clean archive. Only three analysis files are authorized here, so the
   configuration names the existing gate mask explicitly. Portability requires
   providing this external file or changing the path.
3. **No options/profiles dependency.** At the archived schema, switching SFs off
   would require a config edit or hook choice. To avoid a second config and avoid
   rerunning selection, this report compares the preserved base cutflow to the
   corrected histogram integral. This validates before/after yields without a
   new framework feature.
4. **Yield naming is easy to misread.** `merge/yields.tsv` field `yield` remains
   base-weight cutflow yield even in an SF run; `hist_yield` is corrected.
   `histograms_raw.json` is unnormalized, not an SF-off histogram store.
5. **Partial data exposure is not tracked.** `--max-files` selects sorted files
   per sample, not a common integrated luminosity, and MC normalization uses the
   subset generator sum. No automatic subset-luminosity adjustment is available
   in this exercise. The plot label explicitly says bounded technical subset.
6. **Kinematic helpers.** The available invariant-mass helper is massless, not
   an exact massive-muon four-vector. Dimuon pT uses a whitelisted sqrt/sin/cos
   expression because no dedicated vector-sum helper is required/used.
7. **Sequential/nested regions.** The wide-mass region is defined before the
   Z-window cut; its histograms therefore survive that later cut. No disjoint
   region bookkeeping is automatic: fitting both nested regions would double
   count data. Only the Z region is fitted.
8. **Zero jets and empty fit bins.** Jet multiplicity starts at -0.5 to keep
   zero-jet DY events, unlike ttbar's >0 baseline. The full wide-mass binning is
   retained in the Z fit, including empty out-of-window bins (their MC-stat
   parameters are fixed by the existing fit implementation). No fitter range
   selection or automatic rebinning was needed.
9. **No PD event deduplication was added.** Both PDs use the same Muon stream,
   relying on their disjoint reference run coverage. The configured framework
   stream priority is not an event-ID duplicate remover.
10. **Corrections need explicit saved kinematics.** Both muon indices require
    their pt/eta expressions in [variables] and [output]. The object-SF hook does
    not silently recover arbitrary selected-object columns. Pileup reopens the
    input branch using the persisted entry index.
11. **Execution environment.** ROOTPlots' gate wrapper changes cwd to its package
    directory; absolute --project, script, config and --workdir paths are needed.
    Native ROOT rendering requires that wrapper/LCG environment. This is an
    execution workaround, not a code change.
12. **Scope of the demonstration.** genWeight and NanoAOD branch conventions,
    inherited cross sections, shared luminosity, weight-only systematics and
    placeholder priors remain assumptions. No new MET/filters, JEC/JER/veto-map,
    theory, nonprompt, matching, or precision-mass treatment is claimed. This
    proves this second control selection runs by configuration, not arbitrary
    experiment/format or physics readiness.

## Unverified

No full-file run, independent correctionlib oracle comparison, independent
pyhf likelihood comparison, physics validation, or browser-delivery check was
performed in this lane. Existing framework tests were not rerun because no
framework source was changed. The trigger approximation must be replaced before
interpreting normalization or agreement physically.

## Independent artifact checks

A scratch-only Julia verification feature `p4-dy/verify.jl` was run through the
same wrapper (no Python runtime/oracle was used):

```sh
cd ~/analisis/Cascade_dev/p4-dy
/usr/bin/time -p nice -n 10 bash ~/packages/rootplots-gate.sh \
  --project=$PWD $PWD/verify.jl $PWD > verify.log 2>&1
```

Exit **0**, **843/843 assertions passed**: configuration/input checks 33/33,
smoke artifact checks 217/217, bounded checks 593/593. Wall 28.04 s, user 33.40 s,
system 1.64 s. The script/log remain on gate, outside the repository write scope.
Checks cover inventory and inherited cross sections/branching ratios, per-sample
file limits, finite aligned weights, both saved muons' pT/eta and ordering,
unchanged data weights, all four MC up/down SF pairs, agreement between njet and
mass histogram Z-window integrals, successful fit/placeholder labels, and all
65 indexed output files per run existing with nonzero size. Source branches
independently confirm every persisted data event fires HLT_IsoMu24 and passes
the same run-range/Golden-JSON mask. Selected input-file run ranges are disjoint
between SingleMuon (maximum 356386) and Muon (minimum 356428) in the bounded set;
these are input-file ranges, not selected-event ranges.

| Run | Input events indexed | Data/MC before SF | Data/MC after SF |
|---|---:|---:|---:|
| Smoke | 2,809,785 | 0.00938208798285089 | 0.009980098884020804 |
| Bounded | 17,491,337 | 0.08659343962727287 | 0.09353515807921359 |

Again, these ratios only describe independently truncated samples; they have no
luminosity-complete data/MC or physics interpretation.
