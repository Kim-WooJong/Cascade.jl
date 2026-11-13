"""
    KernelContext(cols, offs, objs)

Data seen by compiled kernels for one chunk: `cols` (NamedTuple of column
vectors; jagged columns as flat content), `offs` (NamedTuple collection ->
offsets) and `objs` (NamedTuple object name -> selected flat indices of the
current event).
"""
struct KernelContext{C,F,O,V}
    cols::C
    offs::F
    objs::O
    memo::V
end
KernelContext(cols, offs, objs) = KernelContext(cols, offs, objs, nothing)
