"""
    propagate_met(met_pt, met_phi, phi, pt_from, pt_to, pt_ref, min_pt, needed) -> (pt, phi)

Propagate a change of object transverse momenta to the missing transverse
momentum: `MET -= sum((pt_to - pt_from) * (cos(phi), sin(phi)))` over the
objects with `pt_ref > min_pt` (Float64 arithmetic, results converted to the
MET column type). Events where no selected object changes, or with
`needed[i] == false`, keep their MET bit-for-bit.
"""
function propagate_met(met_pt::AbstractVector{T}, met_phi::AbstractVector{S}, phi::Jagged, pt_from::Jagged,
                       pt_to::Jagged, pt_ref::Jagged, min_pt::Real, needed) where {T,S}
    outpt = copy(met_pt); outphi = copy(met_phi)
    o = phi.offsets
    for i in 1:length(o)-1
        (needed === nothing || needed[i]) || continue
        mx = Float64(met_pt[i]) * cos(Float64(met_phi[i]))
        my = Float64(met_pt[i]) * sin(Float64(met_phi[i]))
        changed = false
        for j in o[i]+1:o[i+1]
            Float64(pt_ref.content[j]) > min_pt || continue
            d = Float64(pt_to.content[j]) - Float64(pt_from.content[j])
            d == 0 && continue
            changed = true
            mx -= d * cos(Float64(phi.content[j]))
            my -= d * sin(Float64(phi.content[j]))
        end
        changed || continue
        outpt[i] = T(hypot(mx, my))
        outphi[i] = S(atan(my, mx))
    end
    return outpt, outphi
end
