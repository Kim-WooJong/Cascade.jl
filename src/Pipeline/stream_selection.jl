"""Analysis-only state: compiled pure kernels, persistent ordered sums and output.

No path reader, ROOTFile, EventWindowSource or lazy branch is stored here.
"""
mutable struct StreamSelectionAnalysis
    selection::Any
    sample::String
    cutflow::Cutflow
    table::Any
end
StreamSelectionAnalysis(sel,sample)=StreamSelectionAnalysis(sel,String(sample),Cutflow(vcat("all",sel.cut_names)),nothing)

function analyze_stream_selection_window(a::StreamSelectionAnalysis,payload,k)
    table,_=select_events(a.selection,payload.raw,length(payload.range);sample=a.sample,cutflow=a.cutflow,
        progress=get(payload,:progress,nothing))
    return append_stream_selection_window!(a,table,payload.range)
end

# Shared by asynchronous conservative and serial incremental windows.
function append_stream_selection_window!(a,table,range; validate=false)
    # Entries in raw kernels are window-local; public artifacts remain original.
    offset=first(range)-1
    for i in eachindex(table["entry"])
        validate && !(1 <= table["entry"][i] <= length(range)) && error("window-local selected entry out of bounds")
        table["entry"][i]=Base.checked_add(table["entry"][i],offset)
    end
    if validate && a.table !== nothing && !isempty(a.table["entry"]) && !isempty(table["entry"])
        last(a.table["entry"]) < first(table["entry"]) || error("stream selected entry order drift")
    end
    if a.table===nothing
        a.table=table
    else
        a.table.order==table.order || error("stream selected schema drift")
        for name in table.order
            append!(a.table.columns[name],table.columns[name])
        end
    end
    # Logical output plus conservative capacity/copy allowance, not an RSS bound.
    return 4sum(sizeof(v) for v in values(a.table.columns))
end

function finish_stream_selection!(a,n; validate=false)
    a.table===nothing && error("stream missing empty/first window")
    validate && validate_windowed_selection_result(a,n)
    a.table.meta["nevents"]=n
    a.table.meta["cutflow"]=cutflow_dict(a.cutflow)
    a.table.meta["regions"]=region_counts(a.table)
    return a.table
end

function validate_windowed_selection_result(a,n)
    a.cutflow.n[1] == n || error("stream cutflow/event count mismatch")
    a.cutflow.names == vcat("all", a.selection.cut_names) || error("stream cutflow schema mismatch")
    all(a.cutflow.n[i] <= a.cutflow.n[i-1] for i in 2:length(a.cutflow.n)) || error("stream cutflow population drift")
    kept = count(s -> s >= a.selection.keep_stage, a.table["stage"])
    kept == nrows(a.table) == a.cutflow.n[a.selection.keep_stage+1] || error("stream table/cutflow kept count mismatch")
    all(length(v) == nrows(a.table) for v in values(a.table.columns)) || error("stream selected column length mismatch")
    entries = a.table["entry"]
    issorted(entries) && all(1 <= e <= n for e in entries) || error("stream selected entry bounds/order mismatch")
    all(entries[i-1] < entries[i] for i in 2:length(entries)) || error("stream duplicate selected entry")
    return nothing
end

function stream_selection_fallback(cfg,sample,plan)
    memoization_options(cfg).enabled && return "memoize_variables_requires_incremental_owner"
    Threads.nthreads()>=2 || return "one_thread"
    Threads.nthreads()>=3 || return "stage_thread_budget"
    builtin_source_readers() || return "replaced_readers"
    isempty(HOOKS) || return "custom_hooks"
    allowed=Dict("correct"=>("","Cascade.Systematics.apply_corrections"),"systematics"=>("",),"fit"=>("",),"plot"=>("",))
    for (key,value) in get(cfg.raw,"hooks",Dict())
        value in get(allowed,key,()) || return "custom_hooks"
    end
    sample.format=="nanoaod" || return "unsupported_format"
    plan===nothing && isempty(shape_variations(cfg)) || return "shape_variations"
    isempty(theory_weights(cfg)) || return "theory_weights"
    isempty(cfg.variations) || return "weight_variations"
    return ""
end

