"""
    fit_report(store::HistogramStore, fc::FitConfig) -> Dict{String,Any}

Run the configured fit on the histograms of `store` and collect everything as
a JSON-ready dictionary (non-finite numbers are `nothing`):

- `status`, `converged`, `nll`, `edm`, `iterations`, `dataset`
  (`"observed"` or `"asimov"`);
- `poi`, `poi_value`, `poi_error` (Hesse), `poi_interval` (profile
  likelihood, when `fc.profile_interval`);
- `parameters`: per parameter `name, group, kind, value, error, init,
  prefit_sigma, floating, pull, constraint` (model order) and `covariance`
  (rows in the same order);
- `impacts` (sorted by the larger postfit POI shift), `upper_limit`,
  `significance` (when requested);
- `channels`: per channel name, region, variable, edges, members, histosys,
  data and the `prefit`/`postfit` sample yields with errors
  ([`group_yields`](@ref)); `counting`: [`counting_estimate`](@ref) per channel;
- `normsys` (incl. `placeholder` flags), `notes`, `options` (interpolation
  codes) and the pyhf `workspace` that was fitted.

Rebuild the model and result with [`report_model`](@ref) and
[`report_result`](@ref).
"""
function fit_report(store::HistogramStore, fc::FitConfig)
    built = build_workspace(store, fc)
    model = HistModel(built.workspace; normsys_code = fc.normsys_code, histosys_code = fc.histosys_code)
    data = fc.asimov ? asimov_data(model, [p.init for p in model.parameters]) : observed_data(model)
    r = fit(model, data)
    ip = model.poi
    out = Dict{String,Any}("status" => r.converged ? "ok" : "not_converged", "converged" => r.converged,
                           "nll" => r.nll, "edm" => r.edm, "iterations" => r.iterations,
                           "dataset" => fc.asimov ? "asimov" : "observed", "poi" => fc.poi,
                           "poi_value" => r.parameters[ip], "poi_error" => r.uncertainties[ip])
    fc.profile_interval && (out["poi_interval"] = collect(profile_interval(model, data, r)))
    pl = Dict(p.name => p for p in pulls(model, r))
    out["parameters"] = [Dict("name" => p.name, "group" => p.group, "kind" => p.kind, "value" => r.parameters[i],
                              "error" => r.uncertainties[i], "init" => p.init, "prefit_sigma" => p.sigma,
                              "floating" => r.floating[i],
                              "pull" => haskey(pl, p.name) ? pl[p.name].pull : NaN,
                              "constraint" => haskey(pl, p.name) ? pl[p.name].constraint : NaN)
                         for (i, p) in enumerate(model.parameters)]
    out["covariance"] = r.covariance
    if fc.impacts
        imp = impacts(model, data, r)
        out["impacts"] = sort!(collect(imp); by = x -> -max(abs(x.postfit_up), abs(x.postfit_down)))
    end
    fc.upper_limit && (out["upper_limit"] = upper_limit(model, data))
    fc.significance && (out["significance"] = significance(model, data))
    prefit_cov = Matrix(Diagonal([(p.constraint !== :none && !p.fixed) ? p.sigma^2 : 0.0 for p in model.parameters]))
    init = [p.init for p in model.parameters]
    out["channels"] = map(built.channels) do c
        ci = findfirst(==(c.name), model.channels)
        d = data.main[model.channel_bins[ci]]
        Dict("name" => c.name, "region" => c.region, "variable" => c.variable, "edges" => c.edges,
             "members" => c.members, "histosys" => c.histosys, "data" => d,
             "prefit" => group_yields(model, init, prefit_cov, c.name),
             "postfit" => group_yields(model, r.parameters, r.covariance, c.name))
    end
    out["counting"] = [counting_estimate(model, c.name; signal = fc.signal) for c in built.channels]
    out["normsys"] = [Dict("name" => n.name, "hi" => n.hi, "lo" => n.lo,
                           "samples" => isempty(n.samples) ? ["all"] : n.samples, "placeholder" => n.placeholder)
                      for n in fc.normsys]
    out["notes"] = built.notes
    out["options"] = Dict("normsys_code" => fc.normsys_code, "histosys_code" => fc.histosys_code,
                          "signal" => fc.signal)
    out["workspace"] = built.workspace
    return json_safe(out)
end
