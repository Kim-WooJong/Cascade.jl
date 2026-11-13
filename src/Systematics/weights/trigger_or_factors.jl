"""
    trigger_or_factors(t::TriggerOR, table, index) -> WeightFactors

Evaluate separate data/MC efficiencies for each eligible selected object and
rebuild the event OR ratio in each nuisance direction. All configured objects
and both efficiency payloads vary together; an unvaried payload stays nominal.
Object fields use explicit output columns, as for `object_factors`.
"""
function trigger_or_factors(t::TriggerOR, table::EventTable, index::AbstractDict)
    n = nrows(table)
    varied = any(e -> !isempty(e.keys[2]), (t.data, t.mc))
    ndir = varied ? 3 : 1
    # Each entry holds per-event efficiencies; no efficiency is invented for
    # objects excluded by `when` (those contribute zero to the OR).
    efficiencies = [[zeros(n, length(t.indices)) for _ in 1:ndir] for _ in 1:2]
    label = "trigger_or '$(t.name)' ($(t.path))"
    for (side, e) in enumerate((t.data, t.mc))
        c = cached_correctionset(e.set)[e.correction]
        bound = bind_inputs(e.inputs, e.systematic, c; label = "$label $(side == 1 ? "data" : "mc")")
        for (leg, k) in enumerate(t.indices)
            resolve = _object_resolver(index, table, t.object, k, label)
            rows = if isempty(t.when)
                collect(1:n)
            else
                m = eval_vector_expression(parse_expression(t.when), resolve, n)
                eltype(m) <: Bool || throw(ArgumentError("$label: when must be a condition"))
                findall(m)
            end
            isempty(rows) && continue
            cols = Any[b.kind === :expression ?
                _input_column(b, eval_vector_expression(b.value, resolve, n)[rows], label) : nothing for b in bound]
            for direction in 1:ndir
                key = isempty(e.keys[2]) ? e.keys[1] : e.keys[direction]
                values = evaluate_term(c, bound, cols, key, length(rows); label)
                efficiencies[side][direction][rows, leg] = values
            end
        end
    end
    factors = [Float64[trigger_or_ratio(view(efficiencies[1][d], r, :), view(efficiencies[2][d], r, :);
                      label = "$label row $r direction $d") for r in 1:n] for d in 1:ndir]
    return WeightFactors(t.name, factors[1], varied ? factors[2] : nothing, varied ? factors[3] : nothing)
end
