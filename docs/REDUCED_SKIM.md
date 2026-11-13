# Legacy eager reduced ROOT RNTuple bundles (schema1)

Current0.6 default streaming/sharding: STREAMING_REDUCED_SKIM.md.
This page documents retained0.5 eager mode and shared scientific safeguards.

Version 0.5 adds an explicit, opt-in export. The existing index-only pipeline
skim and original NanoAOD TTree reader/default serial execution are unchanged.
A reduced ROOT file contains a genuine ROOT::RNTuple, **not a NanoAOD TTree**.

## One analysis TOML, CLI and API

~~~sh
julia --project=/absolute/Cascade.jl /absolute/Cascade.jl/bin/cascade.jl reduce analysis.toml --output-dir /absolute/unused_bundle --profile baseline --max-files 1
julia --project=/absolute/Cascade.jl /absolute/Cascade.jl/bin/cascade.jl run /absolute/unused_bundle/analysis.toml --workdir /absolute/new_run
julia --project=/absolute/Cascade.jl /absolute/Cascade.jl/bin/cascade.jl batch plan /absolute/unused_bundle/analysis.toml --workdir /absolute/new_batch
~~~

Profile/sample/max-files options are optional; output-dir is required. No force,
resume, overwrite, automatic splitting or dependency installation occurs.
API: Cascade.Pipeline.reduce_analysis(RunOptions(config; profile, samples,
max_files); output_dir=unused_directory). Each sample uses padded ordinal files,
preserving the original sorted file partition/reduction order.

~~~toml
[reduced_skim]
format = "root_rntuple"
mode = "legacy_eager"
retention = "analysis_union"
include = ["event", "PSWeight"]
drop = []
max_events = 1000000
max_payload_bytes = 64000000
max_input_bytes = 256000000
max_buffer_bytes = 1024000000
~~~

The generated resolved analysis.toml maps files to format="reduced_rntuple"
with an empty samples.source table. It recomputes actual reduced-reader theory
extraction provenance; original extraction is separate sidecar evidence.
Every successful export validates the generated final-path TOML in a fresh
Julia process before publication. Validation uses an explicit stage-only input
mapping, checks every output reader/schema/retention contract and never writes
through planned final paths. Scientific declarations are not silently pruned:
subsets excluding explicit theory or shape references are rejected, and any
proper sample subset with a fit section is conservatively unsupported. Supply
an explicitly revised complete analysis when that scientific change is intended.
Full-sample fit data/signal/group/channel references are also validated.

Original sample audit expectations are retained in manifest resolved_config,
not reapplied as retained-Events expectations. Other analysis metadata survives.
Generated paths are absolute. To relocate, explicitly update file mappings and
external payload paths in a working analysis TOML, retaining the bundle layout.

## Scientific retention and compatibility

Retention unions the actual keep_stage entries of nominal and every applicable
configured shape, including nominal JER. This is the earliest region-prefix
contract, not a nominal final-selection skim. Raw original branch values are
written; shapes are rerun. Every retained object's full input list and counters
remain intact. Local selection table.entry indexes reduced rows for correction
BranchReader; source_entry separately maps to original 1-based source entries.
The RNTuple provenance branch is cascade_source_entry. No original backlink read
is performed. JER HashPRNG uses original raw jet inputs/rho/event ID, not paths
or newly assigned rows. Existing JER Int64 event-ID conversion constraints are
unchanged; preserving UInt64 storage does not extend that correction's domain.

Required branch closure uses compiled pre/post object/selection/output/region/
histogram/scalar-variation dependencies, triggers including priority vetoes,
run/LS aliases, shape inputs and correction event-weight expressions, theory
members/reference branches and available IDs/generator/scale/PDF/PS vectors.
Present collection counters are retained. Additional branches may be included;
explicit drop of a required branch fails before publication. Unsupported types,
inconsistent lengths/offsets/counters and custom/replaced hooks/readers fail.
Only original built-in nanoaod/cols inputs can be exported; derivative re-export
is rejected. Original cols MC requires explicit gen_weight_sum metadata.

Reuse enforces an exact semantic retention contract over selection/object/
variable/output/region expressions, histogram value/when/region declarations,
weights, extraction inputs, correction configuration/payloads, shape settings/
payloads, trigger/data-quality and relevant selection/shape code. Changed cuts
or shapes require re-export; no arbitrary alternate selection is promised.
Histogram edges and fit channels may change; overlap is recomputed. Theory
reduction-only settings such as CL scale do not alter retained raw population.
Correction configuration changes are conservatively rejected even if a narrower
change might be safe.

