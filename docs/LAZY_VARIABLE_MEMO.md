# Opt-in lazy named-variable memo

```toml
[execution]
memoize_variables = true        # default false
memoize_max_bytes = 268435456   # per-workunit cache-column limit (256 MiB)
```

## Contract

Named event variables receive explicit `NodeID{N}` identities in sorted
variable-name order, scoped to one compiled selection. A consumer invokes a
concrete demand getter in the original expression position. Variable dependencies
invoke the same getters, preserving native arithmetic and evaluation order.
`&&`, `||`, `if` and histogram `when` guards are not lifted.
Object-scope bare fields retain their existing precedence over event variables.

Each admitted node owns a native `Vector{T}` and byte-validity `Vector{Bool}`
indexed by workunit-local event. Successful evaluation commits validity; exceptions
do not. A single-current-event stamp is deliberately not used: values survive
stage-wide passes, conservative prefix replay, weights, and final histogram/
output consumers. Object buffers keep their existing independent lifetime.

`SelectionProgress` owns the cold heterogeneous registry. Context creation
specializes that registry into a concrete tuple; per-event getters never inspect
the registry or use an Any-valued memo lookup. Type discovery uses compiler
return-type inference once per ready node outside the event loop, without running
its expression. No per-event eval/inference is added. New invocations, worker
contexts, windows and shape labels own separate caches.

## Safety bounds and diagnostics

Only exact concrete built-in Bool, signed/unsigned integers through 128 bits,
Float16/32/64 and floating Complex scalar types are admitted. Inferred Any,
unions, bottom, nonnumeric, custom and reference-containing values fall back to
original uncached demand evaluation; there is no Float64 coercion. Fallback
produces a cold warning and an entry in `registry.diagnostics`. The existing
output schema still converts histogram/output sinks as it did before.

A node is considered for allocation only after all transitive input columns,
builtins and collection offsets exist. Allocation does not compute the node.
Only original stage/prefix execution can demand a value; this preserves masked
read validity and avoids caching zero-filled placeholders for rejected events.
Input arrays and source offsets must remain stable within a progress invocation,
as required by the existing incremental reader. Do not share a context across
concurrent event loops or mutate/replace its inputs after caching.

Admission checks native value bytes, byte validity and column object/array
headers against `memoize_max_bytes`. Overbudget nodes use explicit uncached
fallback rather than eviction (which would violate the once guarantee).
`registry.allocated_bytes` measures admitted column capacities;
`variable_memo_bytes(registry)` measures the complete owned registry including
metadata/diagnostics. `incremental_window_bytes` includes the latter, deduplicating
shared raw/progress objects. The scalar-column cap does not purport to cap Julia
compiler memory or all window payloads; the existing window budget remains the
outer bound.

The once-per-event guarantee applies to admitted nodes. Unsupported or overbudget
nodes explicitly retain uncached behavior. Current opt-in compilation validates
all named variable definitions, including unused definitions; cycles/invalid
expressions are rejected then, whereas disabled compilation retains its existing
used-expression validation behavior.

## Integration notes

The public two-value `read_selection_columns` API cannot carry progress; external
callers using it followed by `select_events` start a new workunit/cache. Internal
`run_selection` paths preserve memo across conservative prefix and final replay.
Incremental window payloads preserve progress too. The legacy asynchronous
streaming + memo combination uses the planner's explicit pre-read ordinary-path
fallback for this release; it is not admitted with unbudgeted memo growth.

Old 18/19-argument `CompiledSelection` constructors and the three-argument
`KernelContext` constructor remain available and disable memo. Default execution
retains inline variable translation and checkpoint/output/dependency schemas.

## Verification

Self-contained synthetic coverage (stdlib only, no ROOT/dependency load):

```sh
julia --startup-file=no test/node_memo/runtests.jl
```

Covers staged and conservative cross-pass call counts, native Int/Float32 types,
rounding, NaN, guarded unsafe indices, failed-getter validity, transitive readiness,
shadowing/cycles, independent contexts/shape labels, fallback budgets, old
constructors, disabled bytewise equivalence, typed cache hits and warmed hit
allocations. Tests were authored but deliberately not executed in the implementation
lane; the parent owns serialized execution and full-module integration validation.

## Metadata-only window reservation

Pipeline planners should call `Selection.variable_memo_reservation(sel, n)::Int128`
for each workunit, rather than charging the entire configured cap. Disabled/no-node
selections return zero. The authoritative scalar whitelist and its maximum native
width (16 bytes) live only in `VariableMemo.jl`.

For `m` nodes and `n` events, the column bound is
`min(cap, m * (column_header + n * (16 + sizeof(Bool))))`. Registry, slot-reference,
full diagnostic-entry capacity, bounded reason strings, and every variable-name
byte are added separately. Arithmetic uses Int128 and clips to cap before multiplying
node counts. The header is measured from the production column representation;
registry metadata is measured from its empty representation with conservative
per-node metadata/alignment allowance. Each admitted column is charged using its
actual summary size against cap, never evicted or resized.

Diagnostics now use fixed-capacity, initialized backing storage (one entry per
node, exposed as a length-bounded iterable). The backing storage remains visible
to `Base.summarysize` even before a fallback, so incremental-window accounting
includes its entire capacity. Duplicate fallback reporting cannot append twice.
Reasons use fixed strings of at most 128 bytes: arbitrary inferred-type displays
are deliberately not retained or formatted. Variable names may be arbitrarily
long, but all their bytes are charged in the reservation.

Thus actual owned registry/column bytes are bounded by the helper, while a tiny
workunit is no longer forced to reserve 256 MiB against the default 64 MiB window.
The helper excludes raw inputs, selected outputs and compiler scratch; those remain
separate planner charges. It makes no claim about process RSS/allocator arenas.

Additional focused tests cover every whitelisted dtype over empty/small/larger
workunits and tiny/default budgets, Any/union fallback, long names, duplicate
report suppression, disabled/no-node/overflow cases, actual generated transitive
getter inference/warmed allocation, and actual compiler -> masked incremental
window reader -> final all-event ledger (physical IO alone is stubbed). The latter
checks masked placeholders are never validated, a mass node is computed only once
across staged cuts and persisted output, rejected-event stage/weight ledgers remain
exact, and the default memo/window budgets admit the tiny workunit together.

Legacy async + memo requests explicitly fall back before metadata/Events work to
the ordinary **full-file-owned** memo path, not a window-bounded async cache.
Serial incremental windows and event-range windows reserve the authoritative
complete memo bound before Events reads, including late/output-only nodes.
The range planner independently computes raw+memo once; the common preflight
check does not add another memo charge to its per-job accounting.
