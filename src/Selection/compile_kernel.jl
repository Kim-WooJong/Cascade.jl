"""
    compile_kernel(args::Vector{Symbol}, body) -> Function

Evaluate `(args...) -> body` in the `Kernels` namespace. The returned function
is newer than the calling code: call it through `Base.invokelatest` (or from a
function entered with it).
"""
compile_kernel(args::Vector{Symbol}, body) = Core.eval(Kernels, Expr(:->, Expr(:tuple, args...), body))
