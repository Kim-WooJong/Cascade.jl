"""
    reduce_theory(cfg, store::HistogramStore) -> HistogramStore

Reduce merged, normalized member histograms per sample/region/variable/bin,
not per event or chunk. Envelope includes nominal. PDF bands are centered on
nominal. Internal members are removed from fit templates, retained in merge.
Input arrays are never mutated. Band sumw2 policy is recorded in metadata.
"""
function reduce_theory(cfg, store::HistogramStore)
    ts=theory_weights(cfg)
    if isempty(ts)
        any(k->startswith(k.variation,"__theory_"),keys(store)) &&
            throw(ArgumentError("orphan internal theory members remain without active declarations; rerun correct/histogram/merge"))
        return store
    end
    verify_theory_extraction(cfg,store)
    haskey(store.meta,"theory_weights") && throw(ArgumentError("theory templates are already reduced; use the merged member store"))
    out=deepcopy(store)
    records=Any[]
    for t in ts
        name=t["name"]; recipe=t["reduction"]
        yields=Any[]
        for key in keys(store)
            key.variation==NOMINAL && key.sample in t["samples"] || continue
            nom=store[key]
            all(isfinite,nom.sumw) && all(x->isfinite(x)&&x>=0,nom.sumw2) || throw(ArgumentError("theory '$name': nonfinite nominal histogram"))
            members=BinnedHist[]
            for i in t["indices"]
                k=HistKey(key.region,key.sample,"__theory_$(name)_$i",key.variable)
                haskey(store,k) || throw(ArgumentError("theory '$name': missing merged member $i for $key"))
                h=store[k]
                h.edges==nom.edges || throw(ArgumentError("theory '$name': member edges mismatch"))
                all(isfinite,h.sumw) && all(x->isfinite(x)&&x>=0,h.sumw2) || throw(ArgumentError("theory '$name': nonfinite merged member"))
                push!(members,h)
                delete!(out.hists,k)
            end
            up,down=_theory_band(nom,members,t)
            for (suffix,h) in (("Up",up),("Down",down))
                k=HistKey(key.region,key.sample,name*suffix,key.variable)
                haskey(out,k) && throw(ArgumentError("theory '$name': template collision"))
                out.hists[k]=h
            end
            # Integral of binwise envelope != envelope of total yield. Keep both.
            totals=[BinnedHist([0.0,1.0],[sum(h.sumw)],[sum(h.sumw2)]) for h in members]
            n= BinnedHist([0.0,1.0],[sum(nom.sumw)],[sum(nom.sumw2)])
            yu,yd=_theory_band(n,totals,t)
            push!(yields,Dict("sample"=>key.sample,"region"=>key.region,"variable"=>key.variable,
                "nominal"=>integral(nom),"template_up"=>integral(up),"template_down"=>integral(down),
                "yield_up"=>integral(yu),"yield_down"=>integral(yd)))
        end
        push!(records,Dict("config"=>deepcopy(t),"yields"=>yields,
            "sumw2_policy"=>recipe in ("pair","envelope") ? "selected member per bin (nominal eligible for envelope)" : "nominal MC statistical variance; PDF spread is not MC sumw2"))
    end
    any(k->startswith(k.variation,"__theory_"),keys(out)) && throw(ArgumentError("unconfigured internal theory members remain"))
    out.meta["theory_weights"]=records
    return out
end
