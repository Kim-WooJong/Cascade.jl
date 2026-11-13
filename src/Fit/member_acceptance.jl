"""
    member_acceptance(selected_sumw, preselection_sumw; decay_fraction=1)

Compute decay_fraction * selected_sumw[i] / preselection_sumw[i] for each
signed generator-weight member. Denominators must represent ALL original input
events, once per original source; never selected skim sums. Ratios from Runs
must first be converted per file as sumw_nominal[file] * Runs_ratio[file,i]
and then summed, not averaged. Apply inclusive cross section and luminosity
later, once; do not apply decay_fraction again to already scaled yields.
"""
function member_acceptance(selected_sumw::AbstractVector, preselection_sumw::AbstractVector; decay_fraction=1)
    length(selected_sumw) == length(preselection_sumw) && !isempty(selected_sumw) || throw(ArgumentError("member lengths differ or are empty"))
    decay_fraction isa Real && !(decay_fraction isa Bool) && isfinite(decay_fraction) && 0 < decay_fraction <= 1 || throw(ArgumentError("invalid decay fraction"))
    all(isfinite, selected_sumw) && all(x -> isfinite(x) && x != 0, preselection_sumw) || throw(ArgumentError("nonfinite member or zero signed denominator"))
    return [decay_fraction * selected_sumw[i] / preselection_sumw[i] for i in eachindex(selected_sumw, preselection_sumw)]
end
