# Cascade.jl — Design Draft (v0)

Status: draft, 2026-11-04. Phase 0 (design). No code yet.

## Goal
Julia framework for a complete CMS NanoAOD analysis: data + MC -> selection ->
corrections/scale factors -> systematic variations -> histograms -> profile
likelihood fit -> plots. The ttbar e-mu control analysis (AN-22-103) is the first
validation analysis and must reproduce existing numbers exactly before any
correction is enabled (>=1 jet: data 5905, MC 6434.9316; >=2 jets: data 3836,
MC 4235.2102; per-sample cutflows in out_cutflow/).

## Scope decisions (the maintainer, 2026-11-04)
- Input: CMS NanoAOD only at first. Input access goes through an
  `AbstractEventSource` interface so other formats/experiments can be added.
- Statistical fit included from the start (binned profile likelihood).
- Development/execution on gate; Mac holds the Git original only.
- Every step can be run alone, from a given step, or as a full chain.
- Corrections: native Julia implementation of the correctionlib JSON schema
  (no Python at runtime). Python correctionlib 2.8.0 (LCG_110 on gate) is used
  only as a test oracle.
- Plotting and histogram rendering: ROOTPlots.jl (Hist1D/2D with sumw2).

## Pipeline steps
| Step | Input | Output (artifact) |
|---|---|---|
| skim | NanoAOD files | input index: file signatures, event counts, generator-weight sums |
| select | skim + analysis config | per-chunk event table (kept events, stage, base weight, histogram values), cutflow |
| correct | select + correction sets | per-event weight columns (nominal + up/down) |
| histogram | select + correct | per-chunk histogram store (region x sample x variation x variable) |
| merge | chunk stores | merged store, scaled by sigma*L/sum(genWeight) |
| systematics | merged store | template set, symmetrized/smoothed variations |
| fit | templates + fit config | fit result (POIs, nuisances, covariance, pulls/impacts) |
| plot | merged store / fit result | data/MC plots with uncertainty bands, tables |

CLI sketch:
    cascade run analysis.toml
    cascade run analysis.toml --steps histogram,merge
    cascade run analysis.toml --from fit
    cascade run analysis.toml --only plot --samples TTto2L2Nu

Each artifact records hashes of its inputs, its config section and the code
version. A step whose hashes are unchanged is skipped (make-like). Work is split
in file chunks so failed chunks can be rerun alone and chunks run in parallel.

## Module layout (planned)
- `Cascade.Config`      TOML analysis definition and validation
- `Cascade.IO`          AbstractEventSource, NanoAOD source (UnROOT), lumi mask
- `Cascade.Objects`     object selection, overlap removal
- `Cascade.Selection`   regions, cutflow
- `Cascade.Corrections` correctionlib schema v2 evaluator (pure Julia)
- `Cascade.Systematics` weight-type and shape-type (object-varying) variations
- `Cascade.Histograms`  histogram store (thin, ROOTPlots-convertible; see below)
- `Cascade.Fit`         binned likelihood model, minimization, impacts
- `Cascade.Plotting`    ROOTPlots-based data/MC, bands, ratio panels
- `Cascade.Pipeline`    step graph, artifact cache, CLI

## Core implementation (Phase 1: Config, IO, Objects, Selection, Histograms, Pipeline)

### Analysis definition (TOML)
One file per analysis (`analyses/<name>/analysis.toml`). Sections:
`[analysis]` (name, lumi_pb, workdir), `[paths]` (`${name}` substitution in file
patterns), `[[samples]]` (name, kind mc|data, files globs, format, xsec_pb,
branching_ratio, stream, group), `[data_quality]` (run_range, golden_json),
`[triggers]` (groups, streams, priority, mc), `[[objects]]` (name, collection,
cut, clean = {against, dr}, sort_by), `[variables]`, `[weights]` (mc/data factor
expressions, expression variations), `[[cuts]]` (sequential; `only = "data"|"mc"`),
`[[regions]]` (`after` = last cut of the region), `[[histograms]]` (edges | range
| linspace, values, when, regions), `[merge]` (yield_variable), `[hooks]`.
Sections owned by other areas (`corrections`, `systematics`, `fit`, `plot`) are
kept raw and passed to their hooks. Arrays of tables keep a defined order.

