"""Execution-only serial per-file incremental windows; independent of memory_handoff."""
function windowed_selection(raw::AbstractDict)
    execution = get(raw, "execution", Dict())
    execution isa AbstractDict || throw(ArgumentError("execution must be a table"))
    enabled = get(execution, "windowed_selection", false)
    enabled isa Bool || throw(ArgumentError("execution.windowed_selection must be boolean"))
    return enabled
end
windowed_selection(cfg::AnalysisConfig) = windowed_selection(cfg.raw)

"""
    windowed_reusable_decoder(raw; validate_relations = true) -> Bool

Opt-in (stage1 A prototype, default false) modern reusable basket decoder for the
existing serial `windowed_selection` route. Execution-only: never part of
scientific/artifact identity. Strict Bool. Valid only with
`windowed_selection = true`; the separate `event_range_selection` runner does not
implement it, so that combination is rejected instead of silently ignored.
Profile overlays defer relations to the merged per-profile validation.
"""
function windowed_reusable_decoder(raw::AbstractDict; validate_relations::Bool = true)
    execution = get(raw, "execution", Dict())
    execution isa AbstractDict || throw(ArgumentError("execution must be a table"))
    enabled = get(execution, "windowed_reusable_decoder", false)
    enabled isa Bool || throw(ArgumentError("execution.windowed_reusable_decoder must be boolean"))
    if validate_relations && enabled
        windowed_selection(raw) ||
            throw(ArgumentError("execution.windowed_reusable_decoder requires execution.windowed_selection = true"))
        event_range_selection(raw) &&
            throw(ArgumentError("execution.windowed_reusable_decoder is not supported with execution.event_range_selection"))
    end
    return enabled
end
windowed_reusable_decoder(cfg::AnalysisConfig) = windowed_reusable_decoder(cfg.raw)

"""
    reusable_shared_offsets(raw; validate_relations = true) -> Bool

Allocation reduction for the `windowed_reusable_decoder` route. CONDITIONAL DEFAULT
(not a blanket default): when `execution.reusable_shared_offsets` is omitted it follows the
effective `windowed_reusable_decoder` setting, i.e. it is ON exactly on the supported
reusable-decoder route and OFF everywhere else (ordinary, non-windowed, windowed-legacy or
event-range configurations never get a new reader or behavior). Explicit `false` disables
it; explicit `true` still requires `windowed_reusable_decoder = true` (otherwise an
ArgumentError); any non-Bool value is rejected. Profile overlays defer relations to the
merged per-profile validation (an omitted flag never throws; an inherited explicit `true`
with a profile that disables the decoder is rejected).

Contract exception when enabled: sibling jagged columns of one window
BORROW the canonical counter offsets vector that the per-file decoder state issued
for its current window record, instead of each receiving a private copy. The
borrowed `Jagged.offsets` is a mutable Vector{Int} shared with the record and every
sibling: no caller may mutate or resize it for its whole reachable lifetime (also
after return, window advance, release or source close); mutation requires an
explicit private copy. Content stays freshly allocated; sharing across windows,
readers/sources or decoder states is never admitted (unproven requests copy).
Values, types, order and decoder validation are unchanged. Window memory checks
re-charge each borrow as the copy it replaces: equal for exact-capacity records,
otherwise conservative (a sharing run near the window budget may reject where a
copying run passes). The bounded sharing-proof metadata is additionally reserved before any
Events read through the existing window reservation, so the sharing required reservation
is >= the copying one under the SAME configured caps (never raised). Execution-only.

Low-level seams keep an explicit default of false (caller-owned proof):
`EventIO.StreamDecodeState(r; share_window_offsets = false)` and the Pipeline
`prepare_/run_reusable_windowed_selection(...; shared_offsets = false)` keywords. Only the
configuration resolver above applies the conditional default (select_chunk_results passes
its result).
"""
function reusable_shared_offsets(raw::AbstractDict; validate_relations::Bool = true)
    execution = get(raw, "execution", Dict())
    execution isa AbstractDict || throw(ArgumentError("execution must be a table"))
    # Omitted => follow the effective reusable decoder (its own relations validated as usual).
    haskey(execution, "reusable_shared_offsets") || return windowed_reusable_decoder(raw; validate_relations)
    enabled = execution["reusable_shared_offsets"]
    enabled isa Bool || throw(ArgumentError("execution.reusable_shared_offsets must be boolean"))
    if validate_relations && enabled
        windowed_reusable_decoder(raw) ||
            throw(ArgumentError("execution.reusable_shared_offsets requires execution.windowed_reusable_decoder = true"))
    end
    return enabled
end
reusable_shared_offsets(cfg::AnalysisConfig) = reusable_shared_offsets(cfg.raw)


"""Default-OFF task-local object/progress reuse; modern serial decoder only."""
function reuse_window_buffers(raw::AbstractDict; validate_relations::Bool=true)
    execution = get(raw, "execution", Dict{String,Any}())
    execution isa AbstractDict || throw(ArgumentError("execution must be a table"))
    enabled = get(execution, "reuse_window_buffers", false)
    enabled isa Bool || throw(ArgumentError("execution.reuse_window_buffers must be boolean"))
    if enabled && validate_relations
        windowed_reusable_decoder(raw) || throw(ArgumentError("execution.reuse_window_buffers requires execution.windowed_reusable_decoder = true"))
        memoization_options(raw).enabled && throw(ArgumentError("execution.reuse_window_buffers does not support variable memo"))
    end
    return enabled
end
reuse_window_buffers(cfg::AnalysisConfig) = reuse_window_buffers(cfg.raw)

"""Default-OFF bounded typed accounting; requires task-owned buffer reuse."""
function reuse_window_accounting(raw::AbstractDict; validate_relations::Bool=true)
    execution = get(raw, "execution", Dict{String,Any}())
    execution isa AbstractDict || throw(ArgumentError("execution must be a table"))
    enabled = get(execution, "reuse_window_accounting", false)
    enabled isa Bool || throw(ArgumentError("execution.reuse_window_accounting must be boolean"))
    if enabled && validate_relations
        reuse_window_buffers(raw) || throw(ArgumentError("execution.reuse_window_accounting requires execution.reuse_window_buffers = true"))
        VERSION >= v"1.11" && VERSION < v"1.13" || throw(ArgumentError("reuse_window_accounting supports Julia 1.11/1.12 only"))
    end
    return enabled
end
reuse_window_accounting(cfg::AnalysisConfig) = reuse_window_accounting(cfg.raw)
