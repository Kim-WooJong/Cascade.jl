# Opt-in stable selection kernels (execution.stable_selection_kernels, default false).
#
# The legacy compile_kernel Core.evals one anonymous function per kernel; its type
# (Kernels.var"#N#M") depends on process-local eval order, so it can never be named by
# a package image and is never reused by a later process. A stable kernel is instead a
# zero-field singleton StableKernel{A,T} whose type parameter T is a lossless type-level
# encoding of the SAME translated body Expr the legacy path would eval (line nodes
# dropped). A @generated call method defined in the Kernels namespace decodes T back to
# that Expr, so the compiled body is the legacy body: identical name resolution,
# lowering (&&/||/if, comparison chains, literal_pow for integer-literal exponents),
# typeasserts, evaluation order and floating-point operations. Literal values live in
# the type (exact bits), so different configurations never alias, and the same
# configuration yields the identical type in every process and package image.
#
# No per-event dispatch, no runtime method definition, no cache: kernel identity is
# Julia's own type interning. Unsupported kernel content is an ArgumentError while the
# selection is compiled (before any data), never a fallback to the legacy kernels.

"Type-level Expr node: Expr(H, decode.(A.parameters)...)."
struct KE{H,A} end
"Type-level Symbol."
struct KS{S} end
"Type-level isbits literal (exact value, type and bits)."
struct KV{V} end
"Type-level QuoteNode of a Symbol (KS) or of a singleton instance (KI)."
struct KQ{X} end
"Singleton instance of T (only under KQ: compiled variable kernels and NodeIDs)."
struct KI{T} end
"Type-level GlobalRef into one of the fixed modules of _stable_module."
struct KG{M,S} end

"""
    StableKernel{A,T}()

Zero-field callable kernel with argument names A (one of STABLE_KERNEL_ARGS) and
encoded body T. Subtypes Function like the legacy anonymous kernels.
"""
struct StableKernel{A,T} <: Function end

"""Object predicate of a materialize kernel (legacy: the closure j -> pred capturing ctx)."""
struct StableObjectPredicate{T,C} <: Function
    ctx::C
end
StableObjectPredicate{T}(ctx::C) where {T,C} = StableObjectPredicate{T,C}(ctx)

const STABLE_KERNEL_ARGS = ((:ctx, :i), (:ctx, :j), (:ctx, :i, :lo, :hi), (:ctx, :i, :s))
const _ARROW = Symbol("->")
const STABLE_KERNEL_HEADS = (:call, :comparison, Symbol("&&"), Symbol("||"), :if, Symbol("."), :ref, :tuple, :block,
                             _ARROW, :parameters, :kw)
const _STABLE_RECEIVER = Symbol("#stable_kernel#")
const _STABLE_PREDICATE = Symbol("#stable_predicate#")

_stable_unsupported(what) = throw(ArgumentError(string("execution.stable_selection_kernels: unsupported kernel ",
    "content (", what, "); the selection was not compiled and no legacy fallback is used")))

const _STABLE_SELECTION_MODULE = @__MODULE__
function _stable_module_key(m::Module)
    m === _STABLE_SELECTION_MODULE && return :Selection
    m === Kernels && return :Kernels
    m === Base && return :Base
    m === Core && return :Core
    return nothing
end
function _stable_module(s::Symbol)
    s === :Selection && return _STABLE_SELECTION_MODULE
    s === :Kernels && return Kernels
    s === :Base && return Base
    s === :Core && return Core
    error("internal: unknown stable kernel module $s")
end

_stable_strip(x) = x
_stable_strip(x::Expr) = Expr(x.head, Any[_stable_strip(a) for a in x.args if !(a isa LineNumberNode)]...)

# outer: argument names of the enclosing kernel; inlambda: inside the object predicate.
function _stable_encode(x, outer, inlambda::Bool)
    if x isa Symbol
        (x === _STABLE_RECEIVER || x === _STABLE_PREDICATE) && _stable_unsupported("reserved name $x")
        inlambda && x in outer && x !== :ctx && _stable_unsupported("object predicate captures '$x'")
        return KS{x}
    elseif x isa Expr
        h = x.head
        h in STABLE_KERNEL_HEADS || _stable_unsupported("syntax '$h'")
        if h === _ARROW
            inlambda && _stable_unsupported("nested anonymous function")
            (:lo in outer && length(x.args) == 2 && x.args[1] === :j) ||
                _stable_unsupported("anonymous function outside an object predicate")
            return KE{_ARROW,Tuple{KS{:j},_stable_encode(x.args[2], outer, true)}}
        end
        args = Any[_stable_encode(a, outer, inlambda) for a in x.args if !(a isa LineNumberNode)]
        return KE{h,Tuple{args...}}
    elseif x isa QuoteNode
        v = x.value
        v isa Symbol && return KQ{KS{v}}
        T = typeof(v)
        ((v isa NodeID || v isa StableKernel) && Base.issingletontype(T)) ||
            _stable_unsupported("quoted value of type $T")
        return KQ{KI{T}}
    elseif x isa GlobalRef
        m = _stable_module_key(x.mod)
        m === nothing && _stable_unsupported("global reference $(x.mod).$(x.name)")
        return KG{m,x.name}
    elseif x isa Number
        isbitstype(typeof(x)) || _stable_unsupported("literal of type $(typeof(x))")
        return KV{x}
    end
    _stable_unsupported("value of type $(typeof(x))")
