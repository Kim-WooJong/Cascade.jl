"""
    read_selection_columns(sel, src; stream = "", lumimask = nothing,
                           inputs = String[], full = false, staged = false)
        -> (raw, needed)

Public conservative two-value contract: pre columns/builtins are read for all
entries, post columns use the original object-free prefix mask. The legacy
internal staged keyword remains accepted; incremental column validity requires
its matching progress consumer and is not exposed by this public interface.
Shapes, full reads, custom sources and active decode/reader scopes retain this
route. Ordinary serial run_selection uses _read_selection_columns with reuse.
"""
function read_selection_columns(sel::CompiledSelection, src::AbstractEventSource;
                                stream::AbstractString = "", lumimask = nothing,
                                inputs::AbstractVector{<:AbstractString} = String[],
                                full::Bool = false, reader_scope = nothing,
                                decode_scope = nothing, staged::Bool = false)
    if !isempty(sel.variable_nodes) && !full && sel.mat_at > 0
        @warn "Public/shape read has independent prefix memo; final invocations receive isolated caches"
    end
    raw, needed, _ = _read_selection_columns(sel, src; stream, lumimask, inputs,
                                            full, reader_scope, decode_scope)
    return raw, needed
end

# Only the matching internal final consumer can use refined raw plus progress.
function _read_selection_columns(sel::CompiledSelection, src::AbstractEventSource;
                                 stream::AbstractString = "", lumimask = nothing,
                                 inputs::AbstractVector{<:AbstractString} = String[],
                                 full::Bool = false, reader_scope = nothing,
                                 decode_scope = nothing, reuse::Bool = false)
    n = nevents(src)
    use_stages = reuse && src isa EventIO.NanoAODSource &&
                 reader_scope === nothing && decode_scope === nothing && !full &&
                 isempty(inputs) && !isempty(sel.column_stages)
    cache = use_stages ? EventIO.NanoAODReadCache(src) : nothing
    bcols = String[]
    dq = sel.data_quality
    "trigger" in sel.builtins && append!(bcols, trigger_paths(sel.triggers, sel.kind, stream))
    ("lumimask" in sel.builtins && lumimask !== nothing) && append!(bcols, [dq.run_branch, dq.lumi_branch])
    read_phase(names; needed = nothing) = decode_scope !== nothing ? read_decoded_columns(decode_scope, names; needed) :
        reader_scope !== nothing ? read_parallel_columns(reader_scope, names; needed) :
        cache === nothing ? read_columns(src, names; needed) : read_columns(src, names; needed, cache)
    raw = read_phase(unique!(vcat(sel.columns_pre, bcols)))
    if "trigger" in sel.builtins
        raw["trigger"] = trigger_column(raw, sel.triggers, sel.kind, stream)
    end
    if "lumimask" in sel.builtins
        raw["lumimask"] = lumimask === nothing ? fill(true, n) :
                          lumimask_column(lumimask, raw[dq.run_branch], raw[dq.lumi_branch])
    end
    post = unique!(vcat(sel.columns_post, String[c for c in inputs if !haskey(raw, c)]))
    needed = nothing
    if !use_stages
        # Opt-in memo must survive the conservative prefix and final replay too.
        # No cut progress is advanced here; prefix kernels retain old semantics.
        progress = reuse && !isempty(sel.variable_nodes) ? SelectionProgress(sel, raw, n) : nothing
        if !full && sel.mat_at > 0 && !isempty(post)
            ctx0 = progress === nothing ? selection_context(raw, sel, String[]; n) :
                   _progress_context(raw, sel, String[], progress)
            needed = Base.invokelatest(prefix_pass!, Vector{Bool}(undef, n), sel, ctx0, n)
        end
        isempty(post) || merge!(raw, read_phase(post; needed))
        return raw, needed, progress
    end

    progress = SelectionProgress(sel, raw, n)
    if sel.mat_at > 0 && !isempty(post)
        ctx0 = _progress_context(raw, sel, String[], progress)
        limit = min(sel.mat_at - 1, sel.keep_stage)
        Base.invokelatest(advance_selection!, progress, sel, ctx0, limit)
        # Preserve the original prefix-mask meaning; only the internal caller
        # gets progress. This one copy is never a per-group reevaluation.
        needed = copy(progress.needed)
    end
    groups = Dict{Int,Vector{String}}()
    for name in post
        due = get(sel.column_stages, name, typemax(Int))
        push!(get!(groups, due, String[]), name)
    end
    for due in sort!(collect(keys(groups)))
        limit = min(due - 1, sel.keep_stage)
        if limit > progress.at
            ctx = _progress_context(raw, sel, String[], progress)
            Base.invokelatest(advance_selection!, progress, sel, ctx, limit)
        end
        # One stable mask and canonical offsets across groups; already-read
        # column arrays stay in raw and are not copied or replaced.
        merge!(raw, read_phase(groups[due]; needed = progress.needed))
    end
    return raw, needed, progress
end
