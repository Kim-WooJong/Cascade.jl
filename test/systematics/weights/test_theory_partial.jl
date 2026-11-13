function theory_review_plot_hook(ctx,store,fit)
    write_store(joinpath(ctx.workdir,"plot-hook.json"),store)
    String[]
end
@testset "plot-only reduction config key and orphan partial reruns" begin
    mktempdir() do dir
        t=theory_fixture(family="pdf",reduction="replica_std",cl_scale=1.,pdf_template_model="rank_one")
        raw=deepcopy(theory_config(t).raw)
        p=joinpath(dir,"analysis.toml");open(io->TOML.print(io,raw),p,"w")
        work=joinpath(dir,"work");mkpath(joinpath(work,"merge"));mkpath(joinpath(work,"fit"))
        st=HistogramStore()
        for (label,v) in (("nominal",[10.,10.]),("__theory_scale_1",[11.,9.]),("__theory_scale_2",[9.,11.]))
            st.hists[HistKey("r","mc",label,"x")]=BinnedHist([0.,1.,2.],v,[10.,10.])
        end
        st.meta["theory_extraction"]=theory_extraction(theory_config(t))
        merged=joinpath(work,"merge","histograms.json");write_store(merged,st)
        Cascade.Pipeline.write_meta(merged,"frozen_merge";step="merge")
        fitp=joinpath(work,"fit","result.json");write(fitp,"{}")
        Cascade.Pipeline.write_meta(fitp,"frozen_fit";step="fit")
        beforemerge=read(merged);beforefit=read(fitp)
        old=get(Cascade.Pipeline.HOOKS,:plot,nothing)
        try
            register_hook!(:plot,theory_review_plot_hook;id="theory_review_plot")
            opts=RunOptions(p;workdir=work,steps=[:plot])
            @test run_pipeline(opts)[:plot]["run"]==1
            first=read_store(joinpath(work,"plot-hook.json"))
            @test run_pipeline(opts)[:plot]["run"]==0
            raw["theory_weights"][1]["cl_scale"]=0.5
            open(io->TOML.print(io,raw),p,"w")
            @test run_pipeline(opts)[:plot]["run"]==1
            second=read_store(joinpath(work,"plot-hook.json"))
            @test second["r","mc","scaleUp","x"].sumw≈[10+sqrt(2.)/2,10+sqrt(2.)/2]
            @test first["r","mc","scaleUp","x"].sumw!=second["r","mc","scaleUp","x"].sumw
            @test read(merged)==beforemerge && read(fitp)==beforefit
            for mode in (:removed,:disabled)
                if mode==:removed
                    delete!(raw,"theory_weights")
                else
                    raw["theory_weights"]=[merge(t,Dict("enabled"=>false))]
                end
                open(io->TOML.print(io,raw),p,"w")
                @test_throws ArgumentError run_pipeline(RunOptions(p;workdir=work,steps=[:systematics]))
                @test_throws ArgumentError run_pipeline(opts)
            end
        finally
            old===nothing ? delete!(Cascade.Pipeline.HOOKS,:plot) : (Cascade.Pipeline.HOOKS[:plot]=old)
        end
    end
end
