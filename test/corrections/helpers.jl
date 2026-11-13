# Builders for small in-memory correction sets used by the unit tests.

"""Minimal JSON writer for test fixtures (Dict, Vector, String, Real, Bool, nothing)."""
json_text(x::AbstractDict) = "{" * join((json_text(string(k)) * ":" * json_text(v) for (k, v) in x), ",") * "}"
json_text(x::AbstractVector) = "[" * join((json_text(v) for v in x), ",") * "]"
json_text(x::AbstractString) = "\"" * escape_string(x) * "\""
json_text(x::Bool) = x ? "true" : "false"
json_text(x::Integer) = string(x)
json_text(x::AbstractFloat) = isfinite(x) ? repr(Float64(x)) : (isnan(x) ? "NaN" : (x > 0 ? "Infinity" : "-Infinity"))
json_text(::Nothing) = "null"

var(name, type = "real") = Dict("name" => name, "type" => type)

function corr(name, inputs, data; generic = nothing)
    d = Dict{String,Any}("name" => name, "version" => 1, "inputs" => inputs,
                         "output" => var("out"), "data" => data)
    generic === nothing || (d["generic_formulas"] = generic)
    return d
end

function formula(expr, variables; params = nothing)
    d = Dict{String,Any}("nodetype" => "formula", "expression" => expr, "parser" => "TFormula",
                         "variables" => variables)
    params === nothing || (d["parameters"] = params)
    return d
end

binning(input, edges, content, flow) =
    Dict{String,Any}("nodetype" => "binning", "input" => input, "edges" => edges, "content" => content, "flow" => flow)

category(input, pairs; default = nothing) =
    Dict{String,Any}("nodetype" => "category", "input" => input,
                     "content" => [Dict("key" => k, "value" => v) for (k, v) in pairs], "default" => default)

cset_json(corrections; compound = []) =
    json_text(Dict("schema_version" => 2, "corrections" => corrections, "compound_corrections" => compound))

make_cset(corrections...; compound = []) = parse_correctionset(cset_json(collect(corrections); compound))

"""Single-formula correction over variables x, y, z, t (first `nvars`)."""
function formula_correction(expr, nvars; params = nothing)
    names = ["x", "y", "z", "t"][1:nvars]
    return make_cset(corr("f", [var(n) for n in names], formula(expr, names; params)))["f"]
end

feval_expr(expr, args...; params = nothing) = evaluate(formula_correction(expr, length(args); params), args...)

"""Bytes allocated by a scalar evaluation with three arguments (after compilation)."""
function allocs_scalar(c, a, b, s)
    evaluate(c, a, b, s)
    return @allocated evaluate(c, a, b, s)
end

"""Bytes allocated by an in-place vectorized evaluation (after compilation)."""
function allocs_inplace(out, c, a, b, s)
    evaluate!(out, c, a, b, s)
    return @allocated evaluate!(out, c, a, b, s)
end