### Expression language
Expressions are Julia syntax, parsed with `Meta.parse` and translated by a
whitelist (arithmetic, comparisons incl. chains, `&& || ! ?:`, bit ops, math
functions, `deltaR`, `mass_massless`). Object scope: bare names are fields of the
collection (`pt` -> `Electron_pt`). Event scope: branches (`genWeight`),
builtins `trigger` (stream logic) and `lumimask` (run range + Golden JSON),
variables (inlined), `length(obj)`, `obj.field[k]` (out of range = error, so
gate with `when`). Each expression becomes a Julia function compiled once per
sample kind (`Core.eval` into `Selection.Kernels`, called via `invokelatest` at
the chunk boundary); cuts are a tuple walked by recursion, so the event loop is
type-stable. Arithmetic keeps the input precision (Float32 NanoAOD columns are
compared to Float64 literals exactly as the reference code did).

### Event sources and reading
`IO.AbstractEventSource`: `nevents`, `column_names`, `read_columns(names;
needed)`, `gen_weight_sum`, `source_signature`, `close_source`; formats are
registered with `register_source_format!` (`nanoaod` via UnROOT, `cols` =
Cascade column files). Columns are `Vector{T}` or `Jagged{T}` (flat content +
offsets). Select reads, for all events, only the columns of the object-free
leading cuts (lumimask, trigger) and weights; object columns are read with a
`needed` mask so baskets without surviving events are not decompressed (jagged
branches stay aligned through the `nX` counter branches).

### Artifacts, keys and caching
Layout under the workdir: `skim/<sample>.json`, `select/<sample>/<chunk>.cols`,
`correct/<sample>/<chunk>.cols`, `histogram/<sample>/<chunk>.json`,
`merge/{histograms.json, histograms_raw.json, samples.json, yields.tsv,
cutflow/<sample>.tsv}`, `systematics/templates.json`, `fit/result.json`,
`plot/index.json`. One chunk = one input file (id = hash of its path). Every
artifact has `<artifact>.meta.json` whose `key` hashes: input signature (path,
size, mtime) or upstream keys, the relevant config sections (canonical JSON),
the source of the code areas involved (and Julia version) and the hook id. A
step is skipped when the key is unchanged; e.g. changing histogram binning
reruns histogram/merge only (select hashes only histogram values/when).
Chunks run on `Threads.nthreads()` tasks; merges always proceed in sorted file
order, so results do not depend on scheduling and the floating-point summation
order equals the reference per-file scripts.

Intermediate format (resolved): Cascade column files (`.cols`: magic, JSON
header, raw little-endian arrays; bit-exact, no extra dependency). The skim step
indexes inputs. The distinct opt-in reduce command writes standalone genuine
ROOT RNTuple bundles with UnROOT >=0.11.11; this is not NanoAOD TTree output.
See REDUCED_SKIM.md.

### Histogram store (resolved)
`HistogramStore`: `Dict{HistKey(region, sample, variation, variable) =>
BinnedHist(edges, sumw, sumw2)}` + `meta`. Fill: underflow dropped, overflow in
the last bin, NaN = no value. Mergeable (`merge_store!`), scalable
(`scale_store!`), JSON-serialised with shortest round-trip floats (bit-exact).
Variation labels: `nominal`, `<name>Up`, `<name>Down`. No ROOTPlots dependency:
`hist_arrays(h)` gives `(edges, sumw, sumw2)` for `ROOTPlots.Hist1D` in Plotting.
MC normalisation: `(xsec_pb * branching_ratio) * lumi_pb / sum(genEventSumw)`.

### Hooks for other areas
`Pipeline.register_hook!(step, f; id)` or `[hooks] <step> = "Module.function"`:
- correct: `f(::CorrectionContext) -> Dict("nominal" => w, "<n>Up" => ..., ...)`
  (context: config, sample, source_path, event table with `entry` indices);
- systematics: `f(::StepContext, merged::HistogramStore) -> HistogramStore`;
- fit: `f(::StepContext, templates::HistogramStore) -> Dict` (JSON);
- plot: `f(::StepContext, merged::HistogramStore, fit_result) -> Vector{String}`.
Defaults: base weight + expression variations; identity; configured likelihood fit;
configured plots/tables. Without a [fit] section, fitting is skipped.

