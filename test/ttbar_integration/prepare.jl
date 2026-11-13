"""Freeze the exact ordered bounded inputs and resolved technical configuration."""
function prepare(area, project)
    ispath(area) && error("integration area already exists; inspect, never overwrite")
    cfg=load_analysis(joinpath(project,"analyses/ttbar_emu/analysis.toml");profile="integration_small")
    inventory=Any[]
    for sample in cfg.samples
        files=expand_files(sample.files)
        length(files)>=2 || error("fewer than two available originals for $(sample.name)")
        for (ordinal,path) in enumerate(files[1:2])
            source=open_source(sample.format,path;options=get(sample.raw,"source",Dict()))
            try
                push!(inventory,Dict("sample"=>sample.name,"ordinal"=>ordinal,"path"=>path,
                    "available_nfiles"=>length(files),"signature"=>source_signature(source),
                    "sha256"=>bytes2hex(open(sha256,path)),"nevents"=>nevents(source),
                    "normalization"=>normalization_metadata(source)))
                if sample.name=="TTto2L2Nu"
                    titles=Dict{String,Any}()
                    for (branch,expected) in (("LHEScaleWeight",9),("PSWeight",4))
                        b=UnROOT.LazyBranch(source.file,source.tree*"/"*branch)
                        lengths=[length(b[i]) for i in 1:min(32,length(b))]
                        @test all(==(expected),lengths)
                        titles[branch]=Dict("title"=>String(b.b.fTitle),"first32_lengths"=>lengths)
                    end
                    inventory[end]["inspected_tt_weights"]=titles
                end
            finally
                close_source(source)
            end
        end
    end
    raw=deepcopy(cfg.raw);raw["data_quality"]["golden_json"]=cfg.data_quality.golden_json
    raw["batch"]=Dict("workers"=>2,"threads"=>1)
    raw["reduced_skim"]=Dict("mode"=>"streaming","streaming"=>Dict(
        "window_events"=>5000,"target_shard_events"=>1000,"target_shard_payload_bytes"=>32000000))
    mkpath(area)
    open(io->TOML.print(io,raw),joinpath(area,"analysis.toml"),"w")
    writejson(joinpath(area,"inventory.json"),inventory)
    payloads=String[cfg.data_quality.golden_json]
    append!(payloads,values(Cascade.Systematics.parse_corrections(cfg).sets))
    for shape in shape_variations(cfg), value in values(shape.params)
        value isa AbstractString && isfile(value) && push!(payloads,String(value))
    end
    writejson(joinpath(area,"payloads.json"),[Dict("path"=>p,"sha256"=>bytes2hex(open(sha256,p))) for p in sort!(unique!(payloads))])
    writejson(joinpath(area,"fingerprint.json"),P.batch_fingerprint(load_analysis(joinpath(area,"analysis.toml"))))
    writejson(joinpath(area,"scope.json"),Dict("profile"=>"integration_small","files_per_sample"=>2,
        "lumi_pb"=>1210.,"exposure"=>"unknown; bounded original inventory",
        "float_bound"=>"128 eps(Float64) * ceil(log2(total original N)) * contribution scale",
        "fit_absolute_bound"=>1e-6,"fit_relative_bound"=>1e-7,
        "workspace_absolute_bound"=>1e-9,"workspace_relative_bound"=>1e-10,
        "exact"=>["raw bytes/types/counters","original-entry union/order","all shape entries and event-local selection/weights","original signed Runs and cutflow/LS evidence once","same NEW partition serial/batch histogram bits"],
        "not_claimed"=>["final physics prescription","full dataset skim","arbitrary repartition bit equality","measured exposure","validated trigger OR/PDF/JEC provenance/priors"]))
    @test length(inventory)==26
    @test length(unique(r["sample"] for r in inventory))==13
    println(JSON3.write(Dict("files"=>length(inventory),"events"=>sum(r["nevents"] for r in inventory))))
end
