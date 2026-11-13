fx_osf(name, corr, object, indices, inputs; syst = "syst", keys = ("nom", "up", "down"), when = nothing) = begin
    d = Dict{String,Any}("name" => name, "set" => "fx", "correction" => corr, "object" => object, "indices" => indices,
                         "inputs" => Dict{String,Any}(inputs), "systematic" => syst, "nominal" => keys[1])
    isempty(keys[2]) || (d["up"] = keys[2]; d["down"] = keys[3])
    when === nothing || (d["when"] = when)
    d
end

const FX_CORR = Dict{String,Any}(
    "object_sf" => [
        fx_osf("lep", "lep_sf", "muons", [1, 2], ["eta" => "eta", "pt" => "pt"]),
        fx_osf("ewp", "wp_sf", "electrons", [1], ["year" => "Y1", "WorkingPoint" => "A", "pt" => "pt"];
               syst = "ValType", keys = ("sf", "sfup", "sfdown"), when = "pt < 75.0"),
        fx_osf("ewp", "wp_sf", "electrons", [1], ["year" => "Y1", "WorkingPoint" => "B", "pt" => "pt"];
               syst = "ValType", keys = ("sf", "sfup", "sfdown"), when = "pt >= 75.0")],
    "event_weight" => [
        Dict{String,Any}("name" => "pu", "set" => "fx", "correction" => "pu",
                         "inputs" => Dict{String,Any}("ntrue" => "Pileup_nTrueInt"), "systematic" => "which",
                         "nominal" => "nominal", "up" => "up", "down" => "down"),
        Dict{String,Any}("name" => "nj", "set" => "fx", "correction" => "nint", "inputs" => Dict{String,Any}("n" => "njet"))],
    "flat" => [Dict{String,Any}("name" => "trig", "up" => 1.02, "down" => 0.97)])

function fx_expected(t, pileup)
    n = nrows(t)
    v(c) = t[string("v:", c)]
    w = t["weight"]
    lep(s) = [fx_lep(v("mu1_eta")[i], v("mu1_pt")[i], s) * fx_lep(v("mu2_eta")[i], v("mu2_pt")[i], s) for i in 1:n]
    wa(s) = [v("e1_pt")[i] < 75 ? fx_wp("A", v("e1_pt")[i], s) : 1.0 for i in 1:n]
    wb(s) = [v("e1_pt")[i] >= 75 ? fx_wp("B", v("e1_pt")[i], s) : 1.0 for i in 1:n]
    pu(s) = [fx_pu(Float64(pileup[e]), s) for e in t["entry"]]
    nj = [FX_INT[Int(x)] for x in v("njet")]
    prod(l, a, b, p, tr) = w .* l .* a .* b .* p .* nj .* tr
    one = ones(n)
    e = Dict{String,Vector{Float64}}()
    e["nominal"] = prod(lep("nom"), wa("sf"), wb("sf"), pu("nominal"), one)
    e["lepUp"] = prod(lep("up"), wa("sf"), wb("sf"), pu("nominal"), one)
    e["lepDown"] = prod(lep("down"), wa("sf"), wb("sf"), pu("nominal"), one)
    e["ewpUp"] = prod(lep("nom"), wa("sfup"), wb("sfup"), pu("nominal"), one)
    e["ewpDown"] = prod(lep("nom"), wa("sfdown"), wb("sfdown"), pu("nominal"), one)
    e["puUp"] = prod(lep("nom"), wa("sf"), wb("sf"), pu("up"), one)
    e["puDown"] = prod(lep("nom"), wa("sf"), wb("sf"), pu("down"), one)
    e["trigUp"] = prod(lep("nom"), wa("sf"), wb("sf"), pu("nominal"), fill(1.02, n))
    e["trigDown"] = prod(lep("nom"), wa("sf"), wb("sf"), pu("nominal"), fill(0.97, n))
    e["scaleUp"] = e["nominal"] .* 1.1
    e["scaleDown"] = e["nominal"] .* 0.9
    return e
end

errmsg(f) = try
    f(); ""
catch e
    e isa ArgumentError ? e.msg : rethrow()
end

