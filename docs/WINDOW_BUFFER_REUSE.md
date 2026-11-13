# Window progress/object buffer reuse

execution.reuse_window_buffers is an opt-in strict Bool (default false). Requires windowed_selection and windowed_reusable_decoder; variable memo is rejected before payload work. The validated workload is the nominal no-checkpoint pipeline.

Merge into the existing execution table:

    [execution]
    checkpoints = false
    windowed_selection = true
    windowed_reusable_decoder = true
    reuse_window_buffers = true
    memoize_variables = false

One file task owns its SelectionProgress arrays and CachedObjectBuffer spans/index data. They are reset between serial windows, not shared by thread ID. Raw/output tables remain fresh. Old raw/borrowed-offset references are detached; retained buffer capacity remains charged even when logical length shrinks. Metadata bounds restrict event/index capacity and existing window/queue/retained limits remain enforced. Tight budgets may reject ON before payload when OFF fits. GC is not disabled.

Progress from a reused payload is borrowed mutable task-local state, not an immutable previous-window snapshot. Internal consumers must finish before reset. Stored selected columns/cutflow/order are unchanged. Diagnostic keys: reuse_window_buffers_effective, window_buffer_creations, window_buffer_resets, window_buffer_capacity_highwater_bytes.

Validation: 830 focused assertions, actual six-case selected-table/cutflow parity, and four107.39GB ABBA runs with17scientific files byte-identical. Mean cumulative Julia allocation85.266→62.581GB(-26.61%), GC count437.5→273.5(-37.49%), GC pause25.093→23.513s(-6.30%). Whole wall88.592→88.084s, overlapping ranges: stable speed advantage not established. Allocation event count+1.95%; maxRSS7.429→7.599GB, no peak memory saving claim. Same candidate image and GC observer, GC1/compute16. GC/alloc scope is sampler first-last, not exact body.

Focused invocation: julia --startup-file=no test/windowed_reusable_decoder/test_buffer_reuse.jl (stdlib-only fixture). Actual validation used Linux Julia1.12.2 in a private depot; focused local runs Julia1.12.6. Synthetic padded coverage is separate from real smoke's padded0.

Evidence: ../cascade-window-buffer-reuse-20261112/{native-results,integration,receipts}. Full report (workspace-relative): reports/cascade-window-buffer-reuse-20261112/FINAL_REPORT_KO.md. Production analysis settings were not changed, no commit/push.