## Corrections (correctionlib in Julia)
Implement schema v2 node types: Category, Binning (flow: clamp/error/value),
MultiBinning, Formula (TFormula subset parsed to Julia expressions),
FormulaRef, Transform, HashPRNG, CompoundCorrection, plus gz JSON loading.
Validation: random and edge-point inputs evaluated by Julia and by Python
correctionlib for every correction in the 2022_Summer22 files used
(MUO muon_Z, EGM electron/electronHlt, LUM puWeights, BTV btagging,
JME jet_jerc/jetvetomaps); exact or <=1e-12 relative agreement required.

## Systematics
- Weight type: one event loop fills nominal + all up/down weights.
- Shape type (JES/JER, lepton scale): object collections are re-derived per
  variation; selection runs once per variation on shared columns.
- Naming follows nuisance names used by the fit config.

## Fit
Binned Poisson likelihood with normfactors, normsys (log-normal),
histosys (shape interpolation), Barlow-Beeston-lite MC stat. Outputs: best fit,
profile scans, pulls, impacts, postfit plots. Model format kept close to the
HistFactory/pyhf JSON concepts so results can be cross-checked with pyhf/combine.

## Open questions
- Intermediate format: resolved (Cascade column files, see Core implementation).
- Histogram store: resolved (thin store, ROOTPlots-convertible, see above).
- Minimizer choice for the fit (Optim.jl vs own Newton with AD).


## Phase-2 integrated configuration

`[corrections.sets]` resolves correctionlib payload paths;
`[[corrections.object_sf]]`, `[[corrections.event_weight]]`, and
`[[corrections.flat]]` define correlated named weight products. Set the correct
hook to `Cascade.Systematics.apply_corrections`. Data is never reweighted by
these MC scale factors.

Each `[[shape_variations]]` entry names a collection and kind (`jes`, `jer`,
`scale`). Optional `samples` limits MC applicability; data is unchanged.
JES binds a correction source; JER binds resolution, scale-factor, and smearing
payloads. Generic scales use `up`/`down` expressions. Optional `met` propagates
jet momentum differences above `met_min_pt`. `nominal=true` enables nominal
JER smearing; its default false intentionally preserves legacy results.

Selection reads columns once per chunk, reruns selection for each variation,
and writes `select/<sample>/<chunk>.<label>.cols`. Correct runs the hook on each
varied table and writes its nominal weights under the matching label in
`correct/`. `CorrectionContext.variation` exposes that label. Merge emits
`shape_yields.tsv` and `cutflow_shape/<sample>/<label>.tsv`. Sample-specific
shape configuration and payload SHA256 fingerprints enter selection keys.

Fit configuration names independent region/variable channels, signal groups,
and normalization nuisances. Weight/shape templates automatically become
histosys; missing sample-specific variations use nominal templates. The
likelihood exports a HistFactory workspace, result report, profile interval,
pulls/impacts and covariance-aware yields. Plotting uses the single
`Histograms.BinnedHist` type through ROOTPlots adapters; postfit propagation
retains cross-bin/sample covariance. Example uncertainty priors are explicitly
placeholders, not analysis recommendations.

## Single-file analysis resolution

Config resolves `[profiles.<name>]` before constructing typed configuration.
CLI/RunOptions `profile` overrides `[options].default_profile`; the base and one
profile deep-merge dictionaries and replace arrays. Switches in `[options]`
then select corrections/shapes, nominal JER, and fit; per-entry `enabled=false`
removes correction, shape or normalization-nuisance terms. Consumers see only
the resolved dictionary. Resolution is nonmutating and excludes the unused
profile catalog from hashes. Existing section-based artifact dependency keys
therefore hash the effective physics settings while preserving fine-grained
cache invalidation. Reader options additionally enter the skim key.

Default workdirs append the selected profile; explicit run workdir overrides
are exact. Legacy files with neither section retain their original behavior.
`cascade check` validates and summarizes without opening events; `cascade init`
copies the commented template without overwriting existing configuration.
`docs/CONFIG.md` is the schema/default reference. Reader normalization branches
and JES/JER payload input aliases are configurable, retaining NanoAOD/POG defaults.

Version0.6 streaming export separates original normalization populations from
physical processing chunks: bounded typed TTree windows -> shape-safe union ->
bounded RNTuple shard buffers -> one logical descriptor/original -> fresh staged
validation -> atomic bundle. Serial/audit/batch use the complete group ledger,
never repeated per-shard denominators or concatenated logical-source Events.
See STREAMING_REDUCED_SKIM.md.
