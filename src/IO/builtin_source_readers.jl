"""
    builtin_source_readers() -> Bool

Whether registered built-in reader identities still match their source-pinned
constructors. Fresh-process execution rejects replaced registry implementations.
"""
function builtin_source_readers()
    return get(SOURCE_FORMATS, "nanoaod", nothing) === NanoAODSource &&
        get(SOURCE_FORMATS, "cols", nothing) === ColumnFileSource &&
        get(SOURCE_FORMATS, "reduced_rntuple", nothing) === ReducedRNTupleSource &&
        get(SOURCE_FORMATS, "reduced_rntuple_group", nothing) === ReducedGroupSource &&
        get(SOURCE_FORMATS, "reduced_rntuple_shard", nothing) === ReducedShardSource
end
