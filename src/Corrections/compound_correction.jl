"""
    CompoundCorrection

Ordered stack of corrections from the same set (e.g. JEC L1L2L3Res). Each
stage is evaluated on the current inputs; inputs listed in `inputs_update` are
updated with the stage output (`+`, `*` or `/`) and the outputs are combined
with `output_op` (`+`, `*`, `/` or `last`). Public fields: `name`,
`description`, `inputs`, `output`. Evaluate it with [`evaluate`](@ref).
"""
struct CompoundCorrection
    name::String
    description::String
    inputs::Vector{Variable}
    output::Variable
    intypes::Vector{UInt8}
    update::Vector{Int32}
    input_op::UInt8
    output_op::UInt8
    stage_names::Vector{String}
    stage_trees::Vector{NodeTree}   # constituent trees remapped to the compound inputs
    stage_roots::Vector{NodeRef}
    stage_errors::Vector{String}    # non-empty: input type mismatch raised at evaluation
end

const OP_ADD = 0x01
const OP_MUL = 0x02
const OP_DIV = 0x03
const OP_LAST = 0x04

function parse_update_op(s::String, allow_last::Bool, what::String)::UInt8
    s == "+" && return OP_ADD
    s == "*" && return OP_MUL
    s == "/" && return OP_DIV
    allow_last && s == "last" && return OP_LAST
    throw_correction_error("Invalid CompoundCorrection $what update op")
end

function CompoundCorrection(json::AbstractDict, corrections::AbstractDict{String,Correction})
    name = jstring(json, :name)
    description = jopt_string(json, :description, "")
    output = Variable(jobject(json, :output))
    output.type === :real || throw_correction_error("Outputs can only be real-valued")
    inputs = Variable[]
    for item in jarray(json, :inputs)
        isjsonobject(item) || throw_correction_error("invalid inputs item type")
        push!(inputs, Variable(item))
    end
    types = UInt8[vartype_code(v) for v in inputs]
    update = Int32[]
    for item in jarray(json, :inputs_update)
        item isa AbstractString || throw_correction_error("invalid inputs_update item type")
        i = find_input_index(item, inputs)
        inputs[i].type === :real || throw_correction_error("CompoundCorrection updatable inputs must be real-valued")
        push!(update, i)
    end
    input_op = parse_update_op(jstring(json, :input_op), false, "input")
    output_op = parse_update_op(jstring(json, :output_op), true, "output")
    names = String[]
    trees = NodeTree[]
    roots = NodeRef[]
    errors = String[]
    for item in jarray(json, :stack)
        item isa AbstractString || throw_correction_error("Invalid type")
        haskey(corrections, item) ||
            throw_correction_error("CompoundCorrection constituent $item not found in the CorrectionSet")
        corr = corrections[item]
        map = Int32[find_input_index(v.name, inputs) for v in corr.inputs]
        err = ""
        for (j, v) in enumerate(corr.inputs)
            ci = inputs[map[j]]
            if ci.type !== v.type
                err = "Input $(v.name) has wrong type: got $(vartype_name(vartype_code(ci))) expected $(v.type)"
                break
            end
        end
        push!(names, String(item))
        push!(trees, remap_inputs(corr.tree, map, types))
        push!(roots, corr.root)
        push!(errors, err)
    end
    return CompoundCorrection(name, description, inputs, output, types, update, input_op, output_op,
                              names, trees, roots, errors)
end

intypes(c::CompoundCorrection) = c.intypes

function eval_root(c::CompoundCorrection, v::Vals)::Float64
    out = 0.0
    first = true
    for s in eachindex(c.stage_trees)
        err = @inbounds c.stage_errors[s]
        isempty(err) || throw(CorrectionError(err))
        sf = eval_node(@inbounds(c.stage_trees[s]), @inbounds(c.stage_roots[s]), v)
        for pos in c.update
            x = v.x[pos]
            nx = c.input_op == OP_ADD ? x + sf : c.input_op == OP_MUL ? x * sf : x / sf
            v = setreal(v, pos, nx)
        end
        if first
            out = sf
            first = false
        else
            op = c.output_op
            out = op == OP_ADD ? out + sf : op == OP_MUL ? out * sf : op == OP_DIV ? out / sf : sf
        end
    end
    return out
end

function Base.show(io::IO, c::CompoundCorrection)
    print(io, "CompoundCorrection(", repr(c.name), ", stack: ", join(c.stage_names, " -> "), ")")
end
