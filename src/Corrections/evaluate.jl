"""
    evaluate(c, args...) -> Float64
    evaluate(c, columns...) -> Vector{Float64}

Evaluate a [`Correction`](@ref) or [`CompoundCorrection`](@ref) with one
argument per input, in input order. Real inputs accept any `Real`, int inputs
any `Integer`, string inputs any `AbstractString`.

If any argument is an `AbstractVector`, evaluation is vectorized: all vector
arguments must have the same axes, scalar arguments are broadcast, and a
`Vector{Float64}` is returned (see also [`evaluate!`](@ref)).

Throws [`CorrectionError`](@ref) in the cases where correctionlib raises.
"""
function evaluate(c::Union{Correction,CompoundCorrection}, args::Vararg{Any,N}) where {N}
    if has_array(args)
        return evaluate_columns(c, args)
    end
    check_kinds(c, map(argkind, args))
    return eval_root(c, make_vals(args))
end

@inline has_array(::Tuple{}) = false
@inline has_array(t::Tuple) = (first(t) isa AbstractArray) | has_array(Base.tail(t))
