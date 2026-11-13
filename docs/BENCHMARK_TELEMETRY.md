# Benchmark telemetry v1 (review before real runs)

This is an **opt-in diagnostic**, not a replacement for the existing scientific
comparison/provenance guard. No benchmark has been authorized or run as part of
this change. Review A and this instrumentation together before timing user data.
Python 3.9+ and POSIX are required; no Python packages or Julia dependencies added.

## Entry points

Portable, bounded fixtures (no ROOT, network, SSH or user inputs):

    PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/benchmark/tests -v

Parent's consolidated Julia stdlib test process can include:

    include("test/benchmark_telemetry/runtests.jl")

Standalone equivalent, for the parent **only when authorized**:

    julia --startup-file=no --history-file=no test/benchmark_telemetry/runtests.jl

The Julia test uses a tiny scalar JSON writer stub; it tests the actual production
span library but does not prove full-module/JSON3/physics integration. Parent
should also parse all changed Julia files and run existing no-checkpoint tests in
its consolidated suite. This workstream did not launch Julia.

After review/authorization, the diagnostic runner accepts an exact argv after --:

    python3 tools/benchmark/run.py --output /absolute/new-diagnostic-dir --timeout 300 --interval 0.1 --trace -- COMMAND ARG ...

Omit --trace for ordinary timed diagnostic execution. Both modes use an external
sampler, so neither is a zero-overhead reference; compare the mature ordinary
benchmark separately. Trace/sampler overhead is **not measured yet**. No automatic
retries, cache warming, input discovery, correctness comparisons, input hashes or
benchmark repetitions occur here. The owner supplies the already-reviewed exact
CLI/config/input/thread/cache contract; this runner cannot certify it.

Generate an offline report after the measured process exits (new report directory):

    python3 tools/benchmark/report.py /absolute/new-diagnostic-dir /absolute/new-report-dir

Open new-report-dir/index.html directly; no web server, CDN, JavaScript, network,
font download or graph dependency. SVG files are also standalone. Repeated report
builds from identical inputs produce identical bytes. Input diagnostic file hashes
are included in summary.json, not hashes of scientific inputs/source/runtime.

## Production hooks

Pipeline.jl includes benchmark_telemetry.jl before stage dispatch. Checkpointed
run_step wraps each stage including cached/skipped work; span means invocation,
not necessarily fresh compute. Existing counts remain authoritative.

No-checkpoint hooks cover full invocation (including admission failures), skim,
preparation, each file's select/correct/histogram, overlapping chain_merge and merge,
systematics, fit, plot and publication. Tasks carry sample/chunk IDs; no per-event
instrumentation is added. Chain/merge may overlap file tasks and each other. Stage
wall intervals and existing phase_worker_seconds must **not** be added or treated
as task CPU. The select span covers select_chunk_results; table metadata handoff
is a small unattributed gap. The preparation span covers compile/planning work.

Outside these hooks (e.g. pipeline startup, CLI loading, memory-handoff alternate
route internals, A window internals), resource sampling still works but fine stage
spans are not promised. Do not identify total minus spans as measured JIT or I/O.

Set CASCADE_BENCHMARK_TRACE_DIR to an existing absolute directory outside the
scientific workdir, also after symlink resolution. The supervisor creates it in
its new diagnostic output directory. It removes inherited trace settings in
ordinary mode. Each Julia process creates a pid/monotonic-time JSONL file using
exclusive create, mode 0600; no truncation or collision retry. Directory cannot
change once enabled in a process. No scientific artifact contains trace data.
CASCADE_BENCHMARK_TRACE_MAX_RECORDS is an integer 2..1000000 (default 200000),
including begin/end records; stage/sample/chunk labels are capped at 4096 bytes each. End slots for active spans are reserved; exhausting
the bound fails explicitly before starting another span, never silently truncates.
Instrumentation errors propagate, including from finally. A failed end write can
replace the original error; raw stdout/stderr and unmatched begin records must be
retained for diagnosis. SIGKILL cannot run finally: unmatched begin is incomplete.
Disabled execution does only an environment lookup and ordinary function call;
no trace clocks, file opens, resource reads, IDs or sampler inside Julia.

## Schema 1 and accounting

All JSON/JSONL objects have schema_version=1. CSV rows include that version;
explicit null is written as null (not 0 or an empty string). Timestamps are integer
host nanoseconds: Python explicitly uses CLOCK_MONOTONIC on Linux and
CLOCK_UPTIME_RAW on Darwin to match Julia time_ns()/libuv. Python monotonic_ns
is NOT used (older Darwin Python has a per-process origin); durations/CPU seconds and rates use seconds; memory
and I/O bytes are bytes. CPU cores is CPU seconds / bracket wall seconds (1 = one
fully occupied core), not a percent of a guessed machine capacity.

* trace/stages-*.jsonl: begin/end, span_id (pid:sequence), pid, task_id,
  stage, sample/chunk or null, monotonic_ns, resource_scope=process_nonadditive;
  end status is completed/failed. IDs identify Julia tasks, not worker threads.
* samples.jsonl: sample start/end bracket, supported, root /proc record or null,
  live process-group members and tree_rss_bytes or null. Linux stat utime+stime
  excludes cutime/cstime; CPU is process-wide (all its threads). PID/start_ticks
  identifies a process lifetime. Each member contains its own live counters,
  not a tree total. Non-Linux is explicitly unsupported; /proc metrics are null.
