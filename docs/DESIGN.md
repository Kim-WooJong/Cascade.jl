# Cascade architecture

Cascade is an implemented, experimental Julia framework for CMS NanoAOD analysis.
This overview describes the current organization, not a phased implementation
plan. [Configuration](CONFIG.md) defines the settings; [validation](VALIDATION.md)
defines what has and has not been checked.

## Data flow and modules

Config → IO → Objects / Selection → Corrections → Histograms / Systematics /
Fit / Plotting → Pipeline orchestration.

| Module | Responsibility |
|---|---|
| Config | Resolve TOML paths/profiles/options, construct typed definitions and validate structure |
| IO | AbstractEventSource, registered formats, NanoAOD through UnROOT, flat/Jagged columns, certification masks, column files and reduced inputs |
| Objects / Selection | Object filtering/cleaning/sorting, restricted expression compilation, staged reads, ordered cuts/regions and selected EventTables |
| Corrections | Native Julia correctionlib schema-v2 evaluation, including formula, compound and deterministic random nodes |
| Histograms | BinnedHist / HistogramStore with edges, sumw and sumw2, merging, scaling and transport |
| Systematics | Apply declared MC weight terms, explicit theory members and object-varying shapes; build histogram variations/templates |
| Fit | Binned likelihood models, fits, profile inference and covariance-aware reports / HistFactory workspace export |
| Plotting | Histogram adapters, uncertainty bands/tables and ROOTPlots rendering |
| Audit | Input inventories, physical-file aliases, event counts and normalization provenance |
| Pipeline | CLI, step planning, artifact keys, scheduling, hooks, batch/reduced workflows and publication |

The fit implements a binned Poisson likelihood with normfactors, normsys,
histosys interpolation and MC-statistical terms. Configured nuisance names and
correlations define templates; missing sample-specific variations use nominal
templates. Postfit yield/plot propagation retains cross-bin/sample covariance.
Correction evaluators cover schema-v2 nodes and a supported TFormula subset, not
arbitrary formulas. External oracle comparisons require exact agreement or the
declared tolerance (the real SF comparison uses relative tolerance 1e-12).

Python correctionlib and pyhf are optional external test oracles, not analysis
runtime dependencies. ROOTPlots provides the rendering boundary; native ROOT is
required to render images, not to evaluate every synthetic/configuration test.

## Pipeline and artifacts

The checkpointed execution order is:

| Step | Main output |
|---|---|
| skim | Input index, signatures, event counts and original generator sums |
| select | Per-chunk .cols EventTable, cutflow and original entry indices |
| correct | Selected-event nominal / varied weight columns |
| histogram | Chunk histogram stores |
| merge | Ordered sample stores, normalized/raw histograms, yields and cutflows |
| systematics | Fit-ready templates |
| fit | Configured likelihood results and reports |
| plot | Plots, tables and output index |

The ordinary chunk is an input file. Shape selections produce label-specific
tables and weights; data is unchanged by MC scale factors/shapes. JES/JER and
scale variations rederive objects/selection; nominal JER smearing is opt-in
(default false), and optional MET propagation follows configured thresholds.
Nominal theory members do not create shape × theory products. Hooks use CorrectionContext or
StepContext at their documented stage boundaries; a custom wrapper is not
implicitly trusted as a built-in hook.

Cascade .cols files store typed arrays with a header; they are distinct from
ROOT. The default skim indexes inputs. The separate reduced export writes ROOT
RNTuple bundles, **not** NanoAOD TTree output. Streaming export can split an
original into physical shards while retaining its logical population ledger.
See [reduced skim](REDUCED_SKIM.md) and [streaming export](STREAMING_REDUCED_SKIM.md).

Checkpointing defaults on. The explicit
[no-checkpoint mode](NO_CHECKPOINTS.md) computes a fresh in-memory chain, publishes
final outputs and cannot resume intermediate work. Other execution modes have
separate admission/fallback rules; they do not silently change the scientific
analysis definition. See the [execution guides](README.md).

