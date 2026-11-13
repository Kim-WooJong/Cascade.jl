"""
    region_stages(cfg::AnalysisConfig, kind::Symbol) -> Dict{String,Int}

Number of sequential cuts applicable to sample kind `kind` that an event must
pass to be in each region (a region defined after a cut of the other kind uses
the last applicable cut before it).
"""
function region_stages(cfg::AnalysisConfig, kind::Symbol)
    applies(c) = c.only === :all || c.only === kind
    out = Dict{String,Int}()
    for r in cfg.regions
        out[r.name] = r.after == "all" ? 0 :
                      count(applies, cfg.cuts[1:findfirst(c -> c.name == r.after, cfg.cuts)])
    end
    return out
end
