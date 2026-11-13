# Compiled node tree of one correction: concretely typed per-kind node vectors
# plus the input type codes. Evaluation is a type-stable recursive walk.
struct NodeTree
    intypes::Vector{UInt8}
    binnings::Vector{BinningNode}
    multibinnings::Vector{MultiBinningNode}
    categories::Vector{CategoryNode}
    formulas::Vector{FormulaNode}
    transforms::Vector{TransformNode}
    hashprngs::Vector{HashPRNGNode}
end

NodeTree(intypes::Vector{UInt8}) = NodeTree(intypes, BinningNode[], MultiBinningNode[], CategoryNode[],
                                            FormulaNode[], TransformNode[], HashPRNGNode[])

function eval_node(t::NodeTree, r::NodeRef, v::Vals)::Float64
    k = r.kind
    k == K_CONST && return r.value
    i = r.index
    k == K_FORMULA && return eval_formula(@inbounds(t.formulas[i]), v)
    k == K_BINNING && return eval_binning(t, @inbounds(t.binnings[i]), v)
    k == K_CATEGORY && return eval_category(t, @inbounds(t.categories[i]), v, t.intypes)
    k == K_MULTIBINNING && return eval_multibinning(t, @inbounds(t.multibinnings[i]), v)
    k == K_TRANSFORM && return eval_transform(t, @inbounds(t.transforms[i]), v)
    k == K_HASHPRNG && return eval_hashprng(@inbounds(t.hashprngs[i]), v)
    throw(CorrectionError("Invalid node reference"))
end
