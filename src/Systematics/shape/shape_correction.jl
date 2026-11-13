const _SHAPE_CSETS = Dict{Tuple{String,String},CorrectionSet}()
const _SHAPE_CSET_LOCK = ReentrantLock()

"""
    shape_correction(path, name, inputs = nothing) -> Union{Correction,CompoundCorrection}

Correction `name` of the correction-set file `path` (cached by absolute path and content SHA256). If `inputs` (vector of input names) is given, the correction must
have exactly these inputs in this order (evaluation passes them positionally).
"""
function shape_correction(path::AbstractString, name::AbstractString, inputs = nothing)
    p = abspath(path)
    key = (p, bytes2hex(open(sha256, p)))
    cs = lock(_SHAPE_CSET_LOCK) do
        get!(() -> load_correctionset(p), _SHAPE_CSETS, key)
    end
    haskey(cs, name) || throw(ArgumentError("correction '$name' not found in $path"))
    c = cs[name]
    if inputs !== nothing
        got = [v.name for v in c.inputs]
        got == inputs || throw(ArgumentError("correction '$name' has inputs $got, expected $(collect(inputs))"))
    end
    return c
end
