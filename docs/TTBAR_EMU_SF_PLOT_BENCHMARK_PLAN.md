# ttbar e-mu: Cascade versus RDataFrame benchmark execution plan

Revision: 2026-11-06, following the owner's 19:55 scope clarification.
Status: DOCUMENT PLAN ONLY. No adapter, benchmark, test, gate job, installation,
optimization, source release, or resumed p11 validation is authorized by this file.
The owner must approve a bounded implementation/execution ticket separately.
A read-only timing-method review informed this revision; it is not runtime validation.

## 1. Decision and scope

Build two equivalent small programs that do exactly this:

    identical TTto2L2Nu ROOT inputs
      -> e-mu objects and ordered event cuts
      -> nominal lepton SF and pileup weight
      -> one weighted njet histogram
      -> the same normalization and native rendering procedure
      -> one completed, verified PNG

This answers the professor's requested selection/SF/histogram comparison. It does
NOT require the full Cascade stage graph, all13 samples, background/data stacks,
a reduced-data export, batch orchestration, JES/JER, theory members, a fit,
postfit plots, impacts, or deployment. The broader optimization roadmap is a
separate, profile-driven follow-on, not a prerequisite.

Two conclusions must remain separate:
- Primary: the measured cost of the declared kernel-adapter workload through PNG.
- Secondary: which costs limit event processing and justify a bounded optimization.

The adapter is not the full Cascade CLI. It must reuse Cascade's actual compiled
selection, correction and histogram kernels, not replace them with a hand-tuned
second physics implementation. If a later CLI measurement is wanted, label it
separately and include its artifact/provenance/recovery costs.

## 2. Source, ownership and execution boundary

Last accepted milestone:9071405/v0.6.0. The working tree contains an uncommitted
0.6.1 integration/hash-fix checkpoint. p11 was stopped by the owner at18:00;
its current full regression and end-to-end comparison are incomplete. Do not
resume p11, reuse its elapsed times as RDF evidence, or call it an accepted release.

Before implementation, freeze a source export rather than a moving working tree:
1. Record accepted HEAD, complete benchmark source list, dirty patch if selected,
   Project, runtime Manifest, compiler and dependency versions.
2. Recommended baseline boundary: accepted9071405 plus ONLY the explicitly
   recorded, digest-equivalent canonical_hash byte-vector patch if selected.
   Give it a separate benchmark candidate ID; do not call it fully released0.6.1.
   The patch's focused tests are existing evidence, not a substitute for any
   newly applicable validation. The unpatched accepted baseline may be retained
   as a secondary diagnostic; never silently mix source identities.
3. Verify the diff in Selection, Objects, Corrections, Systematics, Histograms
   and IO. No scientific-kernel rewrite belongs in this initial benchmark.
4. Freeze benchmark adapters and nominal-only configuration separately. Any later
   optimization receives a new candidate ID with the same fixed comparison inputs.

Mac: source, plans and adapters only. Gate: all execution, input data, build products,
ROOT outputs, logs and measurements in a new isolated area. Preserve originals,
p6-p11 and the uncommitted checkpoint. Never install or resolve packages merely
because this plan names a dependency. First inspect existing ROOT, correctionlib,
C++ compiler and Julia capabilities; report a missing dependency as a blocker.

## 3. Exact analysis workload

### 3.1 Sample and input population

- MC sample TTto2L2Nu only; no data, background, PD overlap or Golden JSON cuts.
- Same complete, ordered original files and Events entry ranges on both sides.
- Existing paths are under nano_slim: these are already branch-slimmed inputs,
  not a claim to be reading untouched production NanoAOD. Both engines read the
  same format, compression and bytes; no new event skim on one side only.
- Use whole-file prefixes for timing-size changes. Do not filter or truncate the
  event population merely to make a timing look better. Record original count,
  actually visited count, selected count, file bytes and necessary branch bytes.
- Compute original signed Runs/genEventSumw once per selected original, in declared
  order. Preserve missing/invalid/true-zero/negative semantics. Require finite
  nonzero aggregate before normalization; never substitute retained Events weights.
- Proposed sizes: first1, first2 and first4 sorted files, after availability and
  pilot resource checks. These are proposed counts, not confirmed inventories.
  If they do not separate fixed from variable costs, select a different nested
  set BEFORE final timing, record the reason, and obtain the required time budget.
- Use the same inventory for both engines. A size test need not be linear in N:
  also report file count, jagged multiplicity, compression and selected fraction.

