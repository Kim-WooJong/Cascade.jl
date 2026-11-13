@inline colkind(a::AbstractArray) = eltypekind(eltype(a))
@inline colkind(a) = argkind(a)

@inline rowval(a::AbstractArray, i) = @inbounds a[i]
@inline rowval(a, i) = a

"""
    evaluate!(out, c, columns...) -> out

Vectorized evaluation into `out::AbstractVector{Float64}`. Vector arguments
must have the same axes as `out`; scalar arguments are broadcast. Argument
types are checked once per call from the element types.
"""
function evaluate!(out::AbstractVector{Float64}, c::Union{Correction,CompoundCorrection},
                   args::Vararg{Any,N}) where {N}
    check_axes(axes(out), args...)
    check_kinds(c, map(colkind, args))
    @inbounds for i in eachindex(out)
        row = map(a -> rowval(a, i), args)
        out[i] = eval_root(c, make_vals(row))
    end
    return out
end

@inline check_axes(ax) = nothing
@inline function check_axes(ax, a, rest...)
    if a isa AbstractArray
        (ndims(a) == 1 && axes(a) == ax) ||
            throw(CorrectionError("Array arguments must be vectors with the same axes as the output"))
    end
    return check_axes(ax, rest...)
end

function evaluate_columns(c, args::Tuple)
    n = first_length(args...)
    return evaluate!(Vector{Float64}(undef, n), c, map(a -> a isa AbstractArray ? vec_view(a) : a, args)...)
end

vec_view(a::AbstractVector) = a
vec_view(a::AbstractArray) = throw(CorrectionError("Array arguments with dimension greater than one are not supported"))

first_length(a::AbstractArray, rest...) = length(a)
first_length(a, rest...) = first_length(rest...)
first_length() = 0
