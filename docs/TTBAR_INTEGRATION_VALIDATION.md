# Optional ttbar technical integration

The reference ttbar integration driver is separate from the default unit-test
entry point. It checks a configured combination of selection, corrections, shapes,
theory vectors, reduced export, merge and fit/plot consumers. It is not a final
physics prescription, a stable-release certification or a claim of complete coverage.

## Prerequisites

- A frozen, explicitly configured Julia/ROOT execution environment with dependencies
  already available; the driver is not an installer or scheduler.
- Authorized NanoAOD inputs, calibration payloads and the correct certification mask.
  Never substitute a dummy mask or infer calibrated exposure from a subset.
- An absolute frozen project path, an unused result directory and an explicit
  `CASCADE_ROOTPLOTS_RUNNER` pointing to the site-configured Julia/ROOT runner.

```sh
export CASCADE_TTBAR_PROJECT=/absolute/path/to/frozen-validation-copy
export CASCADE_TTBAR_AREA=/absolute/path/to/unused-results
export CASCADE_ROOTPLOTS_RUNNER=/absolute/path/to/configured-julia-root-runner.sh
export CASCADE_TTBAR_DRIVER=/absolute/path/to/the-frozen-integration-driver.sh
bash "$CASCADE_TTBAR_DRIVER"
```

Select the existing driver from `test/ttbar_integration/` in the frozen checkout.
Do not restore removed helpers or silently substitute a different driver.
Inspect every phase receipt and existing output before retrying. Reuse switches
require their own frozen-reference equality checks; they do not authorize replacing
failed results, rewriting inputs or restarting completed science phases.

The opt-in `integration_small` profile composes technical settings and preserves
normal defaults. Data/MC normalization, logical original-file ownership, selected
entries, signed weights, histogram moments and output validity must be compared
under the declared contract. Floating reductions with different partitioning need
explicit numerical bounds; do not silently clip bins or change physics inputs.

See [configuration](CONFIG.md), [theory weights](THEORY_WEIGHTS.md),
[reduced export](STREAMING_REDUCED_SKIM.md), [batch execution](BATCH_EXECUTION.md)
and [validation limits](VALIDATION.md). Full-suite/runtime-matrix validation of the
current public snapshot remains incomplete; old phase execution logs are not kept
as the current user guide.