### 3.2 Trigger: explicitly four paths

For MC, logical OR of:
1. HLT_Mu8_TrkIsoVVL_Ele23_CaloIdL_TrackIdL_IsoVL_DZ
2. HLT_Mu23_TrkIsoVVL_Ele12_CaloIdL_TrackIdL_IsoVL
3. HLT_IsoMu24
4. HLT_Ele32_WPTight_Gsf

Missing required branches fail preflight. Trigger SF is not supplied by this OR.
The existing unity trigger placeholder is omitted from BOTH programs; no physical
trigger-efficiency claim or artificial trigger variation is introduced.

### 3.3 Objects and cuts, in configuration order

Signal electron: pt>35, abs(eta)<2.4, cutBased>=4, and NOT
1.444<abs(eta+deltaEtaSC)<1.566. Signal muon: pt>35, abs(eta)<2.4,
tightId, pfRelIso04_all<0.15. Veto electron/muon use pt>10 with the same configured
eta, gap and ID/isolation rules. Exact strictness of all boundaries is preserved.

Jets: original Jet columns, pt>30, abs(eta)<2.4, (jetId & 2)!=0, deltaR>0.4 from
selected signal electrons and muons; stable descending-pt ordering with original
order retained on ties. No additional JEC, JES variation or nominal/varied JER.

| Stage | Condition |
|---|---|
| all | All declared Events entries |
| trigger | Four-path OR above |
| two_leptons | Exactly one selected electron AND exactly one selected muon |
| extra_lepton_veto | Exactly one veto electron AND exactly one veto muon |
| opposite_sign | Selected charges multiply to a negative number |
| mll | Existing mass_massless expression >20GeV |
| njet_ge1 | At least one selected cleaned jet |
| njet_ge2 | At least two selected cleaned jets |

Only region emu_ge2j is active. Remove emu_ge1j from the isolated benchmark config,
so the retained correction population is the final selected population. Restrict
actual histogram, region and sample arrays; do not calculate the full analysis
and merely hide its extra outputs. Guard lepton/jet indexing after the required cuts.

Both programs compute the same scientific cutflow: n, sum(genWeight), and
sum(genWeight^2) at all stages, plus final-region base counts/weight sums. The
SF-corrected final yield and squared-weight sum are also required. Cascade's
existing weighted cutflow is not free diagnostic work that RDF can omit.

### 3.4 Nominal SF definition

w_raw = Float64(genWeight) * SF_mu_id * SF_mu_iso * SF_e_reco * SF_e_id * w_pileup.

Preserve the actual Cascade product/grouping order and input conversions; a
mathematically equivalent reordering can change floating-point bits. Validation
checks factors separately as well as the product.

| Factor | Frozen payload and correction contract |
|---|---|
| muon ID | MUO/2022_Summer22/muon_Z.json.gz; NUM_TightID_DEN_TrackerMuons; signed eta, pt; scale_factors=nominal |
| muon isolation | Same file; NUM_TightPFIso_DEN_TightID; signed eta, pt; scale_factors=nominal |
| electron ID | EGM/2022_Summer22/electron.json.gz; Electron-ID-SF; year=2022Re-recoBCD, WorkingPoint=Tight, ValType=sf |
| electron reconstruction | Same file; WorkingPoint=Reco20to75 for pt<75 and RecoAbove75 for pt>=75; ValType=sf |
| pileup | LUM/2022_Summer22/puWeights.json.gz; Collisions2022_355100_357900_eraBCD_GoldenJson; NumTrueInteractions=Pileup_nTrueInt, weights=nominal |

Hash exact payload bytes and inspect declared argument order/types, category keys
and overflow/error rules. No b-tag SF is configured in this primary selection.
Do not add one for appearances. No SF up/down, expression weight variations,
theory vectors, normsys, lumi uncertainty, shapes, fits or background priors.

Removing variations means deleting BOTH up/down keys in the isolated correction
terms, not computing them and discarding output. Profile deep-merging does not
remove inherited keys. Validate the fully resolved nominal-only config.

Normalization for displayed histogram:
A = ((924 * 0.1061) * 1210) / sum_original_Runs_genEventSumw.
Use Float64 in this exact operation order, matching luminosity_scale; do not
reorder the constants merely because multiplication is mathematically commutative.
Then bin sumw scales by A and sumw2 by A^2. These constants reproduce the current
comparison configuration; they are not a new cross-section result or exposure
measurement. Keep raw and scaled histograms in the correctness record.

