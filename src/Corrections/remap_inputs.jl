# Copy of a node tree whose input indices are translated through `map`
# (constituent input i -> compound input map[i]). Used by CompoundCorrection to
# evaluate constituents directly on the compound input values.
function remap_inputs(t::NodeTree, map::Vector{Int32}, intypes::Vector{UInt8})
    m(i) = map[i]
    astcache = IdDict{Vector{FNode},FormulaAst}()
    remap_ast(ast) = get!(() -> remap_formula_ast(ast, map), astcache, ast.nodes)
    return NodeTree(
        intypes,
        [BinningNode(m(n.input), n.axis, n.flow, n.content) for n in t.binnings],
        [MultiBinningNode(m.(n.inputs), n.axes, n.strides, n.flow, n.content) for n in t.multibinnings],
        [CategoryNode(m(n.input), n.isstring, n.strmap, n.intmap, n.dense, n.dense_offset, n.content, n.default)
         for n in t.categories],
        [FormulaNode(remap_ast(n.ast), n.params) for n in t.formulas],
        [TransformNode(m(n.input), n.isint, n.rule, n.content) for n in t.transforms],
        [HashPRNGNode(m.(n.inputs), n.isint, n.dist) for n in t.hashprngs],
    )
end