function open_stream_selection(item,sel,lmask,options)
    # Legacy asynchronous admission does not own a cross-stage memo budget.
    # Decline before metadata/Events reads; the ordinary path owns the cache.
    hasproperty(sel,:variable_nodes) && !isempty(sel.variable_nodes) &&
        return "memoize_variables_requires_incremental_owner"
    sample,path,out,key,_,chunk=item
    validate_stream_metadata(path,Dict("max_metadata_bytes"=>options.stream_metadata_bytes))
    src=open_source(sample.format,path;options=get(sample.raw,"source",Dict()))
    transferred=false
    try
        src isa NanoAODSource || return "unsupported_source"
        identity=EventIO.decode_source_identity(src)
        identity===nothing && return "unbound_mmap_identity"
        treekey=only(k for k in src.file.directory.keys if k.fName==src.tree)
        0<=treekey.fObjlen<=options.stream_metadata_bytes || error("stream TTree metadata exceeds stream_metadata_bytes")
        pre=copy(sel.columns_pre)
        "trigger" in sel.builtins && append!(pre,trigger_paths(sel.triggers,sample.kind,sample.stream))
        "lumimask" in sel.builtins && lmask!==nothing && append!(pre,[sel.data_quality.run_branch,sel.data_quality.lumi_branch])
        pre=unique(pre);post=unique(sel.columns_post)
        reader,reason=EventIO.plan_stream_windows(src,pre,post,length(sel.output_names),options)
        isempty(reason) || return reason
        analysis=StreamSelectionAnalysis(sel,sample.name)
        # The reader tuple is supplied only to read jobs. Analysis callbacks get
        # only the separate analysis state and the owned payload snapshot.
        reading=(reader=reader,selection=sel,stream=sample.stream,lumimask=lmask)
        retained=[Int(64Int128(length(w))*(length(sel.output_names)+3)) for w in reader.windows]
        all(c->c<=options.stream_retained_bytes,retained) || error("stream output window exceeds stream_retained_bytes")
        transferred=true
        return (reader=reading,analysis=analysis,windows=reader.windows,charges=reader.charges,
            retained_charges=retained,source=src,identity=identity,item=item)
    finally
        transferred || close_source(src)
    end
end

function publish_stream_selection(data,reads,analyses)
    sample,path,out,key,_,chunk=data.item
    EventIO.decode_source_identity(data.source;expected=data.identity)
    table=finish_stream_selection!(data.analysis,nevents(data.source))
    diag=copy(data.reader.reader.diagnostics)
    overlap=UInt64(0)
    for k in 1:length(data.windows)-1
        r=reads[k+1];a=analyses[k]
        hi=min(r[2],a[2]);lo=max(r[1],a[1]);hi>lo && (overlap+=hi-lo)
    end
    merge!(diag,Dict("streaming_selection"=>true,"engine"=>"stage_global_owned_windows",
        "requested_readers"=>1,"effective_readers"=>1,"requested_decode_threads"=>1,
        "file_jobs_settled_before_publication"=>true,"max_live_windows_per_file"=>2,
        "same_file_read_analysis_overlap_seconds"=>Float64(overlap)/1e9,
        "read_job_seconds"=>sum(Float64(t[2]-t[1])/1e9 for t in values(reads)),
        "analysis_job_seconds"=>sum(Float64(t[2]-t[1])/1e9 for t in values(analyses)),
        "worker_scope"=>"shared default-pool window jobs; no file-thread pinning"))
    mkpath(dirname(out));write_event_table(out,table)
    write_meta(out,key;step="select",sample=sample.name,source=path,cutflow=cutflow_dict(data.analysis.cutflow),
        nevents=table.meta["nevents"],kept=nrows(table),execution=diag)
    return nothing
end

function run_stream_selection(tasks,compiled,lm,options;diagnostics=Dict{String,Any}())
    opener=item->open_stream_selection(item,compiled[item[1].kind],is_data(item[1]) ? lm : nothing,options)
    reader=(r,k)->Selection.read_stream_selection_window(r.reader,r.selection,k;stream=r.stream,lumimask=r.lumimask)
    analyzer=(a,p,k)->analyze_stream_selection_window(a,p,k)
    closer=d->close_source(d.source)
    return run_window_pipeline(tasks,opener,reader,analyzer,publish_stream_selection,closer;options,diagnostics)
end

