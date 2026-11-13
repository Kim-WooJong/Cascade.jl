# Reusable window accounting

Opt-in execution.reuse_window_accounting=true; default false. Requires
reuse_window_buffers=true, windowed_reusable_decoder=true, windowed_selection=true,
and no variable memo. Julia1.11/1.12 Memory layout only.

Task-owned bounded UInt identity ledger replaces recursive summarysize traversal
for supported primitive Vector/Jagged/counter graphs. Both per-window checks remain;
actual backing capacities and Dict slots are refreshed, not cached. Shared payloads
are deduplicated; headers conservatively charged. Unsupported types/overflow/ledger
exhaustion fail explicitly. No raw/output pooling or GC disabling.

Conservative charges may reject a near-cap workload earlier than the old route.
The production defaults and GC launch settings are unchanged. Recommended measured
runtime is --gcthreads=4,0 on the tested16CPU workload; do not infer other hosts.

Standalone regression: julia --startup-file=no --threads=16 --gcthreads=4,0
 test/window_accounting/runtests.jl

Validation: local1650 assertions; real6case smoke and396file107GB OFF/ON/ON/OFF,
all scientific17 outputs byte-identical. Actual padded smoke coverage0; synthetic
padded cases included. Reports in workspace artifacts/cascade-accounting-reuse-20261112.
