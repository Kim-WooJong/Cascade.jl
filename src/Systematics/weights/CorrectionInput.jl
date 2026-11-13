"""
    CorrectionInput(name, type, kind, value)

Binding of one input of a loaded correction: `type` is the correction input
type (`:real`, `:int`, `:string`); `kind` is `:constant` (`value` is a
`String`, `Float64` or `Int`), `:expression` (`value` is a parsed
expression evaluated per row) or `:systematic` (replaced by the
nominal/up/down key).
"""
struct CorrectionInput
    name::String
    type::Symbol
    kind::Symbol
    value::Any
end
