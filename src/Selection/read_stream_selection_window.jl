"""Read/prefix/post barrier on the exclusive reader. Result has owned arrays only."""
function read_stream_selection_window(reader::EventIO.StreamWindowReader,sel,k;stream="",lumimask=nothing,basket_observer=(_)->nothing)
    range=reader.windows[k];n=length(range)
    raw=Dict{String,Any}(name=>EventIO.read_stream_branch(reader,name,range;basket_observer) for name in reader.pre)
    "trigger" in sel.builtins && (raw["trigger"]=trigger_column(raw,sel.triggers,sel.kind,stream))
    if "lumimask" in sel.builtins
        dq=sel.data_quality
        raw["lumimask"]=lumimask===nothing ? fill(true,n) : lumimask_column(lumimask,raw[dq.run_branch],raw[dq.lumi_branch])
    end
    needed=nothing
    progress=isempty(sel.variable_nodes) ? nothing : SelectionProgress(sel,raw,n)
    if sel.mat_at>0 && !isempty(reader.post)
        ctx=progress===nothing ? selection_context(raw,sel,String[];n) :
            _progress_context(raw,sel,String[],progress)
        needed=Base.invokelatest(prefix_pass!,Vector{Bool}(undef,n),sel,ctx,n)
    end
    countercache=Dict{String,Vector{Int}}()
    for name in reader.post
        offsets=nothing
        if needed!==nothing && haskey(reader.counters,name)
            c=reader.counters[name]
            offsets=get!(countercache,c) do
                counts=EventIO.read_stream_branch(reader,c,range;phase="counter",basket_observer)
                out=zeros(Int,n+1)
                for i in 1:n
                    v=Int(counts[i]);v>=0 || error("negative stream counter")
                    out[i+1]=Base.checked_add(out[i],v)
                end
                out
            end
        end
        raw[name]=EventIO.read_stream_branch(reader,name,range;needed,offsets,phase="post",basket_observer)
    end
    reader.diagnostics["prefix_events"]+=n
    reader.diagnostics["prefix_pass"]+=needed===nothing ? n : count(needed)
    bytes=incremental_window_bytes(raw,progress)+Base.summarysize(needed)
    bytes<=reader.options.stream_window_bytes || error("stream owned raw exceeds stream_window_bytes")
    reader.diagnostics["max_raw_window_bytes"]=max(reader.diagnostics["max_raw_window_bytes"],bytes)
    return progress===nothing ? (raw=raw,range=range,needed=needed) :
        (raw=raw,range=range,needed=needed,progress=progress)
end


"""Serial incremental window; progress/raw/object spans never cross windows.
Uses ordinary staged semantics, not a prefix replay or asynchronous reader.
Branch payloads are owned; canonical counters are cached per collection/window.
"""
function read_incremental_selection_window(reader::EventIO.StreamWindowReader, sel, k;
        stream="", lumimask=nothing, basket_observer=(_)->nothing)
    if isempty(sel.column_stages)
        payload = read_stream_selection_window(reader, sel, k; stream, lumimask, basket_observer)
        return hasproperty(payload, :progress) ? payload : merge(payload, (progress=nothing,))
    end
    range = reader.windows[k]
    n = length(range)
    raw = Dict{String,Any}(name => EventIO.read_stream_branch(reader, name, range; basket_observer) for name in reader.pre)
    "trigger" in sel.builtins && (raw["trigger"] = trigger_column(raw, sel.triggers, sel.kind, stream))
    if "lumimask" in sel.builtins
        dq = sel.data_quality
        raw["lumimask"] = lumimask === nothing ? fill(true, n) :
            lumimask_column(lumimask, raw[dq.run_branch], raw[dq.lumi_branch])
    end
    progress = SelectionProgress(sel, raw, n)
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
    countercache = Dict{String,Vector{Int}}()
    for due in sort!(collect(keys(groups)))
        limit = min(due - 1, sel.keep_stage)
        if limit > progress.at
            ctx = _progress_context(raw, sel, String[], progress)
            Base.invokelatest(advance_selection!, progress, sel, ctx, limit)
        end
        for name in groups[due]
            offsets = nothing
            if haskey(reader.counters, name)
                counter = reader.counters[name]
                offsets = get!(countercache, counter) do
                    # Counters stay unmasked to preserve original flat indices.
                    counts = counter in reader.pre ? get(raw, counter, nothing) : nothing
                    counts === nothing && (counts = EventIO.read_stream_branch(reader, counter, range; phase="counter", basket_observer))
                    out = zeros(Int, n + 1)
                    for i in 1:n
                        v = Int(counts[i])
                        v >= 0 || error("negative stream counter")
                        out[i+1] = Base.checked_add(out[i], v)
                    end
                    out
                end
            end
            raw[name] = EventIO.read_stream_branch(reader, name, range;
                needed=progress.needed, offsets, phase="post", basket_observer)
        end
    end
    # Shared raw/progress arrays counted once, including cached object spans.
    bytes = incremental_window_bytes(raw, progress, countercache)
    bytes <= reader.options.stream_window_bytes || error("incremental owned raw/progress exceeds stream_window_bytes")
    reader.diagnostics["max_raw_window_bytes"] = max(reader.diagnostics["max_raw_window_bytes"], bytes)
    return (raw=raw, range=range, needed=progress.needed, progress=progress)
end

# Do not traverse compiled kernels: they are shared, not window-owned.
function incremental_window_bytes(raw, progress, countercache=nothing)
    progress === nothing && return Base.summarysize(raw)
    return Base.summarysize((raw, progress.passed, progress.failed, progress.active,
        progress.needed, progress.current, progress.objs, progress.offsets, progress.memo, countercache))
end
