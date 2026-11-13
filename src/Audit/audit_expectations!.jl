"Compare explicit inventory/count/signed-sum contracts, retaining unknown checks."
function audit_expectations!(result, s::SampleConfig, cfg::AnalysisConfig, findings)
    contract = get(s.raw, "audit", Dict{String,Any}())
    checks = result["checks"]
    result["inventory_source"] = get(contract, "inventory_source", nothing)
    function compare(code, observed, expected; ready = true, equal = isequal)
        status = !ready ? "unknown" : equal(observed, expected) ? "pass" : "fail"
        push!(checks, Dict("name" => code, "status" => status, "observed" => observed, "expected" => expected))
        status == "fail" && audit_finding!(findings, "error", code * "_mismatch", "declared expectation does not match observed input";
            sample = s.name, observed, expected)
    end
    for (key, field, ready) in (("expected_nfiles", "discovered_nfiles", true),
                                 ("expected_nevents", "nevents", result["source_metadata_complete"]))
        haskey(contract, key) && compare(key, result[field], contract[key]; ready)
    end
    if haskey(contract, "expected_sumw")
        if is_data(s)
            push!(checks, Dict("name" => "expected_sumw", "status" => "not_applicable", "observed" => nothing, "expected" => contract["expected_sumw"]))
        else
            atol = Float64(get(contract, "sumw_atol", 0.0)); rtol = Float64(get(contract, "sumw_rtol", 1e-8))
            equal(a,b) = abs(a-b) <= atol + rtol * abs(b)
            compare("expected_sumw", result["gen_weight_sum"], contract["expected_sumw"];
                ready = result["gen_weight_sum"] !== nothing, equal)
        end
    end
    if haskey(contract, "expected_files")
        paths = get(cfg.raw, "paths", Dict())
        resolve(p) = (q = substitute_paths(p, paths); abspath(isabspath(q) ? q : joinpath(cfg.dir, q)))
        expected = String[]
        invalid = false
        for path in contract["expected_files"]
            try
                push!(expected, resolve(path))
            catch e
                invalid = true
                audit_finding!(findings, "error", "invalid_expected_path", sprint(showerror, e); sample = s.name, path)
            end
        end
        sort!(expected)
        actual = sort!(abspath.([f["path"] for f in result["files"]]))
        length(unique(expected)) == length(expected) || audit_finding!(findings, "error", "duplicate_expected_file", "expected_files contains repeated canonical paths"; sample = s.name)
        missing = sort!(collect(setdiff(Set(expected), Set(actual))))
        extra = sort!(collect(setdiff(Set(actual), Set(expected))))
        compare("expected_files", actual, expected; ready = !invalid, equal = (a,b) -> Set(a) == Set(b))
        result["missing_expected_files"] = missing
        result["unexpected_files"] = extra
        result["inventory_completeness"] = invalid ? "invalid_contract" : isempty(missing) && isempty(extra) ? "matched_declared_paths" : "mismatch"
        haskey(contract, "inventory_source") || audit_finding!(findings, "unknown", "inventory_source_unspecified", "expected paths are user-declared; no authoritative inventory source provided"; sample = s.name)
    else
        audit_finding!(findings, "unknown", "inventory_completeness_unknown", "no explicit expected file list; count agreement alone cannot prove file identity or completeness"; sample = s.name)
    end
    return result
end
