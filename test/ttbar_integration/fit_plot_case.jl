"""Use immutable pipeline outputs in a separate, explicitly labelled reporting scope."""
function fit_plot_case(area,label,source,config;coarse=false)
    work=joinpath(area,coarse ? "diagnostic_asimov_onebin_"*label : "observed_original_bins_"*label)
    ispath(work) && error("fit/plot scope exists; preserve it and inspect before retry")
    mkpath(work)
    for dir in ("skim","merge","systematics");cp(joinpath(source,dir),joinpath(work,dir));end
    cfg=load_analysis(config); path=config
    if coarse
        raw=deepcopy(cfg.raw);raw["fit"]["asimov"]=true
        for h in raw["histograms"]
            h["name"]=="njet" || continue
            pop!(h,"range",nothing);pop!(h,"linspace",nothing);h["edges"]=[0.5,7.5]
        end
        path=joinpath(work,"diagnostic.toml");open(io->TOML.print(io,raw),path,"w");cfg=load_analysis(path)
        for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
            p=joinpath(work,rel);st=read_store(p)
            for k in keys(st)
                k.variable=="njet" || continue
                h=st[k];st.hists[k]=BinnedHist([first(h.edges),last(h.edges)],[sum(h.sumw)],[sum(h.sumw2)])
            end
            write_store(p,st)
            P.write_meta(p,P.artifact_key("explicit one-bin diagnostic",rel,bytes2hex(open(sha256,path)));step="diagnostic",scope="Asimov; all original stored njet bins summed, no clipping")
        end
    end
    record=Dict{String,Any}("label"=>label,"workdir"=>work,"scope"=>(coarse ? "explicit one-bin Asimov diagnostic" : "original observed bins/settings"))
    templates=read_store(joinpath(work,"systematics/templates.json"))
    try
        built=Cascade.Fit.build_workspace(templates,Cascade.Fit.fit_config(cfg))
        writejson(joinpath(work,"workspace-before-fit.json"),built.workspace)
        writejson(joinpath(work,"workspace-notes.json"),built.notes)
        negatives=Any[]
        for channel in built.workspace["channels"], sample in channel["samples"]
            for (i,value) in enumerate(sample["data"])
                value<=0 && push!(negatives,Dict("channel"=>channel["name"],"sample"=>sample["name"],"bin"=>i,"nominal"=>value))
            end
        end
        record["nonpositive_nominal_sample_bins"]=negatives
        run_pipeline(RunOptions(path;max_files=label=="original" ? 2 : 0,workdir=work,steps=[:fit,:plot]))
        report=json(joinpath(work,"fit/result.json"));record["status"]=report["status"]
        record["poi_value"]=report["poi_value"];record["poi_error"]=report["poi_error"];record["nll"]=report["nll"]
    catch err
        record["status"]="failed";record["error"]=sprint(showerror,err,catch_backtrace())
        write(joinpath(work,"fit-failure.txt"),record["error"])
        # Preserve the original failure; still exercise its prefit plotting path.
        run_pipeline(RunOptions(path;max_files=label=="original" ? 2 : 0,workdir=work,steps=[:plot]))
    end
    files=String.(json(joinpath(work,"plot/index.json"))["files"])
    @test !isempty(files)
    @test all(isfile,files)
    pngs=filter(p->endswith(p,".png"),files);pdfs=filter(p->endswith(p,".pdf"),files)
    @test !isempty(pngs) && !isempty(pdfs)
    for p in pngs; @test open(io->read(io,8),p)==UInt8[0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a];end
    for p in pdfs; @test open(io->read(io,4),p)==b"%PDF";end
    record["plot_files"]=length(files);record["png"]=length(pngs);record["pdf"]=length(pdfs)
    record["plot_inventory"]=sort!(relpath.(files,work))
    writejson(joinpath(work,"case-summary.json"),record)
    return record
end