"""Capture ONLY ordinary joined-file failures. Fatal/cancel/controller errors propagate."""
function capture_stream_file_failure(run)
    try
        return (fallbacks=run(),failure=nothing)
    catch e
        e isa StreamFileError || rethrow()
        return (fallbacks=e.fallbacks,failure=e)
    end
end

struct StreamFallbackFailure <: Exception
    stream::StreamFileError
    exception::Any
    backtrace::Any
end
function Base.showerror(io::Base.IO,e::StreamFallbackFailure)
    showerror(io,e.stream)
    print(io,"; independent serial fallback also failed: ")
    showerror(io,e.exception,e.backtrace)
end

"""Attempt independent serial files after joined ordinary stream failures, then report."""
function finish_stream_selection_fallbacks(run,pending)
    pending===nothing && return run()
    try
        run()
    catch e
        (e isa InterruptException || e isa TaskFailedException) && rethrow()
        throw(StreamFallbackFailure(pending,e,catch_backtrace()))
    end
    throw(pending)
end


"""Pre-read eligibility; execution controls do not alter scientific identity."""
function windowed_selection_fallback(cfg, sample, plan)
    get(get(cfg.raw, "execution", Dict()), "streaming_selection", false) && return "streaming_selection_enabled"
    decode_options(cfg).threads == 1 || return "decode_threads_not_one"
    column_readers(cfg) == 1 || return "column_readers_not_one"
    builtin_source_readers() || return "replaced_readers"
    isempty(HOOKS) || return "custom_hooks"
    allowed = Dict("correct" => ("", "Cascade.Systematics.apply_corrections"),
        "systematics" => ("",), "fit" => ("",), "plot" => ("",))
    for (key, value) in get(cfg.raw, "hooks", Dict())
        value in get(allowed, key, ()) || return "custom_hooks"
    end
    sample.format == "nanoaod" || return "unsupported_format"
    plan === nothing && isempty(shape_variations(cfg)) || return "shape_variations"
    isempty(theory_weights(cfg)) || return "theory_weights"
    isempty(cfg.variations) || return "weight_variations"
    return ""
end

# Called in its own scope so raw/progress/object buffers die before next read.
function analyze_incremental_selection_window!(analysis, reader, sel, k; stream, lumimask)
    payload = Selection.read_incremental_selection_window(reader, sel, k; stream, lumimask)
    table, _ = select_events(sel, payload.raw, length(payload.range);
        sample=analysis.sample, cutflow=analysis.cutflow, progress=payload.progress)
    bytes = Selection.incremental_window_bytes(payload.raw, payload.progress)
    bytes <= reader.options.stream_window_bytes || error("finished incremental raw/progress exceeds stream_window_bytes")
    reader.diagnostics["max_raw_window_bytes"] = max(reader.diagnostics["max_raw_window_bytes"], bytes)
    retained = append_stream_selection_window!(analysis, table, payload.range; validate=true)
    retained <= reader.options.stream_retained_bytes || error("windowed retained selected table exceeds stream_retained_bytes")
    return nothing
end

