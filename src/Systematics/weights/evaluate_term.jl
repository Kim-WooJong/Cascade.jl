"""
    evaluate_term(c, bound, columns, key, n; label = "") -> Vector{Float64}

Evaluate correction `c` row-wise. `bound` are the input bindings
(`bind_inputs`), `columns[i]` the per-row values of expression input `i`
(`nothing` for constants), `key` the value of the systematic input.
Correction errors are rethrown as `ArgumentError` naming the term (`label`).
"""
function evaluate_term(c, bound::Vector{CorrectionInput}, columns::AbstractVector, key::AbstractString,
                       n::Integer; label::AbstractString = "")
    args = Any[]
    for (i, b) in enumerate(bound)
        if b.kind === :systematic
            push!(args, String(key))
        elseif b.kind === :constant
            push!(args, b.value)
        else
            push!(args, columns[i])
        end
    end
    out = Vector{Float64}(undef, n)
    n == 0 && return out
    try
        evaluate!(out, c, args...)
    catch e
        e isa CorrectionError || rethrow()
        throw(ArgumentError("$(label): $(e.msg)"))
    end
    return out
end

"Expression values converted to the correction input type (checked: finite reals, exact integers)."
function _input_column(b::CorrectionInput, v::AbstractVector, label::AbstractString)
    for x in v
        x isa Bool && throw(ArgumentError("$(label): input '$(b.name)' evaluated to a boolean"))
        isnan(x) && throw(ArgumentError("$(label): input '$(b.name)' is NaN for a selected row"))
    end
    if b.type === :int
        all(isinteger, v) || throw(ArgumentError("$(label): int input '$(b.name)' has non-integer values"))
        return Int[Int(x) for x in v]
    end
    return Float64[Float64(x) for x in v]
end
