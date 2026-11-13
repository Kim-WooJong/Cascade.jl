"""Only audited regular primitive TBranch encodings may enter detached workers."""
function decode_interpretation_supported(branch, T, J)
    branch isa UnROOT.TBranch || return false
    return T <: AbstractVector ? J === UnROOT.Nooffsetjagg : J === UnROOT.Nojagg
end