### 3.5 Histogram and PNG

Primary: njet, edges Float64[0.5,1.5,2.5,3.5,4.5,5.5,6.5,7.5], seven bins,
final>=2-jet region. Drop underflow, fold overflow into the last regular bin;
values at an upper edge follow Cascade's searchsortedlast convention. Match
NaN/nonfinite-value and signed-weight behavior, including squared weights.
The last visible bin represents>=7jets. Fold the destination BEFORE each fill
while preserving event order; adding a separate ROOT overflow bin afterward changes
the floating-point reduction tree. No clipping of negative weights/bins.

Output exactly one MC-only linear-y PNG with the same ROOT version, axis labels,
dimensions, style and sqrt(sumw2) statistical errors. No ratio, stack, fit,
systematic band, table plots, PDF or duplicate log plot. If signed bins require
negative y extent, preserve them instead of silently discarding them.

Use the same native ROOT renderer and SAME CHAINED topology for BOTH histograms:
external driver -> analyzer exits normally -> identical renderer -> driver closes.
Do not fork the renderer from a large live Julia/ROOT analyzer process. Overall
time includes both normal process exits and the driver interval between them. A shared renderer is an explicit benchmark component, not an existing
MC-only Cascade CLI feature. Cascade's default prefit path requires data and can
skip MC-only figures: do not fabricate data or count tables as PNG rendering.
Default proposed canvas:1000x800pixels, one linear axis view and identical
ROOT font/margins/marker settings. Pin the final style before timing. A neutral histogram transport
contains the same edge/scaled-sumw/scaled-sumw2 arrays on both sides. Proposed
wire format: magic CASCBEN1, little-endian UInt32 version and bin count, followed
by little-endian Float64 edges, scaled sumw, scaled sumw2 and normalization factor.
Validate lengths/version/endian before use. A single-file transport SHA check
is useful when science arrays are bit-identical; otherwise compare decoded
arrays under the declared science contract, never demand false byte equality.
Measure transport costs. Both programs exit normally (no quick_exit/_exit path).
The driver owns the run process group; a failed child or surviving analyzer/renderer
process makes the run incomplete/failed, never a successful fast result.
An optional native-in-process RDF rendering result is a separate topology case,
not mixed with the shared-renderer primary result.

Optional later case: three PNGs (njet,mll,lep_pt), where lep_pt fills both leptons.
Use identical explicit variable-bin edge arrays. It has its own workload ID and
must not be pooled with the one-PNG result.

## 4. Benchmark programs and implementation boundary

### Julia adapter

Reuse compile_selection/read_selection_columns/select_events, the existing nominal
correction evaluator and histogram filling kernels. Keep dictionaries at planning
boundaries and preserve the typed KernelContext; do not replace the kernels with
a benchmark-only hand-written event loop. Compile once per effective config/kind
within an invocation. Do not write/read select/correct checkpoints unless that is
an explicitly separate staged-CLI case. Required cutflow and final metric output
costs are included in both programs.

Primary variant K0 preserves the current correction-reader call default:
source=nothing, so a lazy pileup branch may reopen the ROOT file. Count and include
that cost. This preserves a current-kernel behavior, but still is NOT a full-CLI
benchmark because this adapter omits stage checkpoints. A source-borrowing K1
variant may use the existing API without changing science or ownership, but is
explicitly separate from K0, with its own candidate ID and measured source opens.
Do not quietly give the benchmark an optimization not disclosed in the result.

### C++ RDF adapter

Use an optimized precompiled C++ executable, typed actions/callbacks and native
C++ correctionlib. Primary flags are a recorded optimized build without fast-math
and with floating contraction disabled where supported (e.g. -O2 or -O3 plus
-fno-fast-math -ffp-contract=off; fix the chosen level and target architecture).
Do not use string Filter/Define expressions or untyped actions that introduce
avoidable user-kernel JIT; log framework initialization separately, not as proof
ROOT has no startup/JIT machinery. Reuse graph nodes explicitly. Book all lazy cutflow/yield/
histogram actions before accessing any result. Do not use Python per-event
callbacks, early GetValue calls that force repeated loops, or unconditional
AsNumpy/Snapshot materialization. A multi-threaded correction evaluator must be
thread-safe or use per-slot state. Record actual RDF event-loop counts. The
pinned ROOT6.40 reference exposes GetNRuns(); verify the installed-version API
and require one Events-graph execution per workload. Read Runs freshly outside
the Events graph every run on BOTH engines. Cascade retains its existing prefix
prepass and per-file processing; record those passes instead of falsely calling
all its internal row visits a single loop. Logical processed-entry throughput
uses the declared unique Events population; extra passes/opens are separate counters.

