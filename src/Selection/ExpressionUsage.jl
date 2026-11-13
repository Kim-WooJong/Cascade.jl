"""
    ExpressionUsage()

Accumulates what translated expressions reference: input `columns`, object
`collections` (needing offsets), selected `objects` and `builtins`.
"""
struct ExpressionUsage
    columns::Set{String}
    collections::Set{String}
    objects::Set{String}
    builtins::Set{String}
end

ExpressionUsage() = ExpressionUsage(Set{String}(), Set{String}(), Set{String}(), Set{String}())
