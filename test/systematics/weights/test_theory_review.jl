using Cascade.Fit
@testset "nonlinear cross-sample cancellation fails closed" begin
    st=HistogramStore()
    for (s,vals) in (("A",[12.,8.]),("B",[8.,12.]))
        st.hists[HistKey("r",s,"nominal","x")]=BinnedHist([0.,1.],[10.],[10.])
        for i in 1:2
            st.hists[HistKey("r",s,"__theory_scale_$i","x")]=BinnedHist([0.,1.],[vals[i]],[vals[i]])
        end
    end
    @test [12+8,8+12]==[20,20] # correlated member sum; never independent 24/16
    for grouping in ("sample","group")
        raw=Dict{String,Any}("analysis"=>Dict("lumi_pb"=>1.),
            "samples"=>[Dict("name"=>s,"kind"=>"mc","group"=>"combined","files"=>["unused"],"xsec_pb"=>1.) for s in ("A","B")],
            "fit"=>Dict("grouping"=>grouping,"signal"=>[grouping=="group" ? "combined" : "A"],
                "channels"=>[Dict("region"=>"r","variable"=>"x")]))
        for recipe in ("envelope","replica_std","hessian_symmetric","hessian_pairs")
            t=theory_fixture(samples=["A","B"],reduction=recipe)
            recipe=="envelope" || merge!(t,Dict("family"=>"pdf","cl_scale"=>1.,"pdf_template_model"=>"rank_one"))
            raw["theory_weights"]=[t]
            @test_throws ArgumentError validate_analysis(parse_analysis(raw))
            @test_throws ArgumentError reduce_theory(parse_analysis(raw),st)
        end
        raw["theory_weights"]=[theory_fixture(samples=["A","B"],reduction="pair")]
        cfg=validate_analysis(parse_analysis(raw));st.meta["theory_extraction"]=theory_extraction(cfg);out=reduce_theory(cfg,st)
        ws=build_workspace(out,fit_config(cfg)).workspace
        up=0.;dn=0.
        for s in ws["channels"][1]["samples"]
            mods=filter(x->x["name"]=="scale",s["modifiers"])
            # A grouped exactly cancelling pair is correctly pruned by Fit.
            if isempty(mods)
                @test grouping=="group"
                up+=sum(s["data"]);dn+=sum(s["data"])
            else
                m=only(mods)
                up+=sum(m["data"]["hi_data"]);dn+=sum(m["data"]["lo_data"])
            end
        end
        @test up==dn==20.
        # Only distinct nuisance labels can deliberately declare independent samples.
        raw["theory_weights"]=[theory_fixture(name="scale_$s",samples=[s]) for s in ("A","B")]
        @test length(theory_weights(validate_analysis(parse_analysis(raw))))==2
    end
    @test length(theory_weights(theory_config(theory_fixture(samples=["mc","mc"]))))==1
end
@testset "PDF rank-one acknowledgment and anticorrelation limit" begin
    for recipe in ("replica_std","hessian_symmetric","hessian_pairs")
        t=theory_fixture(family="pdf",reduction=recipe,cl_scale=1.)
        err=try theory_config(t); nothing catch e; e end
        @test err isa ArgumentError
        @test occursin("pdf_template_model",sprint(showerror,err))
        @test_throws ArgumentError theory_config(merge(t,Dict("pdf_template_model"=>"automatic")))
        @test length(theory_weights(theory_config(merge(t,Dict("pdf_template_model"=>"rank_one")))))==1
    end
    @test_throws ArgumentError theory_config(theory_fixture(pdf_template_model="rank_one"))
    st=HistogramStore()
    st.hists[HistKey("r","mc","nominal","x")]=BinnedHist([0.,1.,2.],[10.,10.],[10.,10.])
    for (i,v) in enumerate(([11.,9.],[9.,11.]))
        st.hists[HistKey("r","mc","__theory_scale_$i","x")]=BinnedHist([0.,1.,2.],v,[10.,10.])
    end
    t=theory_fixture(family="pdf",reduction="replica_std",cl_scale=1.,pdf_template_model="rank_one")
    st.meta["theory_extraction"]=theory_extraction(theory_config(t))
    out=reduce_theory(theory_config(t),st)
    y=out.meta["theory_weights"][1]["yields"][1]
    @test y["yield_up"]==y["yield_down"]==20.
    @test y["template_up"]≈20+2sqrt(2.)
    @test y["template_down"]≈20-2sqrt(2.)
    fc=fit_config(Dict("signal"=>["mc"],"channels"=>[Dict("region"=>"r","variable"=>"x")]),theory_config(t).samples)
    ws=build_workspace(out,fc).workspace
    m=only(filter(x->x["name"]=="scale",ws["channels"][1]["samples"][1]["modifiers"]))
    delta=m["data"]["hi_data"].-[10.,10.]
    @test delta*delta'≈fill(2.,2,2) # rank-one positive covariance, original was anticorrelated
    @test sum(m["data"]["hi_data"])>20.
end
@testset "orphan member direct API" begin
    cfg=theory_config(theory_fixture());raw=deepcopy(cfg.raw);delete!(raw,"theory_weights")
    emptycfg=validate_analysis(parse_analysis(raw));st=HistogramStore()
    @test reduce_theory(emptycfg,st)===st
    st.hists[HistKey("r","mc","__theory_scale_1","x")]=BinnedHist([0.,1.])
    @test_throws ArgumentError reduce_theory(emptycfg,st)
    raw["theory_weights"]=[merge(theory_fixture(),Dict("enabled"=>false))]
    @test_throws ArgumentError reduce_theory(validate_analysis(parse_analysis(raw)),st)
end