Do not force identical internal execution strategies: RDF may short-circuit and
share nodes naturally, while Cascade may materialize columns. Match logical
work, requested results, precision and resources; measure resulting differences.

Proposed benchmark-only directory: tools/benchmarks/ttbar_emu/. Separate entry,
config builder, Julia runner, RDF source, metrics writer, comparator, renderer
and repeat driver by feature. Names/API are proposals, not files already present.
No accidental test auto-discovery or expensive real-data default test is allowed.
C++ is a reference tool only, never a new Cascade product dependency.

## 5. Timing design: what can and cannot be measured

RDF interleaves I/O, filtering, SF evaluation and histogram filling inside one
lazy event loop. Therefore a stopwatch around Filter or Define construction is
NOT the event cost of that operation. Never publish an invented additive table
of RDF read+selection+SF+hist times from graph-construction timings.

Use three distinct evidence layers.

### A. Direct wall-clock intervals: primary observations

| Metric | Boundary | Meaning |
|---|---|---|
| total_wall_s | External driver before analyzer creation -> analyzer and renderer normal exits plus driver final close | Primary end-to-end time |
| pre_main_s | External launch -> first instrumented main marker | Runtime/loader startup gap; clock alignment method recorded |
| setup_s | Main entry -> ready for Runs/Events work | Imports/config/payloads/graph/kernel setup; label nested clocks and late JIT |
| runs_read_s | Fresh original Runs read start -> complete ordered denominator | Separate metadata population work, outside Events graph |
| event_loop_s | Before first Events branch read -> completed booked consumers | Inclusive I/O+decode+selection+SF+hist; late JIT may be inside |
| normalize_transport_s | Completed consumers -> renderer input ready | Normalization and neutral output transfer |
| analyzer_finalize_s | Transport ready -> analyzer normal exit | Analyzer metric write/close/cleanup, before renderer |
| render_total_s | Driver renderer launch -> renderer exit | Includes renderer startup, draw/save, close |
| finalize_s | Renderer exit -> driver end | Driver metric write/close/cleanup |
| residual_s | External total minus measured disjoint intervals and aligned launch/exit gaps | Unattributed gap; reported, not silently assigned |

Within a sequential implementation, use disjoint intervals for a stacked total.
Nested renderer clocks (ROOT init, drawing, SaveAs/close) must not be added again
to render_total. Threads and file-level subintervals may overlap; tag inclusive,
exclusive, nested or concurrent. The sum of task times is not elapsed wall time.
If process clock alignment is unavailable, pre_main_s is null and folded into
residual/startup, NOT zero. No final total depends on subtracting unsynchronized clocks.

For Cascade this interval starts BEFORE read_selection_columns or any Events
prefetch, not just before event_loop!. For RDF it starts before triggering the
first booked Events action. Metadata/Runs work is separately located in setup;
no Events decode can disappear into an unreported preparation phase.

JIT is not always a disjoint phase. Report compile/setup clocks, first-versus-warm
behavior and profiler evidence; do not claim event_loop_s is JIT-free by naming it so.
Where supported, Julia phase records include compile_time, gc_time and allocation
bytes as OF-WHICH counters, never subtracted time. C++/ROOT setup and lazy metadata
initialization can occur at different points; direct subphase differences alone
are not causal evidence. If a requested metric cannot be measured reliably, emit
null plus a reason. A clock-alignment failure does not invalidate the external total.

### B. Cumulative workload ladder: required part-cost analysis

Run the same adapters in explicitly separate modes, not extra scans hidden inside
one timed primary invocation. All produce a small metrics record; only W4 draws.

| ID | Work actually consumed | Interpretation |
|---|---|---|
| W1 select | Required inputs, all ordered cuts, base cutflow/region counts and sums | Selection-complete process, including its I/O/startup |
| W2 sf | W1 plus nominal SF and final corrected sumw/sumw2 | Forces SF evaluation with real lazy consumers |
| W3 hist | W2 plus raw/scaled njet histogram | Forces histogram filling; no rendering |
| W4 png | W3 plus common renderer and completed one-PNG output | Primary requested end-to-end workload |

