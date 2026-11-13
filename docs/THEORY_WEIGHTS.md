# Theory vector weights

Optional [[theory_weights]] declarations add scale/PDF/shower members without
changing nominal weights or data. No runtime dependency is added. Use the normal
pipeline through systematics and fit. Either default correction or
apply_corrections is supported; theory multiplies its corrected nominal.

## Configuration

Synthetic declaration, not a physical index prescription:

~~~toml
[[theory_weights]]
name = "example_ISR"
family = "ps"                       # scale / pdf / ps / generic
branch = "PSWeight"
samples = ["signal"]                # explicit MC sample names required
indices = [1, 3]                     # 1-based; pair order [Up, Down]
expected_length = 4                  # exact selected-event length
normalization = "relative"
reduction = "pair"
convention = "Reference defining this sample and these members"
# enabled = false                   # optional opt-out
~~~

- relative: factor = member (already varied/nominal).
- central: factor = member / vector[central_index]; declare central_index.
- absolute: factor = member / scalar reference_branch. Declare the signed
  nominal generator branch; the base MUST contain it. Arbitrary base expressions
  cannot be algebraically certified. Zero/nonfinite reference fails: no 0/0 or
  sign-replacement fallback, even on zero-base-weight events.

Positive unique 1-based indices must fit expected_length. Split samples when
layouts differ. Missing branch, scalar instead of vector, wrong length,
selected NaN/Inf, zero/nonfinite denominator and weight overflow fail. Diagnostics
include original entry/path/branch. Empty selections emit empty member columns
without opening branches; unselected events are not validated. Samples must be
explicit known MC names; missing branches never silently become unity.

## Histogram-wise reduction

Members are filled independently with signed nominal weights and their own
sumw2. Internal __theory_NAME_INDEX labels survive chunk/sample merge. Every
member uses the existing NOMINAL Runs denominator and luminosity normalization;
no member-specific cross-section or acceptance-only renormalization is inferred.
Only after merge/normalization are members reduced per sample/region/variable/bin:

| reduction | definition |
|---|---|
| pair | first member Up, second Down; no reordering |
| envelope | max/min of nominal and declared member histogram contents |
| replica_std | unbiased std about replica mean (N-1); nominal +/- cl_scale*std |
| hessian_symmetric | nominal +/- cl_scale*sqrt(sum((member-nominal)^2)); one symmetric eigenvector per index |
| hessian_pairs | nominal +/- cl_scale/2*sqrt(sum((plus-minus)^2)); consecutive pairs |

PDF band reductions require family=pdf, explicit pdf_template_model="rank_one",
positive cl_scale and convention
reference declaring set, members, input/target CL and prescription. cl_scale=1
is still an explicit physics assertion, not an inferred 68% CL. Exclude central
and alpha-s members unless the recipe really includes them. Percentile replicas,
asymmetric Hessian, alpha-s combination and auto PDF-set discovery are unsupported.

This is NOT eventwise max/min or max/min of chunk envelopes. Signed weights make
that especially wrong. Nonlinear envelope/replica/Hessian declarations MUST name
exactly one distinct sample: cross-sample correlated member reduction is not
implemented and multisample declarations fail, regardless of fit grouping. A
linear pair may name several samples with common member semantics. Deliberately
independent samples need distinct nuisance declarations/names; never split a
correlated envelope into same-name independently reduced bands. Duplicate theory
names and scalar/expression/shape or fit normsys/POI collisions fail.

### PDF covariance approximation: explicit opt-in

The collapsed nominal +/- delta PDF band is ONE rank-one, fully correlated
bin-shift histosys approximation: locally C_ij = delta_i * delta_j (unit Gaussian
nuisance). This also correlates channels sharing that nuisance name. It does
NOT preserve the replica/eigenvector covariance or anticorrelations. Therefore
pdf_template_model="rank_one" is mandatory for all PDF band reducers; it is
never inferred. Pair/scale recipes do not accept or require that setting.

For two replicas with shifts [+1,-1] and [-1,+1], the integrated member spread
is zero, but collapsing positive per-bin spreads gives a nonzero integrated
fit-template shift. Independently reduced metadata yield uncertainty can differ
from integrated fit-template uncertainty; neither certifies covariance closure.
If this approximation is inappropriate, do not use these collapsed PDF recipes.

Pair sumw2 follows its member. Envelope sumw2 follows the extremizing histogram
per bin (nominal first on ties). PDF bands retain nominal MC statistical variance:
PDF spread is not MC sumw2. Band-error correlations are not propagated. Negative
bins/bands are preserved, never clipped; a downstream likelihood can reject them.

systematics/templates.json removes internal members and emits NAMEUp/Down for
existing fit histosys handling. Metadata theory_weights stores declarations,
sumw2 policy, nominal yields, template integrals AND independently reduced
histogram-integral yields. Integral of a binwise envelope is not an envelope of
total yield. Existing merge/yields.tsv remains nominal/base reporting. Multi-value
histogram yields count fills, not necessarily distinct events.

## Scalar/shape interactions and cache

