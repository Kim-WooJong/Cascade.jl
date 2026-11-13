# Theory vector weights: Step2 validation

Date: 2026-11-05. Base: 4cc7abb (0.2.0); compatible feature version0.3.0.
Owner the maintainer authorized ONLY Step2. Step1 audit and historical evidence remain
untouched. No full3307 selection, billion-event baseline, batch, reduced-skim or
deployment work was launched. No push/publication. Git records the final local
milestone commit; earlier execution checkpoints below preceded that commit.

## Design and artifacts

Config.theory_weights validates explicit member indices, exact lengths,
normalization, samples and reduction conventions. Systematics.vector_members
reads Jagged values in original selected-entry order through BranchReader;
source aliases are honored. theory_member_weights multiplies corrected nominal.
Histograms retain members through deterministic merge with nominal normalization.
reduce_theory builds post-merge bands/templates, records yields and sumw2 policy,
and removes internals before the systematics hook/fit. Plot inputs also reduce
theory. No product Python dependency or Python oracle was used.

## Runtime and commands

All execution/data/results/logs stay on gate in ~/analisis/Cascade_dev/p7-theory.
Mac holds source/docs only. Julia1.12.2, established rootplots-gate.sh wrapper,
JULIA_THREADS=2 and OPENBLAS_NUM_THREADS=1. Commands run from that gate area:

~~~sh
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n 10 bash   ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/runtests.jl"
CASCADE_THEORY_REAL=1 CASCADE_THEORY_AREA="$PWD" JULIA_THREADS=2   OPENBLAS_NUM_THREADS=1 nice -n 10 bash ~/packages/rootplots-gate.sh   --project="$PWD" "$PWD/test/systematics/weights/test_theory_real.jl"
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 bash ~/packages/rootplots-gate.sh   --project="$PWD" "$PWD/bin/cascade.jl" check   "$PWD/analyses/ttbar_emu/analysis.toml" --profile theory_example
~~~

Source transferred explicitly by rsync (Project/src/test/analyses/examples/bin/docs,
no .git, data, outputs or credentials; no delete). The existing p6 gate Manifest
was copied into the newly provisioned, previously absent p7 area. No environment
or scheduler configuration changed.

Initial implementation snapshot (before independent-review remediation):
325 Julia files, SHA256
84298b44d5dcfc9cdc11b1af6aad7ca25d8c37921441edb14bb026154fa0b656.
Algorithm: sorted relative paths, one line each consisting of path + space +
SHA256(contents), SHA256 of that stream (LC_ALL=C). Verified identical Mac/gate;
gate source.sha256. This differs from the older audit digest algorithm.
Complete src/test/analyses/examples/bin stream digest also matches Mac/gate:
34cd35080e6d537c3301144e7138cdc4eb4f36b0b24029d77024b7efd43ea289
(validation-inputs.sha256). Project version0.3.0; final test fixture explicitly
declares cols source format. git diff --check also passed.
That initial source hash remained unchanged throughout its suite/real validation;
only the synthetic test sample format declaration was corrected while the
final suite was still in earlier pipeline tests, before theory tests loaded.

## Initial bounded actual ROOT evidence (pre-review snapshot)

final-real.log / final-real.exit:1384 pass, exit0. Independent direct UnROOT
LazyBranch arithmetic checks all selected member columns and independent
njet-bin event accumulation/sumw2; post-normalization scale extrema checked.

- New opt-out baseline:13 files/2,200,037 Events, first file per sample.
- Compared with frozen p6-audit/out_bounded (4cc7abb behavior): all sample
  event counts, signed generator sums, normalizations, cutflows and yields equal.
- 7332 raw/scaled histogram bins plus edges/sumw2 are bit-identical.
- Actual TT scale/PS smoke:1 file/32,853 Events/1493 kept rows. Nominal Runs
  denominator and configured1210 pb^-1 retained. Exposure stays unknown for the
  truncated inventory. Fresh baseline and theory outputs are separate.
- Observed branch titles/first32 entries establish relative9-scale/4-PS layout;
  probe.log / probe.exit=0. TT and TW inspected. No LHEPdfWeight in that TT file.
- real-summary.json stores bounded counts. out_baseline and out_theory retain
  artifacts; historical p6 data/results remain unchanged.

Focused command uses the same wrapper with "$PWD/focused.jl". That gate-only
entry imports Test/Cascade, includes test/systematics/weights/fixtures.jl, then
test_theory_weights.jl and test_theory_pipeline.jl (in that order). No source
is generated or modified by the tests.

## Initial synthetic/regression evidence (pre-review snapshot)