The Cascade compiler currently emits histogram-value and requested SF-kinematic
outputs during selection. Preserve a common minimal selected-observable contract
across W1-W4. Keep the same minimal config on Julia; truncate driver calls only.
Force the corresponding RDF kept-output expressions with cheap booked checksum/
Sum consumers, and compute the SAME summaries from the Julia outputs. Keep these
consumers in all W levels and record their common overhead; no validation dump
or gratuitous full-array materialization in official timing. Do not call already
computed njet/SF kinematics a pure added histogram/SF cost. Record any unavoidable
branch/output differences and include them in the marginal interpretation.

Match engine, size, cache/resource policy and block/repetition IDs before forming
differences; balance the order of modes within blocks so drift is not always
assigned to SF or rendering. A pair is always Julia versus RDF at the SAME W and
size. W-level differences are blocked contrasts between separate runs, not
within-one-run stopwatch measurements. For block i, report dSF_i=T(W2)_i-T(W1)_i,
dHist_i=T(W3)_i-T(W2)_i and dPNG_i=T(W4)_i-T(W3)_i, for both engines.
These are MARGINAL WORKLOAD EXTENSION COSTS, not isolated exact CPU times. They
can include added branch decoding, altered JIT, graph layout and measurement
noise. They may be negative; retain signed values and uncertainty, do not clip
them or use them as a stacked pie. A paired/block design and matching cache states
are required. Independently measured intervals and differences are separate columns.

An optional W0 read/decode diagnostic must consume every declared required scalar
and jagged element through a checksum/reduction. RDF Count alone can avoid branch
reads and is NOT an I/O benchmark. Checksum overhead and the selected branch set
are disclosed; W0 is not subtracted from W1 to manufacture a pure selection time.

### C. Attribution diagnostics and optional exact staged costs

Separate untimed validation/profiling invocations may record sampled CPU stacks,
allocation, branch read/decoded bytes, branch access, basket counts, source opens,
correction evaluations and histogram fills. ROOT I/O counters and Julia/source
counters need explicit scope; OS physical bytes, decompressed bytes and logical
array bytes are different metrics. A zero physical read can mean warm page cache.

Optional matched, predecoded-input kernel tests can isolate selection, SF and fill
CPU, but are a different workload with excluded decode/copy/preparation costs.
Use the same typed data/rows for both; never substitute them for W4 performance.
If a requested report must contain separately measured read, selection, SF and
fill wall times, approve a SECONDARY staged diagnostic on the small/middle fixture:
- Materialize the same required typed input columns once on each side; time this
  as read/decode/materialization, including allocation. Preserve original entries.
- Execute the same selection on those in-memory inputs and consume the selected
  rows; time selection plus its required output materialization.
- Execute the SAME nominal correction evaluators used by the primary adapters
  on the same selected rows with inputs already resident; time SF evaluation.
- Fill the same histogram from resident values/weights; time filling, then
  separately normalization and the shared renderer.
- Report memory-interface/setup/copy costs explicitly. This is a controlled staged
  kernel diagnostic, NOT the natural RDF fused run, and its times cannot replace
  primary W4 or be asserted to sum to the primary total. No physics function is
  independently rewritten for this test. Stop if a reliable resident-input
  interface is unavailable; do not invent a value.

Profiling or per-call clocks that perturb execution are diagnostic only. Avoid
an event-by-event stopwatch in the official benchmark. Measure instrumentation
on/off overhead separately if detailed attribution is claimed.

## 6. Correctness gate before timing conclusions

Use separate validation runs with detailed event dumps, not asymmetric tracing
inside one engine's official timed run. Pair by original file ordinal and entry,
not event number alone or multi-thread iteration position.

Required outputs and checks:
- Exact configured sample, files/ranges, all four triggers and expected stage names.
- Exact event membership at each cut, final original entry identities and counts.
- Selected object original indices/order, charge, pt/eta/phi, njet and mll.
- Individual nominal SF factors, raw genWeight and combined weights; count each
  valid correction and record payload boundary/error cases.
- Per-stage n/sumw/sumw2, final base and corrected yields; original Runs value/status
  and normalization. Base cutflow is not retroactively SF-weighted before SF exists.
- Exact histogram edges and flow mapping; raw/scaled sumw and sumw2; matching final
  fills. No missing sample, hidden variation, extra final scan or skipped consumer.
