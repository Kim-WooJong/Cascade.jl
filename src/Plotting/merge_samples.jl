"""
    merge_samples(templates, names; name=join(names, "+"), allow_missing=false) -> SampleTemplates

Sum the samples `names` of `templates` (a `Dict{String,SampleTemplates}`). The
nominal histograms add ([`hist_sum`](@ref)); for every variation name present in any member, a member
without that variation contributes its nominal (the variation does not affect
it). Missing sample names are an error unless `allow_missing=true`, in which
case they are skipped (at least one member must exist).
"""
function merge_samples(templates::AbstractDict{<:AbstractString,SampleTemplates}, names;
                       name::AbstractString=join(names, "+"), allow_missing::Bool=false)
    members = SampleTemplates[]
    for n in names
        if haskey(templates, n)
            push!(members, templates[n])
        elseif !allow_missing
            throw(ArgumentError("unknown sample $n"))
        end
    end
    isempty(members) && throw(ArgumentError("no sample of $(collect(names)) is available"))
    variations = sort!(collect(union(String[], (keys(t.variations) for t in members)...)))
    nominal = reduce(hist_sum, (t.nominal for t in members))
    merged = Dict(v => reduce(hist_sum, (get(t.variations, v, t.nominal) for t in members)) for v in variations)
    return SampleTemplates(name, nominal, merged)
end
