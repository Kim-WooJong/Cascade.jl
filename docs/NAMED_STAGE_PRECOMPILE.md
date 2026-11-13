# Named no-checkpoint stages

The select, correct and histogram operations inside each no-checkpoint file task
use immutable typed callable objects. The stage bodies, guard order, borrowed
resource ownership and required final publication remain unchanged.

Generation-only declarations prepare the concrete stage/span call forms when
a compatible package image is built. They do not warm ROOT data, decode inputs,
start analysis tasks or bypass world-age protection during image generation.
No new runtime flag is required for the named stage representation. Image build
cost and compatibility are separate from fresh process runtime.

Focused recording fixtures are available through:

```sh
julia --startup-file=no --threads=2 test/named_stages/final_validation.jl
```

The preserved preimage is a regression oracle, not active product code or an
unnecessary historical duplicate. Fixture agreement is not real-data physics
validation or a passing full-package test. See [validation](VALIDATION.md) and
[image coverage](PRECOMPILE_REUSE_COVERAGE.md) for scope and prerequisites.
