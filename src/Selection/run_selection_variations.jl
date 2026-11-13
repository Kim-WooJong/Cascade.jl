"""
    run_selection_variations(sel, src, vary; inputs = String[], replaces = String[],
                             stream = "", lumimask = nothing, sample = "")
        -> Vector{Pair{String,Tuple{EventTable,Cutflow}}}

Process one chunk for the nominal configuration and for column variations
(shape systematics). Columns are read once (`read_selection_columns`, extra
`inputs` included); then `vary(raw, needed)` returns
`label => replacements` pairs, where `replacements::Dict{String,Any}` maps
column names to varied columns with the same type and (for jagged columns)
the same offsets. Label `"nominal"` (optional) replaces the nominal columns;
every other label gives one more selection pass over the shared, otherwise
unchanged columns. Unused replacement columns are ignored.

`replaces` lists every column `vary` may replace: if one of them is used by an
object-free leading cut, all columns are read for all events (no `needed`
mask). Result: `"nominal"` first, then the other labels in `vary` order; the
variation tables have `meta["variation"] = label`.
"""
function run_selection_variations(sel::CompiledSelection, src::AbstractEventSource, vary;
                                  inputs::AbstractVector{<:AbstractString} = String[],
                                  replaces::AbstractVector{<:AbstractString} = String[],
                                  stream::AbstractString = "", lumimask = nothing,
                                  sample::AbstractString = "", cutflows = nothing)
    full = any(c -> c in sel.columns_pre, replaces)
    # Even an empty-input shape callback may promote an event past a nominal cut.
    raw, needed = read_selection_columns(sel, src; stream, lumimask, inputs, full, staged = false)
    n = nevents(src)
    reps = vary(raw, needed)
    used(d) = Dict{String,Any}(k => v for (k, v) in d if haskey(raw, k))
    i = findfirst(p -> first(p) == "nominal", reps)
    base = i === nothing ? raw : merge(raw, used(last(reps[i])))
    accumulator(label) = cutflows === nothing ? nothing : get!(cutflows, label) do
        Cutflow(vcat("all", sel.cut_names))
    end
    out = Pair{String,Tuple{EventTable,Cutflow}}["nominal" => select_events(sel, base, n; sample, cutflow = accumulator("nominal"))]
    for (label, rep) in reps
        label == "nominal" && continue
        cols = merge(base, used(rep))
        push!(out, String(label) => select_events(sel, cols, n; sample,
                                                  meta = Dict{String,Any}("variation" => String(label)), cutflow = accumulator(String(label))))
    end
    return out
end
