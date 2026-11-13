# Trigger efficiencies and matching

Existing HLT decisions and primary-dataset overlap removal are unchanged.
Trigger weights and object matching are opt-in; existing ttbar configurations
retain their factors and multiplication order. No measured efficiencies are
provided by this feature. The DY example's leading-muon trigger SF remains an
explicit approximation, not an event-OR efficiency correction.

## Supported event efficiency

For one **single-object trigger path**, assume the configured selected objects
are independent trials. For each event, evaluate data and MC probabilities
separately and compute

```text
eff_data = 1 - product(1 - eff_data_object)
eff_mc   = 1 - product(1 - eff_mc_object)
SF_event = eff_data / eff_mc
```

This is **not** the product of object scale factors. Scale-factor-only payloads
do not determine these probabilities; actual data and MC efficiency payloads
are required. Correctionlib schema-v2 payloads may come from separate files or
distinct corrections in the same file. The configuration author must establish
that they describe efficiencies for the named path and the relevant selection.

The supported topology must be declared explicitly. Correlated object trials,
ORs across different HLT paths, asymmetric/double-object trigger legs, and
multi-leg assignment are unsupported. Their probabilities cannot be inferred
from marginal per-leg efficiencies. Unsupported topology declarations are
rejected. `path` labels the payload's physical path; it does not change the
`trigger` builtin or add an HLT cut automatically.

```toml
[hooks]
correct = "Cascade.Systematics.apply_corrections"

[corrections.sets]
trigger_efficiencies = "/path/to/real_efficiencies.json.gz"

[[corrections.trigger_or]]
name = "single_mu_trigger"
path = "HLT_IsoMu24"
topology = "independent_single_path_or"
object = "muons"
indices = [1, 2]
# Optional: objects outside the payload's eligible domain contribute zero.
when = "pt > 26.0"

[corrections.trigger_or.data]
set = "trigger_efficiencies"
correction = "data_efficiency"  # use the actual payload's correction name
inputs = { pt = "pt", abseta = "abs(eta)" }
systematic = "variation"
nominal = "nominal"
up = "up"
down = "down"

[corrections.trigger_or.mc]
set = "trigger_efficiencies"
correction = "mc_efficiency"    # use the actual payload's correction name
inputs = { pt = "pt", abseta = "abs(eta)" }
systematic = "variation"
nominal = "nominal"
up = "up"
down = "down"
```

This is a schema example, **not a supplied calibration**; input names and keys
must match a real payload. `[output] columns` must retain the object quantities
used by these expressions, e.g. `muons.pt[1]`, `muons.eta[1]`, and equivalents
for index 2. Every configured position must exist in selected events; guard
multiplicity in selection. Repeated indices are rejected.

Each efficiency must be finite and in `[0,1]`, including every variation.
The ratio fails with an informative error when MC event efficiency is zero
(also when no configured object is eligible); there is no unity fallback or
probability clipping. Empty event tables remain valid.

Up/down are a single correlated nuisance named by `name`: all objects and both
data/MC payloads are reevaluated in the same direction before rebuilding the
event OR. A payload without up/down remains nominal. Terms elsewhere sharing
the same name vary coherently through the existing weight-combination API.
Use appropriate payload variation keys; this declaration does not derive an
uncertainty or covariance from statistical independence. `enabled` and
`options.corrections` filtering apply as for other correction terms.

## Optional trigger-object matching

An event cut or variable can use

```toml
[[cuts]]
name = "trigger_match"
expr = "trigger && length(muons) >= 1 && trigger_match(muons.eta[1], muons.phi[1], 13, 2, 0.1)"
```

The five arguments are reconstructed eta, phi, absolute particle ID, required
filter-bit mask, and a positive maximum delta-R. The helper reads the current
event's `TrigObj_eta`, `TrigObj_phi`, `TrigObj_id`, `TrigObj_filterBits`. It
requires all bits in the mask, uses wrapped phi, and applies strict
`deltaR < max_dr`; mask zero imposes no filter-bit restriction. Nonfinite
coordinates do not match. Empty trigger-object collections return false.

Particle IDs and filter-bit meanings are NanoAOD/campaign/path specific: the
example mask is illustrative and must be replaced with the intended mask.
The helper does not establish that the named HLT path fired, enforce one-to-one
multi-leg matching, or select an efficiency payload. Keep the HLT decision and
appropriate object multiplicity guards in the cut. Matching and trigger OR
weights are independent opt-ins.

## Bounded validation

Gate scratch `~/analisis/Cascade_dev/p5-trigger` contains the execution log
`trigger-final.log`. The complete weights test entry plus the dedicated
matching tests passed **496 assertions**, exit **0** (47 new OR assertions and
16 matching assertions). This includes exact legacy synthetic weights,
synthetic end-to-end correction pipelines, and correction-cache regressions.
Real-data and external-oracle tests were disabled; no all-data run was started.

After syncing source/tests and the established gate Manifest, the command was:

```sh
D="$HOME/analisis/Cascade_dev/p5-trigger"
nice -n 10 env JULIA_THREADS=2 OPENBLAS_NUM_THREADS=1 \
  CASCADE_REAL_DATA=0 CASCADE_PYHF_ORACLE=0 \
  bash ~/packages/rootplots-gate.sh --project="$D" -e \
  'using Test, Cascade; include(joinpath(ARGS[1],"test/systematics/weights/runtests.jl")); include(joinpath(ARGS[1],"test/selection/test_trigger_match.jl"))' "$D"
```
