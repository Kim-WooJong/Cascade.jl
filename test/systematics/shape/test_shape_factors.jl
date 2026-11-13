module TestShapeFactors
# Per-object factors of JES/JER/scale variations, column scaling and MET propagation.
using Test, Random
using Cascade.Config, Cascade.IO, Cascade.Corrections, Cascade.Objects
using Cascade.Systematics.Shape

const DIR = normpath(joinpath(@__DIR__, "..", "..", "..", "analyses", "shape_test"))
const CFG = load_analysis(joinpath(DIR, "analysis.toml"))
const SV = Dict(v.name => v for v in shape_variations(CFG))

"Random jets with gen jets (`genJetIdx` 0-based) and event-level rho/event id."
function jet_columns(rng, n; first_event = 1)
    nj = [rand(rng, 0:5) for _ in 1:n]
    lists(f) = [Float32[f() for _ in 1:k] for k in nj]
    pt = lists(() -> Float32(15 + 200 * rand(rng))); eta = lists(() -> Float32(-4.5 + 9 * rand(rng)))
    phi = lists(() -> Float32(-π + 2π * rand(rng)))
    gidx = Vector{Int16}[]; gpt = Vector{Float32}[]; geta = Vector{Float32}[]; gphi = Vector{Float32}[]
    for i in 1:n
        gi = Int16[]; gp = Float32[]; ge = Float32[]; gf = Float32[]
        for k in 1:nj[i]
            if rand(rng) < 0.6
                push!(gp, pt[i][k] * Float32(1 + 0.1 * randn(rng))); push!(ge, eta[i][k] + Float32(0.03 * randn(rng)))
                push!(gf, phi[i][k]); push!(gi, Int16(length(gp) - 1))
            else
                push!(gi, Int16(rand(rng) < 0.5 ? -1 : 7))     # 7: out of range
            end
        end
        push!(gidx, gi); push!(gpt, gp); push!(geta, ge); push!(gphi, gf)
    end
    return Dict{String,Any}("Jet_pt" => Jagged(pt), "Jet_eta" => Jagged(eta), "Jet_phi" => Jagged(phi),
        "Jet_mass" => Jagged(lists(() -> Float32(5 + 20 * rand(rng)))), "Jet_genJetIdx" => Jagged(gidx),
        "GenJet_pt" => Jagged(gpt), "GenJet_eta" => Jagged(geta), "GenJet_phi" => Jagged(gphi),
        "Rho_fixedGridRhoFastjetAll" => Float32[Float32(5 + 30 * rand(rng)) for _ in 1:n],
        "event" => UInt64[first_event + i - 1 for i in 1:n])
end

