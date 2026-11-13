"""
    compile_selection(cfg::AnalysisConfig, kind::Symbol) -> CompiledSelection

Translate and compile the selection of `cfg` for sample kind `:mc` or `:data`
(cuts with `only` set to the other kind are dropped; weight variations are MC
only). Each object is materialised just before its first dependent cut;
cleaning dependencies are materialised no later than the objects using them.

With execution.stable_selection_kernels = true (default false) every kernel body is
compiled by compile_stable_kernel instead of compile_kernel: the same bodies with a
reproducible type identity; unsupported content throws here, before any data.
"""
function compile_selection(cfg::AnalysisConfig, kind::Symbol)
    kind in (:mc, :data) || throw(ArgumentError("kind must be :mc or :data"))
    objects = Dict{String,String}(o.name => o.collection for o in cfg.objects)
    builtins = Set(["trigger", "lumimask"])
    enabled = get(get(cfg.raw, "execution", Dict()), "memoize_variables", false)
    enabled isa Bool || throw(ArgumentError("execution.memoize_variables must be Bool"))
    max_bytes = get(get(cfg.raw, "execution", Dict()), "memoize_max_bytes", 268435456)
    max_bytes isa Integer && !(max_bytes isa Bool) && 0 < max_bytes <= typemax(Int) ||
        throw(ArgumentError("execution.memoize_max_bytes must be a positive Int"))
    # Read like memoize_variables (Config.stable_selection_kernels has the same rule).
    stable = get(get(cfg.raw, "execution", Dict()), "stable_selection_kernels", false)
    stable isa Bool || throw(ArgumentError("execution.stable_selection_kernels must be boolean"))
    ck = stable ? compile_stable_kernel : compile_kernel
    nodes = enabled ? _compile_variable_nodes(cfg.variables, objects, builtins; compile = ck) : nothing
    tr(s, u; collection = nothing) = translate_expression(parse_expression(s), u;
        objects, variables = cfg.variables, builtins, collection, variable_nodes = nodes)

    cutcfgs = [c for c in cfg.cuts if c.only === :all || c.only === kind]
    pre = ExpressionUsage()
    post = ExpressionUsage()
    cutfns = Any[]
    mat_at = 0
    # Output-only objects are completed after the cuts for retained events.
    object_stage = Dict(o.name => typemax(Int) for o in cfg.objects)
    column_stages = Dict{String,Int}()
    for (k, c) in enumerate(cutcfgs)
        u = ExpressionUsage()
        body = tr(c.expr, u)
        if mat_at == 0 && !isempty(u.objects)
            mat_at = k
        end
        for name in u.objects
            object_stage[name] = min(object_stage[name], k)
        end
        for name in u.columns
            column_stages[name] = min(get(column_stages, name, typemax(Int)), k)
        end
        _absorb!(mat_at == 0 ? pre : post, u)
        push!(cutfns, ck([:ctx, :i], :(Core.typeassert($body, Bool))))
    end

    # Keep definition order, but build only the objects due at each cut.
    ou = ExpressionUsage()
    object_bodies = Any[]
    dependencies = Dict{String,Set{String}}()
    object_columns = Dict{String,Set{String}}()
    for o in cfg.objects
        u = ExpressionUsage()
        stmts = Any[]
        pred = tr(o.cut, u; collection = o.collection)
        for a in o.clean_against
            ac = objects[a]
            for (c, f) in ((o.collection, "eta"), (o.collection, "phi"), (ac, "eta"), (ac, "phi"))
                push!(u.columns, string(c, "_", f))
            end
            iso = :(isolated_from($(_colref(o.collection * "_eta", :j)), $(_colref(o.collection * "_phi", :j)),
                                  $(_colvec(ac * "_eta")), $(_colvec(ac * "_phi")),
                                  $(_objref(a)), $(o.clean_dr)))
            pred = :($pred && $iso)
        end
        push!(u.collections, o.collection)
        push!(stmts, :(select_objects!(j -> Core.typeassert($pred, Bool), $(_objref(o.name)),
                                       $(_offref(o.collection, :i)), $(_offref(o.collection, :(i + 1))))))
        if !isempty(o.sort_by)
            sc = string(o.collection, "_", o.sort_by)
            push!(u.columns, sc)
            push!(stmts, :(sort_objects!($(_objref(o.name)), $(_colvec(sc)); rev = true)))
        end
        push!(object_bodies, Expr(:block, stmts...))
        dependencies[o.name] = union(u.objects, Set(o.clean_against))
        object_columns[o.name] = u.columns
        _absorb!(ou, u)
    end
    # Cleaning references earlier definitions, so reverse propagation closes
    # transitive dependencies before the ordered kernels are emitted.
    for o in Iterators.reverse(cfg.objects), name in dependencies[o.name]
        object_stage[name] = min(object_stage[name], object_stage[o.name])
    end
    # Apply column deadlines only after transitive object dependencies settle.
    for o in cfg.objects, name in object_columns[o.name]
        column_stages[name] = min(get(column_stages, name, typemax(Int)), object_stage[o.name])
    end
    stmts = Any[]
    for (o, body) in zip(cfg.objects, object_bodies)
        due = object_stage[o.name]
        push!(stmts, :(if lo < $due <= hi
                          $body
                      end))
    end
    push!(stmts, :nothing)
    materialize = ck([:ctx, :i, :lo, :hi], Expr(:block, stmts...))
    _absorb!(post, ou)

    # base weight (event-level scalars only: it is evaluated for every event)
    wu = ExpressionUsage()
    wexprs = kind === :mc ? cfg.weights_mc : cfg.weights_data
    wbody = foldl((a, s) -> :($a * Float64($(tr(s, wu)))), wexprs; init = 1.0)
    isempty(wu.objects) || throw(ArgumentError("weight expressions must not use objects; use the correct step"))
    weight = ck([:ctx, :i], :(Core.typeassert($wbody, Float64)))
    _absorb!(pre, wu)

    # outputs of kept events
    names = String[]
    vals = Any[]
    hist_columns = Dict{String,Vector{String}}()
    for h in cfg.histograms
        cols = String[]
        for (k, v) in enumerate(h.values)
            n = string("h:", h.name, ":", k)
            push!(names, n); push!(cols, n)
            push!(vals, :($(tr(h.when, post)) ? Float64($(tr(v, post))) : NaN))
        end
        hist_columns[h.name] = cols
    end
    if kind === :mc
        for v in cfg.variations
            push!(names, string("w:", v.name, "Up")); push!(vals, :(Float64($(tr(v.up, post)))))
            push!(names, string("w:", v.name, "Down")); push!(vals, :(Float64($(tr(v.down, post)))))
        end
    end
    for v in cfg.output_columns
        push!(names, string("v:", v)); push!(vals, :(Float64($(tr(v, post)))))
    end
    # Independent region predicates are evaluated only after their prefix has
    # passed. Short-circuiting keeps object indexing safe in failing events.
    region_stage = region_stages(cfg, kind)
    for r in cfg.regions
        push!(names, string("r:", r.name))
        body = tr(r.expr, post)
        push!(vals, :(Float64(s >= $(region_stage[r.name]) && Core.typeassert($body, Bool))))
    end
    outputs = ck([:ctx, :i, :s], Expr(:tuple, vals...))

    cut_names = [c.name for c in cutcfgs]
    keep = isempty(region_stage) ? length(cut_names) : minimum(values(region_stage))

    cols_pre = sort!(collect(pre.columns))
    cols_post = sort!(collect(setdiff(post.columns, pre.columns)))
    builtins_used = sort!(collect(union(pre.builtins, post.builtins)))
    # Partial contexts get offsets only from an already-read jagged column.
    # A cut="true" object can need offsets without naming any collection field;
    # retain the conservative read route when no such field establishes them.
    stageable = all(cfg.objects) do o
        object_stage[o.name] == typemax(Int) ||
            any(c -> first(split(c, '_')) == o.collection, object_columns[o.name])
    end
    # Output/variation/region-only columns are valid for every retained event.
    post_stages = stageable ?
        Dict{String,Int}(name => get(column_stages, name, typemax(Int)) for name in cols_post) :
        Dict{String,Int}()
    return CompiledSelection(kind, cut_names, Tuple(cutfns), mat_at, materialize, weight, outputs, names,
                             hist_columns, [o.name for o in cfg.objects],
                             sort!(collect(union(Set(o.collection for o in cfg.objects), pre.collections, post.collections))),
                             cols_pre, cols_post, builtins_used, region_stage, keep, cfg.triggers, cfg.data_quality, post_stages,
                             nodes === nothing ? () : Tuple(nodes[name] for name in sort!(collect(keys(nodes)))), Int(max_bytes))
