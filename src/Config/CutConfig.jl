"""
    CutConfig

One sequential event cut (one cutflow stage). `expr` is an event expression
returning `Bool`. `only` is `:all`, `:mc` or `:data`; a cut restricted to one
kind is absent from the cutflow of the other kind.
"""
struct CutConfig
    name::String
    expr::String
    only::Symbol
end
