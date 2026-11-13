# Reference to a node of a compiled correction tree. Constant leaves carry their
# value inline; other nodes index into the per-kind vectors of a NodeTree.
const K_NONE = 0x00
const K_CONST = 0x01
const K_BINNING = 0x02
const K_MULTIBINNING = 0x03
const K_CATEGORY = 0x04
const K_FORMULA = 0x05
const K_TRANSFORM = 0x06
const K_HASHPRNG = 0x07

struct NodeRef
    kind::UInt8
    index::Int32
    value::Float64
end

const NO_NODE = NodeRef(K_NONE, Int32(0), 0.0)

const_node(x::Real) = NodeRef(K_CONST, Int32(0), Float64(x))