Theory multiplies corrected nominal; scalar nuisance columns remain independent.
Shape tables are reselected and scalar corrections recomputed as before.
Shape/theory and scalar/theory Cartesian cross-templates are not generated.
The pipeline reduces theory before calling the systematics hook, including
custom/registered hooks. Such hooks receive reduced templates, not internal
members. Direct API users can call reduce_theory. Inputs are immutable.

Theory edits enter correct keys and propagate through histogram/merge/fit.
Selection does not depend on theory values. Code changes can invalidate broader
caches. Profiles replace the entire theory array, keeping default opt-out.
options.corrections=false disables scalar corrections, NOT separately declared
theory; remove/disable theory explicitly. If systematics/plot sees internal
member histograms after declarations were removed or disabled, it fails closed:
rerun correct/histogram/merge rather than reusing orphaned physics artifacts.
Plot-only keys include theory settings, including cl_scale.

## Observed NanoAOD conventions

The first inspected TTto2L2Nu file has 32,853 Events; its first32 events have
scale length9 and PS length4. TWminusto2L2Nu (23,892 Events) shows the same declared
layouts. Branch titles explicitly say w_var/w_nominal:

- Scale 1-based1..9: (muR,muF)=(0.5,0.5),(0.5,1),(0.5,2),(1,0.5),(1,1),
  (1,2),(2,0.5),(2,1),(2,2).
- Example envelope [1,2,4,6,8,9] excludes anti-correlated combinations3/7;
  nominal stays eligible. This is a declared analysis choice, not universal.
- PS1..4: ISR=2, FSR=2, ISR=0.5, FSR=0.5 (other factor fixed1). ISR pair[1,3],
  FSR pair[2,4] labels Up as doubled shower scale, NOT necessarily larger yield.
- LHEPdfWeight is absent in this TT file. No physical PDF profile is fabricated;
  PDF recipes are synthetic-tested only.

8-member scale layouts require expected_length=8 and independently verified
indices: never blindly shift the9-member mapping. Branch titles and generator
documentation, not length/name alone, determine meaning. Optional ttbar
 theory_example uses only observed TT conventions, not all-file certification
or a production physics recommendation.

See VALIDATION.md for evidence and scope.

## Persisted extraction contracts and partial reruns

Raw member values are not identified by name/index alone. The correct step writes
metadata theory_extraction, propagated unchanged to chunk histograms and merged
raw/scaled stores. Schema: sample name -> {contract, hash}; hash is Config's
canonical SHA256 of contract. Contract version1 includes sample name/kind,
source format and complete declared source options (tree/Runs/gen-weight aliases
included), and sorted member terms: name, branch, explicit index set, exact
expected_length, applicability sample set, normalization and central_index or
reference_branch when used. Missing default options and explicitly supplied
options conservatively have different contracts; no alias equivalence is guessed.

Reduction-only family/recipe/convention/cl_scale/pdf_template_model settings and
member ordering are excluded: they do not change extracted per-index values.
They still enter normal stage cache keys. This allows changing cl_scale or a
compatible reduction recipe on a persisted member store without re-extraction.

A relative->central change with the same label is NOT compatible: for nominal10
and vector[2,4], index2 is40 relative but20 when divided by central index1.
Partial systematics/plot runs reject stale/missing/foreign extraction manifests
rather than stamping new settings onto old values. Validation runs before cache
reuse as well, covering reader/source edits which may leave output keys intact.
Fit validates template extraction provenance before consumption. Histogram/merge
intermediate steps now validate persisted corrected/chunk and
cached-output extraction contracts before returning skipped. Compatible reduction-
only edits retain reuse; no-theory stores preserve identity. Downstream
systematics/plot/fit also reject incompatible consumption even on cache hits. Rebuild upstream
correct/histogram/merge (and selection when its inputs change) to obtain new
contracts. Old pre-contract member artifacts must be rebuilt, not auto-migrated.

Histogram merge validates every incoming chunk before adding contents, checks
same-sample contract compatibility and preserves disjoint/empty sample records.
It never overwrites conflicting provenance. Empty selections still persist their
extraction contract. Member-free baseline stores require no manifest and keep
identity behavior; removed declarations with raw members still fail closed.
Existing luminosity/fit-overlap metadata is untouched by this propagation.

Direct API producers must capture Config.theory_extraction(cfg; samples=[sample])
AT extraction and persist it under store.meta["theory_extraction"] alongside the
members they actually constructed. This is an explicit assertion of truthful
provenance, not a method to relabel old values. Config.validate_theory_manifest
checks records and member labels; Systematics.verify_theory_extraction checks
current semantic compatibility. Hashes are consistency fingerprints, not a
cryptographic attestation against a malicious producer. There is no silent
legacy bypass for missing contracts.

Direct API construction example (only for values actually extracted under cfg):

~~~julia
manifest = theory_extraction(cfg; samples=[sample])  # capture at extraction
weights = theory_member_weights(cfg, sample, path, table, corrected_weights)
# Fill the member columns into a fresh HistogramStore using normal fill_store!.
store.meta["theory_extraction"] = manifest
verify_theory_extraction(cfg, store)
templates = reduce_theory(cfg, store)
~~~

Do not use this example to attach today's settings to yesterday's unknown
members. A legacy or mismatched store requires re-extraction from source.
