"""
    theory_extraction(cfg; samples = cfg.samples) -> Dict

Versioned extraction manifest keyed by applicable sample. Capture this when
members are actually extracted, never retrospectively on old member values.
Reduction-only settings are excluded so compatible raw members can be reused.
"""
function theory_extraction(cfg::AnalysisConfig; samples = cfg.samples)
    manifest=Dict{String,Any}()
    ts=theory_weights(cfg)
    for s in samples
        terms=Any[]
        for t in ts
            s.name in t["samples"] || continue
            term=Dict{String,Any}(k=>deepcopy(t[k]) for k in
                ("name","branch","expected_length","normalization"))
            term["indices"]=sort(unique(t["indices"]))
            term["samples"]=sort(unique(t["samples"]))
            for k in ("central_index","reference_branch")
                haskey(t,k) && (term[k]=deepcopy(t[k]))
            end
            push!(terms,term)
        end
        isempty(terms) && continue
        sort!(terms;by=t->t["name"])
        contract=Dict{String,Any}("version"=>1,"sample"=>s.name,"kind"=>String(s.kind),
            "format"=>s.format,"source"=>deepcopy(get(s.raw,"source",Dict())),"terms"=>terms)
        manifest[s.name]=Dict("contract"=>contract,"hash"=>canonical_hash(contract))
    end
    return manifest
end