"""Plan before Events reads; unsupported plans return a reason, never catch/retry.
The caller owns src and the unchanged file-level checkpoint/handoff publication.
"""
function run_windowed_selection(sel, src, sample, options; lumimask=nothing,
        object_collections=nothing, execution_diagnostics=Dict{String,Any}())
    src isa NanoAODSource || return nothing, "unsupported_source"
    identity = EventIO.decode_source_identity(src)
    identity === nothing && return nothing, "unbound_mmap_identity"
    treekey = only(k for k in src.file.directory.keys if k.fName == src.tree)
    0 <= treekey.fObjlen <= options.stream_metadata_bytes || error("windowed TTree metadata exceeds stream_metadata_bytes")
    pre = copy(sel.columns_pre)
    "trigger" in sel.builtins && append!(pre, trigger_paths(sel.triggers, sample.kind, sample.stream))
    "lumimask" in sel.builtins && lumimask !== nothing && append!(pre, [sel.data_quality.run_branch, sel.data_quality.lumi_branch])
    reader, reason = EventIO.plan_stream_windows(src, unique(pre), unique(sel.columns_post), length(sel.output_names), options)
    isempty(reason) || return nothing, reason
    # Bind again after metadata planning, before the first Events basket read.
    EventIO.decode_source_identity(src; expected=identity)
    reservation, reason = reserve_windowed_selection(reader, sel, object_collections)
    isempty(reason) || return nothing, reason
    execution_diagnostics["reserved_raw_window_bytes"] = reservation
    analysis = StreamSelectionAnalysis(sel, sample.name)
    for k in eachindex(reader.windows)
        analyze_incremental_selection_window!(analysis, reader, sel, k; stream=sample.stream, lumimask)
    end
    EventIO.decode_source_identity(src; expected=identity)
    table = finish_stream_selection!(analysis, nevents(src); validate=true)
    diag = reader.diagnostics
    merge!(execution_diagnostics, diag)
    decoded = sum((v for (key,v) in diag if endswith(key, "_decoded_baskets")); init=0)
    skipped = sum((v for (key,v) in diag if endswith(key, "_skipped_baskets")); init=0)
    # padded_decoded_baskets is a subset of phase decoded counters.
    decoded -= get(diag, "padded_decoded_baskets", 0)
    merge!(execution_diagnostics, Dict("windowed_selection"=>true,
        "windowed_selection_requested"=>true, "windowed_selection_effective"=>true,
        "windowed_selection_reason"=>"", "window_count"=>length(reader.windows),
        "decoded_baskets"=>decoded, "skipped_baskets"=>skipped,
        "engine"=>"serial_per_file_incremental_windows",
        "reader_engine"=>"UnROOT_window_legacy_basketarray_owned_copy",
        "reusable_decoder"=>false, "effective_readers"=>1,
        "max_live_raw_windows_per_file"=>1, "retained_selected_file_table"=>true))
    return (table, analysis.cutflow), ""
end


# Checked Int128 arithmetic: metadata cannot wrap a reservation downwards.
_window_add(a, b) = Base.checked_add(Int128(a), Int128(b))
_window_mul(a, b) = Base.checked_mul(Int128(a), Int128(b))

"""Pure metadata bound. Mapping pairs must match compiled object names in order.
A whole jagged basket's declared bytes bound its flat content bytes, including
any trailer. The minimum bound over fields of ONE collection remains an upper
bound on its elements. Every object is charged separately, even same-collection
categories. No source, basket decode or raw arrays are accessed here.
"""
function windowed_selection_reservation(reader, sel, range, object_collections)
    names = sel.object_names
    if object_collections === nothing
        isempty(names) || return nothing, "object_collection_mapping_missing"
        object_collections = Pair{String,String}[]
    end
    length(object_collections) == length(names) || return nothing, "object_collection_mapping_mismatch"
    for (name, mapping) in zip(names, object_collections)
        mapping isa Pair && first(mapping) == name && last(mapping) isa AbstractString ||
            return nothing, "object_collection_mapping_mismatch"
    end
    n = Int128(length(range)); b = Int128(length(reader.branches)); o = Int128(length(names))
    declared = Int128(0)
    element_bounds = Dict{String,Int128}()
    for (name, br) in reader.branches
        bytes = Int128(0)
        for ib in EventIO.stream_basket_overlap(br.baskets, range)
            bs = br.baskets[ib]
            first(range) <= bs.lo <= bs.hi <= last(range) || error("windowed reservation splits basket")
            bs.decoded isa Integer && !(bs.decoded isa Bool) && bs.decoded >= 0 || error("invalid windowed declared bytes")
            bytes = _window_add(bytes, bs.decoded)
        end
        declared = _window_add(declared, bytes)
        br.jagged || continue
        E = br.E
        E isa DataType && isprimitivetype(E) && isbitstype(E) && sizeof(E) > 0 || continue
        collection = first(split(name, '_'))
        bound = bytes ÷ sizeof(E)
        element_bounds[collection] = min(get(element_bounds, collection, bound), bound)
    end
    elements = Int128(0)
    for mapping in object_collections
        collection = String(last(mapping))
        haskey(element_bounds, collection) || return nothing, "object_collection_bound_unavailable:" * collection
        elements = _window_add(elements, element_bounds[collection])
    end
    # Planner raw = D + 16*n*B + 4*n (canonical offsets/counters included).
    raw = _window_add(declared, _window_add(_window_mul(_window_mul(16,n),b), _window_mul(4,n)))
    # passed+active Int vectors, needed Bool vector, failed packed bits.
    progress = _window_add(_window_mul(17,n), cld(n,8))
    spans = _window_mul(_window_mul(16,n),o)
    # Int selected indices, 2x logical capacity/copy allowance.
    indices = _window_mul(16,elements)
    headers = _window_mul(4096,_window_add(_window_add(b,o),1))
    required = _window_add(raw,_window_add(progress,_window_add(spans,_window_add(indices,headers))))
    return (required_bytes=required, object_element_bound=elements), ""
