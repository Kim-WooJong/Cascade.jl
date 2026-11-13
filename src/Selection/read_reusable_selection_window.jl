"""
    read_reusable_selection_window(reader, decode, sel, k; stream, lumimask) -> payload

Opt-in (execution.windowed_reusable_decoder) modern-only window read for the
existing serial windowed route. Same staged selection semantics as
read_stream_selection_window (no column stages) and
read_incremental_selection_window (column stages); only the physical decoder,
counter policy and accounting differ:

- every planned counter is decoded and checked once per window, all rows
  (including rows later rejected), against file-cumulative totals BEFORE any
  payload of the window is decoded; siblings share read-only offsets;
- every jagged column (pre or post) uses canonical counter offsets;
- owned raw/progress/counter bytes plus scratch and the native decoder bound are
  checked against stream_window_bytes.

Result arrays are window-owned; no scratch-backed view escapes. With opt-in
execution.reusable_shared_offsets, jagged columns of the payload BORROW this
window's counter-record offsets (payload.counters.offsets): they are shared with
siblings and must never be mutated or resized; mutate only a private copy.
"""
function read_reusable_selection_window(reader::EventIO.StreamWindowReader, decode, sel, k;
        stream = "", lumimask = nothing, basket_observer = (_) -> nothing, buffer_reuse = nothing)
    buffer_reuse === nothing || detach_window_buffers!(buffer_reuse)
    range = reader.windows[k]
    n = length(range)
    wc = EventIO.reusable_window_counters!(reader, decode, k; basket_observer)
    readbranch(name, needed, phase) = EventIO.read_reusable_stream_branch(reader, decode, name, range;
        needed, offsets = EventIO.reusable_canonical_offsets(reader, decode, wc, name), phase, basket_observer,
        window_counters = wc)
    raw = Dict{String,Any}()
    for name in reader.pre
        # A counter that is also a pre column was decoded exactly once above.
        raw[name] = haskey(wc.counts, name) ? wc.counts[name] : readbranch(name, nothing, "pre")
    end
    "trigger" in sel.builtins && (raw["trigger"] = trigger_column(raw, sel.triggers, sel.kind, stream))
    if "lumimask" in sel.builtins
        dq = sel.data_quality
        raw["lumimask"] = lumimask === nothing ? fill(true, n) :
            lumimask_column(lumimask, raw[dq.run_branch], raw[dq.lumi_branch])
    end
    if isempty(sel.column_stages)
        # Mirrors read_stream_selection_window.
        needed = nothing
        progress = buffer_reuse === nothing ? (isempty(sel.variable_nodes) ? nothing : SelectionProgress(sel, raw, n)) :
            reset_window_buffers!(buffer_reuse, sel, raw, n)
        if sel.mat_at > 0 && !isempty(reader.post)
            ctx = progress === nothing ? selection_context(raw, sel, String[]; n) :
                _progress_context(raw, sel, String[], progress)
            needed = Base.invokelatest(prefix_pass!, buffer_reuse === nothing ? Vector{Bool}(undef, n) : progress.needed, sel, ctx, n)
        end
        for name in reader.post
            raw[name] = readbranch(name, needed, "post")
        end
        reader.diagnostics["prefix_events"] += n
        reader.diagnostics["prefix_pass"] += needed === nothing ? n : count(needed)
        _finish_reusable_window_read!(reader, decode, raw, progress, wc, needed; buffer_reuse)
        return (raw = raw, range = range, needed = needed, progress = progress, counters = wc)
    end
    # Mirrors read_incremental_selection_window.
    progress = buffer_reuse === nothing ? SelectionProgress(sel, raw, n) : reset_window_buffers!(buffer_reuse, sel, raw, n)
    if sel.mat_at > 0 && !isempty(reader.post)
        ctx = _progress_context(raw, sel, String[], progress)
        Base.invokelatest(advance_selection!, progress, sel, ctx, min(sel.mat_at - 1, sel.keep_stage))
    end
    reader.diagnostics["prefix_events"] += n
    reader.diagnostics["prefix_pass"] += count(progress.needed)
    groups = Dict{Int,Vector{String}}()
    for name in reader.post
        due = get(sel.column_stages, name, typemax(Int))
        due >= 1 || error("invalid incremental column stage: $name")
        push!(get!(groups, due, String[]), name)
    end
    for due in sort!(collect(keys(groups)))
        limit = min(due - 1, sel.keep_stage)
        if limit > progress.at
            ctx = _progress_context(raw, sel, String[], progress)
            Base.invokelatest(advance_selection!, progress, sel, ctx, limit)
        end
        for name in groups[due]
            raw[name] = readbranch(name, progress.needed, "post")
        end
    end
    _finish_reusable_window_read!(reader, decode, raw, progress, wc, progress.needed; buffer_reuse)
    return (raw = raw, range = range, needed = progress.needed, progress = progress, counters = wc)
end

# counters: the whole window counter record (counts AND offsets). Non-pre
# counters live only there; pre counters shared with raw are de-duplicated by
# Base.summarysize object identity within one call.
function _finish_reusable_window_read!(reader, decode, raw, progress, counters, needed; buffer_reuse=nothing)
    # Opt-in borrowed offsets are re-charged as the copies they replace (0 by default).
    bytes = reusable_window_bytes(raw, progress, counters, needed; buffer_reuse) + EventIO.reusable_shared_offsets_charge(decode, raw)
    bytes <= reader.options.stream_window_bytes || error("reusable owned raw/progress exceeds stream_window_bytes")
    EventIO.check_reusable_window_memory!(decode, reader.options, bytes)
    reader.diagnostics["max_raw_window_bytes"] = max(reader.diagnostics["max_raw_window_bytes"], bytes)
    return nothing
end

# Shared arrays are counted once; the window counter record (counts and offsets) is always included.
function reusable_window_bytes(raw, progress, counters = nothing, needed = nothing; buffer_reuse=nothing)
    if buffer_reuse !== nothing && buffer_reuse.accounting !== nothing
        return accounting_window_bytes!(buffer_reuse.accounting, raw, progress, counters, needed, buffer_reuse)
    end
    buffer_reuse === nothing || return Base.checked_add(buffer_reuse.reserved_bytes,
        Base.summarysize((raw, counters, needed, progress.offsets)))
    progress === nothing && return Base.summarysize((raw, counters, needed))
    return Base.summarysize((raw, progress.passed, progress.failed, progress.active,
        progress.needed, progress.current, progress.objs, progress.offsets, progress.memo, counters, needed))
end
