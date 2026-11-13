module TestTheoryReal
using Test, JSON3, UnROOT, Cascade
using Cascade.Config, Cascade.IO, Cascade.Selection, Cascade.Histograms, Cascade.Pipeline
if get(ENV,"CASCADE_THEORY_REAL","0")=="1"
@testset "Actual ROOT vector arithmetic and bounded baseline" begin
    work=ENV["CASCADE_THEORY_AREA"]
    config=joinpath(@__DIR__,"../../../analyses/ttbar_emu/analysis.toml")
    steps=[:skim,:select,:correct,:histogram,:merge]
    base=joinpath(work,"out_baseline")
    run_pipeline(RunOptions(config;workdir=base,steps,max_files=1))
    prior=joinpath(homedir(),"analisis/Cascade_dev/p6-audit/out_bounded")
    bins=0;events=0
    for filename in ("histograms_raw.json","histograms.json")
        a=read_store(joinpath(prior,"merge",filename));b=read_store(joinpath(base,"merge",filename))
        @test Set(keys(a))==Set(keys(b))
        for k in keys(a),field in (:edges,:sumw,:sumw2)
            @test reinterpret(UInt64,getfield(a[k],field))==reinterpret(UInt64,getfield(b[k],field))
            field==:sumw && (bins+=length(a[k].sumw))
        end
    end
    a=JSON3.read(read(joinpath(prior,"merge/samples.json"),String));b=JSON3.read(read(joinpath(base,"merge/samples.json"),String))
    for name in a["order"]
        for k in ("nevents","nfiles","gen_weight_sum","norm","cutflow","regions")
            @test a["samples"][name][k]==b["samples"][name][k]
        end
        events+=b["samples"][name]["nevents"]
    end
    cfg=load_analysis(config)
    raw=deepcopy(cfg.raw)
    # The observed branch titles explicitly declare relative 9-scale/4-shower layouts.
    common=Dict{String,Any}("normalization"=>"relative","samples"=>["TTto2L2Nu"],"convention"=>"Observed NanoAOD branch titles; see THEORY_WEIGHTS.md")
    raw["theory_weights"]=[merge(common,Dict("name"=>"scale","branch"=>"LHEScaleWeight","family"=>"scale","reduction"=>"envelope","indices"=>[1,2,4,6,8,9],"expected_length"=>9)),
        merge(common,Dict("name"=>"ISR","branch"=>"PSWeight","family"=>"ps","reduction"=>"pair","indices"=>[1,3],"expected_length"=>4)),
        merge(common,Dict("name"=>"FSR","branch"=>"PSWeight","family"=>"ps","reduction"=>"pair","indices"=>[2,4],"expected_length"=>4))]
    tc=validate_analysis(parse_analysis(raw;path=config,dir=dirname(config)))
    # Isolated workdir, reuse only fresh baseline skim/select through Pipeline contexts.
    theory=joinpath(work,"out_theory")
    mkpath(theory)
    for part in ("skim","select")
        isdir(joinpath(theory,part)) || cp(joinpath(base,part),joinpath(theory,part))
    end
    opts=RunOptions(config;workdir=theory,samples=["TTto2L2Nu"],max_files=1)
    samples=[sample_by_name(tc,"TTto2L2Nu")]
    for step in (:correct,:histogram,:merge,:systematics)
        Cascade.Pipeline.run_step(step,StepContext(tc,theory,step,samples,opts))
    end
    skim=JSON3.read(read(joinpath(base,"skim/TTto2L2Nu.json"),String))
    e=skim["files"][1];chunk=String(e["chunk"]);path=String(e["path"])
    table=read_event_table(joinpath(base,"select/TTto2L2Nu",chunk*".cols"))
    weights=read_column_file(joinpath(theory,"correct/TTto2L2Nu",chunk*".cols"))[1]
    file=UnROOT.ROOTFile(path)
    @test !("LHEPdfWeight" in keys(file["Events"])) # no physical PDF example is fabricated
    direct=Dict(b=>UnROOT.LazyBranch(file,"Events/"*b) for b in ("LHEScaleWeight","PSWeight"))
    @test nrows(table)>0
    for t in raw["theory_weights"],i in t["indices"]
        expected=[Float64(table["weight"][j])*Float64(direct[t["branch"]][entry][i]) for (j,entry) in enumerate(table["entry"])]
        @test weights["__theory_$(t["name"])_$i"]==expected
    end
    merged=read_store(joinpath(theory,"merge/histograms_raw.json"))
    # Independent event loop, not vector reader or histogram fill implementation.
    for t in raw["theory_weights"],i in t["indices"],r in cfg.regions
        h=merged[r.name,"TTto2L2Nu","__theory_$(t["name"])_$i","njet"]
        sw=zeros(length(h.sumw));sw2=zeros(length(sw));mask=Dict(region_masks(table))[r.name]
        for (j,entry) in enumerate(table["entry"])
            mask[j]||continue
            x=table["h:njet:1"][j];isnan(x)&&continue
            b=clamp(searchsortedlast(h.edges,x),1,length(sw))
            w=Float64(table["weight"][j])*Float64(direct[t["branch"]][entry][i])
            sw[b]+=w;sw2[b]+=w*w
        end
        @test h.sumw==sw;@test h.sumw2==sw2
    end
    tpl=read_store(joinpath(theory,"systematics/templates.json"))
    norm=JSON3.read(read(joinpath(theory,"merge/samples.json"),String))["samples"]["TTto2L2Nu"]["norm"]
    for r in cfg.regions
        hs=[merged[r.name,"TTto2L2Nu","__theory_scale_$i","njet"].sumw.*norm for i in [1,2,4,6,8,9]]
        pushfirst!(hs,merged[r.name,"TTto2L2Nu","nominal","njet"].sumw.*norm)
        @test tpl[r.name,"TTto2L2Nu","scaleUp","njet"].sumw==reduce((a,b)->max.(a,b),hs)
        @test tpl[r.name,"TTto2L2Nu","scaleDown","njet"].sumw==reduce((a,b)->min.(a,b),hs)
    end
    close(file)
    write(joinpath(work,"real-summary.json"),JSON3.write(Dict("baseline_events"=>events,"baseline_bins"=>bins,
        "baseline_files"=>13,"theory_selected_rows"=>nrows(table),"theory_file_events"=>e["nevents"],"pdf_branch"=>"absent")))
end
end
end
