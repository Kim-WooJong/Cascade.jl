"""Check modifier/observation inventories and fitted quantities, not just POI."""
function compare_fit_cases(records)
    reports=[json(joinpath(r["workdir"],"fit/result.json")) for r in records]
    workspaces=[json(joinpath(r["workdir"],"workspace-before-fit.json")) for r in records]
    modifiers(w)=sort!([(c["name"],s["name"],m["name"],m["type"]) for c in w["channels"] for s in c["samples"] for m in s["modifiers"]])
    @test modifiers(workspaces[1])==modifiers(workspaces[2])==modifiers(workspaces[3])
    workspace_comparison=compare_workspace(workspaces[1],workspaces[2])
    if reports[1]["dataset"]=="observed"
        @test workspaces[1]["observations"]==workspaces[2]["observations"]==workspaces[3]["observations"]
    end
    @test workspaces[2]==workspaces[3]
    @test records[1]["plot_inventory"]==records[2]["plot_inventory"]==records[3]["plot_inventory"]
    parameter_names=[[p["name"] for p in report["parameters"]] for report in reports]
    @test length(parameter_names[1])==length(parameter_names[2])==length(parameter_names[3])
    @test parameter_names[1]==parameter_names[2]==parameter_names[3]
    @test all(report["converged"]===true && report["status"]=="ok" for report in reports)
    @test length(unique(report["dataset"] for report in reports))==1
    differences=Dict{String,Any}()
    for key in ("poi_value","poi_error","nll")
        x=reports[1][key];y=reports[2][key];z=reports[3][key]
        @test isfinite(x) && isfinite(y) && isfinite(z)
        @test isapprox(x,y;atol=1e-6,rtol=1e-7)
        @test y==z
        differences[key]=abs(x-y)
    end
    for (x,y,z) in zip(reports[1]["parameters"],reports[2]["parameters"],reports[3]["parameters"])
        @test x["name"]==y["name"]==z["name"]
        for key in ("value","error")
            @test isapprox(x[key],y[key];atol=1e-6,rtol=1e-7)
            @test y[key]==z[key]
        end
    end
    return Dict("workspace_comparison"=>workspace_comparison,"fit_differences"=>differences,"modifier_inventory"=>modifiers(workspaces[1]),
        "observation_inventory"=>workspaces[1]["observations"],"fit_parameters"=>length(reports[1]["parameters"]))
end
