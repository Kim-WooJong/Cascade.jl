# MultiBinning node: N axes, row-major content (last axis fastest). With a value
# flow the default is appended after the content.
struct MultiBinningNode
    inputs::Vector{Int32}
    axes::Vector{BinAxis}
    strides::Vector{Int}
    flow::UInt8
    content::Vector{NodeRef}
end

function build_multibinning!(ctx, json)::NodeRef
    inputs = jarray(json, :inputs)
    edges = jarray(json, :edges)
    axes = BinAxis[]
    idx = Int32[]
    for (d, dim) in enumerate(edges)
        d <= length(inputs) || throw_correction_error("Inconsistency in MultiBinning: fewer inputs than edge dimensions")
        ax = bin_axis(dim, "MultiBinning", d - 1)
        name = inputs[d]
        name isa AbstractString || throw_correction_error("invalid multibinning input type")
        vi = find_input_index(name, ctx.inputs)
        ctx.inputs[vi].type === :string && throw_correction_error("MultiBinning cannot use string inputs as binning variables")
        push!(axes, ax)
        push!(idx, vi)
    end
    strides = zeros(Int, length(axes))
    stride = 1
    for d in length(axes):-1:1
        strides[d] = stride
        stride *= nbins(axes[d])
    end
    content = jarray(json, :content)
    refs = NodeRef[build_node!(ctx, c) for c in content]
    length(refs) == stride ||
        throw_correction_error("Inconsistency in MultiBinning: number of content nodes does not match binning")
    flowjson = jget(json, :flow)
    flow = parse_flow(flowjson)
    flow == FLOW_VALUE && push!(refs, build_node!(ctx, flowjson))
    push!(ctx.tree.multibinnings, MultiBinningNode(idx, axes, strides, flow, refs))
    return NodeRef(K_MULTIBINNING, Int32(length(ctx.tree.multibinnings)), 0.0)
end

function eval_multibinning(t, node::MultiBinningNode, v::Vals)::Float64
    idx = 0
    content = node.content
    @inbounds for d in eachindex(node.axes)
        ax = node.axes[d]
        vi = node.inputs[d]
        local_idx = find_bin(ax, v.x[vi], node.flow, Int(vi) - 1, "MultiBinning")
        # nbins signals the default value (C++ returns content_.back())
        local_idx == nbins(ax) && return eval_node(t, content[end], v)
        idx += local_idx * node.strides[d]
    end
    (0 <= idx < length(content)) || throw(CorrectionError("MultiBinning content index out of range"))
    return eval_node(t, @inbounds(content[idx+1]), v)
end
