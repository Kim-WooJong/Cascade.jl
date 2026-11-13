const ROOT_SYMBOLS = Dict(
    "alpha" => "α", "beta" => "β", "gamma" => "γ", "delta" => "δ", "Delta" => "Δ", "epsilon" => "ε",
    "eta" => "η", "theta" => "θ", "lambda" => "λ", "mu" => "μ", "nu" => "ν", "pi" => "π", "rho" => "ρ",
    "sigma" => "σ", "Sigma" => "Σ", "tau" => "τ", "phi" => "φ", "chi" => "χ", "omega" => "ω",
    "ell" => "ℓ", "geq" => "≥", "leq" => "≤", "pm" => "±", "times" => "×", "oplus" => "⊕",
    "rightarrow" => "→", "infty" => "∞")

"""
    format_label(label, format) -> String

Convert a ROOT TLatex label (`#mu`, `t#bar{t}`, `p_{T}`, `fb^{-1}`) for a table in
`format`: `:text` (Unicode), `:markdown` (Unicode with Markdown escapes) or
`:latex` (math mode when the label uses markup, escaped text otherwise).
"""
function format_label(label::AbstractString, format::Symbol)
    format == :latex && return latex_label(label)
    s = replace(label, r"#bar\{([^{}]*)\}" => m -> join(string(c, '\u0304') for c in m[6:end-1]))
    s = replace(s, r"#([A-Za-z]+)" => m -> get(ROOT_SYMBOLS, m[2:end], m[2:end]))
    s = replace(s, r"\^\{([^{}]*)\}" => m -> "^" * m[3:end-1], r"_\{([^{}]*)\}" => m -> "_" * m[3:end-1])
    format == :text && return s
    format == :markdown && return replace(s, "|" => "\\|", "*" => "\\*", "_" => "\\_")
    throw(ArgumentError("format must be :text, :markdown or :latex"))
end

function latex_label(label::AbstractString)
    if occursin(r"#|\^|_\{", label)
        body = replace(label, "#" => "\\", " " => "\\ ", "%" => "\\%", "&" => "\\&")
        return "\$" * body * "\$"
    end
    return replace(label, "\\" => "\\textbackslash{}", "&" => "\\&", "%" => "\\%", "\$" => "\\\$",
                   "~" => "\\~{}", "_" => "\\_", "{" => "\\{", "}" => "\\}")
end
