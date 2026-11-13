# Deterministic process batch execution

Default `cascade run` is unchanged. The opt-in local POSIX backend uses one
task per existing input-file chunk, in sample order and sorted file order.
Worker count, launch order and completion order do not change that partition
or the existing sample-wise reduction tree.

## One TOML, CLI and API

Add optional settings to the analysis TOML (defaults: one worker/one thread):

~~~toml
[batch]
workers = 2
threads = 1
~~~

~~~sh
julia --project=. bin/cascade.jl batch plan analysis.toml --profile baseline --workdir /absolute/batch_run
julia --project=. bin/cascade.jl batch status /absolute/batch_run
julia --project=. bin/cascade.jl batch worker /absolute/batch_run TASK_ID
julia --project=. bin/cascade.jl batch run /absolute/batch_run --workers 2
julia --project=. bin/cascade.jl batch merge /absolute/batch_run --through systematics
~~~

Plan accepts normal profile/sample/max-files options; explicit unused workdir
is required. Plan never overwrites an existing run. Task IDs are in manifest.json.
`run` is also resume: it reuses only verified results and retries each unverified
task once. Change concurrency with --workers without changing the manifest.
Merge --through accepts merge/systematics/fit/plot (default systematics); choose
the complete global-phase prefix before first publication. Existing results
with another phase request are not overwritten. Final normal analysis layout
is `WORKDIR/result`. No external scheduler or deployment adapter is installed.

Exported API in Cascade.Pipeline: batch_plan(RunOptions(...)),
batch_worker(workdir, task_id), batch_run(workdir; workers=nothing),
batch_status(workdir), batch_merge(workdir; steps=[:merge,:systematics]).
Use CLI/orchestration for fresh-process workers; direct worker API executes
in its caller and is intended for controlled integration/testing only.

Exit codes: 0 success; 1 runtime/contract/claim failure; 2 malformed command;
3 valid but incomplete status. Status emits JSON; failures print stderr.
Attempt state and worker.log retain diagnostic evidence; launches record
fresh-process stdout/stderr and explicit exitcode JSON. Attempts with running
state but no receipt may be interrupted; the lock, not that state, determines
whether retry is safe. There is no automatic infinite retry or job killing.

## Frozen contract and deterministic scope

Manifest schema1 pins original TOML bytes, selected profile and resolved
configuration, source/all repository bin launchers/Project/Manifest content,
Julia version/platform, relevant runtime environment, built-in hook IDs,
correction/shape/luminosity/golden
payloads, extraction semantics, discovered paths/physical identities/size/mtime,
skim metadata (including signed nominal Runs provenance) and exact task list.
Every action revalidates it, including worker-command construction before spawn.
A different config/code/payload/input inventory requires a new run directory; do not edit/re-sign old manifests.

Large ROOT inputs use signatures/physical identity, not full content hashes.
An in-place rewrite preserving size/mtime/inode is outside this signature
contract. Fingerprints detect accidental drift, not a malicious producer who
rewrites receipts and hashes. Input files/source/payloads must remain immutable
through planning/execution. Discovered inventory and user-declared expected
counts are not independent dataset-completeness certificates. Truncated input
coverage retains unknown actual exposure and configured-luminosity provenance.

Exact equality is scoped to identical files, file chunks, code, configuration,
Julia/runtime and numerical environment. It is not promised after repartitioning
events, changing a reduction tree, platform or dependency versions.

## Output isolation boundary

Batch planning and every manifest load reject unsafe output-bearing components:
sample/region/histogram/shape names, fit channel names and region/variable fields,
and plot region/variable/log-y selectors. Components must be nonempty letters,
digits, underscore, hyphen or dot, excluding standalone dot/dot-dot. Absolute
paths, separators and traversal are rejected even for tables-only plots. This
restriction belongs only to batch; ordinary serial config naming is unchanged.

