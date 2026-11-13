"Validate optional declared sample provenance and audit contracts."
function validate_sample_annotations(s::SampleConfig)
    errors = String[]
    for section in ("metadata", "audit")
        haskey(s.raw, section) || continue
        d = s.raw[section]
        if !(d isa AbstractDict)
            push!(errors, "sample $(s.name): $section must be a table")
            continue
        end
        for (key, value) in d
            label = "sample $(s.name): $section.$key"
            if section == "metadata" || key == "inventory_source"
                value isa AbstractString && !isempty(strip(value)) || push!(errors, "$label must be a nonempty string")
            elseif key in ("expected_nfiles", "expected_nevents")
                value isa Integer && !(value isa Bool) && value >= 0 || push!(errors, "$label must be a nonnegative integer")
            elseif key in ("expected_sumw", "sumw_rtol", "sumw_atol")
                good = value isa Real && !(value isa Bool) && isfinite(value) && isfinite(Float64(value))
                key == "expected_sumw" || (good &= value isa Real && value >= 0)
                good || push!(errors, "$label must be a finite $(key == "expected_sumw" ? "number" : "nonnegative number")")
            elseif key == "expected_files"
                value isa AbstractVector && all(x -> x isa AbstractString && !isempty(strip(x)), value) ||
                    push!(errors, "$label must be an array of nonempty literal paths")
                if value isa AbstractVector
                    any(x -> x isa AbstractString && occursin(r"[*?\[]", x), value) && push!(errors, "$label must not contain globs")
                end
            end
        end
    end
    return errors
end
