"""Inspect real plot notes/products and qualify all fitted parameters/covariances."""
function accept_reports(area)
    summary=json(joinpath(area,"fit-plot-summary.json"));records=summary["cases"]
    reports=[json(joinpath(r["workdir"],"fit/result.json")) for r in records]
    names=[[p["name"] for p in r["parameters"]] for r in reports]
    @test length(names[1])==length(names[2])==length(names[3])
    @test names[1]==names[2]==names[3]
    @test all(r["status"]=="ok" && r["converged"]===true for r in reports)
    @test length(unique(r["dataset"] for r in reports))==1
    expected_dataset=occursin("diagnostic",summary["scope"]) ? "asimov" : "observed"
    @test all(r["dataset"]==expected_dataset for r in reports)
    comparison=compare_fit_cases(records) # Full lengths/names already checked.
    qualifications=Any[]
    for (record,report) in zip(records,reports)
        model=Cascade.Fit.report_model(report);result=Cascade.Fit.report_result(report,model)
        @test result.names==names[1]
        @test all(isfinite,result.covariance)
        free=result.covariance[result.floating,result.floating]
        eigenvalues=LinearAlgebra.eigvals(LinearAlgebra.Symmetric(free))
        boundaries=String[]
        for (parameter,value) in zip(model.parameters,result.parameters)
            min(abs(value-parameter.lower),abs(value-parameter.upper))<=1e-6 && push!(boundaries,parameter.name)
        end
        push!(qualifications,Dict("workflow"=>record["label"],"dataset"=>report["dataset"],"status"=>report["status"],
            "parameters"=>names[1],"parameter_count"=>length(names[1]),"boundary_parameters"=>boundaries,
            "floating_covariance_rank"=>LinearAlgebra.rank(free),"floating_covariance_dimension"=>size(free,1),
            "minimum_floating_covariance_eigenvalue"=>minimum(eigenvalues;init=Inf),
            "covariance_positive_definite"=>all(>(0.),eigenvalues),"edm"=>report["edm"],
            "qualification"=>"technical bounded fit only; sparse/negative sample templates and placeholder physics remain"))
    end
    plots=Any[]
    allcases=vcat(get(summary,"original_cases",Any[]),records);seen=Set{String}()
    for record in allcases
        work=record["workdir"];work in seen && continue;push!(seen,work)
        files=String.(json(joinpath(work,"plot/index.json"))["files"])
        @test all(isfile,files)
        rel=relpath.(files,work);notespath=joinpath(work,"plot/notes.txt")
        notes=isfile(notespath) ? read(notespath,String) : ""
        categories=Dict("prefit"=>count(p->startswith(p,"plot/prefit/"),rel),
            "postfit"=>count(p->startswith(p,"plot/postfit/"),rel),
            "tables"=>count(p->startswith(p,"plot/tables/"),rel),
            "impacts"=>count(p->occursin("plot/impacts.",p),rel),
            "cutflow"=>count(p->occursin("plot/cutflow.",p),rel),
            "png"=>count(p->endswith(p,".png"),rel),"pdf"=>count(p->endswith(p,".pdf"),rel))
        @test categories["prefit"]>0 && categories["tables"]>0 && categories["cutflow"]>0
        cfgpath=record["label"]=="original" ? joinpath(area,"analysis.toml") : joinpath(bundle_root(area),"analysis.toml")
        cfg=load_analysis(cfgpath);missing=Any[]
        for region in cfg.regions, h in cfg.histograms
            !isempty(h.regions) && !(region.name in h.regions) && continue
            for log in (h.name in get(get(cfg.raw,"plot",Dict()),"logy",String[]) ? [false,true] : [false])
                stem=joinpath(work,"plot/prefit",region.name,h.name*(log ? "_log" : ""))
                png=isfile(stem*".png");pdf=isfile(stem*".pdf")
                @test png==pdf
                if !png
                    relevant=filter(line->occursin("prefit "*region.name*"/"*h.name*":",line),split(notes,'\n'))
                    @test !isempty(relevant)
                    push!(missing,Dict("region"=>region.name,"variable"=>h.name,"log"=>log,"recorded_notes"=>relevant))
                end
            end
        end
        if record["status"]=="ok"
            @test categories["postfit"]>0
            report=json(joinpath(work,"fit/result.json"))
            isempty(get(report,"impacts",Any[])) || @test categories["impacts"]>0
        end
        push!(plots,Dict("workflow"=>record["label"],"workdir"=>work,"fit_status"=>record["status"],
            "categories"=>categories,"notes"=>notes,"explicitly_accounted_missing_plots"=>missing))
    end
    writejson(joinpath(area,"report-acceptance.json"),Dict("scope"=>summary["scope"],"parameter_comparison"=>comparison,
        "fit_qualifications"=>qualifications,"plot_coverage"=>plots))
end