final-focused2.log / final-focused2.exit:71 pass, exit0 (15 configuration,
16 vector diagnostics/layout,19 reduction/sumw2,5 signed immutable weights,
16 end-to-end/cache/registered hook). These overlap the full suite.
profile-check2.log / profile-check2.exit:theory_example CLI check exit0.
final-suite.log / final-suite.exit:51160 pass, one existing plotting guard
skip (Broken), exit0. Area counts: audit55, config202, corrections209, fit327,
histograms28, IO62, objects23022, pipeline284, plotting191, selection151,
systematics26629. No failed assertions/errors. Focused and real counts overlap
and must not be added to this regression total.
Tests cover signed/zero weights, scalar SF plus theory, shape migration plus
scalar/theory independence, negative/malformed sources, zero central/reference,
8/9 layouts, explicit replica/Hessian CL scaling, histogram-wise extrema,
sumw2, independently reduced yield versus template integral, immutable inputs,
fit histosys templates and fit execution, registered hook contract, cache reuse
and theory-edit invalidation without selection recomputation.

## Corrected validation attempts

- First focused invocation had shell quoting ambiguity: switched to a gate-only
  Julia script. Initial focused57 passed/exit0 before final refinements.
- First full suite failed because examples/ was omitted from transfer, not a
  product assertion. Added the missing source directory before final suite.
- First real harness failed after1328 checks because the qualified Cascade call
  lacked module import; fixed import, retained/reused successful baseline cache.
  Subsequent real1384 passed, and final-source real1384 passed.
- Added direct API fixture initially omitted format=cols, so its declared
  default NanoAOD reader correctly rejected a column file. Fixed the test sample
  declaration; product code was unchanged.
- First CLI check incorrectly handed the shell launcher to Julia; used the
  existing bin/cascade.jl Julia entry instead. No launcher change was needed.

## Limits and independent review

No real PDF set/members/CL semantics were available in the inspected TT file;
PDF recipes are synthetic-validated, not physical PDF closure. No universality
claim for8/9 layouts or ISR/FSR ordering. No asymmetric Hessian/alpha-s/percentile
recipe, cross-sample correlated envelope or Cartesian shape-theory variations.
No event-ID dedup or full-dataset certification. Absolute normalization requires
the user's base expression to contain the declared signed reference weight.
Band sumw2 policy is explicit, not full band-estimator covariance.

Independent concrete review identified the five issues addressed below.
Parent arranges fresh re-review of the remediated concrete diff. Review targets: PDF
recipe conventions and centering, signed normalization, envelope granularity,
sample applicability/collision errors, cache propagation, custom hooks, and
fit grouping/correlation semantics. Validation is not an independent physics
endorsement of optional example settings.

## Independent-review remediation (final snapshot)

1. Nonlinear envelope/replica/Hessian declarations now fail with more than one
   distinct sample, before any reduction/fit, regardless of grouped/ungrouped
   fit configuration. Linear pair remains multisample. Cancellation fixture
   A=(12,8),B=(8,12),nominals10+10 is correlated20/20, never independent24/16.
   Deliberately independent samples require distinct nuisance declarations.
2. Plot key includes the theory section directly. A lightweight registered plot
   hook tests a plot-only cl_scale edit against unchanged merge/fit artifacts:
   plot reruns and reduced bands change without rebuilding upstream artifacts.
3. Removed/disabled declarations with internal members now fail closed in direct
   reduction and partial systematics/plot runs. Member-free baseline retains
   identity-return behavior. Rebuild correct/histogram/merge to remove members.
4. _theory_band moved unchanged to weights/theory_band.jl, included separately;
   public API unchanged, one-function-per-file convention respected.
5. All PDF band reducers require pdf_template_model="rank_one" acknowledgment.
   This is a single fully correlated local C_ij=delta_i*delta_j bin-shift nuisance,
   including channels sharing its name, NOT full replica/eigenvector covariance.
   Anticorrelated two-bin replicas have zero integrated member spread yet a
   nonzero integrated fit-template shift. Explicit tests demonstrate the limit.

The initial suite51160/skip1 and initial ROOT1384 checks above apply ONLY to the
pre-review snapshot. Remediation targeted/full/ROOT counts and new source/input
parity are recorded after final-snapshot execution; no old audit or billion-event
baseline is rerun. Bounded baseline cache is reused with normal invalidation.

Remediation source snapshot:326 Julia files; Mac/gate source stream SHA256
c5dbbf6406c30b4cdf2f8eff6c02c3bda7372970ad43a48d1688586719d12bda
(review-source.sha256). Complete src/test/analyses/examples/bin stream SHA256
59fc99dcb70169570231d35407ed29c015ad2d1c9d2aeba10778d7ec1d154205
(review-validation-inputs.sha256), also identical. Same stream algorithm as above.
Source/tests are frozen before final full/real execution. Documentation/status
updates do not change those digests. git diff --check passed.

