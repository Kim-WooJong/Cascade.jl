# Conversion of evaluation arguments to Vals with type validation.
# Accepted argument types: real inputs take any Real (converted to Float64),
# int inputs take any Integer, string inputs take any AbstractString.
@inline argkind(::AbstractString) = VT_STRING
@inline argkind(::Integer) = VT_INT
@inline argkind(::Real) = VT_REAL
@inline argkind(::Any) = 0x00

@inline eltypekind(::Type{<:AbstractString}) = VT_STRING
@inline eltypekind(::Type{<:Integer}) = VT_INT
@inline eltypekind(::Type{<:Real}) = VT_REAL
@inline eltypekind(::Type) = 0x00

@inline xval(a::Real) = Float64(a)
@inline xval(::Any) = 0.0
@inline kval(a::Integer) = Int64(a)
@inline kval(::Any) = Int64(0)
@inline sval(a::String) = a
@inline sval(a::AbstractString) = String(a)
@inline sval(::Any) = ""

@noinline function throw_nargs(got::Int, expected::Int)
    throw(CorrectionError("Incorrect number of inputs (got $got, expected $expected)"))
end

@noinline function throw_argtype(var::Variable, got::UInt8)
    throw(CorrectionError("Input $(var.name) has wrong type: got $(vartype_name(got)) expected $(var.type)"))
end

"""Check argument kinds against the input types of correction `c`."""
@inline function check_kinds(c, kinds::NTuple{N,UInt8}) where {N}
    types = intypes(c)
    length(types) == N || throw_nargs(N, length(types))
    @inbounds for i in 1:N
        want = types[i]
        got = kinds[i]
        (got == want || (want == VT_REAL && got == VT_INT)) || throw_argtype(c.inputs[i], got)
    end
    return nothing
end

@inline make_vals(args::NTuple{N,Any}) where {N} = Vals{N}(map(xval, args), map(kval, args), map(sval, args))