- Actual PNG decode, dimensions, nonblank axes/content/errors and visual inspection.
  PNG byte equality is not required; numerical histogram equality is checked first.

Numeric contract:
1. Exact integer/raw identity/membership is the target. SFs/observables use explicit
   predeclared numerical tests; histogram tolerances cannot conceal lost events.
2. Copy actual Julia expression evaluation rules, not only docstrings. Electron
   etaSC addition occurs in NanoAOD Float32 before promotion; mass_massless and
   deltaR use their current mixed-precision expression behavior. Floor-mod angle
   wrap is not automatically C++ fmod or a ROOT helper. Preserve stable tie sorting.
3. Include adversarial fixtures near pt/eta/gap/mll/deltaR and the75GeV reco split,
   equal-pt objects, empty jagged rows, NaNs, signed cancellation and overflow.
4. Julia and C++ libm may differ near a boundary. Freeze math/compiler/fast-math/FMA
   policy and report such cases explicitly. Any real-input membership mismatch
   fails the gate until explained and resolved; do not drop boundary events or
   silently widen physics cuts. A separately labelled diagnostic of known
   platform boundary differences is not a passing primary comparison.
5. Before candidate timing, compute and freeze contribution-aware aggregate bounds
   from a correctness fixture and an error model. Candidate policy: weight equality
   abs<=a_w+r_w*abs(reference), plus explicit observed/input-type justification;
   bin sumw bound uses sum(abs(contributions)) times a justified reduction/SF error
   budget, not relative error to a near-zero result. Track sumw2 independently.
   Proposed starting factor/weight check: abs difference <=1e-12 +
   1e-10*abs(reference), with stricter exact checks where supported. This is a
   proposed gate, not proof all payload cases meet it; a mismatch stops for
   investigation rather than automatic relaxation. One auditable aggregate model
   is gamma_n*sum(abs(w)) per implementation plus the allowed per-event weight
   error summed in the bin, where gamma_n=n*eps/(1-n*eps) and n*eps<1. Use the
   actual accumulation/precision model and an independent sumw2 bound; report
   both observed errors and bounds. The model can be conservatively loose and
   does not excuse incorrect selected events or SF factors.
   Final coefficients/model belong in signed-off correctness-policy.json before
   timing, not chosen after seeing the faster candidate. No policy file -> no accepted run.

Disable reassociating fast-math for the primary comparison. Ordinary optimized
C++ and Julia may reduce in different thread orders; use declared cross-language
bounds, not universal bit-equality. The existing same-partition Cascade contract
is not relaxed for internal refactors.

## 7. Resources, cache states and repetitions

Primary allocation: one analysis compute thread on each side; BLAS1; renderer
runs afterward with an equal fixed native allocation. Record all subprocesses,
threads (including Julia GC threads), host CPU, available RAM, affinity/NUMA where
actually controlled, storage,
compiler flags and runtime versions. Do not claim isolated hardware without evidence.

Optional later equal-core case: e.g.2 or4 cores only after agreement. Record actual
file/cluster parallelism. Cascade's file-level path cannot exploit several cores
inside one file as RDF IMT can. Include both enough-files and few-large-files
cases if discussing general scaling; do not hide that limitation by selecting
only the favorable distribution. Parallel peak RSS is simultaneous process-tree
usage where observable, not the sum of unrelated per-process peak maxima.

Record three independent states:
- process/JIT: fresh process primary; warm-process secondary; fixed Julia depot
  and startup-file disabled. Prepare existing package caches separately and record
  that cost. A timed run showing package Precompiling is flagged invalid for the
  prepared-deployment case, retained and investigated, never silently deleted;
- OS page cache: stated observed/pilot-warmed policy, never called cold just because
  a process is new; no shared-host cache dropping or service changes;
- application artifacts: NONE in primary. No selected/SF/hist/PNG result reuse.

Build/install preparation is outside repeated execution and disclosed for BOTH:
C++ compile flags/time, Julia/package preparation and cache state, renderer build.
Runtime Julia kernel JIT remains in fresh-process time. Primary initially uses
NO custom sysimage; a sysimage/precompiled variant requires a separate ID with
its construction cost, source/config limits and amortization disclosed. A future
source-edit workflow comparison includes the corresponding C++ rebuild as well.

