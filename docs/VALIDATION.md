# Validation and limitations

Cascade 0.1.0 is an experimental research snapshot, not a stable release or a
validated final physics analysis. Earlier focused development runs passed fifteen
standalone test areas. **That is not a passing run of this public tree.** Bounded
canonical-suite attempts stopped during batch tests. The complete suite,
Pkg.test(), a fresh installation and the supported-version matrix remain
unverified. Documentation cleanup does not rerun those checks.
No passing CI badge, universal speedup or final cross-section result is asserted.

## Environment and external inputs

- Project.toml declares Julia 1.11 and later in the 1.x series, UnROOT 0.11.11
  compatibility and ROOTPlots 0.2.2 compatibility. The active checkout supplies
  the ROOTPlots v0.2.2 Git source override. Compatibility ranges are not exact
  dependency pins, and downstream environments need not inherit that override.
- Optimized paths may require an exact audited dependency source contract and
  Linux mapping evidence. Compiler/typed-IR and package-image checks can depend
  on the Julia minor version; earlier Linux Julia 1.12.2 checks do not establish
  behavior on every declared version or platform. See each execution guide.
- Native ROOT is needed for rendered plots. Plotting tests skip native rendering
  when ROOTPlots reports ROOT unavailable; other tests can exercise plot arrays,
  uncertainty propagation and tables without producing a native image.
- ROOT inputs, calibration payloads, prior analysis outputs and oracle outputs
  are separate prerequisites, not bundled datasets.

### CMS certification mask: required even for reference configuration tests

The reference analysis expects the external file
analyses/ttbar_emu/Cert_Collisions2022_355100_362760_Golden.json.
Obtain an authorized CMS certification JSON from its official distributor and
provide that expected relative file or configure a valid external path using
[explicit environment bindings](CONFIG.md). Verify provenance, era and content
identity when reproducing an analysis. The Cascade MIT license does **not**
license this mask, calibration payloads or datasets; see
[third-party notices](../THIRD_PARTY.md).

Configuration loading validates that a nonempty configured mask path exists.
Consequently even tests that only load the shipped reference profiles, including
some config, pipeline and feature regressions, need the real mask. A missing
configured file must remain an error: do not suppress it, disable the lumimask,
or substitute an empty/synthetic JSON to make a reference physics check pass.
The low-level run-range-only mask API is not certification. Synthetic masks in
isolated synthetic fixtures prove only fixture behavior, never CMS certification
or calibrated luminosity.

## Test entry points

Run from the repository root in an explicitly prepared environment. These are
commands to run, **not claims that this snapshot has passed them**:

~~~sh
# Downloads dependencies; fresh-install behavior is not yet validated.
julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'

# Canonical test dispatcher (may require the external reference mask).
julia --startup-file=no --project=. test/runtests.jl

# Package test entry point; not yet verified for this snapshot.
julia --startup-file=no --project=. -e 'using Pkg; Pkg.test()'

# Package-free focused harnesses that include selected production source files.
julia --startup-file=no --project=. test/execution_options/runtests.jl
julia --startup-file=no --project=. test/event_ranges/runtests.jl
julia --startup-file=no --project=. test/windowed_reusable_decoder/runtests.jl

# Package-level focused areas; prerequisites vary by included tests.
julia --startup-file=no --project=. test/corrections/runtests.jl
julia --startup-file=no --project=. test/fit/runtests.jl
julia --startup-file=no --threads=4 --project=. test/parallel_columns/runtests.jl
julia --startup-file=no --threads=4 --project=. test/basket_decode/runtests.jl
julia --startup-file=no --project=. test/source_reuse/runtests.jl
~~~

The canonical dispatcher discovers area runtests.jl files and launches selected
standalone harnesses in child Julia processes with the active project and thread
count. A successful child-process assertion counts an area, not its scientific
assertions. Other areas keep their shared include order. Standalone success is
not proof that the aggregate dispatcher or Pkg.test succeeds.

### Optional oracles and real-input checks

Enable only after supplying authorized inputs and an appropriate environment:

