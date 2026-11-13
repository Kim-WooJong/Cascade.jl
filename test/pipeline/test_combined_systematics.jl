module TestCombinedSystematics
using Test, JSON3
using Cascade.Selection, Cascade.Config, Cascade.IO, Cascade.Histograms, Cascade.Pipeline, Cascade.Corrections
using ..TestShapePipeline
const S = TestShapePipeline

@testset "combined shape and kinematic SF" begin
    mktempdir() do dir
        S.setup(dir)
        # Continuous SF makes even within-bin jet shifts observable in weights.
        formula(c) = Dict("nodetype" => "formula", "expression" => "$c + 0.001*x",
                          "parser" => "TFormula", "variables" => ["pt"])
        corr = Dict("schema_version" => 2, "corrections" => [Dict(
            "name" => "jet_sf", "version" => 1,
            "inputs" => [Dict("name" => "pt", "type" => "real"), Dict("name" => "syst", "type" => "string")],
            "output" => Dict("name" => "sf", "type" => "real"),
            "data" => Dict("nodetype" => "category", "input" => "syst", "content" => [
                Dict("key" => k, "value" => formula(v)) for (k,v) in (("nom",1.0),("up",1.1),("down",0.9))]))])
        write(joinpath(dir, "sf.json"), JSON3.write(corr))
        sf = """
        [output]
        columns = ["jet_sf_pt"]
        [hooks]
        correct = "Cascade.Systematics.apply_corrections"
        [corrections.sets]
        sf = "sf.json"
        [[corrections.object_sf]]
        name = "jet_weight"
        set = "sf"
        correction = "jet_sf"
        object = "jets"
        indices = [1]
        inputs = {pt = "pt"}
        systematic = "syst"
        nominal = "nom"
        up = "up"
        down = "down"
        """
        base = replace(read(joinpath(dir,"analysis.toml"), String), "[variables]\n" =>
                       "[variables]\njet_sf_pt = \"jets.pt[1]\"\n")
        write(joinpath(dir,"analysis.toml"), base * "\n" * sf)
        steps = [:skim,:select,:correct,:histogram,:merge]
        work = joinpath(dir,"combined")
        run_pipeline(RunOptions(joinpath(dir,"analysis.toml"); workdir=work, steps))
        st = S.merged(work)
        # Nominal has identical SF-weighted results with shapes disabled.
        pbase = joinpath(dir,"base.toml")
        write(pbase, S.no_shape(base) * "\n" * sf)
        wb = joinpath(dir,"baseline")
        run_pipeline(RunOptions(pbase; workdir=wb, steps))
        sb = S.merged(wb)
        @test all(st[k] == sb[k] for k in keys(sb))
        @test !any(k.sample == "dataEG" && k.variation != "nominal" for k in keys(st))
        # Independently vary raw jets before selection, then recompute SF. This
        # tests migrated events, sorted-object identity and varied kinematics.
        jes = load_correctionset(joinpath(dir,"test_jerc.json"))["Test_JES_Total"]
        S.varied_inputs(dir,"manual") do c, sample
            pt, eta = c["Jet_pt"], c["Jet_eta"]
            S.scale_jets!(c, [1 + evaluate(jes,Float64(eta.content[j]),Float64(pt.content[j])) for j in eachindex(pt.content)])
        end
        pd = joinpath(dir,"direct.toml")
        write(pd, S.with_inputs(S.no_shape(base),"manual") * "\n" * sf)
        wd = joinpath(dir,"direct")
        run_pipeline(RunOptions(pd; workdir=wd, steps))
        sd = S.merged(wd)
        @test S.same_as_label(st, sd, "JES_TotalUp")
        @test all(st[k] == sd[k] for k in keys(sd) if k.sample == "dataEG")
        @test S.samples_json(work)[:sigA][:shape][:JES_TotalUp][:cutflow] == S.samples_json(wd)[:sigA][:cutflow]
        @test any(st[k] != st[HistKey(k.region,k.sample,"JES_TotalUp",k.variable)] for k in keys(sb)
                  if k.sample == "sigA" && k.variation == "nominal")
        # Weight columns explicitly use the varied selected pT, not source pT.
        meta = JSON3.read(read(joinpath(work,"skim","sigA.json"),String))
        rows = 0
        for e in meta[:files]
            chunk = String(e[:chunk])
            t = read_event_table(joinpath(work,"select","sigA",chunk * ".JES_TotalUp.cols"))
            w = read_column_file(joinpath(work,"correct","sigA",chunk * ".JES_TotalUp.cols"))[1]["nominal"]
            @test w ≈ t["weight"] .* (1 .+ 0.001 .* t["v:jet_sf_pt"])
            rows += nrows(t)
        end
        @test rows > 20
    end
end
end