end

"""Reserve every window before any Events reads; unsupported proofs fall back."""
function reserve_windowed_selection(reader, sel, object_collections; extra_bytes=0)
    highwater = Int128(0)
    for (k, range) in enumerate(reader.windows)
        reservation, reason = windowed_selection_reservation(reader, sel, range, object_collections)
        isempty(reason) || return nothing, reason
        # Late/output-only memo slots must fit BEFORE any Events reads.
        memo = hasproperty(sel, :variable_nodes) ?
            Selection.variable_memo_reservation(sel, length(range)) : Int128(0)
        # extra_bytes: opt-in reusable decoder scratch/native/metadata (0 otherwise).
        required = _window_add(_window_add(reservation.required_bytes, memo), extra_bytes)
        required <= reader.options.stream_window_bytes || error(
            "windowed selection window_index=$k required_bytes=$required exceeds execution.stream_window_bytes=$(reader.options.stream_window_bytes); increase execution.stream_window_bytes or reduce the common-boundary window")
        highwater = max(highwater, required)
    end
    return Int(highwater), ""
end


# ---- Opt-in stage1 A: execution.windowed_reusable_decoder (default false) ----
# Same serial windowed route, persistent ordered Cutflow, global entry offset and
# publication contract as run_windowed_selection; only the physical decoder,
# mandatory counter policy and resource charges differ. Modern-only: every
# unsupported condition is a reason (before Events reads) or an explicit
# WindowedReusableUnsupported error (after), never a fallback/retry.

function analyze_reusable_selection_window!(analysis, reader, decode, sel, k; stream, lumimask, buffer_reuse=nothing)
    payload = Selection.read_reusable_selection_window(reader, decode, sel, k; stream, lumimask, buffer_reuse)
    table, _ = select_events(sel, payload.raw, length(payload.range);
        sample=analysis.sample, cutflow=analysis.cutflow, progress=payload.progress)
    bytes = Selection.reusable_window_bytes(payload.raw, payload.progress, payload.counters, payload.needed; buffer_reuse) +
        EventIO.reusable_shared_offsets_charge(decode, payload.raw)
    bytes <= reader.options.stream_window_bytes || error("finished reusable raw/progress exceeds stream_window_bytes")
    EventIO.check_reusable_window_memory!(decode, reader.options, bytes)
    reader.diagnostics["max_raw_window_bytes"] = max(reader.diagnostics["max_raw_window_bytes"], bytes)
    retained = append_stream_selection_window!(analysis, table, payload.range; validate=true)
    retained <= reader.options.stream_retained_bytes || error("windowed retained selected table exceeds stream_retained_bytes")
    decode.stats["retained_table_highwater_bytes"] = max(decode.stats["retained_table_highwater_bytes"], retained)
    return nothing
end

"""Serial ascending windows on one owned reader/decoder; returns final diagnostics."""
function run_reusable_windows!(analysis, reader, decode, sel, n; stream, lumimask, reserved_extra=nothing, buffer_reuse=nothing)
    for k in eachindex(reader.windows)
        analyze_reusable_selection_window!(analysis, reader, decode, sel, k; stream, lumimask, buffer_reuse)
    end
    if buffer_reuse !== nothing
        if buffer_reuse.accounting !== nothing
            w = buffer_reuse.accounting
            reader.diagnostics["reuse_window_accounting_effective"] = true
            reader.diagnostics["window_accounting_checks"] = w.checks
            reader.diagnostics["window_accounting_capacity_bytes"] = w.reserved_bytes
            reader.diagnostics["window_accounting_max_charge_bytes"] = w.max_charge
        end
        reader.diagnostics["reuse_window_buffers_effective"] = true
        reader.diagnostics["window_buffer_creations"] = buffer_reuse.creations
        reader.diagnostics["window_buffer_resets"] = buffer_reuse.resets
        reader.diagnostics["window_buffer_capacity_highwater_bytes"] = buffer_reuse.reserved_bytes
    end
    return EventIO.finish_reusable_stream!(reader, decode, n; reserved_extra)
