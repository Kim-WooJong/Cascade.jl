const SOURCE_FORMATS = Dict{String,Any}()

"""
    register_source_format!(format::AbstractString, opener)

Register `opener(path::String) -> AbstractEventSource` for samples whose
`format` field equals `format`. Built in: `"nanoaod"`, `"cols"`, `"reduced_rntuple"`.
"""
register_source_format!(format::AbstractString, opener) = (SOURCE_FORMATS[String(format)] = opener; nothing)

"""
    source_formats() -> Vector{String}

Registered source format names.
"""
source_formats() = sort!(collect(keys(SOURCE_FORMATS)))

"""
    open_source(format::AbstractString, path::AbstractString) -> AbstractEventSource

Open `path` with the opener registered for `format`.
"""
function open_source(format::AbstractString, path::AbstractString; options::AbstractDict = Dict())
    haskey(SOURCE_FORMATS, format) ||
        throw(ArgumentError("unknown source format '$format' (known: $(join(source_formats(), ", ")))"))
    isempty(options) && return SOURCE_FORMATS[format](String(path))
    return SOURCE_FORMATS[format](String(path); (Symbol(k) => v for (k,v) in options)...)
end