## Configuration, expressions and cache identity

One analysis TOML resolves one selected profile before consumers see it. Tables
deep-merge; arrays replace. Unused profile definitions do not enter effective
physics section keys. Explicit workdir overrides are exact; default workdirs
isolate selected profiles. Expressions use parsed Julia syntax with a restricted
operation set, not arbitrary analysis text evaluation. Collection order,
short-circuiting and guards matter: an out-of-range object access is an error,
not an automatically supplied value. Preserve input precision and event order.

Artifact sidecars bind relevant input signatures/upstream keys, resolved config
sections, code-area hashes (including Julia version) and hook identity. Changing
histogram binning need not reread unchanged selection values; changing source
code invalidates the relevant code key. Keys are dependency checks, not a blanket
claim of cryptographic input immutability: ordinary file signatures and stricter
reduced-input inventories have different contracts.

Reader widths and related execution-only options are excluded from scientific
selection section keys where documented. Full-config/batch/reduced contracts
still see them. A cache hit preserves the artifact's original generation
diagnostics; it must not pretend the requested new engine ran. Reduced integrity
and extraction preflights still execute at their required stage boundaries,
including before applicable cache returns. No persistent cross-invocation trust
cache is implied.

## Ordering and normalization

Scheduling may be concurrent; scientific replay and merges retain defined
sample/file/event order rather than task completion order. Floating-point
addition order is observable and must not be changed casually. Histogram stores
retain sumw and sumw2; underflow is dropped, overflow goes into the last bin and
NaN is not a histogram value.

MC normalization uses

~~~text
(xsec_pb × branching_ratio) × lumi_pb / signed original-population generator sum
~~~

Data remains unscaled by MC normalization. Original Runs-derived denominators
are not selected-event counts. Reduced shards share their original logical
population; complete group ledgers prevent repeated per-shard denominators.
Theory members merge before envelope/replica/Hessian reductions and fit template
construction. Dataset completeness and calibrated exposure are not inferred from
a file limit or a successful synthetic run. See [luminosity](LUMINOSITY.md),
[theory weights](THEORY_WEIGHTS.md) and [input auditing](INPUT_AUDIT.md).

## Ownership and bounded execution

Sources, mutable ROOT streams, object buffers and decoder scratch have explicit
owners. A borrower must not close its owner's source or share mutable stream
state concurrently. Invocation-local correction reuse shares a lazy source, not
partial masked columns or row caches. Parallel column slots own separate handles;
detached basket workers receive owned payloads without ROOTFile/metadata access.
Worker scopes join before owned resources close or errors escape.

Queue/window accounting bounds admitted logical work where specified, not the
entire process heap, GC retention, mmap residency or RSS. Full-file paths remain
eager unless a documented windowed route is selected. Unsupported inputs fall
back or fail according to that route; corruption in an admitted supported format
must not be disguised as a successful fallback. Registry/method replacement
inside an invocation and hostile in-place input mutation are not supported.

See the retained contracts for [parallel columns](PARALLEL_COLUMN_READ_VALIDATION.md),
[detached baskets](BASKET_DECODE_VALIDATION.md),
[correction reuse](CORRECTION_SOURCE_REUSE_VALIDATION.md),
[window accounting](WINDOW_ACCOUNTING.md) and
[windowed reusable decoding](WINDOWED_REUSABLE_DECODER.md).

## Scientific boundary

Configured nuisance names, correlations, normalization and channel overlap checks
are part of analysis semantics, not performance tuning. Reference technical
priors are not final analysis recommendations. Old uncorrected ttbar regression
targets are data/MC 5905/6434.9316 (at least one jet) and 3836/4235.2102 (at least
two jets); they are not new measurements. The real certification mask, payloads
and physics evidence remain necessary. Read [validation and limitations](VALIDATION.md)
before interpreting a passing focused test as scientific approval.
