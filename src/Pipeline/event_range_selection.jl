"""All unsupported modes are decided before Events reads (including handoff)."""
function event_range_selection_fallback(cfg, sample, plan)
    memory_handoff(cfg) && return "memory_handoff_enabled"
    get(get(cfg.raw,"execution",Dict()),"streaming_selection",false) && return "streaming_selection_enabled"
    Threads.nthreads() > 1 || return "one_thread"
    # Reuse the nominal-only eligibility proof, not the serial execution engine.
    return windowed_selection_fallback(cfg,sample,plan)
end

# Keep dynamic ROOT metadata out of the typed event-order reduction loop.
struct EventRangeResult{T,D}
    table::T
    range::UnitRange{Int}
    stage::Vector{Int}
    weight::Vector{Float64}
    diagnostics::D
end

function record_event_range!(cf::Cutflow, stage::Vector{Int}, weight::Vector{Float64})
    length(stage) == length(weight) || error("event-range ledger cardinality mismatch")
    for i in eachindex(stage,weight)
        0 <= stage[i] < length(cf.names) || error("event-range ledger invalid cut stage")
        record!(cf,stage[i],weight[i])
    end
    return nothing
end

function event_range_columns(sel,sample,lumimask)
    pre = copy(sel.columns_pre)
    "trigger" in sel.builtins && append!(pre,trigger_paths(sel.triggers,sample.kind,sample.stream))
    "lumimask" in sel.builtins && lumimask !== nothing &&
        append!(pre,[sel.data_quality.run_branch,sel.data_quality.lumi_branch])
    return unique(pre),unique(sel.columns_post)
end

"""Metadata admission only; src remains exclusively controller-owned."""
function open_event_range_file(item,sel,lumimask,options,object_collections)
    sample,path,_,_,_,_ = item
    validate_stream_metadata(path,Dict("max_metadata_bytes"=>options.stream_metadata_bytes))
    src = open_source(sample.format,path;options=get(sample.raw,"source",Dict()))
    transferred = false
    try
        src isa NanoAODSource || return "unsupported_source"
        identity = EventIO.decode_source_identity(src)
        identity === nothing && return "unbound_mmap_identity"
        treekey = only(k for k in src.file.directory.keys if k.fName == src.tree)
        0 <= treekey.fObjlen <= options.stream_metadata_bytes || error("event-range TTree metadata exceeds stream_metadata_bytes")
        pre,post = event_range_columns(sel,sample,lumimask)
        reader,reason = EventIO.plan_stream_windows(src,pre,post,length(sel.output_names),options)
        isempty(reason) || return reason
        _,reason = reserve_windowed_selection(reader,sel,object_collections)
        isempty(reason) || return reason
        charges = Int[]; retained = Int[]; rawbounds = Int[]
        for (k,range) in enumerate(reader.windows)
            reservation,reason = windowed_selection_reservation(reader,sel,range,object_collections)
            isempty(reason) || return reason
            # Authoritative cache-owned metadata bound, never the whole cap.
            memo = Selection.variable_memo_reservation(sel,length(range))
            raw = _window_add(reservation.required_bytes,memo)
            raw <= options.stream_window_bytes || error("event-range raw/progress/memo reservation exceeds stream_window_bytes")
            ledger = _window_add(_window_mul(16,length(range)),4096)
            output = _window_add(_window_mul(_window_mul(64,length(range)),length(sel.output_names)+3),4096)
            # Includes one independent reader's metadata and the existing basket
            # workspace/copy allowance. Original metadata charged separately.
            charge = _window_add(reader.charges[k],_window_add(raw,_window_add(ledger,
                _window_add(output,options.stream_metadata_bytes))))
            charge <= typemax(Int) || error("event-range reservation overflows Int")
            output <= typemax(Int) && raw <= typemax(Int) || error("event-range reservation overflows Int")
            push!(charges,Int(charge)); push!(retained,Int(output)); push!(rawbounds,Int(raw))
        end
        # Vectors/descriptors retained by the controller replace the temporary
        # planner reader; verify their owned size independently of mmap/closures.
        Base.summarysize((src.file[src.tree],reader.windows,charges,retained,rawbounds,pre,post)) <= options.stream_metadata_bytes ||
            error("event-range controller plan exceeds stream_metadata_bytes")
        EventIO.decode_source_identity(src;expected=identity)
        transferred = true
        return (item=item,source=src,identity=identity,selection=sel,lumimask=lumimask,
            options=options,pre=pre,post=post,windows=reader.windows,charges=charges,
            retained_charges=retained,rawbounds=rawbounds,
            analysis=StreamSelectionAnalysis(sel,sample.name),diagnostics=Dict{String,Any}(),
            object_collections=object_collections)
    finally
        transferred || close_source(src)
    end
end

"""Independent ROOTFile/LazyBranch state; never concurrently share original IO."""
function open_event_range_context(data,k)
    EventIO.decode_source_identity(data.source;expected=data.identity)
    src = EventIO.open_column_reader(data.source,data.identity.identity)
    transferred = false
    try
        EventIO.decode_source_identity(src;expected=data.identity)
        r,reason = EventIO.plan_stream_windows(src,data.pre,data.post,length(data.selection.output_names),data.options)
        isempty(reason) || error("admitted event-range private plan unsupported: $reason")
        r.windows == data.windows || error("event-range private plan drift")
        r.charges[k] <= data.charges[k] || error("event-range private reservation drift")
        # Keep only this range in the private reader. Branch metadata/lazy cache
        # is independent even though immutable compiled kernels are shared.
        reader = EventIO.StreamWindowReader(src,r.branches,r.pre,r.post,r.counters,
            [data.windows[k]],[r.charges[k]],r.options,r.diagnostics,r.seen)
        transferred = true
        return (source=src,identity=data.identity,reader=reader,selection=data.selection,
            sample=data.item[1],lumimask=data.lumimask,rawbound=data.rawbounds[k],
            retained_charge=data.retained_charges[k])
    finally
        transferred || close_source(src)
    end
