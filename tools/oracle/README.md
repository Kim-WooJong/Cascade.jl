# Optional correctionlib oracle

These development utilities compare Cascade corrections with the independent
Python correctionlib implementation. Python/correctionlib are not Cascade runtime
dependencies. Use an existing, explicitly configured oracle environment and new
output directories outside the maintained source tree.

## Synthetic schema comparison

```sh
# OUT is a new absolute output directory; create it explicitly first.
python3 tools/oracle/schema_cases.py "$OUT/schema_cases.json"
python3 tools/oracle/correctionlib_oracle.py "$OUT/schema_cases.json" "$OUT/schema_cases.oracle.json"
julia --startup-file=no --project=. tools/oracle/compare_oracle.jl "$OUT"
```

`schema_cases.py` collects schema-v2 node/flow, TFormula, HashPRNG, transform,
formularef and compound cases. `correctionlib_oracle.py` produces reference values,
including exact hexadecimal float transport. The Julia comparator retains the
existing exact/relative-error and error-behavior rules; vectorized and scalar
results must agree. See the script help/source for input limits and switches.

`run_oracle.sh` is a convenience driver for its explicitly coded CMS CVMFS and
LCG environment. Inspect those existing paths before invoking it; it does not
install dependencies and is not a portable environment setup command. Do not
source a foreign Python/ROOT library environment into Julia blindly. Other
installations should invoke the individual scripts with their own authorized
correction payloads and configured interpreters.

## Existing reference outputs

```sh
CASCADE_REAL_DATA=1 CASCADE_ORACLE_DIR="$OUT" julia --startup-file=no --project=. -e 'using Test; @testset "corrections" begin include("test/corrections/runtests.jl") end'
python3 tools/oracle/python_throughput.py "$OUT"
```

The explicit flag enables tests requiring pre-existing reference outputs; it is
not proof that all physical inputs or corrections are available. Keep synthetic
schema agreement, real calibration checks, throughput diagnostics and final
physics validation distinct. The [scale-factor workflow](sf_README.md) requires
additional real inputs. Full-package validation remains incomplete; see
[validation limits](../../docs/VALIDATION.md). Upstream fixture notices are retained
in [THIRD_PARTY.md](../../THIRD_PARTY.md).