end

"""
    prepare_reusable_windowed_selection(sel, src, sample, options; lumimask, object_collections,
                                        max_windows = nothing) -> (prepared, "") | (nothing, reason)

Metadata-only plan, admission and reservation for the opt-in reusable route,
completed BEFORE any Events basket payload read (two source-identity binds).
Unsupported returns a reason that the caller MUST turn into an explicit error,
never the ordinary reader. max_windows = nothing (production) keeps the whole
plan. A positive Int restricts to the first max_windows common-boundary windows
(bounded diagnostics only); fewer planned windows => "fewer_than_required_windows".
The caller owns prepared.decode and must release it before closing src.
"""
function prepare_reusable_windowed_selection(sel, src, sample, options; lumimask=nothing,
        object_collections=nothing, max_windows=nothing, shared_offsets::Bool=false, reuse_buffers::Bool=false, reuse_accounting::Bool=false)
    reuse_accounting && !reuse_buffers && return nothing, "reuse_window_accounting_requires_buffer_reuse"
    reuse_buffers && !isempty(sel.variable_nodes) && return nothing, "reuse_window_buffers_variable_memo_unsupported"
    max_windows === nothing || (max_windows isa Int && max_windows >= 1) ||
        throw(ArgumentError("max_windows must be nothing or a positive Int"))
    src isa NanoAODSource || return nothing, "unsupported_source"
    identity = EventIO.decode_source_identity(src)
    identity === nothing && return nothing, "unbound_mmap_identity"
    treekey = only(k for k in src.file.directory.keys if k.fName == src.tree)
    0 <= treekey.fObjlen <= options.stream_metadata_bytes || error("windowed TTree metadata exceeds stream_metadata_bytes")
    pre = copy(sel.columns_pre)
    "trigger" in sel.builtins && append!(pre, trigger_paths(sel.triggers, sample.kind, sample.stream))
    "lumimask" in sel.builtins && lumimask !== nothing && append!(pre, [sel.data_quality.run_branch, sel.data_quality.lumi_branch])
    pre = unique(pre); post = unique(sel.columns_post)
    full, reason = EventIO.plan_stream_windows(src, pre, post, length(sel.output_names), options;
        counter_names=unique(vcat(pre, post)), indexed_branch_lookup=true)
    isempty(reason) || return nothing, reason
    reader = full
    if max_windows !== nothing
        length(full.windows) >= max_windows || return nothing, "fewer_than_required_windows"
        reader = EventIO.stream_window_prefix(full, max_windows)
    end
    decode = EventIO.StreamDecodeState(reader; share_window_offsets=shared_offsets)
    handed_over = false
    try
        reason = EventIO.reusable_stream_admission(reader, decode)
        # Bind again after metadata planning/admission, before the first Events basket read.
        isempty(reason) && EventIO.decode_source_identity(src; expected=identity)
        # Includes the opt-in shared-offset proof metadata (identical to the default otherwise).
        extra = EventIO.reusable_reservation_bytes(reader, decode)
        spec = nothing
        if isempty(reason) && reuse_buffers
            spec, reason = window_buffer_spec(reader, sel, object_collections)
        end
        accounting = reuse_accounting ? Selection.WindowAccounting(Base.checked_add(32, Base.checked_mul(8, length(reader.branches)))) : nothing
        reservation = nothing
        if isempty(reason)
            reservation, reason = reserve_windowed_selection(reader, sel, object_collections; extra_bytes=Base.checked_add(extra.total, Base.checked_add(spec === nothing ? 0 : spec.bytes, accounting === nothing ? 0 : accounting.reserved_bytes)))
        end
        isempty(reason) || return nothing, reason
        pool = spec === nothing ? nothing : Selection.WindowBufferReuse(sel, spec.n, spec.bounds)
        pool === nothing || (pool.reserved_bytes = spec.bytes; pool.accounting = accounting)
        handed_over = true
        return (reader=reader, decode=decode, extra=extra, reservation=reservation, identity=identity, buffer_reuse=pool,
            source_events=nevents(src), source_windows=length(full.windows),
            source_max_window_events=maximum(length, full.windows; init=0)), ""
    finally
        handed_over || EventIO.release_reusable_stream!(decode)
    end
end

