# Analysis configuration reference

One TOML file defines an analysis. Start with `cascade init my_analysis`, edit
`my_analysis/analysis.toml`, then `cascade check my_analysis/analysis.toml`.
Run it with `cascade run my_analysis/analysis.toml`. Relative input/payload paths
are resolved against the TOML directory; relative workdirs against the process
working directory. `${name}` expands `[paths]` recursively (maximum 16 passes);
a leading `~` expands to the current user's home. Unknown keys produce errors
with their section path, including inactive profile overlays. Free-label
maps (`paths`, `variables`, trigger groups/streams, payload aliases/input
bindings, fit groups and plot label/color maps) accept arbitrary labels.
`cascade audit my_analysis/analysis.toml [--profile NAME] [--samples a,b]
[--workdir DIR]` freshly inspects all discovered selected-sample inputs and
writes JSON/Markdown reports. It does not alter the analysis pipeline or certify
dataset completeness. See [input audit](INPUT_AUDIT.md) for expectations,
severity rules, unknowns, and exposure boundaries.
Explicit `${ENV:NAME}` references read a nonempty environment variable; missing
values are errors. They may be nested in `[paths]` (for example
`certification="${ENV:CASCADE_GOLDEN_JSON}"`, then
`data_quality.golden_json="${certification}"`). No shell command is evaluated.
The Golden JSON remains an external input, resolved relative to the TOML if not
absolute, and its contents are hashed for selection caching.

## Resolution and options

`[profiles.NAME]` overlays the base configuration. Tables deep merge recursively;
**arrays replace in full**, including arrays of tables. There is no inheritance
between profiles. CLI `--profile NAME` (or `RunOptions(...; profile="NAME")`)
overrides `options.default_profile` (default: no profile). A selected profile
uses `<analysis.workdir>/<NAME>` unless CLI/RunOptions `workdir` explicitly
overrides it. Existing files without options/profiles retain their old behavior.
Only one profile is selected. An unknown profile is an error.

`[options]` keys:

| Key | Default | Meaning |
|---|---|---|
| `default_profile` | `""` | Profile selected when none is explicit |
| `corrections` | `true` | Boolean or list of enabled correction nuisance names (all terms of a name) |
| `shape_variations` | `true` | Boolean or list of enabled shape nuisance names |
| `jer_nominal` | unset | Boolean override for nominal smearing of every enabled JER |
| `fit` | `true` | False removes the fit section from the resolved configuration |

Every `[[corrections.object_sf]]`, `[[corrections.event_weight]]`,
`[[corrections.flat]]`, `[[corrections.trigger_or]]`, `[[shape_variations]]`, `[[fit.normsys]]` accepts
`enabled` (boolean, default true). Disabled entries are removed before consumers
see them; `enabled` itself is stripped. Option name lists further restrict the
remaining entries (they cannot enable an entry with `enabled=false`).
Resolution does not mutate the parsed dictionary. The resolved sections, not
the profile catalog, feed artifact keys. Switching corrections/selections/fit
therefore invalidates their dependent artifacts; editing an unused profile does
not. CLI `--workdir` is an exact explicit override, without a profile suffix.

```toml
[options]
default_profile = "baseline"
[profiles.baseline.options]
corrections = false
shape_variations = false
fit = false
[profiles.calibrated.options]
corrections = ["lepton_id", "pileup"]
shape_variations = ["JES", "JER"]
jer_nominal = true
fit = true
```

## Core sections

Required values below have no useful default. Arrays preserve TOML order.

