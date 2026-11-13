<!-- Historical validation: former standalone TOMLs are frozen in test/config/fixtures; use analysis.toml with --profile sf, phase2 or jer_candidate now. -->

> Since phase 4 (2026-11-04) the separate ttbar configs are profiles of one
> `analysis.toml` (`baseline`, `sf`, `phase2`, `jer_candidate`); old file names
> below refer to those profiles. Frozen copies: `test/config/fixtures/`.
# Phase-2 weight validation

## Scope and files

- `src/Systematics/Systematics.jl`: weights includes/exports and required
  `include("shape/Shape.jl")` (shape implementation owned by the shape lane).
- `src/Systematics/weights/`: term/spec/input/factor types, parser, thread-safe
  correction-set cache, input binding, whitelisted vector expressions, selected
  object/output mapping, lazy event-branch reader, term evaluation, factor
  products, correct hook. Each feature has its own file.
- `test/systematics/runtests.jl`, `test/systematics/weights/`: synthetic correction
  fixtures, expression/parser/product tests, end-to-end pipeline/cache tests,
  baseline-vs-SF config checks, guarded real binding/run and Python comparison.
- `analyses/ttbar_emu/analysis_sf.toml`, `README.md`, `trigger_normsys.toml`, this
  report. `analysis.toml` is unchanged.
- `tools/oracle/sf_dump_events.jl`, `sf_oracle.py`, `sf_README.md`: standalone
  external real-event oracle; Python is not used by the runtime.

No commit, push, root Project.toml or src/Cascade.jl edit. No new dependency or
root module include is needed: Systematics was already included after Corrections
and Selection. Selection's existing `[output] columns` facility is sufficient.

## Gate evidence

Scratch: `/path/to/user/analisis/Cascade_dev/p2-weights`, initially based on
`c7696ba` plus this lane's files, not other lanes' unfinished implementation.
Julia 1.12.2. Thread count <=4; nice priority used. The completed logs recovered
on resumption establish:

| Log | Result |
|---|---|
| `full.log` | EXIT=0; 21425 assertions total: Config 41, Corrections 209, Fit 233, Histograms 28, IO 47, Objects 20011, Pipeline 430, Plotting 173, Selection 115, Systematics 138 |
| `sfrun.log` | full SF skim..merge: 3307 chunks, Systematics 169/169, 26m12.9s (the log's trailing `EXIT $?` is literal, not an exit-code observation) |
| `oracle.log` | Python exit 0; Systematics 599/599, exit 0; 12436 matched events, six TTto2L2Nu and TWminusto2L2Nu files, all 161668 values bit-identical, every column max relative difference 0 |

`full.log`'s baseline reproduction shows exact data histograms/counts, and zero
maximum relative difference for MC bins, sumw2 and cutflow. Total yields:
5905 / 6434.931560809516 (>=1j data/MC),
3836 / 4235.210227397772 (>=2j).

The resumed validation command and result are recorded below separately; this
avoids claiming that the old commands were recoverable from session history.

## SF yields

All MC samples combined, luminosity 1210 pb^-1. These are integral `njet`
yields from `work_sf/merge/histograms.json`; data stays 5905 / 3836.

| Variation | >=1 jet MC | >=2 jets MC |
|---|---:|---:|
| genWeight-only baseline | 6434.931560809516 | 4235.210227397772 |
| nominal | 6010.88601778692 | 3958.7014991678575 |
| muon_idUp | 6018.574557412802 | 3963.7619429250267 |
| muon_idDown | 6003.197478161054 | 3953.641055410703 |
| muon_isoUp | 6022.033757110674 | 3966.154264341499 |
| muon_isoDown | 5999.73827846317 | 3951.2487339942236 |
| electron_recoUp | 6117.666673942714 | 4030.1004227695735 |
| electron_recoDown | 5904.105361631134 | 3887.30257556615 |
| electron_idUp | 6065.2763718155165 | 3994.9115446104483 |
| electron_idDown | 5956.495663758327 | 3922.491453725273 |
| pileupUp | 6001.358881203179 | 3950.40064486671 |
| pileupDown | 6020.617503623192 | 3967.2493632875317 |
| trigger_emuUp | 6010.88601778692 | 3958.7014991678575 |
| trigger_emuDown | 6010.88601778692 | 3958.7014991678575 |

Data/MC before -> after SFs:

- >=1 jet: 0.9176476772438509 -> 0.9823842911887547.
- >=2 jets: 0.905740162598007 -> 0.9690046094170904.

No interpretation of the trigger placeholder as a measured zero uncertainty.

## Source snapshots

SHA256 of gzip files inspected directly on gate on 2026-11-04:

| File under POG | SHA256 |
|---|---|
| MUO/2022_Summer22/muon_Z.json.gz | `07df308866c2903ef95de155def806b3a6e56451783b69a3d0f33afcd55531b7` |
| EGM/2022_Summer22/electron.json.gz | `7a6a3ba13e60667a43b3b728b27ceda57bb38a48dac92d53f1ffe028b88ae898` |
| EGM/2022_Summer22/electronHlt.json.gz | `e5c09b2f0be19c1276ba23c270c1f4d47eddb1a67a5dd0cb2e7f2b921452228f` |
| LUM/2022_Summer22/puWeights.json.gz | `5ab93045d188e1e002e9e24d6e602dcf75cb6019d616ff1c0df65bec0f98bb1a` |

Direct JSON inspection confirms MUO `(eta,pt,scale_factors)`, EGM
`(year,ValType,WorkingPoint,eta,pt)` with sole year `2022Re-recoBCD`, pileup
`(NumTrueInteractions,weights)` with nominal/up/down. The HLT JSON correction
names are `Electron-HLT-SF`, `Electron-HLT-DataEff`, `Electron-HLT-McEff` with
`(year,ValType,Path,eta,pt)`, not an e-mu OR correction.

## Parent integration actions / limitations

1. **Correction artifact cache dependency:** current core
   `Pipeline.step_correct` hashes Selection/Corrections/Pipeline code but omits
   Systematics code. It also hashes correction TOML paths but not the external
   correction-file signature. A file changed at the same path can leave stale
   correct artifacts, despite the in-process correction-set cache correctly
   reloading on size/mtime. Core owner should add Systematics to the code hash
   and resolved set content/signatures to the artifact key. Until then use force
   or a fresh workdir after implementation/set changes. Config changes already
   invalidate correct/downstream; a synthetic test checks this.
2. The required shape include is present in the Mac source. Weight validation
   scratch remains on the phase-1 core; the combined completed shape/fit/core
   snapshot must be tested by the integration owner. No claim of combined
   shape+SF validation is made here.
3. The trigger normsys file is a fit-section **fragment**, not a standalone
   runnable analysis and not merged automatically. A complete nonoverlapping
   channel/fit model and the measured trigger uncertainty remain the fit owner's
   responsibility. The fragment is checked for name/exclusion/placeholder/size.
4. Only six TTto2L2Nu and TWminusto2L2Nu files are covered by the independent per-event oracle;
   the full integrated SF yields include all configured MC and data files.
5. The SF event-branch reader opens the source lazily; selected-object SFs use
   stored outputs. Shape tables must retain those outputs recomputed for the
   varied selected objects. No raw-index/selection reconstruction is hidden in
   the hook.

## Resumed validation invocation

Executed on gate (absolute include paths are necessary: the ROOTPlots wrapper
changes the working directory). The final command uses the two samples actually
present in the existing oracle TSV: TTto2L2Nu (9052 events from two files) and
TWminusto2L2Nu (3384 events from four files).

```bash
D=/path/to/user/analisis/Cascade_dev/p2-weights
export JULIA_THREADS=4 CASCADE_REAL_DATA=1 CASCADE_SF_RUN=1
export CASCADE_SF_WORKDIR=$D/work_sf CASCADE_SF_ORACLE=$D/oracle_out.tsv
export CASCADE_SF_SAMPLES=TTto2L2Nu,TWminusto2L2Nu
export CASCADE_REAL_WORKDIR=$D/work_base
nice -n 10 bash ~/packages/rootplots-gate.sh --project=$D -e \
 'using Test, Cascade; @testset "weights validation" begin include("/path/to/user/analisis/Cascade_dev/p2-weights/test/systematics/weights/runtests.jl"); end; include("/path/to/user/analisis/Cascade_dev/p2-weights/test/pipeline/test_real_reproduction.jl")'
```

Log: `resume_validation_all.log`. Two earlier resumed invocations failed for
command setup, not a weight disagreement: relative include paths were resolved
under ROOTPlots, then a TTto2L2Nu-only sample filter missed the 3384 TW events.
All 117676 values of the 9052 matched TT events were already bit-identical.

Final resumed result: **639/639 weights assertions passed** (1m14.4s), including
real JSON binding, cached full SF run, and all 12436 oracle events / 161668
bit-identical weights. **350/350 baseline reproduction assertions passed**
(5.7s), with maximum relative difference 0 and exact totals. Process **EXIT=0**.
This validates the latest trigger-fragment checks as well as the original lane
implementation. Only documentation and the include-only oracle dumper refactor
changed after the test process loaded the implementation; the product algorithm
was unchanged.
