# Plan-local exact branch lookup for plan_stream_windows(...; indexed_branch_lookup=true),
# used only by the opt-in execution.windowed_reusable_decoder planner. Default false keeps
# the per-name public lookup unchanged.
#
# Public UnROOT 0.11.11 lookup of key "tree/name" (no '/' in tree or name), from
# root.jl:169-182 and 241-253: under file.lock, get!(file.cache, key) do the FIRST element b of
# file[tree].fBranches.elements (a Vector{Any}) with b.fName == name, else missing end.
# On every cache miss this boxes fName for each element until the match.
#
# stream_plan_branch_index scans that element vector at most once per plan, for the requested
# names only, and stops when all are found. stream_plan_branch then runs the SAME locked get!
# on the SAME key, so:
# - the cache gets the same object (or missing), at the same point in the planner loop;
# - an entry that is already present wins unchanged;
# - early planner returns leave the cache exactly as the public path would.
#
# Temporary state: the index is NEW plan-local scratch: a borrowed reference to the file-owned
# element vector (never copied or mutated) plus a Dict of the requested names. The planner
# drops its only reference after the branch loop, before metadata sizing, so it is unreachable
# from then on (GC timing is not guaranteed). It is never stored in StreamWindowReader, never
# retained across plans or files, and not part of any memory accounting (all accounted values
# are unchanged).
#
# The index never parses or looks anything up on its own: it uses the tree only when the file
# cache already holds it (the planner's nevents() put it there), and makes no public lookup.
# It returns nothing, so the caller keeps the unchanged public path, for any shape outside this
# proof:
# - an unsupported file: production support (IO.jl) requires exactly UnROOT 0.11.11 with
#   ROOTFile cache::Dict{Any,Any} and lock::ReentrantLock;
# - a tree not cached yet (read under the same file.lock; never parsed or looked up here), or an
#   empty tree name, or one containing '/';
# - a tree without an fBranches field, a container that is not the normal UnROOT TObjArray or
#   has no elements field (checked with hasfield before getfield; no getproperty on unsupported
#   shapes), elements that are not a non-empty Vector, an unsupported element, or a non-String fName;
# - a query name that is not an AbstractString.
# AbstractString names (including SubString) are supported. A name containing '/' (a nested
# path) is left out of the index and goes through the public path.
# stream_plan_branch also takes the public path for any name that is not an AbstractString.

stream_plan_file_supported(_) = false
stream_plan_tree_supported(_) = false
stream_plan_container_supported(_) = false
stream_plan_branch_supported(_) = false

struct StreamPlanBranchIndex{V<:AbstractVector}
    elements::V                  # borrowed file-owned fBranches.elements (never copied/mutated)
    positions::Dict{String,Int}  # requested name -> first matching position; 0 = no match
end

function stream_plan_branch_index(file, tree::AbstractString, names)
    stream_plan_file_supported(file) || return nothing
    isempty(tree) && return nothing
    '/' in tree && return nothing
    for name in names
        name isa AbstractString || return nothing
    end
    t = Base.@lock file.lock get(file.cache, tree, nothing)
    stream_plan_tree_supported(t) || return nothing
    hasfield(typeof(t), :fBranches) || return nothing
    container = getfield(t, :fBranches)
    stream_plan_container_supported(container) || return nothing
    hasfield(typeof(container), :elements) || return nothing
    elements = getfield(container, :elements)
    elements isa Vector && !isempty(elements) || return nothing
    positions = Dict{String,Int}()
    for name in names
        s = String(name)
        '/' in s || (positions[s] = 0)
    end
    remaining = length(positions)
    for (i, el) in enumerate(elements)
        remaining == 0 && break
        stream_plan_branch_supported(el) || return nothing
        nm = el.fName
        nm isa String || return nothing
        if get(positions, nm, -1) == 0
            positions[nm] = i
            remaining -= 1
        end
    end
    return StreamPlanBranchIndex(elements, positions)
end

function stream_plan_branch(file, tree::AbstractString, name, index::StreamPlanBranchIndex)
    key = string(tree, "/", name)
    name isa AbstractString || return file[key]   # unsupported query: unchanged public lookup
    pos = get(index.positions, String(name), -1)
    pos < 0 && return file[key]                     # not indexed (nested path): unchanged public lookup
    return Base.@lock file.lock begin
        get!(file.cache, key) do
            pos == 0 ? missing : index.elements[pos]
        end
    end
end