@testset "shape factors" begin
    rng = MersenneTwister(7)
    c = jet_columns(rng, 4000)
    pt = c["Jet_pt"]; eta = c["Jet_eta"]
    needed = [rand(rng) < 0.8 for _ in 1:4000]
    jets_of(i) = pt.offsets[i]+1:pt.offsets[i+1]

    @testset "jes" begin
        k = JESShape(SV["JES_Total"])
        unc = load_correctionset(joinpath(DIR, "test_jerc.json"))["Test_JES_Total"]
        up, down = jes_factors(k, "Jet", c, needed)
        for i in 1:4000, j in jets_of(i)
            u = needed[i] ? evaluate(unc, Float64(eta.content[j]), Float64(pt.content[j])) : 0.0
            @test up[j] == 1 + u && down[j] == 1 - u
        end
        @test_throws ArgumentError shape_correction(joinpath(DIR, "test_jerc.json"), "Test_JES_Total", ["JetPt", "JetEta"])
        @test_throws ArgumentError shape_correction(joinpath(DIR, "test_jerc.json"), "missing")
    end

    @testset "scale_column / propagate_met" begin
        f = 1 .+ 0.1 .* rand(rng, length(pt.content))
        s = scale_column(pt, f, needed)
        @test s isa Jagged{Float32} && s.offsets === pt.offsets
        @test all(needed[i] ? s.content[j] == Float32(Float64(pt.content[j]) * f[j]) : s.content[j] == pt.content[j]
                  for i in 1:4000 for j in jets_of(i))
        mpt = Float32[30 for _ in 1:4000]; mphi = Float32[π / 2 for _ in 1:4000]
        same = propagate_met(mpt, mphi, c["Jet_phi"], pt, pt, pt, 15.0, nothing)
        @test same[1] == mpt && same[2] == mphi                        # no change: bit-identical
        one = Dict("phi" => Jagged([Float32[0, 1]]), "from" => Jagged([Float32[50, 10]]),
                   "to" => Jagged([Float32[60, 20]]))
        p, q = propagate_met(Float32[30], Float32[π / 2], one["phi"], one["from"], one["to"], one["from"], 15.0, nothing)
        mx = 30 * cos(Float64(Float32(π / 2))) - 10; my = 30 * sin(Float64(Float32(π / 2)))
        @test p[1] == Float32(hypot(mx, my)) && q[1] == Float32(atan(my, mx))   # jet below 15 GeV ignored
    end

    @testset "gen matching" begin
        gp = Float32[50]; ge = Float32[0.0]; gf = Float32[0.0]; go = [0, 1]
        @test matched_genjet_pt(-1, gp, ge, gf, go, 1, 0.0f0, 0.0f0, 50.0, 0.1, 0.2, 3.0) == -1.0
        @test matched_genjet_pt(1, gp, ge, gf, go, 1, 0.0f0, 0.0f0, 50.0, 0.1, 0.2, 3.0) == -1.0
        @test matched_genjet_pt(0, gp, ge, gf, go, 1, 0.25f0, 0.0f0, 50.0, 0.1, 0.2, 3.0) == -1.0
        @test matched_genjet_pt(0, gp, ge, gf, go, 1, 0.1f0, 0.0f0, 80.0, 0.1, 0.2, 3.0) == -1.0  # 30 > 3*0.1*80
        @test matched_genjet_pt(0, gp, ge, gf, go, 1, 0.1f0, 0.1f0, 60.0, 0.1, 0.2, 3.0) == 50.0
    end

    @testset "jer" begin
        k = JERShape(SV["JER"])
        @test !k.nominal && k.match_dr == 0.2 && k.match_nsigma == 3.0 && k.rho == "Rho_fixedGridRhoFastjetAll"
        jerc = load_correctionset(joinpath(DIR, "test_jerc.json"))
        res = jerc["Test_PtResolution"]; sfc = jerc["Test_ScaleFactor"]
        @test all(==(1.0), jer_factors(k, "Jet", c, needed)[1])            # nominal = false: not evaluated
        nom, up, down = jer_factors(k, "Jet", c, needed; nominal = true)
        rho = c["Rho_fixedGridRhoFastjetAll"]; g = c["GenJet_pt"]
        z = Float64[]
        nmatched = 0
        for i in 1:4000, j in jets_of(i)
            if !needed[i]
                @test nom[j] == up[j] == down[j] == 1.0
                continue
            end
            p = Float64(pt.content[j]); e = Float64(eta.content[j]); r = Float64(rho[i])
            sigma = evaluate(res, e, p, r)
            gpt = matched_genjet_pt(c["Jet_genJetIdx"].content[j], g.content, c["GenJet_eta"].content,
                                    c["GenJet_phi"].content, g.offsets, i, eta.content[j], c["Jet_phi"].content[j],
                                    p, sigma, 0.2, 3.0)
            sf = Dict(s => evaluate(sfc, e, p, s) for s in ("nom", "up", "down"))
            if gpt >= 0
                nmatched += 1
                @test nom[j] == max(1 + (sf["nom"] - 1) * (p - gpt) / p, 0.0)
                @test up[j] == max(1 + (sf["up"] - 1) * (p - gpt) / p, 0.0)
            else
                # the same normal draw for every direction
                zn = (nom[j] - 1) / (sqrt(sf["nom"]^2 - 1) * sigma)
                zu = (up[j] - 1) / (sqrt(sf["up"]^2 - 1) * sigma)
                @test isapprox(zn, zu; rtol = 1e-9, atol = 1e-12)
                abs(eta.content[j]) < 1.5 && @test down[j] == 1.0      # sf_down = 1.0: no smearing
                push!(z, zn)
            end
        end
        @test nmatched > 1000 && length(z) > 1000
        m = sum(z) / length(z)
        @test abs(m) < 0.1 && abs(sqrt(sum((z .- m) .^ 2) / (length(z) - 1)) - 1) < 0.1
        # reproducible and independent of the chunking: events 2001:4000 alone give the same factors
        @test jer_factors(k, "Jet", c, needed; nominal = true) == (nom, up, down)
        sub = Dict{String,Any}()
        for (name, col) in c
            if col isa Jagged
                o = col.offsets
                sub[name] = Jagged(col.content[o[2001]+1:end], o[2001:end] .- o[2001])
            else
                sub[name] = col[2001:end]
            end
        end
        n2, u2, d2 = jer_factors(k, "Jet", sub, needed[2001:end]; nominal = true)
        lo = pt.offsets[2001]
        @test n2 == nom[lo+1:end] && u2 == up[lo+1:end] && d2 == down[lo+1:end]
    end

    @testset "scale expressions" begin
        mu = Dict{String,Any}("Muon_pt" => Jagged([Float32[40, 50], Float32[60]]),
                              "Muon_eta" => Jagged([Float32[0.5, -2.0], Float32[1.2]]))
        k = ScaleShape(SV["MuScale"])
        up, down = scale_factors(k, mu, [true, false])
        @test up == [1.01, 1.02, 1.0] && down == [0.99, 0.98, 1.0]
    end

    @testset "shape_columns" begin
        cols = merge(c, Dict{String,Any}("PuppiMET_pt" => Float32[40 for _ in 1:4000],
                                         "PuppiMET_phi" => Float32[0 for _ in 1:4000]))
        plan = shape_plan(collect(values(SV))[sortperm(collect(keys(SV)))], ["Jet_pt", "Jet_eta", "Muon_pt", "Muon_eta"])
        @test plan.labels == ["JERUp", "JERDown", "JES_TotalUp", "JES_TotalDown", "MuScaleUp", "MuScaleDown"]
        @test "Jet_mass" in plan.replaces && "PuppiMET_pt" in plan.replaces
        @test !("Jet_mass" in plan.inputs) && !("PuppiMET_pt" in plan.inputs)   # not read by the selection
        cols["Muon_pt"] = Jagged([Float32[40] for _ in 1:4000]); cols["Muon_eta"] = Jagged([Float32[0] for _ in 1:4000])
        out = shape_columns(plan, cols, needed)
        @test first.(out) == plan.labels                                # nominal untouched: no entry
        jes = Dict(out)["JES_TotalUp"]
        @test sort(collect(keys(jes))) == ["Jet_pt"]                    # mass and MET are not read
        up, _ = jes_factors(JESShape(SV["JES_Total"]), "Jet", cols, needed)
        @test jes["Jet_pt"].content == scale_column(pt, up, needed).content
        smeared = shape_plan([SV["JER"]], ["Jet_pt", "Jet_mass", "PuppiMET_pt"])
        sv = SV["JER"]
        on = ShapeVariationConfig(sv.name, sv.collection, sv.kind, sv.fields, sv.samples, sv.met, sv.met_min_pt,
                                  merge(sv.params, Dict{String,Any}("nominal" => true)))
        o2 = shape_columns(shape_plan([on], ["Jet_pt", "Jet_mass", "PuppiMET_pt"]), cols, needed)
        @test first.(o2) == ["nominal", "JERUp", "JERDown"]
        @test sort(collect(keys(Dict(o2)["nominal"]))) == ["Jet_mass", "Jet_pt", "PuppiMET_pt"]
        o3 = shape_columns(smeared, cols, needed)
        @test Dict(o3)["JERUp"]["Jet_pt"].content == Dict(o2)["JERUp"]["Jet_pt"].content
    end
end
end
