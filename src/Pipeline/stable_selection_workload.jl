# Bounded, source-tracked package-image training workload for the opt-in stable selection
# kernels (execution.stable_selection_kernels). Executed ONLY from precompile_pipeline.jl while
# a package image is generated. It reads exactly two tracked files (the spec below and the
# analysis TOML it names; both are include_dependency'd, so editing either rebuilds the
# image), constructs the selection with the production compile_selection, replays the staged
# zero-event column order with empty typed columns (Selection.stable_selection_training!) and
# declares the reusable-window call sites with the resulting concrete types. No input glob,
# golden JSON, ROOT file, index, admission, task or environment variable is consulted.
#
# Coverage is EXPLICIT TRAINING for the bundled analysis and column schema: a run whose
# selection expressions, memo setting, sample kinds/streams or column element types differ
# (or that leaves stable_selection_kernels false) gets other types and compiles them at
# runtime as before. Results are never affected.

const STABLE_SELECTION_WORKLOAD = joinpath(@__DIR__, "stable_selection_workload.toml")
const _WORKLOAD_ELTYPES = Dict{String,DataType}("Bool" => Bool, "Int8" => Int8, "UInt8" => UInt8,
    "Int16" => Int16, "UInt16" => UInt16, "Int32" => Int32, "UInt32" => UInt32, "Int64" => Int64,
    "UInt64" => UInt64, "Float32" => Float32, "Float64" => Float64)

"""Absolute path of the analysis TOML named by a workload spec (package-root relative)."""
function stable_selection_workload_analysis(spec_path::AbstractString, spec = TOML.parsefile(spec_path))
    rel = spec["analysis"]
    rel isa AbstractString && !isabspath(rel) || throw(ArgumentError("workload analysis must be a package-relative path"))
    return normpath(joinpath(dirname(spec_path), "..", "..", rel))
end

"""
    _kw_default_type(f, kw, kwnt, argtypes) -> DataType

Generation-only: the concrete type of keyword `kw`'s DEFAULT value as passed by the keyword
call `f(args...; kwnt...)` (kw absent from kwnt), read from the unoptimized typed IR of that
keyword call at the call into `f`'s keyword body (argument position = declaration order of
`kw`). Used for the singleton default observer closure, never by its printed name. Fails
closed unless exactly one concrete singleton Function type is found.
"""
function _kw_default_type(f, kw::Symbol, kwnt::Type{<:NamedTuple}, argtypes::Tuple)
    m = only(methods(f, argtypes))
    i = findfirst(==(kw), Base.kwarg_decl(m))
    i === nothing && error("precompile signature: $(nameof(f)) has no keyword $kw")
    kw in fieldnames(kwnt) && error("precompile signature: $kw must use its default")
    body = Base.bodyfunction(m)
    ci = first(only(Base.code_typed(Core.kwcall, (kwnt, typeof(f), argtypes...); optimize = false)))
    argtype(x) = x isa Core.SSAValue ? ci.ssavaluetypes[x.id] :
        x isa Core.SlotNumber ? ci.slottypes[x.id] : x isa Core.Argument ? ci.slottypes[x.n] : Core.Typeof(x)
    callee(x) = x isa GlobalRef ? getglobal(x.mod, x.name) :
        (t = argtype(x); t isa Core.Const ? t.val : nothing)
    found = Any[]
    for st in ci.code
        st isa Expr && st.head === :(=) && (st = st.args[2])
        (st isa Expr && st.head === :call && callee(st.args[1]) === body) || continue
        push!(found, Core.Compiler.widenconst(argtype(st.args[1+i])))
    end
    T = length(unique(found)) == 1 ? only(unique(found)) : nothing
    (T isa DataType && isconcretetype(T) && T <: Function && Base.issingletontype(T)) ||
        error("precompile signature: default of $kw not resolved to one singleton callable: $(found)")
    return T
end

