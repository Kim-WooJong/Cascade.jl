const KERNEL_CONSTANTS = Set{Symbol}([:π, :pi, :Inf, :NaN, :Inf32, :NaN32])

const KERNEL_FUNCTIONS = Set{Symbol}([
    :abs, :sqrt, :cbrt, :cosh, :sinh, :tanh, :cos, :sin, :tan, :exp, :log, :log10, :atan,
    :min, :max, :hypot, :ifelse, :isnan, :isfinite, :Float64, :Float32, :Int, :round, :floor,
    :ceil, :sign, :mod, :rem, :div, :xor, :deltaR, :mass_massless, :mass_massive, :pair_pt,
    :+, :-, :*, :/, :^, :&, :|, :⊻, :~, :!, :÷, :%, :(==), :(!=), :<, :<=, :>, :>=])

const KERNEL_COMPARISONS = Set{Symbol}([:(==), :(!=), :<, :<=, :>, :>=])

_colref(name::AbstractString, idx) =
    Expr(:ref, Expr(:., Expr(:., :ctx, QuoteNode(:cols)), QuoteNode(Symbol(name))), idx)
_objref(obj::AbstractString) = Expr(:., Expr(:., :ctx, QuoteNode(:objs)), QuoteNode(Symbol(obj)))
_colvec(name::AbstractString) = Expr(:., Expr(:., :ctx, QuoteNode(:cols)), QuoteNode(Symbol(name)))
_offref(coll::AbstractString, idx) = Expr(:ref, Expr(:., Expr(:., :ctx, QuoteNode(:offs)), QuoteNode(Symbol(coll))), idx)

"""
    translate_expression(ex, usage; objects, variables, builtins, collection = nothing) -> Expr

Translate a parsed expression into kernel code. With `collection === nothing`
the expression is an event expression of event index `i`; otherwise it is an
object expression of flat index `j` in that collection (bare names are fields,
`pt` -> `<collection>_pt`). `objects` maps object name -> collection,
`variables` maps variable name -> expression string (inlined), `builtins` is
the set of precomputed per-event columns. References are recorded in `usage`.
"""
function translate_expression(ex, u::ExpressionUsage; objects::AbstractDict, variables::AbstractDict,
                              builtins, collection::Union{Nothing,AbstractString} = nothing,
                              stack::Vector{String} = String[], variable_nodes = nothing)
    rec(x) = translate_expression(x, u; objects, variables, builtins, collection, stack, variable_nodes)
    if ex isa Bool || ex isa Number
        return ex
    elseif ex isa Symbol
        ex in KERNEL_CONSTANTS && return ex
        s = String(ex)
        if collection !== nothing
            col = string(collection, "_", s)
            push!(u.columns, col)
            push!(u.collections, collection)
            return _colref(col, :j)
        end
        if haskey(variables, s)
            s in stack && throw(ArgumentError("cyclic variable definition: $(join([stack; s], " -> "))"))
            if variable_nodes !== nothing
                node = variable_nodes[s]
                _absorb!(u, node.usage)
                slot = Expr(:call, GlobalRef(@__MODULE__, :_variable_slot),
                            :(ctx.memo), QuoteNode(node.id))
                return Expr(:call, GlobalRef(@__MODULE__, :_variable_value),
                            QuoteNode(node.compute), :ctx, :i, slot)
            end
            return translate_expression(parse_expression(variables[s]), u; objects, variables, builtins,
                                        collection, stack = [stack; s], variable_nodes)
        elseif s in builtins
            push!(u.builtins, s)
            return _colref(s, :i)
        elseif haskey(objects, s)
            throw(ArgumentError("object '$s' used as a value; use length($s) or $s.field[k]"))
        end
        push!(u.columns, s)
        return _colref(s, :i)
    elseif ex isa Expr
        h = ex.head
        if h === :ref
            collection === nothing || throw(ArgumentError("indexing is not allowed in object expressions"))
            length(ex.args) == 2 || throw(ArgumentError("use obj.field[k] with a single index"))
            t = ex.args[1]
            (t isa Expr && t.head === :. && t.args[1] isa Symbol && t.args[2] isa QuoteNode) ||
                throw(ArgumentError("only obj.field[k] indexing is supported, got $(ex)"))
            obj = String(t.args[1])
            haskey(objects, obj) || throw(ArgumentError("unknown object '$obj' in $(ex)"))
            coll = objects[obj]
            col = string(coll, "_", t.args[2].value)
            push!(u.columns, col); push!(u.collections, coll); push!(u.objects, obj)
            return _colref(col, Expr(:ref, _objref(obj), rec(ex.args[2])))
        elseif h === :call
            f = ex.args[1]
            if f === :trigger_match
                collection === nothing || throw(ArgumentError("trigger_match is only supported in event expressions"))
                length(ex.args) == 6 || throw(ArgumentError("trigger_match needs eta, phi, id, filter_bits, max_dr"))
                push!(u.collections, "TrigObj")
                vectors = Any[]
                for field in ("eta", "phi", "id", "filterBits")
                    col = "TrigObj_" * field
                    push!(u.columns, col)
                    range = :(($(_offref("TrigObj", :i)) + 1):$(_offref("TrigObj", :(i + 1))))
                    push!(vectors, :(view($(_colvec(col)), $range)))
                end
                return Expr(:call, GlobalRef(@__MODULE__, :trigger_match), map(rec, ex.args[2:end])..., vectors...)
            end
            if f === :length && collection === nothing && length(ex.args) == 2 &&
               ex.args[2] isa Symbol && haskey(objects, String(ex.args[2]))
                obj = String(ex.args[2])
                push!(u.objects, obj)
                return Expr(:call, :length, _objref(obj))
            end
            (f isa Symbol && f in KERNEL_FUNCTIONS) ||
                throw(ArgumentError("function '$(f)' is not allowed in expressions"))
            return Expr(:call, f, map(rec, ex.args[2:end])...)
        elseif h === :comparison
            args = Any[]
            for (k, a) in enumerate(ex.args)
                if iseven(k)
                    a in KERNEL_COMPARISONS || throw(ArgumentError("unsupported comparison $(a)"))
                    push!(args, a)
                else
                    push!(args, rec(a))
                end
            end
            return Expr(:comparison, args...)
        elseif h in (:&&, :||, :if)
            return Expr(h, map(rec, ex.args)...)
        elseif h === :.
            throw(ArgumentError("$(ex) needs an index: write $(ex)[k]"))
        end
        throw(ArgumentError("unsupported syntax '$(h)' in $(ex)"))
    end
    throw(ArgumentError("unsupported literal $(repr(ex))"))
end
