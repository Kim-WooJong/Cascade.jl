"""
    jer_factors(k::JERShape, collection, cols, needed; nominal = k.nominal) -> (nominal, up, down)

Per-object JER smearing factors with scale factor systematic `nom`, `up` and
`down` (`max(JERSmear(...), 0)`), for events with `needed[i]` (others: 1.0).
With `nominal = false` the `nom` factors are not evaluated (all 1.0).
The stochastic part is seeded by `(JetPt, JetEta, Rho, EventID)` through the
correctionlib HashPRNG, so a jet gets the same random number in every
direction, chunking and thread schedule (reproducible per event).
"""
function jer_factors(k::JERShape, collection::AbstractString, cols::AbstractDict, needed; nominal::Bool = k.nominal)
    pt = cols[collection * "_pt"]; eta = cols[collection * "_eta"]; phi = cols[collection * "_phi"]
    gidx = cols[string(collection, "_", k.genjet_index)]
    gpt = cols[k.genjet * "_pt"]; geta = cols[k.genjet * "_eta"]; gphi = cols[k.genjet * "_phi"]
    m = length(pt.content)
    nom = ones(m); up = ones(m); down = ones(m)
    _jer_loop!(nom, up, down, k, pt.content, eta.content, phi.content, gidx.content, pt.offsets,
               gpt.content, geta.content, gphi.content, gpt.offsets, cols[k.rho], cols[k.event], needed, nominal)
    return nom, up, down
end

function _jer_loop!(nom, up, down, k, pt, eta, phi, gidx, offsets, gpt, geta, gphi, goffs, rho, event, needed,
                    nominal)
    for i in 1:length(offsets)-1
        (needed === nothing || needed[i]) || continue
        r = Float64(rho[i])
        id = Int64(event[i])
        for j in offsets[i]+1:offsets[i+1]
            p = Float64(pt[j]); e = Float64(eta[j])
            res = evaluate(k.resolution, e, p, r)
            g = matched_genjet_pt(gidx[j], gpt, geta, gphi, goffs, i, eta[j], phi[j], p, res,
                                  k.match_dr, k.match_nsigma)
            nominal && (nom[j] = _smear(k, p, e, g, r, id, res, "nom"))
            up[j] = _smear(k, p, e, g, r, id, res, "up")
            down[j] = _smear(k, p, e, g, r, id, res, "down")
        end
    end
    return nothing
end

@inline function _smear(k::JERShape, p, e, g, r, id, res, sys)
    sf = k.sf_has_pt ? evaluate(k.scale_factor, e, p, sys) : evaluate(k.scale_factor, e, sys)
    return max(evaluate(k.smear, p, e, g, r, id, res, sf), 0.0)
end
