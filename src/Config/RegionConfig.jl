"""
    RegionConfig

Analysis region: the events that passed all sequential cuts up to and including
the cut named `after` (`"all"` means no cut), and satisfying the independent
event expression `expr` (default `"true"`). Expressions do not change cutflows.
"""
struct RegionConfig
    name::String
    after::String
    expr::String
end

RegionConfig(name::AbstractString, after::AbstractString) = RegionConfig(String(name), String(after), "true")