end

function analyze_event_range(context,k)
    r = context.reader; sel = context.selection; range = only(r.windows)
    EventIO.decode_source_identity(context.source;expected=context.identity)
    payload = Selection.read_incremental_selection_window(r,sel,1;
        stream=context.sample.stream,lumimask=context.lumimask)
    stages = Vector{Int}(undef,length(range)); weights = Vector{Float64}(undef,length(range))
    table,_ = select_events(sel,payload.raw,length(range);sample=context.sample.name,
        progress=payload.progress,all_event_stage=stages,all_event_weight=weights,record_cutflow=false)
    bytes = Selection.incremental_window_bytes(payload.raw,payload.progress)
    bytes <= context.rawbound <= r.options.stream_window_bytes || error("event-range actual raw/progress/memo exceeds reservation")
    4sum(sizeof(v) for v in values(table.columns)) <= context.retained_charge ||
        error("event-range selected output exceeds reservation")
    EventIO.decode_source_identity(context.source;expected=context.identity)
    return EventRangeResult(table,range,stages,weights,copy(r.diagnostics))
end

function merge_event_range!(data,result::EventRangeResult,k)
    result.range == data.windows[k] || error("event-range result geometry drift")
    length(result.stage) == length(result.range) || error("event-range missing failed-event ledger")
    record_event_range!(data.analysis.cutflow,result.stage,result.weight)
    retained = append_stream_selection_window!(data.analysis,result.table,result.range;validate=true)
    for (key,value) in result.diagnostics
        value isa Integer || continue
        data.diagnostics[key] = startswith(key,"max_") ? max(get(data.diagnostics,key,0),value) : get(data.diagnostics,key,0)+value
    end
    return retained
end

"""Detach only this file's previous commit marker immediately before replacement.

An atomic same-directory rename preserves its prior bytes in a uniquely owned
backup on failure. Never restore that marker over possibly replaced data. Fresh
metadata is committed last; any failed callback leaves the artifact not current.
The caller must finish analysis/validation before entering this boundary.
"""
function publish_event_range_checkpoint(writeartifact, writemetadata, out::AbstractString;
        publication_hook=(stage,value)->nothing)
    meta = string(out,".meta.json")
    mkpath(dirname(abspath(out)))
    backup = nothing
    if ispath(meta)
        path,io = mktemp(dirname(abspath(meta));cleanup=false)
        close(io)
        # Same-directory rename: old marker disappears atomically. Record the
        # owned path first; never remove it in a rename/interruption catch that
        # cannot know whether the original bytes already reached the backup.
        backup = path
        mv(meta,path;force=true)
    end
    try
        publication_hook(:invalidated,backup)
        writeartifact()
        publication_hook(:artifact_replaced,backup)
        writemetadata()
        publication_hook(:metadata_committed,backup)
        # Retire only this successful attempt's obsolete marker. Cleanup errors
        # are publication errors too and therefore invalidate the fresh marker.
        backup === nothing || rm(backup;force=true)
    catch
        # A writer may have created metadata and then failed. Never leave a
        # same-key success marker after an incomplete publication attempt.
        ispath(meta) && rm(meta;force=true)
        rethrow()
    end
    # Failed-attempt backups remain for diagnosis. No other checkpoint is touched.
    return nothing
end

function publish_event_range_file(data)
    sample,path,out,key,_,_ = data.item
    EventIO.decode_source_identity(data.source;expected=data.identity)
    table = finish_stream_selection!(data.analysis,nevents(data.source);validate=true)
    execution = merge(copy(data.diagnostics),Dict{String,Any}(
        "event_range_selection_requested"=>true,"event_range_selection_effective"=>true,
        "event_range_selection_reason"=>"","engine"=>"stage_global_event_ranges",
        "window_count"=>length(data.windows),"requested_readers"=>1,"effective_readers"=>1,
        "requested_decode_threads"=>1,"ordered_all_event_cutflow"=>true,
        "file_jobs_settled_before_publication"=>true,
        "source_normalization"=>"unchanged original-file skim; no per-range Runs reads"))
    publish_event_range_checkpoint(
        ()->write_event_table(out,table),
        ()->write_meta(out,key;step="select",sample=sample.name,source=path,
            cutflow=cutflow_dict(data.analysis.cutflow),nevents=table.meta["nevents"],kept=nrows(table),execution=execution),
        out)
    return nothing
end

function run_event_range_selection(items,compiled,lm,cfg,options;diagnostics=Dict{String,Any}(),kwargs...)
    mapping = [o.name=>o.collection for o in cfg.objects]
    opener = item -> open_event_range_file(item,compiled[item[1].kind],is_data(item[1]) ? lm : nothing,options,mapping)
    return run_event_range_pool(items,opener,open_event_range_context,analyze_event_range,
        merge_event_range!,publish_event_range_file,d->close_source(d.source),c->close_source(c.source);
        options,diagnostics,kwargs...)
end

"""Capture only joined ordinary file errors so unrelated fallbacks can finish."""
function capture_event_range_failure(run)
    try
        return (fallbacks=run(),failure=nothing)
    catch e
        e isa EventRangeFileError || rethrow()
        return (fallbacks=e.fallbacks,failure=e)
    end
end

function finish_event_range_fallbacks(run,pending)
    pending === nothing && return run()
    try
        run()
    catch e
        (e isa InterruptException || e isa TaskFailedException) && rethrow()
        throw(CompositeException(Any[pending,e]))
    end
    throw(pending)
end
