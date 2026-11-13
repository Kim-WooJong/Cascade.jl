"""Return original-file normalization ownership, not physical event deduplication."""
function source_population(src::AbstractEventSource)
    p = src.path
    st = stat(p)
    return Dict{String,Any}("realpath" => realpath(p), "device" => string(st.device), "inode" => string(st.inode))
end
