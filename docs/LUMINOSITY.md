# Luminosity provenance and yield accounting

The default plot luminosity label uses the normalized store's `lumi_pb`, so
certified-mode normalization and its default annotation agree. An explicit
`plot.lumi_label` remains a user-controlled override and should be updated if
the exposure changes.

## Default: explicitly configured normalization

Without `[luminosity]`, or with `mode = "configured"`, MC keeps the existing
`analysis.lumi_pb` normalization exactly. No luminosity is inferred from file
counts or event counts. Data are unscaled. In particular, `--max-files` is a
file limit **per sample**, not a luminosity fraction. A truncated run records
unknown exposure and warns that the configured normalization was retained.
This is useful for framework tests; it does not automatically produce a
physics-correct data/MC comparison for a subset.

## Opt-in: luminosity of certified, observed lumisections

The single analysis TOML may opt in:

```toml
[analysis]
lumi_pb = 1000.0 # retained as configured reference in provenance

[data_quality]
golden_json = "certification.json"
run_range = [355100, 362760]
run_branch = "run"             # optional NanoAOD default
lumi_branch = "luminosityBlock" # optional NanoAOD default

[luminosity]
mode = "certified"
file = "luminosity_per_ls.json"
unit = "pb^-1" # this is the only accepted unit; default if omitted
assume_complete_lumisections = true
```

The per-LS JSON must map each run and lumisection explicitly to integrated
luminosity in inverse picobarns (not a certification interval or an event
count):

```json
{"355100": {"1": 0.012, "2": 0.013}, "355101": {"1": 0.014}}
```

Paths are resolved relative to the TOML, with its `[paths]` substitutions.
The table is supplied by the analyst; Cascade does not synthesize one from
input sizes, events, cross sections, or the Golden JSON.

The skim step reads the configured run/LS branches of **all events in selected
data files, before physics cuts**. It applies the Golden JSON and run range,
then the merge step unions the observed pairs across files and primary data
streams. A run/LS pair contributes at most once, including duplicate events or
multiple primary datasets. Every included pair must have a finite,
nonnegative table value; missing entries fail rather than silently biasing the
normalization. MC normalization uses this union's table sum. Empty coverage,
zero total luminosity, missing certification, or no selected data samples fail.

**Observed pairs are not proof of complete exposure.** A truncated input file
list can split a lumisection; a triggered/filtered dataset can omit entire
lumisections or only part of their events. Correct trigger/stream availability
and full lumisection coverage cannot be established from these event branches.
Consequently certified mode requires the explicit
`assume_complete_lumisections = true` acknowledgment. Its recorded status is
`assumed_complete_observed_lumisections`, not “measured exact exposure.” Use it
only when completeness is established independently. It is not an automatic
correction for arbitrary file subsets. Certification establishes acceptable
run/LS ranges, not the completeness of a selected dataset.

Skim caches incorporate table and certification content SHA-256, mode,
completeness assumption, branch names, run range, selected-file signatures,
and available-file counts. Merge caches also include this exposure provenance.
Changed payload content invalidates the relevant artifacts even if its path
is unchanged. Old/mismatched skim coverage is rejected in certified mode.

Both raw and normalized merged histogram stores and `merge/samples.json`
record `luminosity` provenance: `lumi_configured_pb`, `lumi_used_pb`,
`observed_lumisection_lumi_pb`, exposure status/scope, truncation, selected and
available file counts, payload hashes, union coverage, and per-sample counts.
The top-level `lumi_pb` remains the luminosity actually used for normalization.
The raw histogram store remains unnormalized despite carrying this provenance.

## Event yields versus histogram integrals

Region JSON records use explicit names:

| Field | Meaning |
| --- | --- |
| `selected_event_count` | Raw selected-event count for the region |
| `cutflow_sumw_raw` | Region selected-event cutflow weight sum before luminosity normalization |
| `cutflow_yield` | `norm * cutflow_sumw_raw`, not necessarily a corrected histogram prediction |
| `histogram_integral` | Sum of stored bins of the normalized selected histogram |
| `histogram_variable` | Histogram used for that integral |

`yield` aliases `cutflow_yield`; `hist_yield` aliases `histogram_integral`.
`n` and `sumw` are the old event-count and weight-sum aliases. TSV reports keep
their original columns and append the canonical names. Shape-yield reports
provide event/cutflow quantities only; their histogram integral is unavailable.

A histogram integral is not guaranteed to equal the selected-event yield:
`when` can remove fills, multiple value expressions can fill more than once
per event, corrections can change weights, NaNs and underflow are dropped,
and overflow is folded into the last bin. The event-yield name must not be
used to describe an arbitrary histogram integral. None of these naming changes
alters a histogram bin, selection cut, correction, or default normalization.
