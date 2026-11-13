"""Require the intended 13-sample, scalar/shape/theory and fit-observation scope."""
function accept_inventories(area)
    names=["TTto2L2Nu","TWminusto2L2Nu","TbarWplusto2L2Nu","WWto2L2Nu","WZto3LNu","WZto2L2Q","DYto2L_MLL50","DYto2L_MLL10to50","TTtoLNu2Q","MuonEG","SingleMuon","Muon","EGamma"]
    cfg=load_analysis(joinpath(area,"analysis.toml"));rp=joinpath(bundle_root(area),"analysis.toml")
    @test [s.name for s in cfg.samples]==names
    scalar=[n*d for n in ["muon_id","muon_iso","electron_reco","electron_id","pileup","trigger_emu"] for d in ["Up","Down"]]
    shapes=[n*d for n in ["JES_Total","JER"] for d in ["Up","Down"]]
    members=vcat(["__theory_scale_"*string(i) for i in [1,2,4,6,8,9]],["__theory_ISR_1","__theory_ISR_3","__theory_FSR_2","__theory_FSR_4"])
    reductions=[n*d for n in ["scale","ISR","FSR"] for d in ["Up","Down"]]
    batches=json(joinpath(area,"batch-result-path.json"))["path"]
    inventories=Any[]
    for (label,work,p) in [("original",joinpath(area,"original"),joinpath(area,"analysis.toml")),("reduced",joinpath(area,"reduced"),rp),("batch",batches,rp)]
        raw=read_store(joinpath(work,"merge/histograms_raw.json"));templates=read_store(joinpath(work,"systematics/templates.json"))
        @test Set(store_axis(raw,:sample))==Set(names)
        for (index,name) in enumerate(names)
            expected_raw=index>=10 ? ["nominal"] : vcat(["nominal"],scalar,shapes,name=="TTto2L2Nu" ? members : String[])
            expected_templates=index>=10 ? ["nominal"] : vcat(["nominal"],scalar,shapes,name=="TTto2L2Nu" ? reductions : String[])
            @test Set(k.variation for k in keys(raw) if k.sample==name)==Set(expected_raw)
            @test Set(k.variation for k in keys(templates) if k.sample==name)==Set(expected_templates)
        end
        @test !any(k->startswith(k.variation,"__theory_"),keys(templates))
        plot_inputs=Cascade.Systematics.reduce_theory(load_analysis(p),read_store(joinpath(work,"merge/histograms.json")))
        @test !any(k->startswith(k.variation,"__theory_"),keys(plot_inputs))
        fc=Cascade.Fit.fit_config(load_analysis(p))
        @test Set(s.name for s in fc.samples)==Set(["ttbar","single_top","diboson","zjets"])
        @test fc.data==names[10:13]
        workspace=Cascade.Fit.build_workspace(templates,fc).workspace
        @test Set(s["name"] for c in workspace["channels"] for s in c["samples"])==Set(["ttbar","single_top","diboson","zjets"])
        @test !any(startswith(m["name"],"__theory_") for c in workspace["channels"] for s in c["samples"] for m in s["modifiers"])
        @test length(fc.channels)==length(workspace["observations"])
        for (channel,observation) in zip(fc.channels,workspace["observations"])
            expected=reduce(+, (templates[channel.region,name,"nominal",channel.variable].sumw for name in fc.data))
            @test observation["data"]==expected
        end
        push!(inventories,Dict("workflow"=>label,"samples"=>names,"scalar_variations"=>scalar,"shape_variations"=>shapes,
            "tt_raw_members"=>members,"tt_reduced_variations"=>reductions,"observed_contributors"=>fc.data,
            "fit_groups"=>Dict(s.name=>s.members for s in fc.samples),"observations"=>workspace["observations"]))
    end
    writejson(joinpath(area,"inventory-acceptance.json"),inventories)
end
