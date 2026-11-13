# Cascade.jl

Julia framework for CMS NanoAOD analyses: data and MC event selection,
correctionlib scale factors, systematic variations, histograms, binned
profile-likelihood fits and ROOT-quality plots (via ROOTPlots.jl).

Status: research software in active development; package version **0.1.0**.
This is an **experimental research snapshot**, not a stable release or a final
physics result. Fifteen standalone test areas passed across focused runs;
**the complete package test suite is not yet verified** (bounded attempts
stopped during batch tests). `Pkg.test()` and the supported runtime matrix
remain unverified. Do not infer general scientific validity from these checks.

Start with the [documentation index](docs/README.md),
[development guide](CONTRIBUTING.md) and [Git preparation checklist](docs/REPOSITORY.md).

## Getting started from a checkout

Use Julia 1.11 or later within the 1.x series as declared in `Project.toml`.
Some optimized reader paths and compiler-level tests have narrower audited
runtime/dependency contracts; see the development guide before enabling them.

From the repository root, in the environment where you will run the analysis:

```sh
julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
julia --startup-file=no --project=. bin/cascade.jl --help
julia --startup-file=no --project=. bin/cascade.jl init my_analysis
julia --startup-file=no --project=. bin/cascade.jl check my_analysis/analysis.toml
```

Instantiation downloads dependencies. The checkout declares ROOTPlots.jl from
its `v0.2.2` Git tag in `[sources]`; use this active project rather than assuming
a downstream package install inherits that source override. Native ROOT is
needed for rendered plots, not for every configuration or synthetic test.
Input ROOT files, calibration payloads and site-specific reference outputs are
not bundled. Shipped CMS analysis configurations are reference analyses, not
ready-to-run datasets; adapt input/payload paths before `audit` or `run`.

Cascade.jl is distributed under the [MIT License](LICENSE). External libraries,
calibration payloads and datasets retain their respective upstream terms;
this license does not relicense third-party material. See the retained
[third-party copyright and license notices](THIRD_PARTY.md).

## One configuration per analysis

```sh
julia --project=. bin/cascade.jl init my_analysis
julia --project=. bin/cascade.jl check analyses/ttbar_emu/analysis.toml --profile sf
julia --project=. bin/cascade.jl audit analyses/ttbar_emu/analysis.toml --profile baseline --workdir audit_run
julia --project=. bin/cascade.jl run analyses/ttbar_emu/analysis.toml --profile baseline
```

The ttbar configuration defaults to the uncorrected `baseline` reference;
`sf`, `phase2`, `jer_candidate`, and `theory_example` are opt-in profiles
in that same file.
Profiles deep-merge tables and replace arrays, with isolated default workdirs.
See [configuration reference](docs/CONFIG.md) and the commented
[template](analyses/TEMPLATE.toml). Technical-profile normalization/trigger
priors remain placeholders, not a final physics model.

## Reusable analysis helpers

The same configuration controls optional independent-single-path trigger OR
weights and trigger-object matching ([triggers](docs/TRIGGERS.md)), massive
pair kinematics and region predicates with observed-channel overlap checks
([regions](docs/REGIONS.md)), and explicit luminosity provenance plus clearly
named yield columns ([luminosity](docs/LUMINOSITY.md)). External payload paths
may use explicit `${ENV:NAME}` bindings. Defaults preserve the ttbar reference;
no measured efficiency map or luminosity is inferred from a file limit.

## Input audit before an analysis

`cascade audit` reports missing/unmatched inputs, physical-file aliases/shared
samples, event counts and signed generator-sum provenance. Optional sample
metadata and explicit expected inventories live in the same TOML. Reports are
written even when file checks fail; unknown inventory completeness and exposure
stay unknown. See [input auditing](docs/INPUT_AUDIT.md).

## Explicit theory vector weights

Scale/PDF/PS member indices and normalization are declared, never guessed.
Members merge before histogram-wise envelope/replica/Hessian reductions and fit
template construction. Defaults stay opt-out. The ttbar theory_example profile
uses inspected scale/PS layouts only; no PDF set is inferred. See
[theory weights](docs/THEORY_WEIGHTS.md) and
[validation evidence](docs/THEORY_WEIGHTS_VALIDATION.md).

## Deterministic local process batches

Opt-in `cascade batch plan/worker/run/status/merge` freezes file tasks and
verifies receipts for interruption-safe retry/resume. Existing serial defaults
and sample-wise normalization are unchanged; theory reduces only after complete
merge. Batch rejects unsafe output path components and preexisting symlink
ancestry; published plot indexes refer to final result files. See
[batch execution](docs/BATCH_EXECUTION.md) and
[validation](docs/BATCH_VALIDATION.md).

## Execution modes

- [Reduced ROOT RNTuple export](docs/STREAMING_REDUCED_SKIM.md) streams bounded
  input windows and shards large originals; the NanoAOD TTree/index-only skim
  defaults are unchanged.
- [`execution.checkpoints = false`](docs/NO_CHECKPOINTS.md) computes a fresh
  full chain, publishes final outputs only and cannot resume intermediate work.
  The default remains `true`. Historical validation notes are scoped to their
  recorded versions, settings and inputs.
- Bounded/windowed reader optimizations are explicitly opt-in; see the
  [execution guides](docs/README.md#execution-and-performance) for contracts
  and limitations. Do not infer universal speedups from individual benchmarks.

The independent [modern counting analysis](analyses/ttbar_emu/MODERN_COUNTING.md)
is intentionally blocked until its configuration-bound calibration and physics
evidence is supplied; it is not an approved cross-section result.

## Development proposals and historical evidence

See the [performance optimization proposal](docs/PERFORMANCE_OPTIMIZATION_PROPOSAL.md)
and [phased implementation plan](docs/PERFORMANCE_IMPLEMENTATION_PLAN.md) for future
systematics-heavy execution, incremental reruns, and fair RDF benchmarks.
These are historical design references, not a current feature checklist.
Some work has since been implemented; use the corresponding execution guides
and scoped validation records in the documentation index for current context.

The [ttbar e-mu selection/SF-to-plot benchmark plan](docs/TTBAR_EMU_SF_PLOT_BENCHMARK_PLAN.md)
is the first proposed comparison: equivalent Cascade/C++ RDF nominal selection,
SF/PU, one histogram/PNG, direct phase timings and workload-extension costs. It
does not require the full workflow or broad performance refactor. Planning only;
the proposal itself is not proof of an executed benchmark. Later validation
records describe only their own measured workloads.

## Public snapshot inputs and provenance

See [publication scope](PUBLICATION.md) before running reference-analysis tests.
The CMS certification mask is an external input, not part of the MIT code grant.
Historical documentation uses anonymized home/host paths; raw execution records
and private development history are not distributed. Export edits were checked
statically, not rerun as a new full scientific validation.
