"""
    event_factors(t::EventWeight, c, bound, table::EventTable, index, cfg, reader) -> WeightFactors

Per-row factor `c` (nominal and, if configured, up/down). Names in input
expressions are `[output] columns` variables of the event table or branches of
the source file read through `reader` (`BranchReader`); a sub-expression equal
to an output variable expression uses that column.
"""
function event_factors(t::EventWeight, c, bound::Vector{CorrectionInput}, table::EventTable,
                       index::AbstractDict, cfg::AnalysisConfig, reader)
    n = nrows(table)
    label = "event_weight '$(t.name)' ($(t.correction))"
    resolve = function (ex)
        if ex isa Symbol
            haskey(VECTOR_CONSTANTS, ex) && return nothing
            s = String(ex)
            col = string("v:", s)
            haskey(table, col) && return table[col]
            haskey(cfg.variables, s) && throw(ArgumentError(
                "$(label): variable '$s' is not in [output] columns"))
            return reader(s)
        elseif ex isa Expr
            col = get(index, string(ex), nothing)
            return col === nothing ? nothing : table[col]
        end
        return nothing
    end
    cols = Any[b.kind === :expression ? _input_column(b, eval_vector_expression(b.value, resolve, n), label) : nothing
               for b in bound]
    varied = !isempty(t.keys[2])
    fs = [evaluate_term(c, bound, cols, key, n; label) for key in t.keys[1:(varied ? 3 : 1)]]
    return WeightFactors(t.name, fs[1], varied ? fs[2] : nothing, varied ? fs[3] : nothing)
end
