# Cascade.jl development rules

Project development policy: develop in a Julia-optimized style; preserve scientific results and checkpoints.

- Keep performance-critical kernels inside functions and specialize on concrete argument/field/element types. Place function barriers between dynamic configuration/IO metadata and typed loops. A concrete return type alone does not prove a type-stable loop.
- Prefer parametric structs, tuples/NamedTuples and typed vectors for hot state. Heterogeneous dictionaries are acceptable at configuration/planning boundaries; do not introduce Any-valued per-event memo lookups or abstract callable fields in new hot paths.
- Allocate reusable, task-owned buffers outside event/basket loops. Bound live payload/memo/reorder memory; distinguish cumulative allocation, live bytes and peak RSS. Do not increase memory without explicit ownership/limits.
- Preserve native result types and floating-point evaluation/reduction order. No blanket Float64 casts, @fastmath, removed overflow/bounds checks or speculative @inbounds/SIMD as a performance shortcut.
- Keep &&/||/if/when guards and first-use dependency validity. Lazy caches must not evaluate unsafe indices or masked placeholder values early. Invalidate/isolate by source, event/workunit, configuration and variation.
- Use one bounded stage-wide concurrency budget. Mutable readers, scratch, object buffers, progress, memo and outputs belong to worker tasks, not thread IDs; tasks may migrate. Join workers before closing borrowed source resources.
- Restore original entry/order and exact weighted cutflow; do not substitute range subtotal reduction for the established event-order sum. Source normalization is counted once per original file.
- Keep checkpoint schemas/values, atomic publication, cache identity and restart behavior. Persisted columns are output consumers even when a histogram region does not use them.
- New execution optimizations start opt-in with explicit unsupported-path diagnostics; fallback only before data work, never silent retry after an admitted failure.
- Verify focused semantic/call-count/type/allocation tests before speed claims. Check full-module and real-input integration where applicable, label synthetic/stub-only coverage, isolate compilation/preparation from runtime measurements, and preserve pre-existing dirty work/results.
- Benchmark policy: use only no_checkpoints_run with execution.checkpoints=false; do not benchmark per-file checkpoint creation unless the owner explicitly requests a persistence test. Keep required final scientific outputs/publication/verification intact, and preserve production checkpoint support and defaults. Report no_checkpoints_run body time separately from startup/pre-entry and launch-to-exit time; do not silently move necessary work outside the reported clock.
