# Cascade.jl

A Julia framework for CMS NanoAOD analyses: selection, correctionlib-compatible
corrections, systematic variations, histograms, binned fits and native ROOT
plots through ROOTPlots.jl.

**Version 0.1.0 · experimental research software.** Full-package testing, clean
installation and the declared runtime matrix are not yet fully verified.
Technical examples are not approved physics measurements. See
[validation and support limits](docs/VALIDATION.md).

## Quick start

From a checkout, using an explicitly configured execution environment:

```sh
julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
julia --startup-file=no --project=. bin/cascade.jl --help
julia --startup-file=no --project=. bin/cascade.jl init my_analysis
julia --startup-file=no --project=. bin/cascade.jl check my_analysis/analysis.toml
# After configuring real inputs:
julia --startup-file=no --project=. bin/cascade.jl run my_analysis/analysis.toml
```

The declared Julia compatibility starts at 1.11 within the 1.x series. Optimized
reader paths have narrower audited runtime/dependency contracts. This checkout
uses a ROOTPlots.jl Git source override in Project.toml; downstream installation
does not automatically inherit that override. Native ROOT is required for rendered
plots, not every synthetic/configuration test. Instantiation downloads dependencies.

## Configuration and examples

- Start from the commented [analysis template](analyses/TEMPLATE.toml) and
  [configuration reference](docs/CONFIG.md). One TOML defines each analysis.
- Profiles deep-merge tables and replace arrays. Use `--profile NAME` to select
  an explicit overlay; execution optimizations are not enabled merely by installing.
- Before processing external files, use
  `julia --project=. bin/cascade.jl audit my_analysis/analysis.toml --workdir audit_run`.
  [Input auditing](docs/INPUT_AUDIT.md) reports provenance and unknowns; it does not
  certify dataset completeness or calibrated exposure.
- The [synthetic fit/plot demonstration](examples/fit_demo/README.md) is the main
  end-to-end example. Run generators in a disposable working copy and keep outputs
  outside the maintained source tree. Native rendering has separate prerequisites.
- Shipped [ttbar](analyses/ttbar_emu/README.md) and [DY](analyses/dy_mumu/README.md)
  configurations are reference analyses requiring external inputs and payloads.
  The separate [modern counting example](analyses/ttbar_emu/MODERN_COUNTING.md)
  intentionally refuses execution without its required calibration/physics evidence.

## Execution and documentation

The [documentation index](docs/README.md) covers triggers, regions, luminosity,
theory weights, batch execution, reduced export and bounded reader modes.
Intermediate checkpoints remain the default;
[`execution.checkpoints = false`](docs/NO_CHECKPOINTS.md) is a fresh full-chain
mode with final outputs only and no intermediate resume. Keep the documented
compatibility, ownership and failure restrictions when selecting any opt-in mode.

[Architecture](docs/DESIGN.md), [development conventions](docs/CONVENTIONS.md),
[validation](docs/VALIDATION.md) and the optional
[benchmark diagnostics](docs/BENCHMARK_TELEMETRY.md) describe the maintained interfaces.
Python tools are optional development/oracle utilities, not Cascade runtime dependencies.

## External data and certification

ROOT inputs, calibration payloads, raw execution records and the real CMS
certification mask are not bundled. Obtain authorized inputs from their official
distributors and verify their provenance. Reference configurations expect
`analyses/ttbar_emu/Cert_Collisions2022_355100_362760_Golden.json`, or an explicitly
configured external path. The historical reference SHA-256 is
`ba4feb79a5b39a15a73ca0279b1bf9be4966ec816e5263f92fdee086662f73a9`.
Do not substitute an empty/synthetic mask, disable quality selection to make a
reference test pass, or infer luminosity completeness from a file limit.
Configuration/reference-analysis tests requiring that mask need it supplied first.
The historical site-pinned decoder harness is not distributed; its explicit
opt-in request fails rather than pretending a modified input pin was validated.

## License

Cascade original code is under the [MIT License](LICENSE). Identified external
portions retain the copyright and terms in [THIRD_PARTY.md](THIRD_PARTY.md).
The project license does not relicense external libraries, calibrations or datasets.
