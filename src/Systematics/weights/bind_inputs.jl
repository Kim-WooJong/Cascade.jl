"""
    bind_inputs(inputs, systematic, c; label = "") -> Vector{CorrectionInput}

Match the configured input mapping of a term against the inputs of the loaded
correction `c` (in correction input order). Every correction input must be
mapped exactly once (or be the `systematic` input); constants must have the
input type. Throws `ArgumentError` naming the term (`label`) otherwise.
"""
function bind_inputs(inputs::AbstractDict, systematic::AbstractString, c; label::AbstractString = "")
    names = [v.name for v in c.inputs]
    errs = String[]
    for k in keys(inputs)
        k in names || push!(errs, "unknown input '$k' (correction inputs: $(join(names, ", ")))")
    end
    isempty(systematic) || systematic in names ||
        push!(errs, "systematic input '$systematic' is not an input of the correction")
    out = CorrectionInput[]
    for v in c.inputs
        if v.name == systematic
            v.type === :string || push!(errs, "systematic input '$(v.name)' must be string-typed")
            push!(out, CorrectionInput(v.name, v.type, :systematic, nothing))
        elseif !haskey(inputs, v.name)
            push!(errs, "input '$(v.name)' ($(v.type)) is not mapped")
        else
            x = inputs[v.name]
            if v.type === :string
                x isa AbstractString || push!(errs, "input '$(v.name)' is string-typed: give a string constant")
                push!(out, CorrectionInput(v.name, v.type, :constant, string(x)))
            elseif x isa Real
                if v.type === :int && !isinteger(x)
                    push!(errs, "input '$(v.name)' is int-typed: constant $x is not an integer")
                end
                push!(out, CorrectionInput(v.name, v.type, :constant, v.type === :int ? Int(round(x)) : Float64(x)))
            else
                ex = try
                    parse_expression(x)
                catch e
                    push!(errs, "input '$(v.name)': $(sprint(showerror, e))"); nothing
                end
                push!(out, CorrectionInput(v.name, v.type, :expression, ex))
            end
        end
    end
    isempty(errs) || throw(ArgumentError("$(label): " * join(errs, "; ")))
    return out
end
