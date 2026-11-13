# Cross-check against pyhf (external oracle). Runs only with CASCADE_PYHF_ORACLE=1 on a
# host that provides pyhf (default: LCG_110 view on gate, sourced in a subshell only).
# CASCADE_PYHF_CASES=full,large restricts the cases; CASCADE_LCG_VIEW overrides the view.

function _pyhf_reference(spec, point, mu_tests)
    lcg = get(ENV, "CASCADE_LCG_VIEW", "/cvmfs/sft.cern.ch/lcg/views/LCG_110/x86_64-el9-clang22-dbg")
    oracle = joinpath(@__DIR__, "pyhf_oracle.py")
    dir = mktempdir()
    inp, out = joinpath(dir, "in.json"), joinpath(dir, "out.json")
    write(inp, JSON3.write(Dict("workspace" => spec, "point" => point, "mu_tests" => mu_tests)))
    cmd = "source $lcg/setup.sh >/dev/null 2>&1 && python3 $oracle $inp $out"
    run(pipeline(`bash -c $cmd`; stderr=devnull))
    return JSON3.read(read(out, String))
end

_reldiff(a, b) = maximum(abs.(a .- b) ./ max.(abs.(b), 1e-300); init=0.0)
_absdiff(a, b) = maximum(abs.(a .- b); init=0.0)

if get(ENV, "CASCADE_PYHF_ORACLE", "0") == "1"
    @testset "pyhf cross-check" begin
        cases = ["counting" => ws_counting(), "onoff" => ws_onoff(), "full" => ws_full(),
                 "masked" => ws_masked(), "large" => ws_large()]
        only_cases = split(get(ENV, "CASCADE_PYHF_CASES", ""), ","; keepempty=false)
        for (label, spec) in cases
            isempty(only_cases) || label in only_cases || continue
            @testset "$label" begin
                m = HistModel(spec)
                d = observed_data(m)
                names = [p.name for p in m.parameters]
                point = Dict(p.name => (p.fixed ? p.init : p.init + 0.1 * (p.constraint === :none ? 0.5 : p.sigma) * (isodd(i) ? 1 : -1))
                             for (i, p) in enumerate(m.parameters))
                mus = [0.5, 1.0, 2.0]
                ref = _pyhf_reference(spec, point, mus)
                perm = [findfirst(==(n), names) for n in ref.par_names]
                # parameter order differs from pyhf (pyhf: builder order); compare by name
                @test sort(collect(String, ref.par_names)) == sort(names)
                @test [p.init for p in m.parameters][perm] ≈ collect(Float64, ref.init)
                @test [[p.lower, p.upper] for p in m.parameters][perm] ≈ [collect(Float64, b) for b in ref.bounds]
                @test [p.fixed for p in m.parameters][perm] == collect(Bool, ref.fixed)
                x0 = [p.init for p in m.parameters]
                xp = [point[n] for n in names]
                dl0 = abs(-nll(m, x0, d) - ref.logpdf_init)
                dlp = abs(-nll(m, xp, d) - ref.logpdf_point)
                dex = _reldiff(expected_main(m, xp), collect(Float64, ref.expected_point))
                @test dl0 < 1e-9 * (1 + abs(ref.logpdf_init))
                @test dlp < 1e-9 * (1 + abs(ref.logpdf_point))
                @test dex < 1e-12

                t = @elapsed r = fit(m, d)
                rp = collect(Float64, ref.bestfit)[invperm(perm)]
                re = collect(Float64, ref.errors)[invperm(perm)]
                fl = findall(r.floating)
                dnll = r.nll - ref.twice_nll / 2
                dpar = maximum(abs.(r.parameters[fl] .- rp[fl]) ./ r.uncertainties[fl])
                # pyhf "errors" are Minuit's migrad estimates; hess_inv is the HESSE covariance
                pc = reduce(hcat, [collect(Float64, row) for row in ref.covariance])'
                pc = pc[invperm(perm), invperm(perm)]
                derr = _reldiff(r.uncertainties[fl], sqrt.(diag(pc))[fl])
                derr_migrad = _reldiff(r.uncertainties[fl], re[fl])
                dcov = maximum(abs.(r.covariance[fl, fl] .- pc[fl, fl]) ./
                               (r.uncertainties[fl] * r.uncertainties[fl]'))
                @test r.converged
                @test dnll < 1e-7
                @test dpar < 2e-2
                @test derr < 2e-2
                @test dcov < 2e-2

                if haskey(ref, :inference_error)
                    @info "pyhf [$label]: inference part not available in pyhf" first(split(ref.inference_error, "\n"))
                    println("pyhf $(ref.pyhf_version) [$label] npar=$(length(names)) |dlogpdf|=($dl0, $dlp) ",
                            "dexp_rel=$dex dNLL(ours-pyhf)=$dnll max|dpar|/sigma=$dpar max_rel_derr(hesse)=$derr ",
                            "max_rel_derr(migrad)=$derr_migrad max|dcov|/(s_i s_j)=$dcov")
                    continue
                end
                a0 = asimov_data(m, 0.0, d)
                da0 = _reldiff(a0.main, collect(Float64, ref.asimov0_main))
                dla0 = abs(-nll(m, xp, a0) - ref.asimov0_logpdf_point)
                @test da0 < 1e-4
                @test dla0 < 1e-4

                dq = dcls = 0.0
                for tref in ref.tests
                    ht = hypotest(m, d, tref.mu)
                    dq = max(dq, abs(ht.q - tref.qmu_tilde))
                    dcls = max(dcls, abs(ht.cls - tref.cls), abs(ht.clsb - tref.clsb), abs(ht.clb - tref.clb),
                               _absdiff(ht.cls_expected, collect(Float64, tref.cls_expected)))
                end
                @test dq < 1e-4
                @test dcls < 1e-5
                tl = @elapsed ul = upper_limit(m, d; rtol=1e-8)
                dulo = abs(ul.observed - ref.upper_limit_obs) / ref.upper_limit_obs
                dule = _reldiff(ul.expected, collect(Float64, ref.upper_limit_exp))
                @test dulo < 1e-4
                @test dule < 1e-4
                sg = significance(m, d)
                dq0 = abs(sg.q0 - ref.q0)
                dq0a = abs(sg.q0_expected - ref.q0_asimov)
                @test dq0 < 1e-4
                @test dq0a < 1e-4
                println("pyhf $(ref.pyhf_version) [$label] npar=$(length(names)) |dlogpdf|=($dl0, $dlp) ",
                        "dexp_rel=$dex dNLL(ours-pyhf)=$dnll max|dpar|/sigma=$dpar max_rel_derr(hesse)=$derr ",
                        "max_rel_derr(migrad)=$derr_migrad max|dcov|/(s_i s_j)=$dcov asimov_rel=$da0 dlogpdf_asimov=$dla0 max|dq|=$dq max|dCLs|=$dcls ",
                        "UL obs=$(ul.observed) (pyhf $(ref.upper_limit_obs)) rel_obs=$dulo rel_exp=$dule ",
                        "|dq0|=$dq0 |dq0A|=$dq0a optimizer=$(ref.inference_optimizer) t_fit=$(round(t; digits=3))s t_UL=$(round(tl; digits=3))s")
            end
        end
    end
else
    @info "pyhf cross-check skipped (set CASCADE_PYHF_ORACLE=1 on gate to run it)"
end
