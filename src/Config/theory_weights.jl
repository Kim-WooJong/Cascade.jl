"""
    theory_weights(cfg::AnalysisConfig) -> Vector{Dict{String,Any}}

Validate explicit vector-member conventions in [[theory_weights]]. No branch
layout, PDF set, shower mapping or confidence-level conversion is inferred.
"""
function theory_weights(cfg::AnalysisConfig)
    out = Dict{String,Any}[]
    isempty(get(cfg.raw,"theory_weights",Any[])) && return out
    reserved = Set(v.name for v in cfg.variations)
    union!(reserved, (v.name for v in shape_variations(cfg)))
    for k in ("object_sf", "event_weight", "flat", "trigger_or"), t in get(get(cfg.raw,"corrections",Dict()),k,Any[])
        push!(reserved, String(t["name"]))
    end
    seen = Set{String}()
    declared = get(cfg.raw,"theory_weights",Any[])
    fit=get(cfg.raw,"fit",Dict())
    union!(reserved,(String(t["name"]) for t in get(fit,"normsys",Any[])))
    push!(reserved,String(get(fit,"poi","mu")))
    for (i,t) in enumerate(declared)
        label = "theory_weights[$i]"
        fail(msg) = throw(ArgumentError("$label: $msg"))
        t isa AbstractDict || fail("must be a table")
        d = Dict{String,Any}(t)
        for k in ("name", "branch", "family", "normalization", "reduction", "convention")
            get(d,k,nothing) isa AbstractString && !isempty(d[k]) || fail("$k must be a non-empty string")
        end
        name = d["name"]
        isempty(strip(d["convention"])) && fail("convention must declare a reference, not whitespace")
        occursin(r"^[A-Za-z][A-Za-z0-9_]*$",name) && name != "nominal" || fail("invalid name")
        name in union(reserved,seen) && fail("name '$name' collides with another variation")
        push!(seen,name)
        d["family"] in ("scale","pdf","ps","generic") || fail("unknown family")
        d["normalization"] in ("relative","central","absolute") || fail("normalization must be relative, central or absolute")
        idx = get(d,"indices",nothing)
        idx isa AbstractVector && !isempty(idx) && all(x->x isa Integer && !(x isa Bool) && x>0,idx) || fail("indices must be explicit positive 1-based integers")
        length(unique(idx)) == length(idx) || fail("duplicate indices")
        d["indices"] = Int.(idx)
        d["normalization"] == "central" && get(d,"central_index",0) in idx && d["reduction"] in ("replica_std","hessian_symmetric","hessian_pairs") && fail("central member must be excluded from PDF uncertainty indices")
        len = get(d,"expected_length",nothing)
        len isa Integer && !(len isa Bool) && len >= maximum(idx) || fail("expected_length must cover every index")
        samples = get(d,"samples",nothing)
        samples isa AbstractVector && !isempty(samples) && all(x->x isa AbstractString,samples) || fail("samples must explicitly list MC names")
        for s in samples
            any(x->x.name==s && is_mc(x),cfg.samples) || fail("unknown or non-MC sample '$s'")
        end
        if d["normalization"] == "central"
            c = get(d,"central_index",nothing)
            c isa Integer && !(c isa Bool) && 1<=c<=len || fail("central_index must be 1-based and within expected_length")
        elseif haskey(d,"central_index")
            fail("central_index requires normalization = central")
        end
        if d["normalization"] == "absolute"
            get(d,"reference_branch",nothing) isa AbstractString && !isempty(d["reference_branch"]) || fail("absolute requires reference_branch (signed nominal generator weight)")
        elseif haskey(d,"reference_branch")
            fail("reference_branch requires normalization = absolute")
        end
        r=d["reduction"]
        r in ("pair","envelope","replica_std","hessian_symmetric","hessian_pairs") || fail("unsupported reduction")
        r != "pair" && length(unique(samples)) > 1 && fail("nonlinear reduction requires exactly one distinct sample; cross-sample correlated reduction is unsupported; use distinct nuisance declarations only for deliberately independent samples")
        r == "pair" && length(idx)!=2 && fail("pair needs indices ordered [Up, Down]")
        r == "replica_std" && length(idx)<2 && fail("replica_std needs at least two replicas")
        r == "hessian_pairs" && isodd(length(idx)) && fail("hessian_pairs needs consecutive plus/minus index pairs")
        if r in ("replica_std","hessian_symmetric","hessian_pairs")
            d["family"] == "pdf" || fail("PDF reduction requires family = pdf")
            get(d,"pdf_template_model",nothing) == "rank_one" || fail("PDF band reduction requires explicit pdf_template_model = rank_one acknowledgment; replica/eigenvector covariance is not preserved")
            cl=get(d,"cl_scale",nothing)
            cl isa Real && !(cl isa Bool) && isfinite(cl) && cl>0 || fail("declare positive cl_scale (input to target CL multiplier)")
        elseif haskey(d,"cl_scale") || haskey(d,"pdf_template_model")
            fail("cl_scale and pdf_template_model only apply to PDF band reductions")
        end
        push!(out,d)
    end
    return out
end
