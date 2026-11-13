const HOOKS = Dict{Symbol,Tuple{Any,String}}()

"""
    register_hook!(step::Symbol, f; id = string(f))

Install the implementation of a hookable step (`:correct`, `:systematics`,
`:fit`, `:plot`). `id` enters the artifact key, so changing it reruns the
step. Contracts:

- `:correct`: `f(ctx::CorrectionContext) -> Dict{String,Vector{Float64}}` with
  key `"nominal"` and optional `variation_label(name, :up/:down)` keys (full
  per-event weights, one entry per table row).
- `:systematics`: `f(ctx::StepContext, merged::HistogramStore) -> HistogramStore`.
- `:fit`: `f(ctx::StepContext, templates::HistogramStore) -> Dict{String,Any}`
  (JSON-serialisable).
- `:plot`: `f(ctx::StepContext, merged::HistogramStore, fit_result) -> Vector{String}`
  (written files under `joinpath(ctx.workdir, "plot")`).

A hook can also be selected in the analysis TOML, `[hooks] fit = "Module.function"`
(fully qualified, resolved at run time); the TOML entry wins over the registry.
"""
function register_hook!(step::Symbol, f; id::AbstractString = string(f))
    step in (:correct, :systematics, :fit, :plot) || throw(ArgumentError("step $step has no hook"))
    HOOKS[step] = (f, String(id))
    return nothing
end

"""
    hook_for(cfg::AnalysisConfig, step::Symbol) -> (f, id)

Hook implementation for `step`: TOML `[hooks]` entry, else registered hook,
else the built-in default (`default_correct`, ...).
"""
function hook_for(cfg::AnalysisConfig, step::Symbol)
    name = get(get(cfg.raw, "hooks", Dict{String,Any}()), String(step), "")
    isempty(name) || return (_resolve(name), String(name))
    haskey(HOOKS, step) && return HOOKS[step]
    defaults = Dict(:correct => default_correct, :systematics => default_systematics,
                    :fit => default_fit, :plot => default_plot)
    return (defaults[step], "default")
end

function _resolve(name::AbstractString)
    parts = split(name, '.')
    m = parts[1] == "Cascade" ? parentmodule(@__MODULE__) : Main
    obj = parts[1] == "Cascade" ? m : getproperty(m, Symbol(parts[1]))
    for p in parts[2:end]
        obj = getproperty(obj, Symbol(p))
    end
    obj isa Function || throw(ArgumentError("hook '$name' is not a function"))
    return obj
end