end

function _absorb!(a::ExpressionUsage, b::ExpressionUsage)
    union!(a.columns, b.columns); union!(a.collections, b.collections)
    union!(a.objects, b.objects); union!(a.builtins, b.builtins)
    return a
end

# Cold compilation, dependency-first; expressions remain at their original demand
# sites. IDs are independent of Dict insertion order and compilation traversal.
function _compile_variable_nodes(variables, objects, builtins; compile = compile_kernel)
    names = sort!(collect(keys(variables)))
    ids = Dict(name => k for (k, name) in enumerate(names))
    nodes = Dict{String,Any}()
    visiting = String[]
    function build(name)
        haskey(nodes, name) && return
        name in visiting && throw(ArgumentError("cyclic variable definition: $(join([visiting; name], " -> "))"))
        push!(visiting, name)
        ex = parse_expression(variables[name])
        # Translator is authoritative about shadowing, syntax and dependencies.
        # Discover variable references using a complete inline translation first.
        u = ExpressionUsage()
        translate_expression(ex, u; objects, variables, builtins, stack=[name])
        function dependencies(x)
            if x isa Symbol
                x in KERNEL_CONSTANTS && return
                haskey(variables, String(x)) && build(String(x))
            elseif x isa Expr
                if x.head === :call
                    # length(object) and property bases denote objects, not vars.
                    if x.args[1] === :length && length(x.args) == 2 &&
                       x.args[2] isa Symbol && haskey(objects, String(x.args[2]))
                        return
                    end
                    foreach(dependencies, x.args[2:end])
                elseif x.head === :ref
                    foreach(dependencies, x.args[2:end])
                elseif x.head !== :.
                    foreach(dependencies, x.args)
                end
            end
        end
        dependencies(ex)
        body = translate_expression(ex, ExpressionUsage(); objects, variables, builtins,
                                    stack=[name], variable_nodes=nodes)
        nodes[name] = VariableNode(NodeID{ids[name]}(), name, compile([:ctx,:i], body), u)
        pop!(visiting)
        return
    end
    foreach(build, names)
    return nodes
end
