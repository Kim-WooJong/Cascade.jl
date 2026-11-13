"""Create a new consumer view without rewriting producer metadata or event artifacts."""
function prepare_reuse(area,project)
    reference=abspath(ENV["CASCADE_TTBAR_REFERENCE"])
    if ispath(area)
        allowed=Set(["analysis.toml","inventory.json","payloads.json","scope.json","producer-fingerprint.json","original","reduced"])
        issubset(Set(readdir(area)),allowed) || error("consumer view is not the known incomplete preparation; preserve and inspect")
    end
    authorization=verify_continuation(reference,project)
    oldproject=joinpath(dirname(reference),"candidate01")
    for phase in ("original01","export01")
        @test strip(read(joinpath(oldproject,"integration-logs",phase*".exit"),String))=="0"
    end
    @test strip(read(joinpath(oldproject,"integration-logs/reduced01.exit"),String))=="130"
    @test isfile(joinpath(dirname(reference),"parent-handoff01.json"))
    original=joinpath(reference,"original");reduced=joinpath(reference,"reduced")
    original_files=P.batch_files(original);reduced_files=P.batch_files(reduced)
    # All successfully completed event-level stages must exist for every shard.
    for sample in load_analysis(joinpath(reference,"bundle/analysis.toml")).samples
        skim=P.read_skim(reduced,sample.name)
        for chunk in skim["files"]
            for (step,ext) in ((:select,".cols"),(:correct,".cols"),(:histogram,".json"))
                artifact=P.chunk_path(reduced,step,sample.name,chunk["chunk"],ext)
                @test isfile(artifact) && P.read_meta(artifact)!==nothing
            end
        end
    end
    mkpath(area)
    for file in ("analysis.toml","inventory.json","payloads.json","scope.json")
        destination=joinpath(area,file)
        if isfile(destination)
            @test read(destination)==read(joinpath(reference,file))
        else
            cp(joinpath(reference,file),destination)
        end
    end
    producer_path=joinpath(area,"producer-fingerprint.json")
    if isfile(producer_path)
        @test read(producer_path)==read(joinpath(reference,"fingerprint.json"))
    else
        cp(joinpath(reference,"fingerprint.json"),producer_path)
    end
    ispath(joinpath(area,"original")) || cp(original,joinpath(area,"original"))
    ispath(joinpath(area,"reduced")) || cp(reduced,joinpath(area,"reduced"))
    @test P.batch_files(joinpath(area,"original"))==original_files
    @test P.batch_files(joinpath(area,"reduced"))==reduced_files
    cfg=load_analysis(joinpath(area,"analysis.toml"))
    rp=joinpath(reference,"bundle/analysis.toml")
    P.validate_reduced_inputs(load_analysis(rp)) # Actual existing contracts, no bypass.
    writejson(joinpath(area,"reuse-bindings.json"),Dict("reference_area"=>reference,
        "bundle"=>joinpath(reference,"bundle"),"producer_project"=>oldproject,"consumer_project"=>project,
        "reason"=>"parent-authorized SIGINT during old global merge after all event stages; canonical digest semantics unchanged",
        "producer_fingerprint"=>json(joinpath(reference,"fingerprint.json")),
        "producer_manifest_sha256"=>bytes2hex(open(sha256,joinpath(reference,"bundle/manifest.json"))),
        "original_artifacts"=>original_files,"reduced_completed_artifacts"=>reduced_files,
        "authorization"=>authorization,"event_stages_reexecuted"=>false,"producer_metadata_rewritten"=>false))
    writejson(joinpath(area,"fingerprint.json"),P.batch_fingerprint(cfg))
    println("Immutable original/export and completed event artifacts verified; only unfinished global stages will run")
end