First review-targeted attempt stopped at a fixture assumption: an exactly
cancelling grouped pair is correctly pruned by existing Fit, so there is no
histosys modifier to select. Corrected the fixture to check pruned nominal20/20;
no product fix to Fit was needed. Subsequent targeted run uses review-targeted2.

Remediation targeted:review-targeted2.log/.exit =125 pass, exit0, including
23 cross-sample cancellation/fit checks,18 PDF acknowledgment/covariance checks,
3 direct orphan checks,10 plot-only cache/partial-rerun checks and71 original
focused regressions. These overlap final full-suite counts and are not additive.
Gate entry review-targeted.jl imports Test/Cascade and includes weights/fixtures,
test_theory_weights, test_theory_pipeline, test_theory_review, test_theory_partial
(in that order). Exact final-snapshot commands from p7-theory:

~~~sh
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/review-targeted.jl" > review-targeted2.log 2>&1; echo $? > review-targeted2.exit
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/runtests.jl" > review-full-suite.log 2>&1; echo $? > review-full-suite.exit
CASCADE_THEORY_REAL=1 CASCADE_THEORY_AREA="$PWD" JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/systematics/weights/test_theory_real.jl" > review-real.log 2>&1; echo $? > review-real.exit
~~~

Final remediation ROOT:review-real.log/.exit =1384 pass, exit0. The bounded
13-file/2,200,037-event baseline comparison again verifies7332 raw/scaled bins,
edges and sumw2 bit-identical to p6. Actual TT32,853events/1493kept-member checks
and independent direct-branch arithmetic/sumw2 pass on the frozen remediation
source. Normalization denominator/configured luminosity unchanged; partial
exposure explicitly unknown. No physical PDF branch validation is claimed.

Re-review targets are deliberately bounded to the five remediation contracts:
Config rejection before nonlinear multisample reduction, plot direct config key,
zero-declaration orphan detection, the theory_band include/file boundary, and
required PDF rank-one acknowledgment with covariance-limit explanation. Pair,
scale single-sample, signed-weight and baseline APIs are unchanged. Existing
metadata records the explicit PDF acknowledgment inside the full config record.

Final remediation full regression:review-full-suite.log/.exit =**51214 passed,
one existing plotting guard skip (Broken), exit0**. Area counts: audit55,
config202, corrections209, fit327, histograms28, IO62, objects23022, pipeline284,
plotting191, selection151, systematics26683. No failed assertions/errors.
All executions ended; this full suite validates the remediation source/input
snapshot stated above. Targeted125 and real1384 overlap and must not be added.
No source/test changes occurred during this final full/real validation.

## Extraction-contract blocker remediation (latest snapshot)

Re-review accepted the previous five fixes but found member values could be
silently relabeled after extraction-semantic edits during partial systematics/
plot reruns. The prior51214/125/1384 and c5dbbf... snapshot are historical evidence,
NOT final coverage of this fix.

- New Config.theory_extraction produces version1 canonical hash+contract records;
  validate_theory_manifest checks persisted labels/records, not current stamping.
- Correct persists the extraction-time contract in column metadata. Histogram
  propagates the original record unchanged. Every store merge validates incoming
  labels and same-sample contract compatibility before content mutation; manifests
  union only for compatible/disjoint samples, including empty selections.
- verify_theory_extraction compares persisted semantics with current config before
  reduction and histogram/merge/fit consumption. Systematics/plot checks run
  before output-cache reuse, so a same-label source alias change cannot bypass
  validation. Correct keys also include extraction fingerprints directly.
- No contract is inferred from current settings for legacy artifacts. Member-free
  baseline identity and the prior orphan-member error behavior remain. Direct
  API producers explicitly capture truthful manifests when constructing members.
- Tests reproduce nominal10/vector[2,4]/index2 relative40, reject same-label
  central edits on partial consumers, then fresh upstream yields20. Branch,
  layout, indices, source format/options, central/reference edits and missing/
  foreign records reject. Existing CL-only compatible partial reuse still passes.
- Merge tests cover same-contract accumulation, incompatible/missing manifests,
  pre-error immutability, disjoint/partial samples and empty-selection records.
  Existing observed fit provenance and nominal normalization remain untouched.

Exact latest commands from gate p7-theory use Julia1.12.2 and established wrapper:

~~~sh
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/contract-targeted.jl" > contract-final-targeted.log 2>&1; echo $? > contract-final-targeted.exit
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/runtests.jl" > contract-full-suite.log 2>&1; echo $? > contract-full-suite.exit
CASCADE_THEORY_REAL=1 CASCADE_THEORY_AREA="$PWD" JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/systematics/weights/test_theory_real.jl" > contract-real.log 2>&1; echo $? > contract-real.exit
~~~

contract-targeted.jl includes the previous review-targeted files, then
 test_theory_contract.jl. Initial contract-targeted passed163 before the final
histogram/merge/fit consumer guard and additional fit/empty tests; the latest
snapshot is validated separately below. No full inventory audit or historical
billion-event selection was run.

