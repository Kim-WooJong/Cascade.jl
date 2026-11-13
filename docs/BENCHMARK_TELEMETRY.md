# Optional benchmark diagnostics

The Python utilities in `tools/benchmark/` launch one bounded diagnostic process
and produce an offline report. They use the Python standard library, are not
part of Cascade runtime installation, and do not establish scientific equivalence
or a validated performance result on their own.

## Runner and report

Run from the repository root with new output directories outside the checkout:

```sh
python3 tools/benchmark/run.py --help
python3 tools/benchmark/report.py --help
python3 tools/benchmark/run.py --output /path/to/new-run --timeout 60 -- command arg1
python3 tools/benchmark/report.py /path/to/new-run /path/to/new-report
```

The runner executes the supplied argument vector directly, records stdout/stderr,
receipts and bounded resource samples, and cleans up its owned process group on
failure or timeout. Inspect process status and existing receipts before retrying;
do not replace a slow or failed measurement with a faster attempt. Linux and
macOS use explicit host clocks; unsupported clocks are rejected before output.
Linux `/proc` metrics may be unavailable on other systems.

`--trace` expects records from the production trace library enabled separately
through `CASCADE_BENCHMARK_TRACE_DIR`. The runner owns its trace directory. Missing,
malformed, incomplete or out-of-clock records must remain explicit failures or
incomplete diagnostics, not a passing scientific benchmark. The former parent-only
Julia validation wrapper is not distributed because its required local helper
was removed; this guide does not advertise that unsupported workflow.

## Interpretation

- Launch-to-exit wall includes process startup, runtime initialization and required
  output work. Prepare inputs/configuration consistently and label anything excluded.
- Fresh process does not imply cold filesystem caches or no precompiled images.
- Spans can nest/overlap. Worker sums and GC counters are not exclusive stage wall
  or independently additive CPU shares. Resource samples are process-scoped, not
  exact per-task attribution.
- RSS is not cumulative allocation; summed process RSS can double-count shared pages.
  wait4 maximum RSS is not a simultaneous process-tree peak.
- Process I/O counters, syscall characters and total input file size are not physical
  device bandwidth. Missing terminal/tree totals remain unavailable.
- Correctness, numerical bounds, metadata identity and input/output scope require
  a separately declared comparison contract. Do not infer them from a timing report.

## Tool tests

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/benchmark/tests -v
```

These are runner/report fixtures, including lifecycle/error/trace handling. They
do not load the full Julia package or prove real ROOT analysis correctness.