After correctness/pilot, target5 paired repetitions per agreed size, Julia/RDF
order alternated or randomized in balanced blocks. Keep all successful times,
failures and environmental notes. Report medians, IQR/range and paired ratios.
Never trim a run simply because it is slow. Predeclare contention/resource flags
and any whole-pair exclusion rule; preserve flagged originals and report valid N.
Replacement pairs require the agreed ticket budget/policy, not an unbounded retry.
For W1-W4 attribution on the representative middle size, target the same paired
repeat count; preliminary3-pair data are explicitly exploratory, not relabelled5.
The complete proposed matrix is60 timed analyzer+renderer executions:
W4 at3 sizes x2 engines x5 repeats (30), plus W1-W3 at the middle size x2 engines
x5 repeats (30). This is a COSTED PROPOSAL, not a command to launch60 runs. A
pilot must estimate it against the approved budget; reduce or split the matrix
BEFORE final measurements if needed. Never retrospectively call an underfilled
matrix complete. No automated full Cartesian sweep is authorized by this plan.

Before each execution ticket freeze the run matrix, repetition count and hard
wall-time budget. Suggested first pilot ticket cap:30min, no waiting for hours;
this is a STOP BUDGET, not an ETA or promised completion. Use pilot time to propose
an affordable final matrix. Stop and report if budget/memory/error threshold is
hit; preserve completed runs and never restart them automatically. No more cores,
files, repetitions or optimization tickets without scope approval.

## 8. Machine-readable results and analysis

Proposed per-run record, values populated only from actual measurements:

~~~json
{
  "run_id": "engine-candidate-workload-size-repetition",
  "engine": "cascade_adapter | rdf_cpp",
  "candidate_id": "frozen-source-and-build-id",
  "workload": "W1 | W2 | W3 | W4",
  "size_id": "S1 | S2 | S3",
  "pair_id": "...",
  "block_id": "...",
  "run_order": null,
  "input_inventory_sha256": "...",
  "config_sha256": "...",
  "payload_manifest_sha256": "...",
  "process_state": "fresh",
  "os_cache_policy": "declared-policy",
  "application_cache": "none",
  "compute_threads": 1,
  "counts": {"input": null, "visited": null, "selected": null, "fills": null},
  "seconds": {
    "total_wall": null, "pre_main": null, "setup": null, "runs_read": null,
    "event_loop_inclusive": null, "normalize_transport": null,
    "analyzer_finalize": null,
    "render_total": null, "finalize": null, "residual": null
  },
  "process_checks": {"normal_exits": null, "surviving_children": null, "precompile_seen": null},
  "resources": {
    "cpu_seconds_process_tree": null, "peak_rss_bytes_scope_defined": null,
    "physical_read_bytes": null, "logical_decoded_bytes": null,
    "output_bytes": null, "source_open_count": null
  },
  "metric_notes": {},
  "correctness_policy_id": "...",
  "correctness": "pending | pass | fail",
  "exit_code": null,
  "status": "completed | failed | interrupted | skipped"
}
~~~

Additional records: original inventory+Runs, environment/build manifest, resolved
nominal config, cutflow.csv, selected-event validation data, sf-validation.csv,
histogram-raw/scaled.json, per-phase timestamps, per-run timing.csv/json,
paired-summary.csv, workload-differences.csv, PNG-validation.json and report.
Large validation dumps stay on gate, not in the Mac repository.

Required tables:
1. Work and correctness: file/input/selected/fill counts, normalization, cutflows,
   SF errors, bin errors and PNG pass/fail.
2. Direct time: engine x size x disjoint phase; median/IQR/number completed.
3. Part-cost analysis: W1/W2/W3/W4 times plus signed marginal dSF/dHist/dPNG;
   label them non-additive extension estimates, including uncertainty.
4. Resources: CPU, scoped RSS, input/output bytes, source opens and event-loop counts.
   UnROOT mmap can put file-backed pages in RSS and bypass process read syscalls;
   /proc read_bytes/rchar are not interchangeable with ROOT logical I/O counters.
   wait4 maxrss is a maximum, not a process-tree sum. Record the collection method
   and avoid a memory/I/O ranking when scopes are not comparable. CPU/wall above
   the declared1-thread expectation is an investigation flag for hidden threads,
   not an automatic claim about a specific kernel.
5. Scaling: total and event-loop time versus events/files; approximate intercept/
   slope only if supported, alongside per-size results. Not a mandatory linear fit.
6. Preparation: build/preparation time and any independently warmed secondary case.

