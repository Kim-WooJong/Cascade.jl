# correctionlib oracle (gate only)

External test oracle for `Cascade.Corrections`. Python and correctionlib are
used here only to produce reference values; Cascade never depends on them.

Files:
- `schema_cases.py` — writes a correction set covering every schema-v2 node type,
  all flow behaviours (incl. `wrap`), and the TFormula / HashPRNG / transform /
  formularef / compound cases of correctionlib's own test-suite.
- `correctionlib_oracle.py` — generates edge, flow, category and tree-guided random
  inputs for every correction of a file, evaluates them with correctionlib and
  writes `*.oracle.json` (floats as `float.hex`).
- `run_oracle.sh` — runs both for the schema cases and the 2022_Summer22 POG files.
- `compare_oracle.jl` + `report_oracle.jl` — Julia comparison (exact or relative
  difference <= 1e-12, errors raised in the same cases, vectorized == scalar) and
  throughput measurement.
- `python_throughput.py` — correctionlib `evalv` throughput on the same points.

Run on gate from the repository copy:

    bash tools/oracle/run_oracle.sh oracle_out
    julia +release --project=. tools/oracle/compare_oracle.jl oracle_out
    CASCADE_REAL_DATA=1 CASCADE_ORACLE_DIR=oracle_out julia +release --project=. -e \
        'using Test; @testset "corrections" begin include("test/corrections/runtests.jl") end'
    (source /cvmfs/sft.cern.ch/lcg/views/LCG_110/x86_64-el9-clang22-dbg/setup.sh; \
        python3 tools/oracle/python_throughput.py oracle_out)
