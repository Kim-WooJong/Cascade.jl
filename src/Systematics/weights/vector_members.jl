"""
    vector_members(reader::BranchReader, spec) -> Vector{Vector{Float64}}

Read declared 1-based vector members in selected-entry order. Returns relative
factors, never changes the signed base weight. Missing/malformed values fail
with source, branch and original entry diagnostics; zero denominators fail.
"""
function vector_members(r::BranchReader, t::AbstractDict)
    isempty(r.entries) && return [Float64[] for _ in t["indices"]]
    r.source === nothing && (r.source = open_source(r.format,r.path;options=r.options))
    branch=t["branch"]
    label="theory '$(t["name"])' branch '$branch' in $(r.path)"
    branch in column_names(r.source) || throw(ArgumentError("$label: missing branch"))
    n=nevents(r.source)
    all(e->1<=e<=n,r.entries) || throw(ArgumentError("$label: entry out of range 1:$n"))
    needed=falses(n); needed[r.entries].=true
    col=get!(r.vectors,branch) do
        c=read_columns(r.source,[branch];needed)[branch]
        c isa Jagged || throw(ArgumentError("$label: expected a vector branch (Jagged)"))
        c
    end
    ref=t["normalization"]=="absolute" ? r(t["reference_branch"]) : nothing
    out=[Vector{Float64}(undef,length(r.entries)) for _ in t["indices"]]
    for (row,e) in enumerate(r.entries)
        v=col[e]
        fail(msg)=throw(ArgumentError("$label entry $e: $msg"))
        length(v)==t["expected_length"] || fail("length $(length(v)), expected $(t["expected_length"])")
        den=t["normalization"]=="central" ? v[t["central_index"]] : ref===nothing ? 1.0 : ref[row]
        den isa Real && !(den isa Bool) && isfinite(den) && den!=0 || fail("nonfinite or zero normalization denominator")
        for (j,k) in enumerate(t["indices"])
            x=v[k]
            x isa Real && !(x isa Bool) && isfinite(x) || fail("member $k is not finite real")
            f=Float64(x)/Float64(den)
            isfinite(f) || fail("member $k ratio is nonfinite")
            out[j][row]=f
        end
    end
    return out
end