S = T_RDF / T_Cascade for the SAME metric/workload/state/resources; S>1 favors
Cascade, S<1 favors RDF. Report both underlying times. Input throughput uses all
visited original entries/event-loop time; selected throughput is separately named.
Do not divide original population by reduced scanned time or use cut-passing counts
as the denominator of an unlabeled event/s figure.

Do not equate a lower end-to-end time with a faster SF evaluator. A render-dominated
one-PNG result can hide compute differences; show event_loop and the workload
ladder together. Histograms with different contents cannot enter a speed ranking.

## 9. Bounded implementation and execution tickets

| Ticket | Deliverable | Exit / stop gate |
|---|---|---|
| P0 freeze/preflight | Choose source candidate, input inventory, payloads, existing native toolchain, nominal config, resources and metric policy | No moving source; missing dependency is a blocker, not an install request |
| P1 adapters/correctness | Two minimal adapters, common renderer, external timer, opt-in synthetic and one-file comparison | Exact selection/valid SF/hist/PNG; mismatches stop before performance conclusions |
| P2 pilot | One pair at agreed sizes, measure launch/loop/render and counters | Actual cost and feasible final matrix reported within ticket budget |
| P3 measured comparison | Approved paired W4 matrix plus bounded W1-W3 middle-size matrix | Frozen before/after inputs and reliable metrics; no hidden failures |
| P4 analysis/report | Timing tables, correctness, resource/scaling analysis and one next optimization recommendation | Workload-scoped conclusion; no mandatory speedup |
| O1 optional optimization | One measured bottleneck only, same frozen reference workload | Same science + benefit above observed noise; regressions disclosed |

No single ticket authorizes all subsequent tickets. P1 can precede the broad
M0-M7 roadmap. A complete initial report does not require implementing a generic
DAG, persistent workers, full streaming or cache redesign. Benchmark RDF from the
start rather than adding the competitor only after optimization.

Acceptance of the benchmark means: reproducible work, correct outputs, measured
and honestly labelled parts, complete error records and an interpretable comparison.
It does not mean Cascade must win. A deployment/competitiveness target must be
chosen explicitly later: time-to-PNG, event throughput, memory cap, or iteration
turnaround. Do not invent a required speedup in advance of a baseline.

## 10. Link to later optimization decisions

- Setup/JIT dominates -> investigate specialization/startup and bounded process
  reuse; report first-run versus warm behavior, do not hide startup.
- Source-open/verification/parse dominates -> operation-scoped verified reuse and
  borrowing, preserving integrity/drift checks; count calls and bytes first.
- Intermediate artifact I/O dominates in a separate CLI case -> M3 persisted
  handoff before checkpoint omission; not proof the minimal adapter has that cost.
- Repeated lepton/object work dominates JES/JER extension -> object-level invariant
  dependency sharing, not a trigger-only prefix optimization.
- Multi-weight histogram dominates a later weight sweep -> M1 bin-index reuse;
  nominal one-histogram results do not establish this opportunity.
- Few-large-file parallelism or memory dominates -> M4a bounded source processing,
  then separately approved intra-file tasks; original normalization once remains.

Keep Cache/Snapshot/incremental analysis and failure recovery as separately
specified future workflow comparisons. RDF already supports shared lazy nodes,
IMT, Cache, Snapshot and Vary; do not frame these as absent competitor features.

## 11. Verification and references

Plan validation now: local links, explicit scope, measurement/schema consistency,
English repo docs, and preservation of runtime/source files. No benchmark value
in this plan is an observed measurement. Earlier hash timings are separate
profiling evidence, never a whole-pipeline or RDF speedup.

Source references: analyses/ttbar_emu/analysis.toml; Selection/{compile_selection,
event_loop,select_events,Cutflow,region_counts}.jl; Objects/{deltaR,mass_massless,
sort_objects}.jl; Systematics/weights/{correction_weights,BranchReader,object_factors,
apply_corrections}.jl; Histograms/{fill_store,fill_bin}.jl; Pipeline/code_hash.jl.

Official pinned comparison documentation:
https://root.cern/doc/v640/classROOT_1_1RDataFrame.html
Use its lazy-action, shared-node, parallelism and JIT semantics, then pin the
ACTUALLY INSTALLED benchmark ROOT version before implementation.

Related plans: [implementation roadmap](PERFORMANCE_IMPLEMENTATION_PLAN.md),
[optimization proposal](PERFORMANCE_OPTIMIZATION_PROPOSAL.md).
