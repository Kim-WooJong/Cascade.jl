# Type codes used internally for fast input-type checks.
const VT_REAL = 0x01
const VT_INT = 0x02
const VT_STRING = 0x03

"""
    Variable(name, type, description)

Description of a correction input or output. `type` is one of `:real`,
`:int` or `:string`.
"""
struct Variable
    name::String
    type::Symbol
    description::String
end

function Variable(json::AbstractDict)
    name = jstring(json, :name)
    t = jstring(json, :type)
    type = t == "real" ? :real : t == "int" ? :int : t == "string" ? :string :
           throw_correction_error("Unrecognized variable type")
    return Variable(name, type, jopt_string(json, :description, ""))
end

vartype_code(v::Variable) = v.type === :real ? VT_REAL : v.type === :int ? VT_INT : VT_STRING

vartype_name(code::UInt8) = code == VT_REAL ? "real-valued" : code == VT_INT ? "int" :
                            code == VT_STRING ? "string" : "unsupported"

function find_input_index(name::AbstractString, inputs::Vector{Variable})::Int32
    for (i, var) in pairs(inputs)
        var.name == name && return Int32(i)
    end
    throw_correction_error("Error: could not find variable $name in inputs")
end

function Base.show(io::IO, v::Variable)
    print(io, "Variable(", repr(v.name), ", :", v.type, ")")
end