"""Plan, admit and reserve before Events reads (prepare_reusable_windowed_selection);
unsupported returns a reason that the caller MUST turn into an explicit error."""
function run_reusable_windowed_selection(sel, src, sample, options; lumimask=nothing,
        object_collections=nothing, execution_diagnostics=Dict{String,Any}(), shared_offsets::Bool=false, reuse_buffers::Bool=false, reuse_accounting::Bool=false)
    prepared, reason = prepare_reusable_windowed_selection(sel, src, sample, options; lumimask, object_collections, shared_offsets, reuse_buffers, reuse_accounting)
    prepared === nothing && return nothing, reason
    reader = prepared.reader; decode = prepared.decode; identity = prepared.identity
    try
        execution_diagnostics["reserved_raw_window_bytes"] = prepared.reservation
        analysis = StreamSelectionAnalysis(sel, sample.name)
        rdiag = run_reusable_windows!(analysis, reader, decode, sel, nevents(src);
            stream=sample.stream, lumimask, reserved_extra=prepared.extra, buffer_reuse=prepared.buffer_reuse)
        EventIO.decode_source_identity(src; expected=identity)
        table = finish_stream_selection!(analysis, nevents(src); validate=true)
        diag = reader.diagnostics
        merge!(execution_diagnostics, diag)
        decoded = sum((v for (key,v) in diag if endswith(key, "_decoded_baskets")); init=0)
        skipped = sum((v for (key,v) in diag if endswith(key, "_skipped_baskets")); init=0)
        # Proven padded branches (EventIO.reusable_padded_index_reason) are decoded unmasked by
        # the SAME modern decoder; padded_decoded_baskets is a subset of the phase decoded
        # counters, exactly as in run_windowed_selection, and must match the decoder's count.
        padded = get(diag, "padded_decoded_baskets", 0)
        padded == rdiag["reusable_padded_decoded_baskets"] || error("reusable decoder padded basket accounting mismatch")
        decoded -= padded
        # Every demanded basket went through the modern decoder exactly as counted.
        decoded == rdiag["reusable_decoded_baskets"] && skipped == rdiag["reusable_skipped_baskets"] ||
            error("reusable decoder basket accounting mismatch")
        merge!(execution_diagnostics, Dict("windowed_selection"=>true,
            "windowed_selection_requested"=>true, "windowed_selection_effective"=>true,
            "windowed_selection_reason"=>"", "window_count"=>length(reader.windows),
            "decoded_baskets"=>decoded, "skipped_baskets"=>skipped,
            "engine"=>"serial_per_file_incremental_windows", "effective_readers"=>1,
            "max_live_raw_windows_per_file"=>1))
        merge!(execution_diagnostics, rdiag)
        return (table, analysis.cutflow), ""
    finally
        EventIO.release_reusable_stream!(decode)
    end
end


function window_buffer_spec(reader, sel, object_collections)
    mappings = object_collections === nothing ? Pair{String,String}[] : object_collections
    length(mappings) == length(sel.object_names) || return nothing, "object_collection_mapping_missing"
    bounds = zeros(Int, length(mappings))
    for range in reader.windows
        for (i, (name, collection)) in enumerate(mappings)
            name == sel.object_names[i] || return nothing, "object_collection_mapping_mismatch"
            bound = typemax(Int)
            for (branch, br) in reader.branches
                br.jagged && first(split(branch, '_')) == collection || continue
                E = br.E
                E isa DataType && isprimitivetype(E) && sizeof(E) > 0 || continue
                bytes = sum((Int128(br.baskets[ib].decoded) for ib in EventIO.stream_basket_overlap(br.baskets, range)); init=Int128(0))
                bound = min(bound, Int(bytes ÷ sizeof(E)))
            end
            bound == typemax(Int) && return nothing, "object_collection_bound_unavailable:" * collection
            bounds[i] = max(bounds[i], bound)
        end
    end
    n = maximum(length, reader.windows; init=0)
    payload = _window_add(_window_mul(n, 17 + 16length(bounds)), cld(Int128(n), 8))
    payload = _window_add(payload, _window_mul(8, sum(Int128.(bounds); init=Int128(0))))
    bytes = _window_add(_window_mul(2, payload), _window_mul(4096, 2length(bounds) + 4 + length(reader.branches)))
    bytes <= typemax(Int) || error("window buffer capacity overflow")
    return (n=n, bounds=bounds, bytes=Int(bytes)), ""
end
