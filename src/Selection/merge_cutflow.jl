"""
    merge_cutflow!(dest::Cutflow, src::Cutflow) -> dest

Add `src` into `dest` (stage names must match).
"""
function merge_cutflow!(dest::Cutflow, src::Cutflow)
    dest.names == src.names || throw(ArgumentError("cutflow stage names differ"))
    dest.n .+= src.n
    dest.sumw .+= src.sumw
    dest.sumw2 .+= src.sumw2
    return dest
end
