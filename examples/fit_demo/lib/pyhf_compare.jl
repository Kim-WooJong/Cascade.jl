"""
    pyhf_compare(workspace_path; lcg=LCG_110 view) -> Bool

Fit a pyhf workspace written by the Cascade fit step (`fit/workspace.json`)
with `Cascade.Fit` and with pyhf (external oracle `test/fit/pyhf_oracle.py`,
run in a subshell with the LCG view; Python is not a runtime dependency) and
print the comparison: log-pdf at the initial parameters, NLL at the minimum,
POI and every parameter (difference in units of the error) and the Hesse
errors. Returns whether the agreement is within the cross-check tolerances
(|ΔNLL| < 1e-6, |Δθ| < 0.02 σ, relative error difference < 2%).
"""
function pyhf_compare(path::AbstractString; lcg = "/cvmfs/sft.cern.ch/lcg/views/LCG_110/x86_64-el9-clang22-dbg")
    spec = Cascade.Fit.load_workspace(path)
    m = Cascade.Fit.HistModel(spec)
    d = Cascade.Fit.observed_data(m)
    r = Cascade.Fit.fit(m, d)
    names = [p.name for p in m.parameters]
    dir = mktempdir()
    inp, out = joinpath(dir, "in.json"), joinpath(dir, "out.json")
    write(inp, JSON3.write(Dict("workspace" => spec, "point" => Dict(n => p.init for (n, p) in zip(names, m.parameters)),
                                "mu_tests" => [1.0], "mle_only" => true)))
    oracle = joinpath(@__DIR__, "..", "..", "..", "test", "fit", "pyhf_oracle.py")
    run(pipeline(`bash -c "source $lcg/setup.sh >/dev/null 2>&1 && python3 $oracle $inp $out"`; stderr = devnull))
    ref = JSON3.read(read(out, String))
    perm = [findfirst(==(n), String.(ref.par_names)) for n in names]
    bf, er = collect(Float64, ref.bestfit)[perm], collect(Float64, ref.errors)[perm]
    pc = reduce(hcat, [collect(Float64, row) for row in ref.covariance])'[perm, perm]
    fl = findall(r.floating)
    dlog = abs(-Cascade.Fit.nll(m, [p.init for p in m.parameters], d) - ref.logpdf_init)
    dnll = r.nll - ref.twice_nll / 2
    dpar = maximum(abs.(r.parameters[fl] .- bf[fl]) ./ r.uncertainties[fl])
    derr = maximum(abs.(r.uncertainties[fl] .- sqrt.(diag(pc))[fl]) ./ sqrt.(diag(pc))[fl])
    ip = m.poi
    println("pyhf ", ref.pyhf_version, " vs Cascade.Fit on ", path)
    println("  POI ", names[ip], ": Cascade ", r.parameters[ip], " ± ", r.uncertainties[ip],
            " | pyhf ", bf[ip], " ± ", sqrt(pc[ip, ip]), " (hesse), ± ", er[ip], " (migrad)")
    println("  |dlogpdf(init)| = ", dlog, "  dNLL(min) = ", dnll, "  max|dθ|/σ = ", dpar, "  max rel. Δerror = ", derr)
    for i in fl
        println("    ", rpad(names[i], 28), " ", rpad(round(r.parameters[i]; digits = 6), 12), " ",
                rpad(round(bf[i]; digits = 6), 12), " err ", round(r.uncertainties[i]; digits = 6), " / ",
                round(sqrt(pc[i, i]); digits = 6))
    end
    ok = dlog < 1e-6 * (1 + abs(ref.logpdf_init)) && abs(dnll) < 1e-6 && dpar < 0.02 && derr < 0.02
    println(ok ? "  AGREEMENT WITHIN TOLERANCES" : "  DISAGREEMENT")
    return ok
end
