"""Try unchanged observed fit first; never hide or overwrite sparse-fit failures."""
function fit_plot(area)
    p=joinpath(area,"analysis.toml");rp=joinpath(bundle_root(area),"analysis.toml")
    batch=json(joinpath(area,"batch-result-path.json"))["path"]
    inputs=[("original",joinpath(area,"original"),p),("reduced",joinpath(area,"reduced"),rp),("batch",batch,rp)]
    records=[fit_plot_case(area,label,source,config) for (label,source,config) in inputs]
    writejson(joinpath(area,"observed-fit-plot-summary.json"),records)
    if all(r["status"]=="ok" for r in records)
        comparison=compare_fit_cases(records)
        writejson(joinpath(area,"fit-plot-summary.json"),Dict("scope"=>"original observed bins/settings","cases"=>records,"comparison"=>comparison))
    else
        # Separate scope: preserve original results/failures above. No physics
        # configuration or template is mutated; all stored njet bins are summed.
        diagnostics=[fit_plot_case(area,label,source,config;coarse=true) for (label,source,config) in inputs]
        writejson(joinpath(area,"fit-plot-summary.json"),Dict("scope"=>"explicit diagnostic Asimov one-bin; original observed results preserved","original_cases"=>records,"cases"=>diagnostics))
        @test all(r["status"]=="ok" for r in diagnostics)
        comparison=compare_fit_cases(diagnostics)
        writejson(joinpath(area,"fit-plot-summary.json"),Dict("scope"=>"explicit diagnostic Asimov one-bin; original observed results preserved","original_cases"=>records,"cases"=>diagnostics,"comparison"=>comparison))
    end
end