| Check | Activation / prerequisites |
|---|---|
| Correction evaluator vs correctionlib | CASCADE_REAL_DATA=1 and CASCADE_ORACLE_DIR containing generated .oracle.json outputs; [oracle tools](../tools/oracle/README.md) use Python correctionlib as an external oracle, not a Julia runtime requirement |
| Per-event SF oracle | CASCADE_SF_ORACLE points to the oracle TSV; CASCADE_SF_WORKDIR to the corresponding SF-run workdir; optional CASCADE_SF_SAMPLES limits sample names |
| Fit vs pyhf | CASCADE_PYHF_ORACLE=1; the test helper expects a bash-sourceable Python environment via CASCADE_LCG_VIEW; optional CASCADE_PYHF_CASES selects cases |
| Prior ttbar plotting outputs | CASCADE_REAL_DATA=1 and TTBAR_CTRL pointing to the required prior outputs; native rendering separately depends on ROOT |
| Parallel columns / detached decode | CASCADE_PARALLEL_REAL=1 / CASCADE_DECODE_REAL=1, respectively, plus CASCADE_PARALLEL_MC and CASCADE_PARALLEL_DATA and the real mask; fixtures assert specific event populations, not arbitrary ROOT files |
| Correction source reuse | CASCADE_SOURCE_REUSE_REAL=1, CASCADE_SOURCE_REUSE_REFERENCE pointing to compatible persisted selections, optional CASCADE_SOURCE_REUSE_PROFILE, plus original sources/payloads/mask |
| Technical ttbar integration | Separate test/ttbar_integration scripts, not automatically discovered as an area; require explicitly configured inputs, output area and, for the shell runner, CASCADE_ROOTPLOTS_RUNNER |

Do not turn on all flags indiscriminately or treat skipped oracle/render checks
as passing coverage. Some real-input harnesses have deliberately fixed population
or identity contracts. The historical site-pinned decoder harness is not shipped;
its opt-in dispatcher errors rather than accepting a substituted pin.

## What synthetic and recording tests establish

Focused tests include real production functions against generated columns,
synthetic basket bytes, recording sources or stubbed external boundaries. Their
scope is explicit in each harness:

- Event-range tests exercise scheduling, ordered replay, admission, cancellation
  and ownership with physical ROOT I/O stubbed. They do not establish native
  codec behavior, real source identity, physical I/O throughput or CMS yields.
- Named-stage tests prove routing, reference identity, call order and declared
  precompile types; selection, correction, histogram and fit callees are fakes
  there, not independently validated science.
- Windowed reusable-decoder tests exercise production config/window/selection
  logic and synthetic uncompressed basket handling. UnROOT metadata parsing,
  XZ/LZMA checksums, real-file planning, source binding and full dispatch require
  separate native checks. Read [the feature contract](WINDOWED_REUSABLE_DECODER.md).
- Lightweight entry-count fixtures use source-derived parsing primitives and an
  IOBuffer seam. They do not validate an actual compressed TTree metadata block
  or real Events/Runs parity. Retain the [upstream notices](../THIRD_PARTY.md).
- Queue/reader/source-reuse tests demonstrate the tested lifetime, mask and
  failure paths. They are not proofs of OOM recovery, uninterruptible cleanup,
  hard RSS bounds or arbitrary concurrent source mutation safety.

## Scientific and performance boundaries

Preserve selected-entry order, primitive types/bits, cutflows, histogram edges,
sumw/sumw2 and signed original-population generator denominators when comparing
execution paths. MC normalization remains sample-wise; reduced shards do not
each acquire a new normalization population. Theory layouts and normalization
are declared, and members reduce only after complete merge. Data is not given
MC scale factors. See [configuration](CONFIG.md), [theory weights](THEORY_WEIGHTS.md),
[luminosity](LUMINOSITY.md), [regions](REGIONS.md) and
[batch execution](BATCH_EXECUTION.md).

The old uncorrected ttbar output fixtures target data/MC yields 5905/6434.9316
for at least one jet and 3836/4235.2102 for at least two jets. These are scoped
reference regression targets, not newly reproduced public-tree results or final
physics validation. Technical fit/trigger priors can be placeholders. The
[modern counting analysis](../analyses/ttbar_emu/MODERN_COUNTING.md) remains
blocked until its configuration-bound calibration and physics evidence exists.

Historical warm decoder improvements did not establish whole-process superiority;
a matched ordinary CLI pair was slower with detached decoding. Parallel column
reads and asynchronous/windowed modes likewise carry no general speed guarantee.
Keep opt-in defaults unchanged. Logical requested bytes, overlapping calls and
queue credits are not physical storage bandwidth, CPU utilization or RSS bounds.
A faster warm phase is not a sustained-scan, fair RDF or end-to-end result.

Current lifetime and compatibility contracts are retained in
[detached decoding](BASKET_DECODE_VALIDATION.md),
[parallel columns](PARALLEL_COLUMN_READ_VALIDATION.md) and
[correction source reuse](CORRECTION_SOURCE_REUSE_VALIDATION.md).