Preexisting symlink ancestry is rejected before creating locks, attempts, merge
stages, launch logs, JSON temporaries or spawning a child. Lexical containment
also protects receipt artifact paths and published output references. The
workspace and its parents must be trusted and remain stable: protection against
a hostile simultaneous filesystem replacement is not claimed.

## Claims, interruption and publication

Persistent lock files use nonblocking POSIX flock. A live task owns its lock
until it exits; concurrent retries cannot both publish. Process death releases
it automatically, with no TTL stealing/PID reuse guess or unrelated job kill.
Coordinator plan/run/merge operations are serialized. This backend is constrained
to one pinned host and a filesystem providing correct flock and atomic rename;
network/distributed filesystems and multi-host workers are not supported.

Workers write unique attempt directories only; never shared global outputs.
Partial writes stay isolated. A same-directory atomic receipt rename publishes
full artifact checksums and manifest/task/contract identity. Status/resume check
all bytes, required artifacts, source/sample/event/hook keys and extraction
contracts. Corrupt/missing/foreign receipts are unverified, never success.
Unexpected receipt filenames (including partial files) stop run/merge; retain
and investigate them rather than silently ingesting or deleting arbitrary files.
No fsync/power-loss durability guarantee is claimed; a damaged result is detected.

Merge validates exactly the manifest task set, takes task locks while copying
verified immutable artifacts, and never globs arbitrary outputs. It stages
normal chunks and runs existing merge in serial file order. Signed nominal Runs
denominators are summed once globally per sample; luminosity is not multiplied
by workers. Data sharing, sample selection, scalar/shape labels, region counts,
fit overlap and exposure metadata use the existing pipeline contracts.

Raw theory members survive workers. Nonlinear envelope/replica/Hessian reduction
runs only after complete sample normalization/merge. Fit and plot run only as
global phases after validated merge. The entire result directory (including
cache metadata/checksums) is atomically renamed into place; an existing final
result is reused only after verifying its manifest, requested phases and bytes.
Before publication, only plot/index.json output references are rebased from
staging to absolute paths under the final result. Every indexed file must exist
inside the stage first. Scientific input paths in skims, source metadata and
configuration remain provenance, not relocated output links; fit reports embed
the workspace rather than a staging filename. Serial plot path behavior is
unchanged. Final results therefore must not be moved to a different path without
an explicit relocation procedure (not supplied by this backend).

A failed global phase retains its staging evidence but publishes no result.
Concurrent run/merge requests fail busy on the coordinator lock, not a wait/queue;
task workers own separate per-task locks. Published global-phase prefixes are
immutable: requesting a different prefix fails without replacing the old result.
A corrupt existing final result fails closed; preserve it and use a new output
location rather than silently replacing important evidence.

Registered hooks and arbitrary TOML hooks are rejected: registry state/source
dependencies cannot be reconstructed safely in fresh processes. Supported hooks
are built-in defaults and Cascade.Systematics.apply_corrections, pinned by full
source hashes. There is no silent fallback to a different implementation.
Process arguments use Julia Cmd interpolation/structured args, not a shell.

See BATCH_VALIDATION.md for exact tested snapshots and remaining scope.

## Reduced RNTuple input

The built-in `reduced_rntuple` adapter is available in fresh workers. Mandatory
ROOT/sidecar/manifest bytes are verified and enter input identity/cache hashes;
original paths in provenance are never reopened. Filewise original normalization
is consumed once globally, including zero-retained files. Retention/selection
compatibility and same-sample original-population ownership are preflighted.
Original prefilter cutflows remain separate from reduced-row cutflow prefixes.
See REDUCED_SKIM.md; original NanoAOD partition/default behavior is unchanged.

Schema2 streaming bundles use complete logical-source ledgers plus bounded physical
shard tasks. --max-files selects original groups; normalization is once per group,
never summed from shard denominators. Worker scope is not a completeness certificate.
Same new partition/order is deterministic; repartitioned old/new floating trees
need quantified agreement, not a universal bit-equality claim. See
STREAMING_REDUCED_SKIM.md; legacy raw input partitions remain unchanged.
