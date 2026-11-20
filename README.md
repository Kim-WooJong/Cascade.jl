# Cascade.jl

A Julia framework for CMS NanoAOD analyses: data and MC event selection,
correctionlib-compatible corrections, systematic variations, histograms, binned
profile-likelihood fits and native ROOT plots through ROOTPlots.jl.

**Version 0.1.0 · experimental research software.** This is a source snapshot,
not a stable release, registered package or approved physics measurement.
The full test suite has not passed in a source-only environment: reference
configuration tests require the external CMS mask and calibration payloads.
Package loading, CLI smoke checks and scoped tests passed; see the exact
[validation results and limits](docs/VALIDATION.md). Clean-checkout installation
and the declared runtime matrix remain unverified. See also
[external inputs and scientific limits](#external-inputs-corrections-and-scientific-limits).

## What it provides

- Ordered object selection/cleaning, event cuts and regions, trigger selection
  and matching, and data-quality masks.
- MC normalization, explicit luminosity provenance, correctionlib JSON/JSON.gz
  weights, JES/JER shape variations and explicitly configured scale/PDF/PS members.
- Weighted histograms, cutflows, yield tables, fit templates, profile-likelihood
  fits and data/MC plots; technical priors are not measured calibrations.
- Input auditing, checkpointed reruns, local process batches and optional reduced
  ROOT RNTuple export. Reader/memory optimizations are separately opt-in.

## Prerequisites and installation

Use **Julia 1.11 or later within the 1.x series**, as declared in
[Project.toml](Project.toml). Optimized reader/compiler paths may have narrower
runtime and dependency contracts; the complete version matrix is not verified.
From the checkout root, in the environment where the analysis will run:

```sh
julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
julia --startup-file=no --project=. bin/cascade.jl --help
```

Instantiation downloads dependencies. This active project declares
[ROOTPlots.jl](https://github.com/Kim-WooJong/ROOTPlots.jl) from Git tag
`v0.2.2` in `[sources]`; a downstream package installation does not automatically
inherit that source override. **Native ROOT is needed for PNG/PDF rendering**,
not for NanoAOD reading through UnROOT or every configuration/synthetic test.
The built-in plotting path writes tables and skips rendered plots when the
native backend is unavailable; installing Julia packages alone does not prove
that backend is configured. Python utilities are optional, not runtime prerequisites.

## Quick start: init → check → audit → run

```sh
julia --startup-file=no --project=. bin/cascade.jl init my_analysis
julia --startup-file=no --project=. bin/cascade.jl check my_analysis/analysis.toml
# Edit the generated TOML: supply real inputs and justified analysis settings.
julia --startup-file=no --project=. bin/cascade.jl audit my_analysis/analysis.toml --workdir audit_run
# Only after resolving audit findings and supplying required external assets:
julia --startup-file=no --project=. bin/cascade.jl run my_analysis/analysis.toml --workdir analysis_run
```

`init` writes a commented template and refuses to overwrite it. `check` validates
the resolved configuration and expressions and expands file globs, but does not
open event ROOT files. Enabled corrections can require payloads even at this
stage. A successful check is not evidence of input completeness or valid physics.

`audit` freshly inspects all discovered inputs for selected samples, reporting
missing/unmatched files, physical-file aliases, counts and signed generator-sum
provenance. It writes `audit_run/audit/report.json` and `report.md`, including
failed file checks. Optional expected inventories and sample metadata make
assumptions explicit; unknown completeness or exposure stays unknown.

`run` defaults to the ordered pipeline
`skim → select → correct → histogram → merge → systematics → fit → plot`.
Under the explicit workdir above, inspect:

| Output | Purpose |
|---|---|
| `analysis_run/merge/histograms.json` | Merged histogram store |
| `analysis_run/merge/samples.json`, `yields.tsv` | Sample/normalization provenance and yields |
| `analysis_run/merge/cutflow/` | Per-sample cutflow tables |
| `analysis_run/fit/result.json` | Fit result, when fitting is configured/enabled |
| `analysis_run/plot/index.json` | Output index; plots require native ROOT |

Cutflow yields and histogram integrals are distinct quantities: multiple fills,
selection predicates and flow-bin handling can make them differ. Keep generated
outputs outside the maintained source files.

## One analysis entry, optionally split by domain

A single TOML is still supported. The reference
[ttbar entry](analyses/ttbar_emu/analysis.toml) now explicitly includes **10 TOML
fragments**, rather than keeping the analysis in one long file:

```text
analyses/ttbar_emu/
  analysis.toml
  config/
    analysis.toml       # identity, paths, merge
    samples.toml        # ordered sample inventory
    data_quality.toml   # mask, triggers, stream priority
    objects.toml        # objects and cleaning
    selection.toml      # variables, output, weights, cuts/regions
    histograms.toml     # ordered histogram definitions
    corrections.toml    # correction hook and terms
    systematics.toml    # shape variations
    fitplot.toml        # fit and plotting
    profiles.toml       # switches and existing profile overlays
```

The entry declares the complete list explicitly:

```toml
include = ["config/analysis.toml", "config/samples.toml", "config/data_quality.toml",
           "config/objects.toml", "config/selection.toml", "config/histograms.toml",
           "config/corrections.toml", "config/systematics.toml",
           "config/fitplot.toml", "config/profiles.toml"]
```

Includes are literal paths, not directory globs or executable configuration.
Nested includes resolve relative to their declaring file, in declared
depth-first order.

**Asset paths remain relative to the entry directory**, including sample files,
Golden JSON and correction payloads; moving a section into `config/` does not
change that base. Relative workdirs instead resolve from the process working
directory. `[paths]` substitutions use `${name}`; explicit `${ENV:NAME}` bindings
require a nonempty environment variable and never evaluate shell commands.

Tables compose recursively, but **duplicate leaves are errors even if equal**.
An ordered array is one leaf: keep each complete samples/objects/cuts/histograms
array in one fragment. Includes never append arrays or silently override keys.
Missing/repeated files (including aliases), cycles, malformed include lists and
unknown keys fail; schema checks include inactive profiles after composition.

Configuration provenance covers the ordered entry and transitive TOML dependency
closure, including comments and inactive profiles. Batch plans, no-checkpoint
runs and reduced exports use that closure, not just the entry bytes. A single
file keeps its historical byte SHA-256 identity. Splitting alone does not alter
scientific section hashes or array order; payloads, datasets and environment are
not certified by the TOML closure hash.

### Main sections at a glance

This small **illustrative MC-only configuration** shows the core sections. Its
luminosity and cross section are placeholders, not reference calibrations;
supply appropriate NanoAOD files under `inputs/` beside the entry before running.

```toml
[analysis]
name = "example"
lumi_pb = 1000.0
workdir = "cascade_out/example"

[paths]
input = "inputs"

[[samples]]
name = "signal"
kind = "mc"
files = ["${input}/*.root"]
format = "nanoaod"
xsec_pb = 1.0
group = "signal"

[[objects]]
name = "jets"
collection = "Jet"
cut = "pt > 30 && abs(eta) < 2.4"
sort_by = "pt"

[variables]
njet = "length(jets)"

[weights]
mc = ["genWeight"]

[[cuts]]
name = "one_jet"
expr = "njet >= 1"

[[histograms]]
name = "njet"
values = ["njet"]
edges = [0.0, 1.0, 2.0, 3.0, 4.0, 8.0]

[options]
default_profile = "baseline"
fit = false

[profiles.baseline]
```

For data, configure `[data_quality]` and `[triggers]` for the actual era/streams.
Optional `[output]` retains variables for downstream correction bindings.
Correction terms use `[hooks] correct = "Cascade.Systematics.apply_corrections"`,
`[corrections.sets]` payload aliases and ordered `[[corrections.object_sf]]` or
`[[corrections.event_weight]]` terms. Shape variations, theory weights, `[fit]`
and `[plot]` describe the enabled model explicitly; payload semantics, member
indices, normalization and efficiencies are not inferred. Start from the full
[commented template](analyses/TEMPLATE.toml), not placeholder physics values.

### Profiles

`--profile NAME` selects one overlay and overrides `options.default_profile`.
Tables deep-merge; **arrays replace in full**, and profiles do not inherit from
each other. Default workdirs receive a profile suffix; an explicit `--workdir`
is used exactly, without that suffix. Fragment composition does not change these
rules or existing reference profiles.

The ttbar default is uncorrected `baseline`; `sf` enables corrections, `phase2`
enables corrections/shapes/fit with unsmeared nominal JER, and `jer_candidate`
opts into nominal JER smearing. `theory_example` declares inspected TT scale/PS
members, not an inferred PDF prescription. These are technical configurations,
not approved physics models. Once the external prerequisites below are met:

```sh
julia --startup-file=no --project=. bin/cascade.jl check analyses/ttbar_emu/analysis.toml --profile sf
julia --startup-file=no --project=. bin/cascade.jl audit analyses/ttbar_emu/analysis.toml --profile baseline --workdir audit_ttbar
julia --startup-file=no --project=. bin/cascade.jl run analyses/ttbar_emu/analysis.toml --profile baseline --workdir run_ttbar
```

## Execution modes

- **Default: checkpointed execution.** Intermediate per-file artifacts support
  caching and reruns. `run` accepts mutually exclusive `--steps a,b`, `--from STEP`
  or `--only STEP`, plus `--samples a,b`, `--force` and `--max-files N` (`0`: all).
  Partial runs still need compatible upstream artifacts. A file limit does not
  establish calibrated luminosity or dataset completeness.
- **Fresh full chain:** `[execution] checkpoints = false` publishes final outputs
  only, without reading/writing intermediate checkpoints or supporting resume.
  Partial plans and batch execution are not supported in this mode; other
  compatibility restrictions are checked before data work.
- **Local batches:** `batch plan/worker/run/status/merge` freezes file tasks and
  verifies receipts for retry/resume. Theory reductions occur after complete merge.
- **Reduced export:** `reduce FILE --output-dir UNUSED_DIR` is a separate opt-in
  ROOT RNTuple export, not a change to the default NanoAOD/index-only skim.
- **Reader/memory options:** serial windowed selection and the reusable decoder
  are opt-in. The default-off `execution.reuse_raw_destinations` reuses raw
  decoder content buffers only; it requires `windowed_selection = true` and
  `windowed_reusable_decoder = true`, and rejects event-range execution. Selected
  outputs do not alias raw buffers; low-level borrowed raw content is valid only
  until that branch is read again. Do not retain it as an owned result.

These execution options do not change science guards, selection definitions or
floating-point accumulation order. Allocation reduction is not a general speed
guarantee: small shared-host launch measurements do not establish broad runtime
improvements. Experimental candidates and archived performance plans are not
shipped capabilities.

## External inputs, corrections and scientific limits

ROOT data/MC files, calibration payloads, the real CMS certification mask and raw
execution records are **not bundled**. The ttbar reference expects
`analyses/ttbar_emu/Cert_Collisions2022_355100_362760_Golden.json`, or an explicitly
configured external path. Its historical SHA-256 is
`ba4feb79a5b39a15a73ca0279b1bf9be4966ec816e5263f92fdee086662f73a9`.
Obtain authorized inputs from their official distributors and verify era,
provenance and applicable terms.

The reference correction paths target the CMS JSONPOG CVMFS payload tree.
Supply that tree or configure equivalent verified external payload paths.
**Without the required CMS mask and, for correction-enabled profiles, the
CVMFS/external payloads, the reference run cannot be reproduced.** Some
configuration/integration checks also need those assets. Never substitute an
empty/synthetic mask or disable quality cuts to force a reference test to pass.

No file-count/event-count luminosity extrapolation, trigger efficiency map or
final physics prescription is inferred. The separate modern-counting example
remains blocked pending its required calibration and physics evidence.
Historical focused checks and benchmarks apply only to their recorded versions,
inputs and settings; no fresh full-suite pass or final cross-section result is
asserted here. The historical site-pinned decoder harness is not distributed;
its explicit opt-in request fails rather than claiming a modified pin was validated.

## Reference material and license

- [Documentation index](docs/README.md), [configuration reference](docs/CONFIG.md) and [validation limits](docs/VALIDATION.md).
- [Analysis template](analyses/TEMPLATE.toml) and [ttbar entry](analyses/ttbar_emu/analysis.toml): concrete configuration examples.
- [CLI entry point](bin/cascade.jl): invoke with `--help` for command syntax.
- [Project dependencies](Project.toml): declared compatibility and source override.

Cascade original code is under the [MIT License](LICENSE). Identified external
portions retain the copyright and terms in [THIRD_PARTY.md](THIRD_PARTY.md).
The project license does not relicense external libraries, calibrations or datasets.
