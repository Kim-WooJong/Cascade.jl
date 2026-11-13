"""Prepare immutable counter offsets serially once per collection for this mask phase."""
function column_read_jobs(src::NanoAODSource, names, needed, diagnostics)
    needed === nothing || length(needed) == nevents(src) || throw(ArgumentError("needed mask length mismatch"))
    avail = needed === nothing ? Set{String}() : Set(column_names(src))
    counters = Dict{String,Union{Nothing,Vector{Int}}}()
    jobs = Tuple{String,Union{Nothing,Vector{Int}}}[]
    for name in unique(names)
        offsets = nothing
        if needed !== nothing
            prefix = first(split(name, '_'))
            offsets = get!(counters, prefix) do
                counter = string("n", prefix)
                counter in avail || return nothing
                counts = read_nanoaod_branch(src.file, src.tree, counter)
                diagnostics["counter_reads"] += 1
                out = Vector{Int}(undef, length(counts) + 1)
                out[1] = 0
                for i in eachindex(counts)
                    out[i+1] = out[i] + Int(counts[i])
                end
                out
            end
        end
        push!(jobs, (String(name), offsets))
    end
    return jobs
end
