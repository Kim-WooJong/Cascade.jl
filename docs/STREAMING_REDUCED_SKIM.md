# Streaming reduced ROOT RNTuple bundles

Version0.6 refines Step4: new cascade reduce exports default to genuine bounded
TTree windows and automatic physical RNTuple shards. No input-file-size or
whole-source Events cap applies to this ROOT streaming path. This is still
**ROOT::RNTuple, not NanoAOD TTree**. Original serial/TTree/index-only skim defaults
are unchanged; no product Python, external C++ writer or new dependency is used.

## One TOML and existing commands

~~~sh
julia --project=/absolute/Cascade.jl /absolute/Cascade.jl/bin/cascade.jl reduce analysis.toml --output-dir /absolute/unused_bundle --max-files 1
julia --project=/absolute/Cascade.jl /absolute/Cascade.jl/bin/cascade.jl run /absolute/unused_bundle/analysis.toml --workdir /absolute/new_run
julia --project=/absolute/Cascade.jl /absolute/Cascade.jl/bin/cascade.jl batch plan /absolute/unused_bundle/analysis.toml --workdir /absolute/new_batch
julia --project=/absolute/Cascade.jl /absolute/Cascade.jl/bin/cascade.jl batch run /absolute/new_batch --workers 2
julia --project=/absolute/Cascade.jl /absolute/Cascade.jl/bin/cascade.jl batch merge /absolute/new_batch
~~~

Profiles and selected samples retain the existing interface. API:
Cascade.Pipeline.reduce_analysis(RunOptions(config; profile, samples, max_files);
output_dir=unused_directory). No overwrite, force/resume, scheduler or deployment.

~~~toml
[reduced_skim]
format = "root_rntuple"
mode = "streaming"             # default
retention = "analysis_union"
include = ["event"]
drop = []

[reduced_skim.streaming]
window_events = 20000
# Independent from input windows. Typed UNCOMPRESSED bytes, including offsets.
target_shard_events = 250000
target_shard_payload_bytes = 32000000
max_basket_bytes = 64000000
max_window_bytes = 128000000
max_buffer_bytes = 1024000000
max_metadata_bytes = 64000000
~~~

See examples/reduced_skim.toml. Legacy top-level max_events/max_input_bytes/
max_payload_bytes/max_buffer_bytes keep their old whole-source meanings ONLY
with mode="legacy_eager". They cause a clear migration error in streaming mode;
they are never silently reinterpreted as shard controls. Legacy eager export
still produces schema1; its documentation is REDUCED_SKIM.md.

Native cols inputs use explicitly declared bounded **eager compatibility IO**,
limited to256MB/1M input rows, then window-local processing/sharding. Export
checks file size before parsing, caps the JSON header at1MB, validates primitive
descriptors/counts/overflow-safe payload arithmetic against actual available bytes
and configured byte/buffer budgets, then scans offsets/Bool bytes in fixed-size
workspaces BEFORE payload vectors are allocated. Header and payload use the same
open handle; legacy export correction/theory readers borrow that validated source
rather than reopening it eagerly. Generic serial ColumnFileSource IO is unchanged.
These are not advertised as streaming. Only original built-in nanoaod/cols inputs are
exportable; derivative re-export remains rejected.

## Real bounded input, not whole-file slicing

IO.read_nanoaod_window constructs an UnROOT.LazyBranch, validates branch/tree
entry counts and basket boundaries, then decodes only overlapping baskets,
**one at a time**. Before decompression it bounds compressed bytes and reads a
fixed16-byte TKey prefix to check declared decoded fObjlen. It copies typed
scalar/list values into window-local arrays and offsets. Unsupported/recovered
basket layouts fail explicitly; no whole-source needed masks or padded arrays.

