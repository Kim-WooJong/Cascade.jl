# Category node: lookup by int or string key with optional default.
struct CategoryNode
    input::Int32
    isstring::Bool
    strmap::StringLookup
    intmap::Dict{Int64,Int32}
    dense::Vector{Int32}      # dense lookup table for compact int keys (0 = absent)
    dense_offset::Int64
    content::Vector{NodeRef}
    default::NodeRef          # NO_NODE when there is no default
end

function build_category!(ctx, json)::NodeRef
    input = find_input_index(jstring(json, :input), ctx.inputs)
    var = ctx.inputs[input]
    isstring = var.type === :string
    strmap = Dict{String,Int32}()
    intmap = Dict{Int64,Int32}()
    refs = NodeRef[]
    for item in jarray(json, :content)
        (isjsonobject(item) && haskey(item, "key") && haskey(item, "value")) ||
            throw_correction_error("Expected CategoryItem object")
        key = item["key"]
        if key isa AbstractString
            var.type === :string ||
                throw_correction_error("Category got a key of type string, but its input is type $(var.type)")
            haskey(strmap, key) && continue   # first occurrence wins (std::map::try_emplace)
            push!(refs, build_node!(ctx, item["value"]))
            strmap[String(key)] = Int32(length(refs))
        elseif key isa Integer && !(key isa Bool) && typemin(Int32) <= key <= typemax(Int32)
            var.type === :int ||
                throw_correction_error("Category got a key of type int, but its input is type $(var.type)")
            haskey(intmap, key) && continue
            push!(refs, build_node!(ctx, item["value"]))
            intmap[Int64(key)] = Int32(length(refs))
        else
            throw_correction_error("Invalid key type in Category")
        end
    end
    def = joptional(json, :default)
    default = def === nothing ? NO_NODE : build_node!(ctx, def)
    dense = Int32[]
    offset = Int64(0)
    if !isempty(intmap)
        lo, hi = extrema(keys(intmap))
        if hi - lo < 4 * length(intmap) + 64
            offset = lo
            dense = zeros(Int32, hi - lo + 1)
            for (k, j) in intmap
                dense[k-lo+1] = j
            end
        end
    end
    push!(ctx.tree.categories, CategoryNode(input, isstring, StringLookup(strmap), intmap, dense, offset, refs, default))
    return NodeRef(K_CATEGORY, Int32(length(ctx.tree.categories)), 0.0)
end

@inline function category_int_lookup(node::CategoryNode, key::Int64)::Int32
    dense = node.dense
    if !isempty(dense)
        j = key - node.dense_offset
        return (0 <= j < length(dense)) ? @inbounds(dense[j+1]) : Int32(0)
    end
    return get(node.intmap, key, Int32(0))
end

@noinline function throw_category_error(input::Int32, val)
    throw(CorrectionError("Index not available in Category for input argument $(input - 1) val: $val"))
end

function eval_category(t, node::CategoryNode, v::Vals, intypes::Vector{UInt8})::Float64
    i = node.input
    ty = @inbounds intypes[i]
    if ty == VT_STRING
        s = v.s[i]
        j = node.isstring ? lookup(node.strmap, s) : Int32(0)
        if j == 0
            node.default.kind == K_NONE && throw_category_error(i, s)
            return eval_node(t, node.default, v)
        end
    elseif ty == VT_INT
        key = v.k[i]
        j = node.isstring ? Int32(0) : category_int_lookup(node, key)
        if j == 0
            node.default.kind == K_NONE && throw_category_error(i, key)
            return eval_node(t, node.default, v)
        end
    else
        throw(CorrectionError("Invalid variable type"))
    end
    return eval_node(t, @inbounds(node.content[j]), v)
end