end

_stable_decode(::Type{KS{S}}) where {S} = S
_stable_decode(::Type{KV{V}}) where {V} = V
_stable_decode(::Type{KQ{KS{S}}}) where {S} = QuoteNode(S)
_stable_decode(::Type{KQ{KI{T}}}) where {T} = QuoteNode(T.instance)
_stable_decode(::Type{KG{M,S}}) where {M,S} = GlobalRef(_stable_module(M), S)
_stable_decode(::Type{KE{H,A}}) where {H,A} = Expr(H, Any[_stable_decode(p) for p in A.parameters]...)

# Code generation = decode, except the object-predicate lambda (generated bodies may not
# contain closures): construct StableObjectPredicate{body}(ctx), whose generated call
# binds ctx exactly as the closure captured it and evaluates the same body.
_stable_gen(::Type{T}) where {T} = _stable_decode(T)
function _stable_gen(::Type{KE{H,A}}) where {H,A}
    H === _ARROW && return Expr(:call, Expr(:curly, GlobalRef(_STABLE_SELECTION_MODULE, :StableObjectPredicate), A.parameters[2]), :ctx)
    return Expr(H, Any[_stable_gen(p) for p in A.parameters]...)
end
_stable_kernel_codegen(::Type{T}) where {T} = _stable_gen(T)
_stable_predicate_codegen(::Type{T}) where {T} = Expr(:block,
    Expr(:(=), :ctx, Expr(:call, GlobalRef(Core, :getfield), _STABLE_PREDICATE, QuoteNode(:ctx))), _stable_gen(T))

# Exact structural identity: same Expr heads/arity, same literal TYPE and bits.
function _stable_same(a, b)
    if a isa Expr
        return b isa Expr && a.head === b.head && length(a.args) == length(b.args) &&
               all(k -> _stable_same(a.args[k], b.args[k]), eachindex(a.args))
    elseif a isa QuoteNode
        return b isa QuoteNode && _stable_same(a.value, b.value)
    elseif a isa GlobalRef
        return b isa GlobalRef && a.mod === b.mod && a.name === b.name
    end
    return typeof(a) === typeof(b) && a === b
end

"""
    compile_stable_kernel(args::Vector{Symbol}, body) -> StableKernel

Stable counterpart of compile_kernel(args, body): same body, reproducible type,
no runtime method definition (no invokelatest needed, but harmless). Throws
ArgumentError for content outside the admitted translated-kernel subset.
"""
function compile_stable_kernel(args::Vector{Symbol}, body)
    a = Tuple(args)
    a in STABLE_KERNEL_ARGS || _stable_unsupported("kernel arguments $a")
    T = _stable_encode(body, a, false)
    # Self-check, every compile: the encoding is lossless for this body.
    _stable_same(_stable_decode(T), _stable_strip(body)) ||
        error("internal: stable kernel encoding is not lossless")
    return StableKernel{a,T}()
end

"""The (argument names, body Expr) a stable kernel executes (line nodes dropped)."""
stable_kernel_expr(::StableKernel{A,T}) where {A,T} = (A, _stable_decode(T))

"""True when every kernel of a compiled selection is a StableKernel."""
is_stable_selection(sel) = all(k -> k isa StableKernel, sel.cuts) && sel.materialize isa StableKernel &&
    sel.weight isa StableKernel && sel.outputs isa StableKernel &&
    all(node -> node.compute isa StableKernel, sel.variable_nodes)

"""
    precompile_stable_selection(sel, ctx) -> NTuple{2,Bool}

Declare the serial event loop and the prefix pass for this stable selection and
kernel-context type (e.g. while a package image is generated). Type-level only:
ctx may be an empty context built from in-memory zero-event columns; nothing is
read, written or spawned. Legacy selections are rejected (their kernel types are
process-local).
"""
function precompile_stable_selection(sel, ctx)
    is_stable_selection(sel) || throw(ArgumentError("precompile_stable_selection requires execution.stable_selection_kernels = true"))
    S = typeof(sel); C = typeof(ctx)
    return (precompile(_event_loop_recording!, (S, C, Int, Cutflow, Vector{Int64}, Vector{Int16}, Vector{Float64},
                                                Vector{Vector{Float64}}, Nothing, Val{true})),
            precompile(prefix_pass!, (Vector{Bool}, S, C, Int)))
end