| Section | Keys (defaults in parentheses) |
|---|---|
| `analysis` | `name` (`analysis`), `lumi_pb` (required positive for MC), `workdir` (`cascade_out/<name>`) |
| `paths` | Arbitrary string substitutions |
| `samples` array | `name`, `kind` (`mc`; `mc` or `data`), `files` (required array of globs), `format` (`nanoaod`), `xsec_pb` (positive for MC), `branching_ratio` (1), `stream` (`""`), `group` (sample name), `source` (reader keyword table) |
| `samples.source` | Reduced RNTuple: empty table, mandatory bundle metadata; NanoAOD: `tree` (`Events`), `runs_tree` (`Runs`), `gen_sumw` (`genEventSumw`); cols: `gen_weight` (`genWeight`). Custom source formats receive supplied keywords. Use only keys supported by that source |
| `samples.metadata` | Optional nonempty strings: `dataset`, `era`, `campaign`, `xsec_source`, `xsec_note`, `branching_ratio_source`, `provenance`; declarations only, also recorded in merge output |
| `samples.audit` | Optional `expected_nfiles`, `expected_nevents`, `expected_sumw`, `sumw_rtol` (1e-8), `sumw_atol` (0), `expected_files` (literal paths), `inventory_source`; see [audit contracts](INPUT_AUDIT.md) |
| `objects` array | `name`, `collection`, `cut` (`true`), `sort_by` (`""`: preserve order), `clean.against` (`[]`: earlier object names), `clean.dr` (0.4) |
| `variables` | Arbitrary name = event expression |
| `cuts` array | `name`, `expr`, `only` (`all`; `all`, `mc`, `data`) |
| `regions` array | `name`, `after` (cut name or `all`), `expr` (`true`: optional additional event predicate); absent: `signal` after last cut |
| `histograms` array | `name`, `values` (nonempty expressions), exactly one of `edges`, `range=[start,step,stop]`, `linspace=[lo,hi,nbins]`; `when` (`true`), `regions` (`[]`: all), `xlabel` (name) |
| `weights` | `mc` (`[]`), `data` (`[]`): multiplicative event expressions; `variations` (`[]`) with `name`, `up`, `down` multiplicative relative factors |
| `triggers` | `groups` (map name -> HLT branch list), `streams` (map stream -> group list), `priority` (`[]`: ordered data streams), `mc` (`[]`: OR of groups) |
| `data_quality` | `run_range` (all runs), `golden_json` (`""`: no mask), `run_branch` (`run`), `lumi_branch` (`luminosityBlock`); data only |
| `luminosity` | `mode` (`configured` or `certified`), `file` (`""`: per-LS JSON path), `unit` (`pb^-1`), `assume_complete_lumisections` (`false`); see [luminosity tracking](LUMINOSITY.md) |
| `output` | `columns` (`[]`): retained variable names for downstream SF bindings |
| `merge` | `yield_variable` (`""`: fallback first histogram) |
| `hooks` | `correct`, `systematics`, `fit`, `plot`: qualified Julia function names; absent uses built-ins |

Expressions use whitelisted Julia arithmetic, comparisons, logical operations,
math functions, `deltaR`, `mass_massless`, `mass_massive`, `pair_pt`, `trigger_match`, selected `object.field[index]`,
`length(object)`, variables, and event branches. `trigger` and `lumimask` are
built-ins. Object-scope expressions use bare collection fields. Guard absent
indices with `when` or earlier cuts. Event weight branch names are independent
of reader normalization names: changing `samples.source.gen_weight` does not
rewrite `weights.mc`. NanoAOD normalization sums the configured Runs branch;
column normalization uses `meta.gen_weight_sum` if present, otherwise the
configured event weight column, otherwise zero.
`mass_massive(pt1,eta1,phi1,m1,pt2,eta2,phi2,m2)` uses the supplied rest masses;
`pair_pt(pt1,phi1,pt2,phi2)` returns the transverse vector-sum magnitude.
The old massless helper is unchanged. Region masks, contributing-event overlap
checks for multi-channel observed fits, and their limitations are documented in
[regions](REGIONS.md). Trigger matching is configured explicitly for the
relevant path/era; it is not inferred from the HLT branch name.

## Correctionlib weights

