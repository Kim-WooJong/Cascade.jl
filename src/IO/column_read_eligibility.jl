"""Fail closed unless the source is an unchanged built-in local mmap reader."""
function column_read_eligibility(src::AbstractEventSource)
    builtin_source_readers() || return "replaced_readers"
    src isa NanoAODSource || return "unsupported_source"
    isfile(src.path) || return "nonlocal_source"
    src.file.fobj isa UnROOT.MmapStream || return "non_mmap_source"
    return ""
end