* /proc/PID/io rchar/wchar count syscall characters, syscr/syscw syscall counts;
  read_bytes/write_bytes are process-attributed storage/dirtying accounting,
  not physical device bandwidth. mmap/cache/input footprint/logical requested
  bytes are not substitutes. Linux parent I/O can fold waited descendants; live
  root deltas may include that accounting and are not guaranteed root-only I/O.
* Root RSS is resident pages, **not Julia allocation bytes/live heap**. Live
  process-group RSS is a simultaneous sampled sum with shared-page double
  counting; short-lived, escaped-group children and between-sample peaks can be
  missed. No sampled peak is an exact terminal/true maximum tree total.
* receipt.json: exact argv, cwd, mode, status, timeout, pid, start/end, measured
  wall, wait4 CPU/maxrss with scope labels, group-presence/cleanup result.
  wait4 usage is never added to live/root/member counters. wait4 maxrss is not
  simultaneous tree peak. Terminal tree CPU and storage totals stay null. No
  last-seen dead descendant counters are summed into later parents.
* summary.json, spans.csv: stage wall intervals, status, identities; per-task
  CPU/read/write/allocation are deliberately null. process_scope_sampled_rss_max_bytes
  is process RSS observed wholly inside a span, not task RAM. Short spans with
  no enclosed sample are null. intervals.csv holds root-process counter deltas,
  process scope/nonadditive, and active-at-start/end/any span sets. A delta bracket
  crossing stage boundaries cannot be assigned to either stage. Nested spans
  remain in the active sets; multiple spans are not multiple resource samples.

The sampler records one bracket, then waits the requested interval; actual time
spacing (including /proc scan cost) governs rates. Missing, reset, recycled-PID
or decreasing counters yield null; no interpolation. Sampling is capped at
100000 records (API max 1000000), bound exhaustion fails and kills the worker.
Report input bounds are 1M rows/file and 256 MiB/file (combined traces 256 MiB).
Capacity timeout/interval + 2 must fit max_samples before any directory is created;
CLI --max-samples selects a bound up to 1000000. No complete terminal /proc accounting is claimed, so no zombie-I/O assumption or
WNOWAIT aggregation is needed in v1.

## Lifecycle and failure contract

New output directory only; stdout/stderr are separate files. Popen owns a new
session/process group; blocking wait4 marks the end before joins/cleanup/JSON
parsing/graphs. A timer SIGKILLs that group on deadline. Interrupt/exception cleanup
also kills it and waits for the root. A remaining group after root exit prevents
completed status and is killed; post-cleanup group presence is recorded, not
assumed absent. Escaped process groups are outside this simple diagnostic runner's
ownership contract: use the existing mature supervisor for hostile/daemonizing
commands. Zombie descendants can keep killpg(0) presence true until OS reaping;
that is visible, not converted into a success claim. This runner is not a security
sandbox, disk quota or global guard framework.

Nonzero/timeout/incomplete-process-group status produces a non-success CLI exit.
SIGTERM/SIGHUP handlers are installed before Popen and restored after cleanup;
they produce interrupted receipts like SIGINT. SIGKILL of the supervisor itself
cannot run cleanup and remains outside this simple supervisor contract.
BaseException handling writes failed/interrupted receipts before re-raising;
post-clock exception/KeyboardInterrupt fixtures protect that path. Diagnostic
receipts report lifecycle, **not** scientific validation. Full benchmark completion
and speed claims require the existing provenance/correctness gates and explicit
approval after code review.


## Revision review gates (parent only)

Run this **once** in the parent's remaining authorized Julia test budget:

    PYTHONDONTWRITEBYTECODE=1 python3 tools/benchmark/parent_gate.py --julia /approved/existing/julia --output /absolute/new-parent-gate

It starts exactly one Julia process through the revised traced runner, capped at
120 seconds and four Julia threads. That subject includes the existing real span
library stdlib suite, compares top-level Core.Box lowering counts to the retained
pre-instrumentation no-checkpoint preimage, prints tight native clock brackets,
and exercises the production span writer with four concurrent synthetic tasks
and an explicit failure. Python checks the actual Julia time_ns stamp against the
runner receipt, builds the offline report, and checks complete/failed spans and
per-phase counts. On Darwin it also proves CLOCK_MONOTONIC does not bracket the
same uv_hrtime stamp. No extra tiny Julia PID is needed. The subject deliberately
uses the scalar JSON encoder stub, not unavailable full Cascade dependencies.
This is a library integration gate, **not** full production no-checkpoint science.
The prior parent's consolidated 1360-test gate need not be rerun by this lane.

Report receipt.clock must name a supported explicit host clock; missing/guessed
clock receipts are rejected. Traced mode requires at least one trace file and span.
Incomplete spans are retained with trace_status=incomplete prominently in HTML,
even if process status is completed; consumers must not call that a complete trace.
No stage records in traced mode is an error, not an empty successful report.

A/no-checkpoint concurrency note: A's bounded memory budget is **per active file**;
with file_workers active files, total live budget can multiply by file_workers
(plus merge/other process memory). The initial A benchmark must control one file
worker (e.g. the admitted single-thread case) until mult-file concurrent operation
and total RAM are separately reviewed. This is a documentation constraint only,
not a change to A algorithms or default worker policy.