Set `[hooks] correct="Cascade.Systematics.apply_corrections"` to activate
configured terms. `[corrections.sets]` maps free aliases to JSON/JSON.gz paths.
All terms apply only to MC. Terms sharing a name are varied together.

| Array | Keys |
|---|---|
| `corrections.object_sf` | `enabled` (true), `name`, `set`, `correction`, `object`, `indices` (required nonempty positive 1-based list), `when` (`""`: always), `inputs` (`{}`), `systematic` (`""`), `nominal` (`""`), `up`/`down` (`""`) |
| `corrections.event_weight` | Same, without `object`, `indices`, `when` |
| `corrections.flat` | `enabled` (true), `name`, `nominal` (1), `up`, `down` (required finite factors) |
| `corrections.trigger_or` | `enabled` (true), `name`, `path`, `topology` (`independent_single_path_or` required), `object`, `indices`, `when`, `data`, `mc`; see [trigger efficiencies](TRIGGERS.md) |

`set` references an alias; `correction` references its payload entry.
`inputs` maps payload input names to numbers or expressions. String-typed
payload inputs use literal string constants; numeric inputs use numeric
constants or expression strings. Object expressions must resolve to retained
`output.columns` variables; event expressions may read source branches.
`systematic` names the payload's variation-selector input, with a required
`nominal` selector and either both `up`/`down` selectors or neither. It cannot
also appear in `inputs`. MC base weights multiply every applicable term.
`trigger_or.data` and `.mc` each use `set`, `correction`, `inputs`,
`systematic`, `nominal`, `up`, `down`. They must evaluate **efficiencies**, not
per-object SFs. Only the explicitly declared independent-object OR of a single
single-object trigger path is supported, not an arbitrary trigger menu.

## Yield and luminosity outputs

`merge/samples.json` and `merge/yields.tsv` expose `cutflow_yield` (base weights
times normalization) and `histogram_integral` (the chosen corrected histogram
integral). `histogram_variable` records the chosen observable. These are not
interchangeable: multiple fills, `when`, and underflow can change the histogram
integral. Legacy `yield`/`hist_yield` aliases are retained. Region counts apply
the region's actual predicate; sequential cutflow tables remain prefix counts.
Luminosity metadata records configured/used luminosity, file truncation and
coverage status. No file-count or event-count luminosity extrapolation is made.

## Shape variations

Common `[[shape_variations]]` keys: `enabled` (true), `name`, `collection`,
`kind` (`jes`, `jer`, `scale`), `fields` (`["pt","mass"]`), `samples`
(`[]`: all MC), `met` (`""`: no recoil), `met_min_pt` (15). Data never varies.
Names must match `[A-Za-z0-9_]+` and must not duplicate weight nuisances.

| Kind | Additional keys |
|---|---|
| `scale` | `up`, `down`: required object-scope multiplicative expressions |
| `jes` | `corrections`, `source`: required payload path/entry; evaluates uncertainty at stored eta/pt |
| `jer` | Required `corrections`, `resolution`, `scale_factor`, `smear_file`; `smear` (`JERSmear`), `rho` (`Rho_fixedGridRhoFastjetAll`), `event` (`event`), `genjet` (`GenJet`), `genjet_index` (`genJetIdx`), `match_dr` (0.2), `match_nsigma` (3), `nominal` (false) |

JES/JER `inputs` (`{}`) maps semantic input names to payload names, e.g.
`inputs={JetEta="eta", JetPt="pt", systematic="variation"}`. Semantic names:
JES `JetEta, JetPt`; JER resolution `JetEta, JetPt, Rho`; JER SF
`JetEta[, JetPt], systematic`; smear `JetPt, JetEta, GenPt, Rho, EventID, JER,
JERSF`. Unmapped names retain their current defaults. This renames contracts;
it does not reorder positional payload inputs or redefine their physics.
At most one enabled nominal JER is allowed per collection.

## Fit

Absent `[fit]` skips fitting. `options.fit=false` also skips it.

