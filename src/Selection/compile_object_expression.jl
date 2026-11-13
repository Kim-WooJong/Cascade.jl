"""
    compile_object_expression(expr::AbstractString, collection::AbstractString) -> (kernel, columns)

Compile an object expression (bare names are fields of `collection`, e.g.
`"abs(eta) < 1.5 ? 1.01 : 1.02"`) into `kernel(ctx, j)::Float64` for flat object
index `j`. `columns` are the input columns it reads. Evaluate with
`evaluate_object_expression`.
"""
function compile_object_expression(expr::AbstractString, collection::AbstractString)
    u = ExpressionUsage()
    body = translate_expression(parse_expression(expr), u; objects = Dict{String,String}(),
                                variables = Dict{String,String}(), builtins = Set{String}(), collection)
    kernel = compile_kernel([:ctx, :j], :(Float64($body)))
    return kernel, sort!(collect(u.columns))
end
