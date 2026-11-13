# Binning node: one axis; content has nbins + 1 entries, the last one being the
# flow default (or a constant 0 when flow is not a value).
struct BinningNode
    input::Int32
    axis::BinAxis
    flow::UInt8
    content::Vector{NodeRef}
end

function build_binning!(ctx, json)::NodeRef
    content = jarray(json, :content)
    axis = bin_axis(jget(json, :edges), "Binning", 0)
    if nbins(axis) != length(content)
        throw_correction_error("Inconsistency in Binning: number of content nodes does not match binning")
    end
    input = find_input_index(jstring(json, :input), ctx.inputs)
    ctx.inputs[input].type === :string && throw_correction_error("Binning cannot use string inputs as binning variables")
    flowjson = jget(json, :flow)
    flow = parse_flow(flowjson)
    default = flow == FLOW_VALUE ? build_node!(ctx, flowjson) : const_node(0.0)
    refs = NodeRef[build_node!(ctx, c) for c in content]
    push!(refs, default)
    push!(ctx.tree.binnings, BinningNode(input, axis, flow, refs))
    return NodeRef(K_BINNING, Int32(length(ctx.tree.binnings)), 0.0)
end

function eval_binning(t, node::BinningNode, v::Vals)::Float64
    i = node.input
    idx = find_bin(node.axis, v.x[i], node.flow, Int(i) - 1, "Binning")
    return eval_node(t, @inbounds(node.content[idx+1]), v)
end
