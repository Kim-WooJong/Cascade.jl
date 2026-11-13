@testset "persisted extraction contracts and safe partial consumers" begin
    mktempdir() do dir
        input=joinpath(dir,"events.cols")
        write_column_file(input,Dict("x"=>[0.5],"genWeight"=>[10.],"V"=>Jagged([[2.,4.]]),"Other"=>Jagged([[3.,6.]])); meta=Dict("gen_weight_sum"=>10.))
        t=theory_fixture(indices=[2],reduction="envelope")
        raw=deepcopy(theory_config(t).raw)
        raw["analysis"]["lumi_pb"]=10.
        raw["samples"][1]["files"]=[input]
        raw["histograms"]=[Dict("name"=>"x","edges"=>[0.,1.],"values"=>["x"])]
        raw["weights"]=Dict("mc"=>["genWeight"])
        p=joinpath(dir,"analysis.toml");open(io->TOML.print(io,raw),p,"w")
        work=joinpath(dir,"work");steps=[:skim,:select,:correct,:histogram,:merge,:systematics]
        run_pipeline(RunOptions(p;workdir=work,steps))
        merged=joinpath(work,"merge/histograms.json")
        st=read_store(merged)
        @test st["signal","mc","__theory_scale_2","x"].sumw==[40.]
        @test st.meta["theory_extraction"]==theory_extraction(load_analysis(p))
        skim=JSON3.read(read(joinpath(work,"skim/mc.json"),String));chunk=String(skim["files"][1]["chunk"])
        cm=read_column_file(joinpath(work,"correct/mc",chunk*".cols"))[2]
        hm=read_store(joinpath(work,"histogram/mc",chunk*".json")).meta
        @test cm["theory_extraction"]==hm["theory_extraction"]==st.meta["theory_extraction"]
        old=get(Cascade.Pipeline.HOOKS,:plot,nothing)
        try
            register_hook!(:plot,theory_review_plot_hook;id="contract_plot")
            run_pipeline(RunOptions(p;workdir=work,steps=[:plot]))
            for change in (Dict("normalization"=>"central","central_index"=>1),Dict("branch"=>"Other"),
                Dict("expected_length"=>3),Dict("normalization"=>"absolute","reference_branch"=>"genWeight"),
                Dict("indices"=>[1]))
                d=deepcopy(raw);merge!(d["theory_weights"][1],change)
                open(io->TOML.print(io,d),p,"w")
                for step in (:systematics,:plot,:fit)
                    @test_throws ArgumentError run_pipeline(RunOptions(p;workdir=work,steps=[step]))
                end
            end
            for change in (Dict("format"=>"nanoaod"),Dict("source"=>Dict("tree"=>"Alternate")),Dict("source"=>Dict("gen_weight"=>"otherGen")))
                d=deepcopy(raw);merge!(d["samples"][1],change)
                open(io->TOML.print(io,d),p,"w")
                for step in (:systematics,:plot,:fit)
                    @test_throws ArgumentError run_pipeline(RunOptions(p;workdir=work,steps=[step]))
                end
            end
            open(io->TOML.print(io,raw),p,"w")
            for broken in (:missing,:foreign)
                bad=deepcopy(st)
                broken==:missing ? delete!(bad.meta,"theory_extraction") : (bad.meta["theory_extraction"]["mc"]["hash"]="foreign")
                write_store(merged,bad)
                for step in (:systematics,:plot)
                    @test_throws ArgumentError run_pipeline(RunOptions(p;workdir=work,steps=[step]))
                end
            end
            write_store(merged,st)
            d=deepcopy(raw);merge!(d["theory_weights"][1],Dict("normalization"=>"central","central_index"=>1))
            open(io->TOML.print(io,d),p,"w")
            sm=run_pipeline(RunOptions(p;workdir=work,steps))
            fresh=read_store(merged)
            @test fresh["signal","mc","__theory_scale_2","x"].sumw==[20.]
            @test fresh.meta["theory_extraction"]==theory_extraction(load_analysis(p))
            # Same label/reference family but different central must fail.
            d["theory_weights"][1]["central_index"]=2
            open(io->TOML.print(io,d),p,"w")
            for step in (:systematics,:plot,:fit)
                @test_throws ArgumentError run_pipeline(RunOptions(p;workdir=work,steps=[step]))
            end
            d=deepcopy(raw);merge!(d["theory_weights"][1],Dict("normalization"=>"absolute","reference_branch"=>"genWeight"))
            open(io->TOML.print(io,d),p,"w")
            run_pipeline(RunOptions(p;workdir=work,steps))
            d["theory_weights"][1]["reference_branch"]="x"
            open(io->TOML.print(io,d),p,"w")
            for step in (:systematics,:plot,:fit)
                @test_throws ArgumentError run_pipeline(RunOptions(p;workdir=work,steps=[step]))
            end
        finally
            old===nothing ? delete!(Cascade.Pipeline.HOOKS,:plot) : (Cascade.Pipeline.HOOKS[:plot]=old)
        end
    end