EventWindowSource owns only the current window's raw branch cache. Required
branches are preloaded without masked placeholders, including all selection,
object clean/sort, triggers/priority vetoes, histogram/region, correction,
shape/JER/JES/GenJet/rho/MET and theory/reference dependencies. An explicit drop
of a required branch fails. Window loading can shrink its event range before
selection when actual data exceed window/buffer budgets. An irreducible oversized
event/basket fails; it is never truncated or split across physical events.

Plans compile once per source. Nominal and EVERY applicable shape use the actual
earliest-region keep-stage union, including nominal JER. Raw unvaried typed
values, complete retained object lists/counters and original event order are
copied; all transformations run again on readback. UInt64 IDs are never exported
through derived EventTable Float64 values. Existing JER's Int64-ID input domain
is unchanged; its HashPRNG uses original jet/rho/event inputs, not chunk paths.

A borrowed-source BranchReader explicitly owns or borrows its source. Window
retention validation passes the current window to correction/theory readers,
including lazy scalar weights and absolute-vector references. No path reopen or
whole-source mask is permitted on that path. table.entry remains local; output
cascade_source_entry is the separate original1-based entry. Readback corrections
use physical-shard-local table.entry, never the original global entry.

Prefilter certified run/LS discovery also reads each original window. Only unique
coverage pairs and fixed-size cutflow accumulators persist. Per-variation
cutflow accumulators are updated in original event order, not added from window
subtotals. Original prefilter evidence stays once per logical source under its
exact semantic contract; reexecuted reduced prefixes remain a different population.

## Logical originals versus physical shards

Schema2 has one padded sample/00000001.source.json descriptor per original.
It owns ORIGINAL signed Runs normalization/status/provenance/count, canonical
population identity, source options/signature, full original Events count,
prefilter cutflows and LS/inventory/truncation evidence **once**.

Physical sample/00000001-00000001.root files are genuine bounded single-cluster
RNTuples. Their mandatory .cascade.json sidecars contain group ID, ordinal,
source-entry coverage interval, retained-row interval, raw schema and contract.
They have **no normalization value**. Neither repeated denominators nor a
first-owner-shard/fake-zero-nonowners shortcut is used. Unscoped physical-shard normalization APIs throw. A group metadata
source cannot concatenate Events; the pipeline enumerates verified physical tasks.

Source coverage intervals must form exactly1:N, independently of sparse retained
entry maps. Shard maps must be strictly ordered, unique and within their interval;
retained-row coverage is contiguous. Every original has at least one carrier,
including zero-retained and zero-original sources (empty source range1:0).
Missing/extra/duplicate/foreign/reordered/gapped/overlapping records, schema,
contract, header/count/map or checksum conflicts fail. Missing MC Runs cannot
fall back to retained genWeight; true zero and negative sums remain distinct.
Zero aggregate MC normalization fails.

Canonical meaningful device/inode identity, with persisted canonical-path
fallback, enforces same-sample original-population ownership. Several shards are
legal ONLY inside one complete declared group. Independent derivations/copies,
hardlink aliases and original+derivative duplication are not separate populations.
Explicit cross-sample sharing remains allowed; this is not event/collision dedup.

--max-files means **logical originals**, before physical expansion: A with4 shards
plus B with1, max-files1 selects ALL4 A shards and none of B. Skim/coverage/merge
report logical selected/available and physical counts separately. Original export
truncation composes with current selection; retained Events do not establish
luminosity. An original3+7pb^-1 coverage stays10 even if only LS2 is retained.
Configured luminosity/exposure-unknown semantics remain unchanged.

## Standalone serial, batch and cache integrity

Generated TOML uses built-in format="reduced_rntuple_group", empty source options
and logical descriptors, never arbitrary shard globs or process-local registries.
Original source paths are provenance only. Serial and fresh batch read published
bundle bytes without originals. Actual new-reader theory extraction is recorded;
original-reader extraction is retained separately, never relabeled.