"""
    _reusable_lazybranch_type(E, jagged) -> DataType

Generation-only: the concrete UnROOT.LazyBranch type of a planned primitive branch, following
the audited UnROOT 0.11.11 LazyBranch constructor (flat: buffer Vector{E}; jagged: Bool payload
uses BitVector, view element SubArray, buffer VectorOfVectors(V(), Int32[1])). The caller requires
the decode dependency source contract (iteration.jl hash) before using it.
"""
function _reusable_lazybranch_type(::Type{E}, jagged::Bool) where {E}
    jagged || return UnROOT.LazyBranch{E,UnROOT.Nojagg,Vector{E}}
    V = E === Bool ? BitVector : Vector{E}
    B = typeof(UnROOT.VectorOfVectors(V(), Int32[1]))
    return UnROOT.LazyBranch{SubArray{E,1,V,Tuple{UnitRange{Int64}},true},UnROOT.Nooffsetjagg,B}
end

"""(element type, jagged) cases for reusable-decoder declarations: the workload [flat] and
[jagged] schema element types plus [reusable_decode].counter_eltype (flat). Sorted, finite."""
function reusable_decode_cases(spec)
    flat = _workload_schema(spec, "flat"); jagged = _workload_schema(spec, "jagged")
    rd = get(spec, "reusable_decode", nothing)
    rd isa AbstractDict && haskey(rd, "counter_eltype") || throw(ArgumentError("workload spec lacks [reusable_decode].counter_eltype"))
    c = rd["counter_eltype"]
    haskey(_WORKLOAD_ELTYPES, c) || throw(ArgumentError("workload counter_eltype: unsupported element type $c"))
    counter = _WORKLOAD_ELTYPES[c]
    f = sort!(unique!(vcat(collect(values(flat)), [counter])); by = string)
    j = sort!(unique!(collect(values(jagged))); by = string)
    return (counter = counter, cases = vcat([(E, false) for E in f], [(E, true) for E in j]))
end

function _workload_schema(spec, key)
    table = get(spec, key, Dict{String,Any}())
    return Dict{String,DataType}(String(name) => (haskey(_WORKLOAD_ELTYPES, t) ? _WORKLOAD_ELTYPES[t] :
        throw(ArgumentError("workload column $name: unsupported element type $t"))) for (name, t) in table)
end

