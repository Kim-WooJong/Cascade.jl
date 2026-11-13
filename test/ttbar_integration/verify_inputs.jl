"""Recheck the exact inventory, original bytes and payload/runtime provenance."""
function verify_inputs(area)
    cfg=load_analysis(joinpath(area,"analysis.toml")); inventory=json(joinpath(area,"inventory.json"))
    @test P.batch_fingerprint(cfg)==json(joinpath(area,"fingerprint.json"))
    for payload in json(joinpath(area,"payloads.json"))
        @test bytes2hex(open(sha256,payload["path"]))==payload["sha256"]
    end
    for sample in cfg.samples
        rows=filter(r->r["sample"]==sample.name,inventory)
        files=expand_files(sample.files)
        @test files[1:2]==[r["path"] for r in rows]
        @test length(files)==first(rows)["available_nfiles"]
        for row in rows
            source=NanoAODSource(row["path"])
            try
                @test source_signature(source)==row["signature"]
            finally
                close_source(source)
            end
            @test bytes2hex(open(sha256,row["path"]))==row["sha256"]
        end
    end
end
