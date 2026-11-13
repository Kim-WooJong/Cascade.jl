# Regions and independent fit channels

Regions preserve the sequential cutflow and can additionally select independent
event categories. `after = "all"` applies no sequential cut; otherwise it names
the last required cut. `expr` defaults to `"true"`, preserving existing analyses.
It is evaluated only after that prefix passes, using the same whitelisted
event expressions, variables and selected objects as cuts.

```toml
[[regions]]
name = "zero_b"
after = "baseline"
expr = "length(bjets) == 0"

[[regions]]
name = "one_b"
after = "baseline"
expr = "length(bjets) == 1"

[[regions]]
name = "many_b"
after = "baseline"
expr = "length(bjets) >= 2"
```

These categories are disjoint; successive `after` cuts alone usually define
nested regions. Inclusive or overlapping regions remain useful and legal for
histograms and plots. Region yields use actual membership, while cutflow tables
continue to describe only the sequential cuts.

## Fit protection

The likelihood treats channels as independent Poisson observations. Before a
multi-channel observed fit, Cascade checks actual selected data entries for
overlap **only among the active fit channels**. Each channel is a region and a
histogram; two different histograms in one region can also double count data.
Histogram `when` predicates, all value expressions and flow handling enter the
check: NaN and underflow do not contribute; overflow (including positive
infinity) folds into the last bin. Zero or cancelling weights do not establish
disjointness. A positive shared-event count raises an error naming the channels,
sample and count before the workspace or fit is built. Use exclusive region
expressions or fit only one channel when overlap is intentional.

Selection tables store `r:<region>` membership columns. `region_masks(table)`
and `region_counts(table)` expose masks and actual count/weight summaries;
legacy tables without mask metadata keep their old prefix-stage interpretation.
Merge aggregates `Fit.channel_overlap_provenance(table, cfg)` with
`Fit.merge_channel_provenance!` into histogram-store metadata under
`fit_channel_provenance`. The fit checks channel definitions and histogram
edges against that metadata. A changed fit-channel list requires rerunning
merge, not selection. Multi-channel observed stores lacking complete provenance
fail clearly; a histogram integral cannot prove that its entries are disjoint.
Single-channel and data-free fits do not require provenance. Synthetic
`fit.asimov = true` workspaces replace observations with expected counts and
also bypass this observed-data check; that bypass does not prove independence
of physical channels for a later observed fit.

The identity unit is one entry in one selected source chunk. This check does
not deduplicate the same physical collision repeated in different source files
or samples; dataset uniqueness and stream arbitration remain input duties.
Custom template hooks must retain the metadata and preserve channel membership;
custom changes to membership must regenerate provenance.

## Massive-pair kinematics

Whitelisted event/variable helpers:

```julia
mass_massive(pt1, eta1, phi1, mass1, pt2, eta2, phi2, mass2)
pair_pt(pt1, phi1, pt2, phi2)
```

`eta` is pseudorapidity, `phi` is in radians, and masses and transverse momenta
use common units. Both helpers evaluate in Float64. `mass_massive` requires
nonnegative transverse momenta and rest masses, uses massive four-vectors and a
cancellation-resistant rapidity expression. The existing `mass_massless`
formula and argument-precision behavior are unchanged and remain bit-exact for
existing analyses.
