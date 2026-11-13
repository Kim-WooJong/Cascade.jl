"""
    trigger_match(eta, phi, id, filter_bits, max_dr, trigger_eta, trigger_phi, trigger_id, trigger_bits)

Whether an event-local trigger object matches one reconstructed object.
Requires absolute particle ID, every bit in `filter_bits`, and `deltaR < max_dr`
(wrapped phi). This geometric helper does not establish a fired HLT path or
resolve multi-leg assignments. Selection syntax accepts the first five args;
the compiler supplies the four event-local `TrigObj` vectors.
"""
function trigger_match(eta::Real, phi::Real, id::Integer, filter_bits::Integer, max_dr::Real,
                       trigger_eta::AbstractVector, trigger_phi::AbstractVector,
                       trigger_id::AbstractVector, trigger_bits::AbstractVector)
    isfinite(max_dr) && max_dr > 0 || throw(ArgumentError("trigger_match: max_dr must be finite and positive"))
    id != 0 && filter_bits >= 0 || throw(ArgumentError("trigger_match: nonzero id and nonnegative filter_bits required"))
    n = length(trigger_eta)
    all(v -> length(v) == n, (trigger_phi, trigger_id, trigger_bits)) ||
        throw(ArgumentError("trigger_match: trigger-object column lengths differ"))
    isfinite(eta) && isfinite(phi) || return false
    for k in 1:n
        abs(trigger_id[k]) == abs(id) || continue
        (trigger_bits[k] & filter_bits) == filter_bits || continue
        isfinite(trigger_eta[k]) && isfinite(trigger_phi[k]) || continue
        dphi = rem2pi(Float64(phi) - Float64(trigger_phi[k]), RoundNearest)
        hypot(Float64(eta) - Float64(trigger_eta[k]), dphi) < max_dr && return true
    end
    return false
end