Latest extraction-contract snapshot:330 Julia source files, Mac/gate SHA256
b2b3a7e22010183417e1c4f616bd09b9b7f5b603f43cd1740ff932340354729b
(contract-source.sha256). Complete src/test/analyses/examples/bin stream SHA256
a9d63ffa1032d8b3475cecdeed7a77bdfd074115d3334b65d2732c7c0048509e
(contract-validation-inputs.sha256), also identical. Same sorted path+content
hash stream algorithm as earlier. No source/test edits during final full/ROOT.

contract-final-targeted.log/.exit:181 passed, exit0. This includes125 preceding
review checks plus39 partial extraction/consumer propagation checks,12 manifest
merge/API checks,2 empty-selection checks and3 partial-applicability checks.
The stage-propagation assertion was synchronized before this final test file
loaded; final full/ROOT runs begin only after that successful targeted snapshot.

Latest contract-real.log/.exit:1384 passed, exit0 on the extraction-contract
snapshot. Baseline comparison remains13files/2,200,037events and7332 raw/scaled
bins/edges/sumw2 bit-identical to frozen p6. TT32,853events/1493kept rows direct
member arithmetic and independent histogram sumw2 checks pass. Normal nominal
Runs denominator/luminosity preserved; actual exposure remains unknown. This
bounded validation is not real PDF closure or a full dataset rerun.

Extraction contracts intentionally describe per-index extraction semantics, not
input-inventory completeness or a malicious producer's truthfulness. Normal
source file signatures/upstream artifact keys remain responsible for inventory
and event-selection provenance. No user option bypasses manifest verification.
Persisted contracts are compared, never overwritten from current cfg during
histogram/merge/reduction; only actual correct extraction creates new records.

Latest final full regression:contract-full-suite.log/.exit =**51270 passed,
one existing plotting guard skip (Broken), exit0**. Areas: audit55, config202,
corrections209, fit327, histograms28, IO62, objects23022, pipeline284, plotting191,
selection151, systematics26739. No failed assertions/errors. All executions ended.
The final frozen source/input snapshot above is covered by this full suite,
181 targeted checks and1384 bounded ROOT checks; counts overlap, do not add.
Metadata-only audit cache and observed-fit overlap regressions passed unchanged.
Independent final concrete-diff review completed after the extraction-contract
fix. Original physics and stale-extraction blockers are resolved; no material
in-scope blocker remains for bounded Step2 reporting. The reviewer statically
checked propagation, compatibility, regression discriminators and all previous
fixes; runtime evidence was independently checked by the parent from gate logs
and current Mac/gate source/input hashes, not rerun by the reviewer.

Nonblocking review caveat: cached histogram/merge intermediate stages can skip
before their contract checks. Systematics/plot/fit validate compatibility before
cache reuse, closing the incorrect-template path. Do not claim every intermediate
cache hit validates before returning. Strengthening intermediate preflight is a
separate follow-up, not an implemented guarantee. PDF rank-one/covariance and
real-PDF-closure limits remain unchanged. Final parent edits only documentation
and state; the frozen source/test/input hashes and runtime evidence above remain
valid. Step2 stops for owner review; no push or later-step work.

## Final EOF whitespace closure

After final independent approval, staged whitespace checking found one redundant
blank line at EOF in src/Systematics/weights/reduce_theory.jl. Removed only that
blank line, preserving one trailing newline. No logic/API/test change; staged
index untouched for parent restaging. Source diff against staged snapshot is
0 added/1 deleted blank line. Parent final review/caveat notes above are preserved.

Final artifact Mac/gate330-source hash:
b1b74b3bb442eb3dcac9d3d62fb3fc6d7b23fda9dfc729d19668b1ab8506d153
(eof-source.sha256). Complete src/test/analyses/examples/bin hash:
1d71621e562814fcd593305bf2b38b3e8964c3861989d48470423e496e1e024b
(eof-validation-inputs.sha256), also identical. Same stream algorithm as above.

Full51270/skip1 and ROOT1384 evidence remains frozen on pre-whitespace
b2b3a7... / a9d63f... snapshot. It differs only by this semantically inert EOF
blank line; no expensive full-suite/ROOT rerun was performed for formatting.
Small final focused command (same181-check contract entry):

~~~sh
JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/contract-targeted.jl" > eof-final-targeted.log 2>&1; echo $? > eof-final-targeted.exit
~~~

eof-final-targeted.log/.exit:181 passed, exit0. Worktree diff --check passed.
Exact byte comparison against staged source verified current bytes plus one
newline equal staged bytes, and current source retains exactly one trailing
newline. Final staged diff --check also passed at parent closure. Git records
the local milestone commit; no push or later-stage execution. Final review and
nonblocking cache-hit caveat text remain unchanged.
