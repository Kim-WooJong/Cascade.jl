"Append a structured audit finding without changing input or analysis state."
function audit_finding!(findings, severity, code, message; sample = "", path = "", observed = nothing, expected = nothing)
    push!(findings, Dict{String,Any}("severity" => severity, "code" => code, "message" => message,
        "sample" => sample, "path" => path, "observed" => observed, "expected" => expected))
    return nothing
end
