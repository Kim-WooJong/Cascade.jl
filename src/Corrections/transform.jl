# Transform node: rewrites one input with the value of `rule`, then evaluates
# `content`. Int inputs receive the rule value rounded half away from zero.
struct TransformNode
    input::Int32
    isint::Bool
    rule::NodeRef
    content::NodeRef
end

function build_transform!(ctx, json)::NodeRef
    input = find_input_index(jstring(json, :input), ctx.inputs)
    var = ctx.inputs[input]
    var.type === :string && throw_correction_error("Transform cannot rewrite string inputs")
    rule = build_node!(ctx, jget(json, :rule))
    content = build_node!(ctx, jget(json, :content))
    push!(ctx.tree.transforms, TransformNode(input, var.type === :int, rule, content))
    return NodeRef(K_TRANSFORM, Int32(length(ctx.tree.transforms)), 0.0)
end

function eval_transform(t, node::TransformNode, v::Vals)::Float64
    vnew = eval_node(t, node.rule, v)
    if node.isint
        r = round(vnew, RoundNearestTiesAway)
        v2 = setint(v, node.input, unsafe_trunc(Int64, r))
    else
        v2 = setreal(v, node.input, vnew)
    end
    return eval_node(t, node.content, v2)
end