Skim schema2 separates groups from physical files. Normalization sums selected
group denominators once in original group order. Shards merge in declared order,
then group subtotals merge in original order; theory reduces only after complete
sample merge. Current observed fit overlap is recomputed per shard and merged
as exact counts, retaining zero-weight/multivalue/flow safeguards.

Every downstream partial/cached stage binds CURRENT selected logical groups,
ordered shards and mandatory integrity signatures to persisted skim before
consumption. Changed source mappings/max-files require skim and appropriate
upstream stages. Full runs may refresh skim first. Compatible histogram-edge,
fit-channel and reduction-only theory changes retain the existing contracts;
input binding does not automatically refresh arbitrary skipped numerics.

Batch manifests freeze logical groups plus physical tasks. Workers verify their
own shard and immutable group/manifest bindings, not all sibling payloads per
task. Explicit worker scope is processing authority, NOT a complete-population
certificate: global skim/merge/systematics/fit/plot reject it. Coordinators verify
complete selected groups and exact task receipts before normalization/publication.
Global preflights hash payloads sequentially; no persistent hidden trust cache or
size-only replacement of checksums is used. Metadata/stat work can scale with
shard count; full sibling payload hashing is not quadratic in task count.

Manifest, descriptors and sidecars bind actual payload checksums, source options/
signatures, schema/retention/config/profile/code/payload/runtime provenance.
Checksums establish consistency, not hostile-producer attestation. Original large
inputs use identity/size/mtime, not full content hashes.

Whole-bundle publication retains nonoverwrite, safe containment/symlink checks,
an exclusive POSIX claim and same-filesystem staged directory rename. Fresh
Julia validation checks generated final-path TOML via stage-only input mapping,
all group/readers/raw schemas/contracts and fit references before publication.
Original inventory/config/code/payload signatures are rechecked after that child
validation, too. Failed intermediate shards/sidecars, source drift or invalid
configuration leave no accepted final bundle or overwritten prior output.
Scientific subsets are not silently pruned: excluded explicit theory/shape
references and proper fit subsets remain unsupported.

## Bounds, numerical scope and compatibility

Physical hard ceilings remain1M rows,64MB typed payload,256 columns and an encoded
file strictly below256MB, safely below the tested writer's32-bit positions. A
single event exceeding the configured shard payload target fails with an explicit
error; raise that target only within its64MB hard maximum. No append/multicluster
or external writer is required. Window/shard targets are independent.

max_buffer_bytes is conservative accounting (including16x raw/shard allowance,
selection outputs/shapes and basket budget), **not an OS RSS reservation**.
UnROOT locally mmaps the whole file virtually; decoded baskets, compilation,
allocator capacities, mapped-page residency and native library caches add memory.
Metadata grows with basket indexes, shards and unique LS pairs, not retained
all-source event arrays/ID lists. Header/descriptor/manifest budgets and conservative
metadata limits may reject pathological inputs. No arbitrary total-unboundedness,
fixed RSS, hostile concurrent filesystem defense, NFS/multihost coordination or
fsync/power-loss guarantee is claimed. Bounded process/thread counts still matter.

Physical repartition changes floating-point reduction trees. Exact raw types,
bytes, entry order/membership and original normalization are required. Same NEW
partition serial/batch is deterministic; universal old-partition bit equality is
not promised. Validation uses predefined contribution-scale bounds and explicit
near-cancellation/BigFloat reference evidence, not a loose relative-to-zero rule.

Schema1/0.5 bundle byte readers remain supported, including frozen actual bundles.
Existing analysis retention/code fingerprints are NOT rewritten: a preexisting
bundle may correctly require re-export after relevant code changes. This is reader
format compatibility, not a promise to bypass an old semantic-code contract.
Installed UnROOT0.11.11 is tested, compatible0.11 minimum pinned. Upstream documents
ROOT>=6.34 interoperability; independent executed proof is uproot5.7.1, not C++ ROOT.

Exact evidence and remaining limits: STREAMING_VALIDATION.md.
