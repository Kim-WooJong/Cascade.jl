"""
    apply_corrections(ctx) -> Dict{String,Vector{Float64}}

`:correct` step hook (select it with `[hooks] correct =
"Cascade.Systematics.apply_corrections"`). `ctx` is the
`Pipeline.CorrectionContext` of one chunk (fields `config`, `sample`,
`source_path`, `table`); returns `correction_weights` of that chunk. Without
a `[corrections]` section the result equals the default hook.
"""
apply_corrections(ctx) = correction_weights(ctx.config, ctx.sample, ctx.source_path, ctx.table; source = hasproperty(ctx, :source) ? ctx.source : nothing)