## Original versus retained populations

There is one output for every original file, including zero-retained outputs.
The original signed Runs denominator, status/tree/branch provenance and original
Events count are separate from retained counts and retained genWeight sums.
The reduced reader never falls back to retained genWeight. A per-file true zero
is distinct from missing normalization; zero aggregate MC normalization fails.
Ownership prefers meaningful persisted device/inode, independently of descriptive
realpath aliases; only sources without usable inode identity fall back to their
persisted canonical absolute realpath. Derivative reads never reopen originals.
Duplicate derivations, hard-link aliases and repeated original normalization
populations within one sample fail serial/audit/batch ownership checks. This is
not collision/event-ID deduplication and does not prohibit configured
cross-sample sharing.

Before any downstream select/correct/histogram/merge/systematics/fit/plot stage,
including cached returns and direct step calls, the persisted skim file list and
ROOT/sidecar/manifest signatures must match the current selected reduced inputs
and max-files partition. A source mapping switch requires skim and required
upstream stages to be rerun; a full run is allowed to refresh skim first. This
is input binding, not automatic refresh of arbitrary omitted numerical stages.
Fresh batch workers bind explicitly to their verified one-file task.

Original per-file nominal/shape cutflows are stored under an exact semantic
fingerprint. Reexecuted cutflow prefixes describe **retained events** and may
differ from original all-event prefixes. Merge reports these populations
separately; original evidence is not fabricated by adding residual sums or
relabeling current cutflows. Retained region yields/histograms/templates must
close against the original run. Filewise original cutflows remain separate to
avoid a changed floating-point reduction order.

Original inventory/max-files truncation and prefilter certified run/LS coverage
are preserved. Explicit certified mode consumes the preserved coverage only
under the same luminosity/table/Golden JSON contract, or fails. Retained Events
cannot shrink a 3+7 pb^-1 prefilter coverage to 7 pb^-1. Configured mode retains
unknown exposure, never infers luminosity from event/file counts. Complete LS
and stream coverage remain user assumptions, not established measurements.
Observed fit overlap is recomputed from current compatible retained raw events,
including existing zero-weight, multivalue and flow semantics.

## Integrity, limits and dependencies

Each payload has mandatory .cascade.json metadata. manifest.json binds every
payload/sidecar checksum, original identity/signature/options, population,
coverage, cutflows, schema, profile/config/code/payload/runtime fingerprints.
Readers verify bytes without opening original paths. Serial cache signatures
and batch input identities include payload/sidecar/manifest integrity. Checksums
establish internal consistency, not malicious-producer attestation or independent
dataset completeness. Original large ROOT signatures remain identity/size/mtime,
not full content hashes; preserving all of these during an in-place rewrite is
outside the input mutation detection contract.

Publication uses an exclusive local POSIX flock claim and same-filesystem staged
whole-directory rename. Existing destination, unsafe paths, symlink ancestry,
source drift, failed writes and invalid bytes never publish a final bundle.
The parent filesystem must be trusted/stable; hostile concurrent replacement,
NFS/multihost coordination and fsync/power-loss durability are not promised.

The existing qualified UnROOT.write_rntuple API is pinned to UnROOT >=0.11.11
within the 0.11 series. No new dependencies, product Python or external C++
writer bridge are introduced. Python uproot is used only as an independent
validation oracle. UnROOT documents ROOT >=6.34 interoperability; direct proof
here is independent uproot5.7.1, not a C++ ROOT runtime test. ROOTPlots plotting
output does not provide a TTree writing API.

The writer is eager: one RNTuple/cluster and one page per column, with 32-bit
TFile positions. Hard maximums above may only be lowered. Source input file size
and Events count are bounded before selection; NanoAOD required uncompressed
branch totals are bounded before branch materialization. Actual raw scalar/
jagged payload including offsets is checked before retention copies/writing.
The 64 MB payload ceiling conservatively leaves room below 32-bit positions;
a 256-column ceiling and preselection conservative eager-buffer estimate
(16 times uncompressed bytes, 128 bytes per event/list, selection-output tables
and schema overhead) are checked against max_buffer_bytes. This is accounting,
not an OS RSS reservation; multiple temporary buffers and runtime compilation
can use additional memory. ColumnFileSource is eager on open. No streaming,
append, multiple trees or automatic shard/denominator duplication is claimed.
Bitwise supported primitive tests, including NaN payload and negative zero,
are recorded in REDUCED_SKIM_VALIDATION.md; unsupported nested/struct/string
schemas fail instead of coercing values.
