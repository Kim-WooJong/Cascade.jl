# Formula and FormulaRef nodes. A non-generic formula has its parameters bound
# at parse time; a FormulaRef shares the generic formula's AST and supplies its
# own parameter vector.
struct FormulaNode
    ast::FormulaAst
    params::Vector{Float64}
end

function formula_variables(ctx, json)::Vector{Int32}
    idx = Int32[]
    for item in jarray(json, :variables)
        item isa AbstractString || throw_correction_error("Invalid formula variable")
        i = find_input_index(item, ctx.inputs)
        var = ctx.inputs[i]
        var.type === :real || throw_correction_error(
            "Formulas only accept real-valued inputs, got type $(var.type) for variable $(var.name)")
        push!(idx, i)
    end
    return idx
end

function formula_ast(ctx, json, generic::Bool)::FormulaAst
    expr = jstring(json, :expression)
    parser = jstring(json, :parser)
    parser == "numexpr" && throw_correction_error("numexpr formula parser is not yet supported")
    parser == "TFormula" || throw_correction_error("Unrecognized formula parser type")
    variables = formula_variables(ctx, json)
    params = Float64[]
    items = jopt_array(json, :parameters)
    if items !== nothing
        for item in items
            isjsonnumber(item) || throw_correction_error("Invalid formula parameter")
            push!(params, Float64(item))
        end
    end
    return parse_tformula(expr, variables, params, !generic)
end

function build_formula!(ctx, json)::NodeRef
    ast = formula_ast(ctx, json, false)
    push!(ctx.tree.formulas, FormulaNode(ast, Float64[]))
    return NodeRef(K_FORMULA, Int32(length(ctx.tree.formulas)), 0.0)
end

function build_formularef!(ctx, json)::NodeRef
    index = jint(json, :index)
    (0 <= index < length(ctx.generic)) || throw_correction_error("FormulaRef index $index out of range")
    ast = ctx.generic[index+1]
    params = Float64[]
    for item in jarray(json, :parameters)
        isjsonnumber(item) || throw_correction_error("Invalid formula parameter")
        push!(params, Float64(item))
    end
    length(params) >= ast.nparams || throw_correction_error("Insufficient parameters for formula")
    push!(ctx.tree.formulas, FormulaNode(ast, params))
    return NodeRef(K_FORMULA, Int32(length(ctx.tree.formulas)), 0.0)
end

@inline eval_formula(node::FormulaNode, v::Vals)::Float64 = feval(node.ast, node.ast.root, v.x, node.params)
