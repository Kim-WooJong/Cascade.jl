"""Warm actual-manifest equality and timing; legacy String SHA is an oracle only."""
function hash_probe(area)
    manifest=json(joinpath(bundle_root(area),"manifest.json"))
    rendered=Cascade.Config.canonical_json(manifest)
    @test sizeof(rendered)>1_000_000
    legacy()=bytes2hex(sha256(rendered))
    current()=canonical_hash(manifest)
    old=legacy();new=current() # Warm both paths before measuring.
    @test old==new
    old_seconds=@elapsed old_again=legacy()
    times=Float64[]
    for _ in 1:3
        t=@elapsed new_again=current()
        @test new_again==old_again
        push!(times,t)
    end
    @test maximum(times)<old_seconds/10
    group_path=joinpath(bundle_root(area),manifest["groups"][1]["path"])
    read_reduced_group(group_path)
    group_seconds=@elapsed read_reduced_group(group_path)
    writejson(joinpath(area,"hash-timing-summary.json"),Dict("canonical_bytes"=>sizeof(rendered),
        "digest"=>old,"legacy_warm_sha_string_seconds"=>old_seconds,
        "fixed_warm_complete_canonical_seconds"=>times,"fixed_warm_group_validation_seconds"=>group_seconds,
        "scope"=>"same canonical bytes/digest; no verification or cache bypass"))
end
