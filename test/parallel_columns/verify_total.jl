using Test, Cascade, JSON3, ROOTPlots, SHA
using Cascade.Config, Cascade.IO, Cascade.Selection, Cascade.Histograms, Cascade.Pipeline
using Cascade.Plotting
base=ENV["CASCADE_PARALLEL_CANDIDATE"]
cases=["t1-r1","t4-r1","t4-r4"]
reference=joinpath(base,"total-"*first(cases))
function bitvector_equal(a,b)
    return typeof(a)==typeof(b) && reinterpret(UInt8,a)==reinterpret(UInt8,b)
end
@testset "ordinary pipeline exact science and transport parity" begin
    for case in cases
        work=joinpath(base,"total-"*case)
        cfg=load_analysis(joinpath(base,"configs",endswith(case,"r4") ? "readers4.toml" : "readers1.toml"))
        original=read_store(joinpath(reference,"merge/histograms.json"))
        store=read_store(joinpath(work,"merge/histograms.json"))
        @test Set(keys(store))==Set(keys(original))
        @test all(k.variation=="nominal" for k in keys(store))
        for k in keys(store), field in (:edges,:sumw,:sumw2)
            @test bitvector_equal(getfield(store[k],field),getfield(original[k],field))
        end
        info=JSON3.read(read(joinpath(work,"merge/samples.json"),String))
        refinfo=JSON3.read(read(joinpath(reference,"merge/samples.json"),String))
        @test info==refinfo
        for name in ("TTto2L2Nu","MuonEG")
            e=only(Cascade.Pipeline.read_skim(work,name)["files"])
            chunk=e["chunk"]
            for stage in ("select","correct")
                path=joinpath(work,stage,name,chunk*".cols")
                refpath=joinpath(reference,stage,name,chunk*".cols")
                cols,meta,order=read_column_file(path)
                rc,rm,ro=read_column_file(refpath)
                @test order==ro && meta==rm
                @test all(bitvector_equal(cols[k],rc[k]) for k in order)
                @test read_meta(path)["key"]==read_meta(refpath)["key"]
            end
            path=joinpath(work,"select",name,chunk*".cols")
            diag=read_meta(path)["execution"]
            effective=case=="t4-r4" ? 2 : 1
            @test diag["effective_readers"]==effective
            @test diag["extra_opens"]==diag["extra_closes"]==effective-1
            @test case!="t4-r4" || diag["max_active_reads"]==2
            @test read_meta(path)["cutflow"]==read_meta(joinpath(reference,"select",name,chunk*".cols"))["cutflow"]
            println(JSON3.write(Dict("case"=>case,"sample"=>name,"execution"=>diag)))
        end
        @test info["samples"]["TTto2L2Nu"]["gen_weight_sum"]==2646014.7375000003
        @test info["samples"]["MuonEG"]["norm"]==1.0
        opts=plot_options(cfg;lumi_pb=store.meta["lumi_pb"])
        stack=analysis_stack_config(cfg,store,opts)
        tpl=store_templates(store,"emu_ge1j","njet")
        groups=group_templates(tpl,stack); data=merge_data(tpl,stack)
        band=uncertainty_band(groups)
        cmp=stack_comparison(data,groups,[g.color for g in stack.groups],band)
        @test bitvector_equal(cmp.data.sumw,store["emu_ge1j","MuonEG","nominal","njet"].sumw)
        @test bitvector_equal(cmp.prediction,store["emu_ge1j","TTto2L2Nu","nominal","njet"].sumw)
        limits=auto_ylimits(cmp)
        spec=cms_panel_spec("Number of jets";lumi=opts.lumi,energy=opts.energy,extra=opts.extra,
            annotation=opts.region_labels["emu_ge1j"],ymin=limits[1],ymax=limits[2])
        transport=joinpath(base,"evidence","transport-"*case*".tsv")
        ROOTPlots.write_root_spec(transport,[cmp],[spec],spec.ratio_limits)
        rows=[split(line,'\t') for line in readlines(transport) if startswith(line,"BIN\t")]
        @test length(rows)==length(cmp.data.sumw)
        @test all(parse(Float64,row[6])==cmp.data.sumw[i] && parse(Float64,row[9])==cmp.prediction[i] for (i,row) in enumerate(rows))
        @test isfile(joinpath(work,"plot/prefit/emu_ge1j/njet.png"))
    end
    @test read(joinpath(base,"evidence/transport-t1-r1.tsv"))==read(joinpath(base,"evidence/transport-t4-r1.tsv"))==read(joinpath(base,"evidence/transport-t4-r4.tsv"))
end
