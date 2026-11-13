# pyhf cross-check of a workspace exported from a histogram store (CASCADE_PYHF_ORACLE=1, gate).
if get(ENV, "CASCADE_PYHF_ORACLE", "0") == "1"
    @testset "pyhf cross-check of the store workspace" begin
        data = round.(1.3 .* (FIX_SIG1 .+ FIX_SIG2) .+ FIX_BKG .+ [3.0, -4.0, 2.0])
        fc = fit_config(fixture_section(), fixture_samples())
        spec = plainjson(JSON3.read(JSON3.write(build_workspace(fixture_store(; data), fc).workspace)))
        m = HistModel(spec)
        d = observed_data(m)
        names = [p.name for p in m.parameters]
        point = Dict(p.name => p.init + 0.1 * (p.constraint === :none ? 0.5 : p.sigma) for p in m.parameters)
        ref = _pyhf_reference(spec, point, [1.0, 2.0])
        perm = [findfirst(==(n), names) for n in ref.par_names]
        @test sort(collect(String, ref.par_names)) == sort(names)
        @test abs(-nll(m, [p.init for p in m.parameters], d) - ref.logpdf_init) < 1e-9 * (1 + abs(ref.logpdf_init))
        @test abs(-nll(m, [point[n] for n in names], d) - ref.logpdf_point) < 1e-9 * (1 + abs(ref.logpdf_point))
        r = fit(m, d)
        rp = collect(Float64, ref.bestfit)[invperm(perm)]
        pc = reduce(hcat, [collect(Float64, row) for row in ref.covariance])'[invperm(perm), invperm(perm)]
        fl = findall(r.floating)
        dnll = r.nll - ref.twice_nll / 2
        dpar = maximum(abs.(r.parameters[fl] .- rp[fl]) ./ r.uncertainties[fl])
        derr = maximum(abs.(r.uncertainties[fl] .- sqrt.(diag(pc))[fl]) ./ sqrt.(diag(pc))[fl])
        @test dnll < 1e-7 && dpar < 2e-2 && derr < 2e-2
        println("pyhf $(ref.pyhf_version) [store workspace] mu=$(r.parameters[m.poi]) (pyhf $(rp[m.poi])) ",
                "dNLL=$dnll max|dpar|/sigma=$dpar max_rel_derr=$derr")
        if !haskey(ref, :inference_error)
            ul = upper_limit(m, d; rtol = 1e-8)
            @test abs(ul.observed - ref.upper_limit_obs) / ref.upper_limit_obs < 1e-4
        end
    end
end
