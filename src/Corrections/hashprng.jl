# HashPRNG node: deterministic pseudo-random number from the input values.
# Seed = XXH64 of the raw 64-bit words of the inputs (int64 value or double
# bit pattern), generator = pcg32_oneseq, as in correctionlib.
const DIST_STDFLAT = 0x01
const DIST_STDNORMAL = 0x02
const DIST_NORMAL = 0x03

struct HashPRNGNode
    inputs::Vector{Int32}
    isint::Vector{Bool}
    dist::UInt8
end

function build_hashprng!(ctx, json)::NodeRef
    idx = Int32[]
    isint = Bool[]
    for item in jarray(json, :inputs)
        item isa AbstractString || throw_correction_error("invalid hashprng input type")
        i = find_input_index(item, ctx.inputs)
        ctx.inputs[i].type === :string && throw_correction_error("HashPRNG cannot use string inputs as entropy sources")
        push!(idx, i)
        push!(isint, ctx.inputs[i].type === :int)
    end
    d = jstring(json, :distribution)
    dist = d == "stdflat" ? DIST_STDFLAT : d == "stdnormal" ? DIST_STDNORMAL : d == "normal" ? DIST_NORMAL :
           throw_correction_error("invalid distribution type for hashprng")
    push!(ctx.tree.hashprngs, HashPRNGNode(idx, isint, dist))
    return NodeRef(K_HASHPRNG, Int32(length(ctx.tree.hashprngs)), 0.0)
end

function eval_hashprng(node::HashPRNGNode, v::Vals)::Float64
    inputs = node.inputs
    isint = node.isint
    word = j -> begin
        i = @inbounds inputs[j]
        @inbounds isint[j] ? reinterpret(UInt64, v.k[i]) : reinterpret(UInt64, v.x[i])
    end
    state = pcg32_seed(xxh64_words(word, length(inputs)))
    node.dist == DIST_STDFLAT && return pcg32_stdflat(state)
    node.dist == DIST_STDNORMAL && return pcg32_stdnormal(state)
    return pcg32_normal(state)
end
