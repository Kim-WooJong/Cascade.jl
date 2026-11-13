"""
    object_factors(t::ObjectScaleFactor, c, bound, table::EventTable, index) -> WeightFactors

Product over the selected objects `t.indices` of the scale factor `c`
(nominal and, if configured, up/down), per event-table row. Object fields and
sub-expressions are read from the `[output] columns` variables found through
`index` (`output_column_index`); objects failing `t.when` contribute 1.
"""
function object_factors(t::ObjectScaleFactor, c, bound::Vector{CorrectionInput}, table::EventTable,
                        index::AbstractDict)
    n = nrows(table)
    varied = !isempty(t.keys[2])
    fs = [ones(n) for _ in 1:(varied ? 3 : 1)]
    label = "object_sf '$(t.name)' ($(t.correction))"
    for k in t.indices
        resolve = _object_resolver(index, table, t.object, k, label)
        rows = if isempty(t.when)
            collect(1:n)
        else
            m = eval_vector_expression(parse_expression(t.when), resolve, n)
            eltype(m) <: Bool || throw(ArgumentError("$(label): when must be a condition"))
            findall(m)
        end
        isempty(rows) && continue
        cols = Any[b.kind === :expression ?
                   _input_column(b, eval_vector_expression(b.value, resolve, n)[rows], label) : nothing
                   for b in bound]
        for (j, key) in enumerate(t.keys[1:length(fs)])
            vals = evaluate_term(c, bound, cols, key, length(rows); label)
            f = fs[j]
            for (r, x) in zip(rows, vals)
                f[r] *= x
            end
        end
    end
    return WeightFactors(t.name, fs[1], varied ? fs[2] : nothing, varied ? fs[3] : nothing)
end

function _object_resolver(index, table, object, k, label)
    return function (ex)
        ex isa Symbol || ex isa Expr || return nothing
        ex isa Symbol && haskey(VECTOR_CONSTANTS, ex) && return nothing
        key = string(object_expression(ex, object, k))
        col = get(index, key, nothing)
        col === nothing || return table[col]
        ex isa Symbol && throw(ArgumentError(
            "$(label): no [output] columns variable with expression \"$key\"; " *
            "add e.g. $(object)_$(ex)_$(k) = \"$key\" to [variables] and its name to [output] columns"))
        return nothing
    end
end