| Key | Default |
|---|---|
| `channels` | Required nonempty array `{region, variable, name?}`; name defaults `region_variable` |
| `signal` | Required fit sample/group names carrying the POI |
| `poi`, `poi_init`, `poi_bounds` | `mu`, 1, `[0,10]` |
| `grouping` | `group` (`sample` also supported) |
| `groups` | Optional map of explicit fit sample name -> analysis MC sample list; replaces grouping |
| `data` | All data sample names |
| `staterror`, `histosys` | true, true |
| `histosys_exclude`, `histosys_prune` | `[]`, 0 |
| `normsys_code`, `histosys_code` | `code4` (`code1` also), `code4p` (`code0` also) |
| `impacts`, `profile_interval` | true, true |
| `upper_limit`, `significance`, `asimov` | false, false, false |
| `normsys` | Array; each entry has `enabled` (true), `name`, `samples` (`["all"]`), `placeholder` (false), either `size` (hi=1+size, lo=1-size) or positive `hi` and `lo` |

Shape/weight histogram pairs become histosys unless excluded/pruned. Missing
sample-specific variations fall back to nominal. Placeholder priors are not
measurements and must be replaced before physics interpretation.

## Plot

All `[plot]` keys optional:
`formats=["png","pdf"]` (one or both), `lumi_label` (derived from luminosity),
`energy="13.6 TeV"`, `extra="Preliminary"`, `regions=[]`, `variables=[]`,
`logy=[]`, `region_labels={}`, `labels={}`, `colors={}`, `data` (all data),
`groups` (ordered array `{label,color,samples}`; default sample grouping),
`prefit=true`, `postfit=true`, `tables=true`, `cutflow=true`, `impacts=true`,
`band_normsys=true`, `max_impacts=30`.

## CLI and API

`cascade run FILE [--profile NAME] [--steps a,b | --from STEP | --only STEP]`
accepts `--samples a,b`, `--force`, `--workdir DIR`, `--max-files N` (0: all).
`cascade check FILE [--profile NAME]` validates configuration and expressions,
prints sample file counts, cuts/regions, enabled corrections/shapes and fit.
It does not read event files or certify payload physics. `cascade init DIR`
writes a commented template as `DIR/analysis.toml`, refusing to overwrite.

Julia: `load_analysis(path; profile="", validate=true)`,
`parse_analysis(dict; profile="", path="", dir=pwd())`,
`resolve_config(dict; profile="")`, `RunOptions(path; profile="", ...)`,
`check_analysis(options; io=stdout)`, `init_analysis(dir)`.

## Theory vector systematics

Optional [[theory_weights]] declares explicit vector indices, sample applicability,
normalization and histogram-level reduction. See [THEORY_WEIGHTS.md](THEORY_WEIGHTS.md).
Default profiles remain unchanged; ttbar theory_example is opt-in and declares
only the inspected scale/PS layouts, not an inferred PDF prescription.

PDF band reducers additionally require pdf_template_model="rank_one" to
acknowledge the single fully correlated bin-shift approximation, not preservation
of replica/eigenvector covariance. Nonlinear theory reducers accept only one
distinct sample; pair can correlate multiple samples. See theory docs for limits.

Internal theory extraction provenance is persisted by correct/histogram/merge,
not configured by a user override. See THEORY_WEIGHTS.md for the version1
manifest/API contract and partial-rerun incompatibility rules.

## Opt-in reduced export

`[reduced_skim]` configures the distinct `cascade reduce` command. The generated
analysis TOML defaults to built-in `format="reduced_rntuple_group"` logical descriptors
(schema2); explicit legacy_eager uses `reduced_rntuple` (schema1). Both have empty `source` options,
not `nanoaod`. See [STREAMING_REDUCED_SKIM.md](STREAMING_REDUCED_SKIM.md) for
independent window/shard controls, logical max-files and retention compatibility,
original normalization/exposure provenance, resource limits and publication.
