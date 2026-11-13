"""
    Correction

One correction of a [`CorrectionSet`](@ref). Public fields: `name`,
`description`, `version`, `inputs::Vector{Variable}`, `output::Variable`.
Evaluate it with [`evaluate`](@ref).
"""
struct Correction
    name::String
    description::String
    version::Int
    inputs::Vector{Variable}
    output::Variable
    tree::NodeTree
    root::NodeRef
end

function Correction(json::AbstractDict)
    name = jstring(json, :name)
    description = jopt_string(json, :description, "")
    version = jint(json, :version)
    output = Variable(jobject(json, :output))
    output.type === :real || throw_correction_error("Outputs can only be real-valued")
    inputs = Variable[]
    for item in jarray(json, :inputs)
        isjsonobject(item) || throw_correction_error("invalid input item type")
        push!(inputs, Variable(item))
    end
    ctx = BuildContext(NodeTree(UInt8[vartype_code(v) for v in inputs]), inputs, FormulaAst[])
    generic = jopt_array(json, :generic_formulas)
    if generic !== nothing
        for item in generic
            isjsonobject(item) || throw_correction_error("invalid generic_formulas item type")
            push!(ctx.generic, formula_ast(ctx, item, true))
        end
    end
    root = build_node!(ctx, jget(json, :data))
    return Correction(name, description, version, inputs, output, ctx.tree, root)
end

intypes(c::Correction) = c.tree.intypes

@inline eval_root(c::Correction, v::Vals) = eval_node(c.tree, c.root, v)

function Base.show(io::IO, c::Correction)
    print(io, "Correction(", repr(c.name), ", v", c.version, ", inputs: ",
          join((string(v.name, "::", v.type) for v in c.inputs), ", "), ")")
end