end

@testset "manifest merge compatibility and partial/empty samples" begin
    cfg=theory_config(theory_fixture());st=HistogramStore()
    for label in ("nominal","__theory_scale_1","__theory_scale_2")
        st.hists[HistKey("r","mc",label,"x")]=BinnedHist([0.,1.],[1.],[1.])
    end
    @test_throws ArgumentError reduce_theory(cfg,st) # direct stores must explicitly persist truthful provenance
    st.meta["theory_extraction"]=theory_extraction(cfg)
    dest=HistogramStore();merge_store!(dest,st);merge_store!(dest,st)
    @test dest["r","mc","__theory_scale_1","x"].sumw==[2.]
    @test dest.meta["theory_extraction"]==st.meta["theory_extraction"]
    incompatible=deepcopy(st)
    d=deepcopy(cfg.raw);d["theory_weights"][1]["branch"]="Other"
    incompatible.meta["theory_extraction"]=theory_extraction(validate_analysis(parse_analysis(d)))
    before=deepcopy(dest)
    @test_throws ArgumentError merge_store!(dest,incompatible)
    @test dest.hists==before.hists && dest.meta==before.meta
    missing=deepcopy(st);delete!(missing.meta,"theory_extraction")
    @test_throws ArgumentError merge_store!(dest,missing)
    empty=HistogramStore();empty.meta["theory_extraction"]=theory_extraction(cfg)
    merge_store!(dest,empty)
    @test length(reduce_theory(cfg,empty))==0
    other=HistogramStore();other.hists[HistKey("r","data","nominal","x")]=BinnedHist([0.,1.])
    merge_store!(dest,other)
    @test haskey(dest.meta["theory_extraction"],"mc")
    @test reduce_theory(cfg,other)["r","data","nominal","x"]==other["r","data","nominal","x"]
    @test theory_extraction(cfg;samples=SampleConfig[])==Dict()
    # Extraction manifest excludes all reduction-only settings.
    d=deepcopy(cfg.raw);merge!(d["theory_weights"][1],Dict("family"=>"pdf","reduction"=>"replica_std","cl_scale"=>0.5,"pdf_template_model"=>"rank_one"))
    @test theory_extraction(validate_analysis(parse_analysis(d)))==theory_extraction(cfg)
    d["theory_weights"][1]["indices"]=[2,1]
    @test theory_extraction(validate_analysis(parse_analysis(d)))==theory_extraction(cfg)
end

@testset "empty selection extraction persists truthful contract" begin
    mktempdir() do dir
        input=joinpath(dir,"empty.cols")
        # Branch V need not open on zero selected rows; the declaration still persists.
        write_column_file(input,Dict("x"=>[0.5],"genWeight"=>[10.]);meta=Dict("gen_weight_sum"=>10.))
        raw=deepcopy(theory_config(theory_fixture()).raw)
        raw["samples"][1]["files"]=[input]
        raw["weights"]=Dict("mc"=>["genWeight"])
        raw["cuts"]=[Dict("name"=>"none","expr"=>"x < 0")]
        raw["histograms"]=[Dict("name"=>"x","edges"=>[0.,1.],"values"=>["x"])]
        p=joinpath(dir,"a.toml");open(io->TOML.print(io,raw),p,"w")
        work=joinpath(dir,"work")
        run_pipeline(RunOptions(p;workdir=work,steps=[:skim,:select,:correct,:histogram,:merge,:systematics]))
        st=read_store(joinpath(work,"merge/histograms.json"))
        @test st.meta["theory_extraction"]==theory_extraction(load_analysis(p))
        @test all(all(iszero,h.sumw) for h in values(st.hists))
    end
end
@testset "partial applicable sample manifests" begin
    raw=deepcopy(theory_config(theory_fixture(reduction="pair")).raw)
    second=deepcopy(raw["samples"][1]);second["name"]="other";push!(raw["samples"],second)
    raw["theory_weights"][1]["samples"]=["mc","other"]
    cfg=validate_analysis(parse_analysis(raw))
    st=HistogramStore();st.meta["theory_extraction"]=theory_extraction(cfg;samples=[cfg.samples[1]])
    for label in ("nominal","__theory_scale_1","__theory_scale_2")
        st.hists[HistKey("r","mc",label,"x")]=BinnedHist([0.,1.],[1.],[1.])
    end
    @test length(reduce_theory(cfg,st))==3
    empty=HistogramStore();empty.meta["theory_extraction"]=theory_extraction(cfg;samples=[cfg.samples[2]])
    merge_store!(st,empty)
    @test Set(keys(st.meta["theory_extraction"]))==Set(["mc","other"])
    @test length(reduce_theory(cfg,st))==3
end
