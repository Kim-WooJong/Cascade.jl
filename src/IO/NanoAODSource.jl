"""
    NanoAODSource(path; tree = "Events", runs_tree = "Runs")

CMS NanoAOD file read with UnROOT. Implements `AbstractEventSource`;
`gen_weight_sum` sums `Runs/genEventSumw` (0.0 if absent, e.g. data).
"""
struct NanoAODSource <: AbstractEventSource
    path::String
    file::UnROOT.ROOTFile
    tree::String
    runs_tree::String
    gen_sumw::String
end

NanoAODSource(path::AbstractString; tree::AbstractString = "Events", runs_tree::AbstractString = "Runs", gen_sumw::AbstractString = "genEventSumw") =
    NanoAODSource(String(path), UnROOT.ROOTFile(String(path)), String(tree), String(runs_tree), String(gen_sumw))

nevents(s::NanoAODSource) = Int(s.file[s.tree].fEntries)

column_names(s::NanoAODSource) = String.(keys(s.file[s.tree]))

"""
    NanoAODReadCache(source::NanoAODSource)

Caller-owned metadata for repeated ordinary `read_columns` calls on exactly
`source`. Reuses available names and masked collection counter offsets, not
column contents or masks. Also owns bounded serial basket scratch; final columns
never alias scratch. Use one cache per file/read scope, never concurrently;
discard it before closing the source. Returned Jagged offsets are shared and
must remain read-only. The cache does not own or close the source.
"""
struct NanoAODReadCache
    source::NanoAODSource
    available::Set{String}
    counters::Dict{String,Union{Nothing,_ValidatedNanoAODOffsets}}
    scratch::_NanoAODScratch
    function NanoAODReadCache(source::NanoAODSource)
        return new(source, Set(column_names(source)),
                   Dict{String,Union{Nothing,_ValidatedNanoAODOffsets}}(), _NanoAODScratch())
    end
end

function _nanoaod_counter_offsets(s::NanoAODSource, counter; scratch = nothing)
    counts = read_nanoaod_branch(s.file, s.tree, counter; scratch)
    o = Vector{Int}(undef, length(counts) + 1)
    o[1] = 0
    for i in eachindex(counts)
        count = Int(counts[i])
        count >= 0 || throw(ArgumentError("negative collection count in $counter at event $i"))
        count <= typemax(Int) - o[i] ||
            throw(ArgumentError("collection offsets overflow in $counter at event $i"))
        o[i+1] = o[i] + count
    end
    return o
end

function read_columns(s::NanoAODSource, names::AbstractVector{<:AbstractString};
                      needed::Union{Nothing,AbstractVector{Bool}} = nothing,
                      cache::Union{Nothing,NanoAODReadCache} = nothing)
    cache === nothing || cache.source === s ||
        throw(ArgumentError("NanoAODReadCache belongs to a different source"))
    scratch = cache === nothing ? nothing : cache.scratch
    out = Dict{String,Any}()
    avail = cache === nothing ? (needed === nothing ? Set{String}() : Set(column_names(s))) : cache.available
    counters = cache === nothing ? Dict{String,Union{Nothing,Vector{Int}}}() : cache.counters
    for n in unique(names)
        offs = nothing
        if needed !== nothing
            prefix = first(split(n, '_'))
            offs = get!(counters, prefix) do
                c = string("n", prefix)
                c in avail || return nothing
                o = _nanoaod_counter_offsets(s, c; scratch)
                cache === nothing ? o : _ValidatedNanoAODOffsets(o)
            end
        end
        out[String(n)] = read_nanoaod_branch(s.file, s.tree, n; needed, offsets = offs, scratch)
    end
    return out
end

function gen_weight_sum(s::NanoAODSource)
    haskey(s.file, s.runs_tree) || return 0.0
    s.gen_sumw in keys(s.file[s.runs_tree]) || return 0.0
    # Same reduction as sum(LazyTree(file, "Runs", ["genEventSumw"]).genEventSumw).
    return Float64(sum(UnROOT.LazyBranch(s.file, string(s.runs_tree, "/", s.gen_sumw))))
end

source_signature(s::NanoAODSource) = merge(file_signature(s.path), Dict{String,Any}("format" => "nanoaod"))

close_source(s::NanoAODSource) = (close(s.file); nothing)

register_source_format!("nanoaod", NanoAODSource)
