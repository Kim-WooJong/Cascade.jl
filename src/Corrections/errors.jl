"""
    CorrectionError(msg)

Exception raised when a correction set cannot be loaded or a correction cannot
be evaluated: malformed or unsupported JSON content, a category key that is not
present (and no default), an input outside the binning range with
`flow = "error"`, or a wrong number or type of inputs.
"""
struct CorrectionError <: Exception
    msg::String
end

Base.showerror(io::IO, e::CorrectionError) = print(io, "CorrectionError: ", e.msg)

@noinline throw_correction_error(msg::AbstractString) = throw(CorrectionError(String(msg)))
