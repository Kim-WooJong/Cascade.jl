function _theory_band(nom, members, t)
    up=deepcopy(nom);down=deepcopy(nom)
    r=t["reduction"]
    if r=="pair"
        return deepcopy(members[1]),deepcopy(members[2])
    end
    for b in eachindex(nom.sumw)
        vals=[h.sumw[b] for h in members]
        if r=="envelope"
            hs=vcat([nom],members)
            hi=argmax([h.sumw[b] for h in hs]);lo=argmin([h.sumw[b] for h in hs])
            up.sumw[b]=hs[hi].sumw[b];up.sumw2[b]=hs[hi].sumw2[b]
            down.sumw[b]=hs[lo].sumw[b];down.sumw2[b]=hs[lo].sumw2[b]
        else
            delta=if r=="replica_std"
                mean=sum(vals)/length(vals)
                sqrt(sum((x-mean)^2 for x in vals)/(length(vals)-1))
            elseif r=="hessian_symmetric"
                sqrt(sum((x-nom.sumw[b])^2 for x in vals))
            else
                0.5*sqrt(sum((vals[i]-vals[i+1])^2 for i in 1:2:length(vals)))
            end
            delta*=t["cl_scale"]
            up.sumw[b]=nom.sumw[b]+delta;down.sumw[b]=nom.sumw[b]-delta
        end
    end
    all(isfinite,up.sumw) && all(isfinite,down.sumw) || throw(ArgumentError("theory '$(t["name"])': reduction overflow"))
    return up,down
end