"""
    stable_selection_training!(sel, stream, lumimask, column) -> NamedTuple

Generation-time coverage driver for a STABLE selection (package-image workload only).
Replays, on ZERO events and only through the production Selection functions, the staged
column order of read_reusable_selection_window: pre columns + trigger paths (+ run/lumi
when the lumimask builtin is used), trigger/lumimask builtins, prefix advance,
column_stages groups, then select_events with the file progress. The progress, staged
KernelContext and event-loop specializations for the supplied column element types are
therefore compiled exactly as a real file of that schema would request them.
column(name) must return an empty typed column (Vector{E}() or Jagged(E[], [0])).
Nothing is read, written or spawned; zero-event loops execute no cut/weight kernel.
Returns the progress, the final raw column names and the staged/final context types.
"""
function stable_selection_training!(sel, stream::AbstractString, lumimask, column)
    is_stable_selection(sel) || throw(ArgumentError("stable_selection_training! requires execution.stable_selection_kernels = true"))
    n = 0
    pre = copy(sel.columns_pre)
    "trigger" in sel.builtins && append!(pre, trigger_paths(sel.triggers, sel.kind, stream))
    "lumimask" in sel.builtins && lumimask !== nothing &&
        append!(pre, [sel.data_quality.run_branch, sel.data_quality.lumi_branch])
    pre = unique(pre); post = unique(sel.columns_post)
    raw = Dict{String,Any}()
    for name in pre
        raw[name] = column(name)
    end
    "trigger" in sel.builtins && (raw["trigger"] = trigger_column(raw, sel.triggers, sel.kind, stream))
    if "lumimask" in sel.builtins
        dq = sel.data_quality
        raw["lumimask"] = lumimask === nothing ? fill(true, n) :
            lumimask_column(lumimask, raw[dq.run_branch], raw[dq.lumi_branch])
    end
    stages = Any[]
    if isempty(sel.column_stages)
        # Mirrors the unstaged branch (prefix mask, then all post columns).
        progress = isempty(sel.variable_nodes) ? nothing : SelectionProgress(sel, raw, n)
        if sel.mat_at > 0 && !isempty(post)
            ctx = progress === nothing ? selection_context(raw, sel, String[]; n) :
                _progress_context(raw, sel, String[], progress)
            push!(stages, typeof(ctx))
            Base.invokelatest(prefix_pass!, Vector{Bool}(undef, n), sel, ctx, n)
        end
        for name in post
            raw[name] = column(name)
        end
    else
        # Mirrors the staged branch: advance only when a new limit is reached.
        progress = SelectionProgress(sel, raw, n)
        if sel.mat_at > 0 && !isempty(post)
            ctx = _progress_context(raw, sel, String[], progress)
            push!(stages, typeof(ctx))
            Base.invokelatest(advance_selection!, progress, sel, ctx, min(sel.mat_at - 1, sel.keep_stage))
        end
        groups = Dict{Int,Vector{String}}()
        for name in post
            due = get(sel.column_stages, name, typemax(Int))
            due >= 1 || error("invalid incremental column stage: $name")
            push!(get!(groups, due, String[]), name)
        end
        for due in sort!(collect(keys(groups)))
            limit = min(due - 1, sel.keep_stage)
            if limit > progress.at
                ctx = _progress_context(raw, sel, String[], progress)
                push!(stages, typeof(ctx))
                Base.invokelatest(advance_selection!, progress, sel, ctx, limit)
            end
            for name in groups[due]
                raw[name] = column(name)
            end
        end
    end
    select_events(sel, raw, n; sample = "", cutflow = Cutflow(vcat("all", sel.cut_names)), progress)
    final = progress === nothing ? selection_context(raw, sel, sel.collections; n) :
        _progress_context(raw, sel, sel.collections, progress)
    return (progress = progress, columns = sort!(collect(keys(raw))), stages = stages, final = typeof(final))
end

# Call methods live in Kernels so the decoded body resolves names exactly like the
# legacy Core.eval(Kernels, ...) lambda. Defined last: generators only use the
# helpers above. Argument names equal the legacy lambda arguments.
for args in STABLE_KERNEL_ARGS
    Core.eval(Kernels, Expr(:macrocall, Symbol("@generated"), LineNumberNode(@__LINE__, Symbol(@__FILE__)),
        Expr(:function,
            Expr(:where, Expr(:call, Expr(:(::), _STABLE_RECEIVER, Expr(:curly, StableKernel, QuoteNode(args), :T)), args...), :T),
            Expr(:block, Expr(:return, Expr(:call, _stable_kernel_codegen, :T))))))
end
Core.eval(Kernels, Expr(:macrocall, Symbol("@generated"), LineNumberNode(@__LINE__, Symbol(@__FILE__)),
    Expr(:function,
        Expr(:where, Expr(:call, Expr(:(::), _STABLE_PREDICATE, Expr(:curly, StableObjectPredicate, :T, :C)), :j), :T, :C),
        Expr(:block, Expr(:return, Expr(:call, _stable_predicate_codegen, :T))))))
