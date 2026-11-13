# Recursive construction of a node tree from the JSON `data` of a correction.
struct BuildContext
    tree::NodeTree
    inputs::Vector{Variable}
    generic::Vector{FormulaAst}
end

function build_node!(ctx::BuildContext, json)::NodeRef
    isjsonnumber(json) && return const_node(json)
    if isjsonobject(json) && haskey(json, "nodetype")
        t = jstring(json, :nodetype)
        t == "binning" && return build_binning!(ctx, json)
        t == "multibinning" && return build_multibinning!(ctx, json)
        t == "category" && return build_category!(ctx, json)
        t == "formula" && return build_formula!(ctx, json)
        t == "formularef" && return build_formularef!(ctx, json)
        t == "transform" && return build_transform!(ctx, json)
        t == "hashprng" && return build_hashprng!(ctx, json)
        throw_correction_error("Unrecognized Content object nodetype")
    end
    throw_correction_error("Invalid Content node type")
end
