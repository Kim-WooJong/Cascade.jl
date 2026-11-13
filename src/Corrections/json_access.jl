# Internal helpers to read parsed JSON (Dict{String,Any} / Vector{Any}) with
# correctionlib-style error messages. Keys are given as Symbols for brevity.

isjsonobject(v) = v isa AbstractDict
isjsonnumber(v) = v isa Real && !(v isa Bool)

function jget(obj, key::Symbol)
    haskey(obj, String(key)) || throw_correction_error("Object missing required attribute '$key'")
    return obj[String(key)]
end

function jstring(obj, key::Symbol)
    v = jget(obj, key)
    v isa AbstractString || throw_correction_error("Encountered invalid type for required attribute '$key'")
    return String(v)
end

function jint(obj, key::Symbol)
    v = jget(obj, key)
    (v isa Integer && !(v isa Bool)) || throw_correction_error("Encountered invalid type for required attribute '$key'")
    return Int(v)
end

function jnumber(obj, key::Symbol)
    v = jget(obj, key)
    isjsonnumber(v) || throw_correction_error("Encountered invalid type for required attribute '$key'")
    return Float64(v)
end

function jarray(obj, key::Symbol)
    v = jget(obj, key)
    v isa AbstractVector || throw_correction_error("Encountered invalid type for required attribute '$key'")
    return v
end

function jobject(obj, key::Symbol)
    v = jget(obj, key)
    isjsonobject(v) || throw_correction_error("Encountered invalid type for required attribute '$key'")
    return v
end

"""Optional attribute: returns `nothing` when absent or null."""
function joptional(obj, key::Symbol)
    haskey(obj, String(key)) || return nothing
    return obj[String(key)]
end

function jopt_string(obj, key::Symbol, default::String)
    v = joptional(obj, key)
    v === nothing && return default
    v isa AbstractString || throw_correction_error("Encountered invalid type for optional attribute '$key'")
    return String(v)
end

function jopt_array(obj, key::Symbol)
    v = joptional(obj, key)
    v === nothing && return nothing
    v isa AbstractVector || throw_correction_error("Encountered invalid type for optional attribute '$key'")
    return v
end