"""
    stable_selection_workload(spec_path = STABLE_SELECTION_WORKLOAD) -> NamedTuple

Generation-only. For every distinct (kind, stream) of the bundled analysis' samples: stable
compile_selection (memo setting as in the analysis), zero-event staged training, and
precompile declarations of the reusable-window entry points for the same types. Throws on any
failed declaration or schema gap (fail closed: the image build reports it).
"""
function stable_selection_workload(spec_path::AbstractString = STABLE_SELECTION_WORKLOAD)
    spec = TOML.parsefile(spec_path)
    base = load_analysis(stable_selection_workload_analysis(spec_path, spec); validate = false)
    raw = deepcopy(base.raw)
    execution = get!(raw, "execution", Dict{String,Any}())
    execution["stable_selection_kernels"] = true
    cfg = Config.AnalysisConfig((f === :raw ? raw : getfield(base, f) for f in fieldnames(Config.AnalysisConfig))...)
    flat = _workload_schema(spec, "flat"); jagged = _workload_schema(spec, "jagged")
    isempty(intersect(keys(flat), keys(jagged))) || throw(ArgumentError("workload column declared flat and jagged"))
    column(name) = haskey(jagged, name) ? EventIO.Jagged(jagged[name][], [0]) :
        haskey(flat, name) ? flat[name][] : throw(ArgumentError("workload schema has no column $name"))
    # Type only: the production LumiMask type, built without reading the golden JSON.
    lm = EventIO.LumiMask(cfg.data_quality.run_min, cfg.data_quality.run_max)
    D = EventIO.StreamDecodeState{typeof(EventIO._read_reusable_basket!), typeof(EventIO._reusable_branch),
                                  typeof(EventIO._close_reusable_branch)}
    O = typeof(streaming_selection_options(Dict{String,Any}()))
    X = NamedTuple{(:scratch, :native, :metadata, :total),NTuple{4,Int128}}
    WC = NamedTuple{(:counts, :offsets),Tuple{Dict{String,Any},Dict{String,Vector{Int}}}}
    selections = Dict{Symbol,Any}(); ok = Bool[]; contexts = 0
    for (kind, stream) in unique([(s.kind, s.stream) for s in cfg.samples])
        sel = get!(() -> compile_selection(cfg, kind), selections, kind)
        L = kind === :data ? lm : nothing
        t = Selection.stable_selection_training!(sel, stream, L, column)
        contexts += length(t.stages) + 1
        S = typeof(sel); LT = typeof(L)
        push!(ok, precompile(Core.kwcall, (NamedTuple{(:lumimask, :object_collections, :execution_diagnostics, :shared_offsets),
                Tuple{LT,Vector{Pair{String,String}},Dict{String,Any},Bool}}, typeof(run_reusable_windowed_selection),
                S, EventIO.NanoAODSource, Config.SampleConfig, O)))
        push!(ok, precompile(Core.kwcall, (NamedTuple{(:extra_bytes,),Tuple{Int128}}, typeof(reserve_windowed_selection),
                EventIO.StreamWindowReader, S, Vector{Pair{String,String}})))
        push!(ok, precompile(Core.kwcall, (NamedTuple{(:stream, :lumimask, :reserved_extra),Tuple{String,LT,X}},
                typeof(run_reusable_windows!), StreamSelectionAnalysis, EventIO.StreamWindowReader, D, S, Int)))
        t.progress === nothing || push!(ok, precompile(Selection._finish_reusable_window_read!,
                (EventIO.StreamWindowReader, D, Dict{String,Any}, typeof(t.progress), WC, Vector{Bool})))
        # Reuse-ON call sites: production keyword order, concrete zero-event pool.
        # Capacity/bounds change values, not P's type. No reader/ROOT/native input is created.
        # Keep the declarations above for the unchanged default-OFF route.
        if isempty(sel.variable_nodes) # reuse is declined by production when variable memo exists
            pool = Selection.WindowBufferReuse(sel, 0, zeros(Int, length(sel.object_names)))
            pool.accounting = Selection.WindowAccounting(32)
            P = typeof(pool); PT = typeof(pool.progress)
            isconcretetype(P) && isempty(pool.progress.passed) &&
                all(isempty(buf.data) && isempty(buf.spans) for buf in pool.progress.objs) ||
                error("reuse workload must remain concrete and zero-event")
            push!(ok, precompile(Core.kwcall, (NamedTuple{(:lumimask, :object_collections,
                    :execution_diagnostics, :shared_offsets, :reuse_buffers, :reuse_accounting),
                    Tuple{LT,Vector{Pair{String,String}},Dict{String,Any},Bool,Bool,Bool}},
                    typeof(run_reusable_windowed_selection), S, EventIO.NanoAODSource, Config.SampleConfig, O)))
            push!(ok, precompile(Core.kwcall, (NamedTuple{(:lumimask, :object_collections,
                    :shared_offsets, :reuse_buffers, :reuse_accounting),
                    Tuple{LT,Vector{Pair{String,String}},Bool,Bool,Bool}},
                    typeof(prepare_reusable_windowed_selection), S, EventIO.NanoAODSource, Config.SampleConfig, O)))
            push!(ok, precompile(Core.kwcall, (NamedTuple{(:stream, :lumimask, :reserved_extra, :buffer_reuse),
                    Tuple{String,LT,X,P}}, typeof(run_reusable_windows!),
                    StreamSelectionAnalysis, EventIO.StreamWindowReader, D, S, Int)))
            push!(ok, precompile(Core.kwcall, (NamedTuple{(:stream, :lumimask, :buffer_reuse),Tuple{String,LT,P}},
                    typeof(analyze_reusable_selection_window!), StreamSelectionAnalysis,
                    EventIO.StreamWindowReader, D, S, Int)))
            push!(ok, precompile(Core.kwcall, (NamedTuple{(:stream, :lumimask, :buffer_reuse),Tuple{String,LT,P}},
                    typeof(Selection.read_reusable_selection_window), EventIO.StreamWindowReader, D, S, Int)))
            for N in (Nothing, Vector{Bool})
                push!(ok, precompile(Core.kwcall, (NamedTuple{(:buffer_reuse,),Tuple{P}},
                    typeof(Selection._finish_reusable_window_read!), EventIO.StreamWindowReader, D,
                    Dict{String,Any}, PT, WC, N)))
            end
        end
    end
    # Reusable branch reads (R16 trace): reached from read_reusable_selection_window by dynamic
    # dispatch on the Any-typed plan branch, so declared per (element type, jagged) with the
    # production keyword shapes (counter / pre / post reads). Type-level only: no data or source.
    isempty(EventIO.decode_dependency_contract().reason) ||
        error("stable selection workload: LazyBranch type derivation requires the audited UnROOT source contract")
    S1 = typeof(selections[first(sort!(collect(keys(selections))))])
    observers = Set{Any}(_kw_default_type(Selection.read_reusable_selection_window, :basket_observer,
        NamedTuple{(:stream, :lumimask),Tuple{String,LT}}, (EventIO.StreamWindowReader, D, S1, Int)) for LT in (Nothing, typeof(lm)))
    length(observers) == 1 || error("stable selection workload: observer default type differs by lumimask type")
    OB = only(observers)
    rdc = reusable_decode_cases(spec)
    shapes(jagged) = jagged ? ((Nothing, Vector{Int}, WC), (Vector{Bool}, Vector{Int}, WC)) :
        ((Nothing, Nothing, Nothing), (Nothing, Nothing, WC), (Vector{Bool}, Nothing, WC))
    for (E, jagged) in rdc.cases
        BR = NamedTuple{(:lazy, :T, :E, :jagged, :maskable, :baskets),
            Tuple{_reusable_lazybranch_type(E, jagged),DataType,DataType,Bool,Bool,Vector{EventIO.StreamBasketDesc}}}
        isconcretetype(BR) || error("stable selection workload: non-concrete plan branch type for $E")
        for (N, Off, W) in shapes(jagged)
            KW = NamedTuple{(:needed, :offsets, :phase, :basket_observer, :window_counters),Tuple{N,Off,String,OB,W}}
            push!(ok, precompile(Core.kwcall, (KW, typeof(EventIO.read_reusable_branch_owned), BR, String,
                UnitRange{Int}, O, Dict{String,Any}, Set{Tuple{String,Int}}, D)))
        end
        # The same concrete destination/branch barrier observed in R26, but with
        # source-derived branch and typed-IR default observer types (no printed closure name).
        BS = NamedTuple{(:scratch, :codec),Tuple{EventIO._NanoAODScratch,Base.RefValue{Any}}}
        for (N, Off) in unique([(N, Off) for (N, Off, _) in shapes(jagged)])
            push!(ok, precompile(EventIO._reusable_basket_loop!, (Vector{E}, BR, String, UnitRange{Int},
                N, Off, String, Dict{String,Any}, Set{Tuple{String,Int}}, D, BS, OB)))
        end
    end
    push!(ok, precompile(EventIO._checked_window_offsets, (Vector{rdc.counter}, Int, Int, String)))
    push!(ok, precompile(EventIO.check_reusable_window_memory!, (D, O, Int)))
    all(ok) || error("stable selection workload declaration failed: $(ok)")
    return (selections = length(selections), contexts = contexts, declarations = length(ok))
end
