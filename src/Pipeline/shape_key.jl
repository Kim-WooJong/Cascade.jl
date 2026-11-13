"""
    shape_key(configs::AbstractVector{ShapeVariationConfig}) -> String

Hash of the shape variations applied to a sample: their configuration and the
SHA-256 of every correction file they read (external inputs).
"""
function shape_key(configs::AbstractVector{ShapeVariationConfig})
    parts = Any[]
    for c in configs
        files = Dict{String,String}()
        for (k, v) in c.params
            v isa AbstractString && isfile(v) && (files[k] = bytes2hex(open(sha256, v)))
        end
        push!(parts, Dict{String,Any}("name" => c.name, "collection" => c.collection, "kind" => String(c.kind),
                                      "fields" => c.fields, "samples" => c.samples, "met" => c.met,
                                      "met_min_pt" => c.met_min_pt, "params" => c.params, "files" => files))
    end
    return canonical_hash(parts)
end
