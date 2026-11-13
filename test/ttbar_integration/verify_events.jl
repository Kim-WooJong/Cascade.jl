"""Compare exact typed raw bytes and event-local results for every original/shape."""
function verify_events(area)
    cfg=load_analysis(joinpath(area,"analysis.toml")); bundle=bundle_root(area)
    manifest=json(joinpath(bundle,"manifest.json")); inventory=json(joinpath(area,"inventory.json"))
    @test length(manifest["groups"])==26
    summary=Any[]; raw_comparisons=0; event_values=0; weight_values=0; migrations=0
    for (record,row) in zip(manifest["groups"],inventory)
        group=read_reduced_group(joinpath(bundle,record["path"])); name=record["sample"]
        @test name==row["sample"]
        @test group["source_signature"]==row["signature"]
        @test group["original_nevents"]==row["nevents"]
        @test group["normalization"]==row["normalization"]
        @test group["coverage"]["selected_nfiles"]==2
        @test group["coverage"]["available_nfiles"]==row["available_nfiles"]
        @test group["luminosity_spec"]==P.luminosity_spec(cfg)
        # This analysis uses configured1210, not a certified per-LS table.
        @test group["certified_observed_lumisections"]===nothing
        original_skim=P.read_skim(joinpath(area,"original"),name)
        original=only(filter(e->e["path"]==row["path"],original_skim["files"]))
        reduced_skim=P.read_skim(joinpath(area,"reduced"),name)
        chunks=filter(e->e["group_id"]==group["group_id"],reduced_skim["files"])
        @test length(chunks)==length(group["shards"])
        op=P.chunk_path(joinpath(area,"original"),:select,name,original["chunk"],".cols")
        meta=P.read_meta(op); labels=vcat("nominal",String.(get(meta,"shape",String[])))
        expected=Int64[]; mapping=Int64[]; nominal_entries=Set{Int64}(); local_migrations=0
        for label in labels
            origpath=label=="nominal" ? op : P.shape_chunk_path(joinpath(area,"original"),:select,name,original["chunk"],label,".cols")
            table=read_event_table(origpath); es=Int64.(table["entry"]); append!(expected,es)
            if label=="nominal"
                union!(nominal_entries,es)
                @test group["original_cutflows"][label]==meta["cutflow"]
            else
                @test group["original_cutflows"][label]==meta["shape_cutflows"][label]
                local_migrations+=length(setdiff(Set(es),nominal_entries))
            end
            combined=Dict(k=>eltype(table[k])[] for k in table.order if k!="entry")
            owpath=label=="nominal" ? P.chunk_path(joinpath(area,"original"),:correct,name,original["chunk"],".cols") : P.shape_chunk_path(joinpath(area,"original"),:correct,name,original["chunk"],label,".cols")
            original_weights=read_column_file(owpath)[1]
            combined_weights=Dict(k=>Float64[] for k in keys(original_weights)); source_entries=Int64[]
            for chunk in chunks
                selpath=label=="nominal" ? P.chunk_path(joinpath(area,"reduced"),:select,name,chunk["chunk"],".cols") : P.shape_chunk_path(joinpath(area,"reduced"),:select,name,chunk["chunk"],label,".cols")
                t=read_event_table(selpath);append!(source_entries,Int64.(t["source_entry"]))
                for k in keys(combined); append!(combined[k],t[k]); end
                wpath=label=="nominal" ? P.chunk_path(joinpath(area,"reduced"),:correct,name,chunk["chunk"],".cols") : P.shape_chunk_path(joinpath(area,"reduced"),:correct,name,chunk["chunk"],label,".cols")
                weights=read_column_file(wpath)[1]
                @test Set(keys(weights))==Set(keys(original_weights))
                for k in keys(combined_weights); append!(combined_weights[k],weights[k]); end
            end
            @test source_entries==es
            for k in keys(combined)
                @test eltype(combined[k])==eltype(table[k])
                @test reinterpret(UInt8,combined[k])==reinterpret(UInt8,table[k]);event_values+=length(table[k])
            end
            for k in keys(combined_weights)
                @test reinterpret(UInt8,combined_weights[k])==reinterpret(UInt8,original_weights[k]);weight_values+=length(original_weights[k])
            end
        end
        source=NanoAODSource(row["path"])
        try
            names=[d["name"] for d in group["columns"] if d["name"]!="cascade_source_entry"]
            reference=read_columns(source,names)
            for shard in group["shards"]
                r=ReducedShardSource(joinpath(bundle,shard["path"]))
                try
                    es=read_columns(r,["cascade_source_entry"])["cascade_source_entry"]
                    append!(mapping,es);values=read_columns(r,names)
                    for name in names
                        x=reference[name];y=values[name]
                        if x isa Jagged
                            @test y isa Jagged && eltype(x.content)==eltype(y.content)
                            @test diff(y.offsets)==[length(x[e]) for e in es]
                            for (i,e) in enumerate(es)
                                @test reinterpret(UInt8,collect(x[e]))==reinterpret(UInt8,collect(y[i]));raw_comparisons+=1
                            end
                        else
                            @test eltype(x)==eltype(y)
                            @test reinterpret(UInt8,x[es])==reinterpret(UInt8,y);raw_comparisons+=length(es)
                        end
                    end
                    @test_throws Exception normalization_metadata(r)
                finally
                    close_source(r)
                end
            end
        finally
            close_source(source)
        end
        @test mapping==sort!(unique!(expected))
        @test length(mapping)==group["retained_nevents"]
        migrations+=local_migrations
        push!(summary,Dict("sample"=>name,"ordinal"=>row["ordinal"],"original_events"=>row["nevents"],
            "retained"=>length(mapping),"shards"=>length(group["shards"]),"shape_added_entries"=>local_migrations,
            "normalization"=>group["normalization"],"windows"=>group["metrics"]["windows"]))
        GC.gc()
    end
    tt=filter(r->r["sample"]=="TTto2L2Nu",summary)
    @test length(tt)==2
    @test any(r["shards"]>1 for r in tt)
    @test sum(r["shape_added_entries"] for r in tt)>0
    @test migrations>0
    writejson(joinpath(area,"event-summary.json"),Dict("sources"=>summary,"raw_branch_event_comparisons"=>raw_comparisons,
        "event_local_values"=>event_values,"corrected_weight_values"=>weight_values,"shape_added_entries"=>migrations))
end
