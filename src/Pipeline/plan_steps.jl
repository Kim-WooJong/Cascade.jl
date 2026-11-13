"""
    plan_steps(; steps = nothing, from = nothing, only = nothing) -> Vector{Symbol}

Steps to run, in pipeline order: all (default), a comma-separated list
(`steps`), everything from one step on (`from`) or a single step (`only`).
"""
function plan_steps(; steps = nothing, from = nothing, only = nothing)
    count(!isnothing, (steps, from, only)) <= 1 ||
        throw(ArgumentError("--steps, --from and --only are mutually exclusive"))
    check(s) = (sym = Symbol(strip(s)); sym in STEPS ||
                throw(ArgumentError("unknown step '$s' (steps: $(join(STEPS, ", ")))")); sym)
    only !== nothing && return [check(only)]
    if from !== nothing
        f = check(from)
        return STEPS[findfirst(==(f), STEPS):end]
    end
    steps === nothing && return copy(STEPS)
    want = Set(check(s) for s in split(steps, ','; keepempty = false))
    return [s for s in STEPS if s in want]
end