@testset "correction_weights (synthetic sets)" begin
    mktempdir() do dir
        setpath = write_fixture_set(joinpath(dir, "fx.json"))
        src = write_fixture_source(joinpath(dir, "src.cols"))
        pileup = read_column_file(src)[1]["Pileup_nTrueInt"]
        vars = [Dict{String,Any}("name" => "scale", "up" => "1.1", "down" => "0.9")]
        cfg = fixture_config(FX_CORR; setpath, variations = vars)
        mc, data = cfg.samples
        t = fixture_table()
        t.columns["w:scaleUp"] = fill(1.1, nrows(t)); t.columns["w:scaleDown"] = fill(0.9, nrows(t))
        append!(t.order, ["w:scaleUp", "w:scaleDown"])

        w = correction_weights(cfg, mc, src, t)
        exp = fx_expected(t, pileup)
        @test sort(collect(keys(w))) == sort(collect(keys(exp)))
        for (k, v) in exp
            @test w[k] == v          # same multiplication order: bit-identical
        end
        @test !haskey(w, "njUp")     # term without variation
        # the when-split terms cover every electron exactly once
        @test all(w["ewpUp"] .!= w["nominal"])

        # hook = correction_weights of the context fields
        ctx = Cascade.Pipeline.CorrectionContext(cfg, mc, src, t)
        @test apply_corrections(ctx) == w

        # data: base weight only
        wd = correction_weights(cfg, data, src, t)
        @test collect(keys(wd)) == ["nominal"] && wd["nominal"] == t["weight"]

        # no [corrections]: identical to the default hook
        cfg0 = parse_analysis(Dict{String,Any}(filter(p -> p.first != "corrections", cfg.raw)); dir)
        ctx0 = Cascade.Pipeline.CorrectionContext(cfg0, cfg0.samples[1], src, t)
        @test apply_corrections(ctx0) == Cascade.Pipeline.default_correct(ctx0)

        # empty table
        t0 = fixture_table(; n = 0, entries = Int[])
        w0 = correction_weights(cfg, mc, src, t0)
        @test all(isempty, values(w0)) && haskey(w0, "lepUp")

        # errors name the term and the fix
        c3 = deepcopy(FX_CORR); c3["object_sf"][1]["indices"] = [1, 3]
        m = errmsg(() -> correction_weights(fixture_config(c3; setpath), mc, src, t))
        @test occursin("object_sf 'lep'", m) && occursin("\"muons.eta[3]\"", m) && occursin("[output] columns", m)
        c4 = deepcopy(FX_CORR); delete!(c4["object_sf"][1]["inputs"], "pt")
        @test occursin("input 'pt' (real) is not mapped", errmsg(() -> correction_weights(fixture_config(c4; setpath), mc, src, t)))
        c5 = deepcopy(FX_CORR); c5["object_sf"][1]["inputs"]["phi"] = "phi"
        @test occursin("unknown input 'phi'", errmsg(() -> correction_weights(fixture_config(c5; setpath), mc, src, t)))
        c6 = deepcopy(FX_CORR); c6["object_sf"][2]["inputs"]["WorkingPoint"] = 3
        @test occursin("string-typed", errmsg(() -> correction_weights(fixture_config(c6; setpath), mc, src, t)))
        c7 = deepcopy(FX_CORR); c7["event_weight"][2]["inputs"]["n"] = "njet + 0.5"
        @test occursin("non-integer", errmsg(() -> correction_weights(fixture_config(c7; setpath), mc, src, t)))
        c8 = deepcopy(FX_CORR); c8["event_weight"][2]["inputs"]["n"] = "nlep"
        cfg8 = fixture_config(c8; setpath, extra_vars = Dict{String,Any}("nlep" => "length(muons)"))
        @test occursin("'nlep' is not in [output] columns", errmsg(() -> correction_weights(cfg8, mc, src, t)))
        c9 = deepcopy(FX_CORR); c9["event_weight"][1]["inputs"]["ntrue"] = "Pileup_nPU"
        @test occursin("branch 'Pileup_nPU' not found", errmsg(() -> correction_weights(fixture_config(c9; setpath), mc, src, t)))
        # flow = error outside the binning: reported with the term name
        tbad = fixture_table(); tbad.columns["v:mu1_eta"] = [3.5, 0, 0, 0, 0, 0]
        @test occursin("object_sf 'lep' (lep_sf)", errmsg(() -> correction_weights(cfg, mc, src, tbad)))
        tnan = fixture_table(); tnan.columns["v:mu2_pt"] = [NaN, 1, 1, 1, 1, 1]
        @test occursin("NaN", errmsg(() -> correction_weights(cfg, mc, src, tnan)))
        # unknown correction name
        c10 = deepcopy(FX_CORR); c10["object_sf"][1]["correction"] = "nope"
        @test_throws KeyError correction_weights(fixture_config(c10; setpath), mc, src, t)

        # whole-expression lookup: object input "eta + deltaEtaSC" uses e1_eta_sc
        c11 = Dict{String,Any}("object_sf" => [fx_osf("e", "lep_sf", "electrons", [1], ["eta" => "eta + deltaEtaSC", "pt" => "pt"])])
        w11 = correction_weights(fixture_config(c11; setpath), mc, src, t)
        @test w11["nominal"] == t["weight"] .* [fx_lep(t["v:e1_eta_sc"][i], t["v:e1_pt"][i], "nom") for i in 1:nrows(t)]
        # expression inputs: abs() on a field
        c12 = Dict{String,Any}("object_sf" => [fx_osf("m", "lep_sf", "muons", [1], ["eta" => "-abs(eta)", "pt" => "pt * 0.5"];
                                                      keys = ("nom", "", ""))])
        w12 = correction_weights(fixture_config(c12; setpath), mc, src, t)
        @test w12["nominal"] == t["weight"] .* [fx_lep(-abs(t["v:mu1_eta"][i]), t["v:mu1_pt"][i] * 0.5, "nom") for i in 1:nrows(t)]
        @test sort(collect(keys(w12))) == ["nominal", "scaleDown", "scaleUp"]   # expression variations only
    end
end
