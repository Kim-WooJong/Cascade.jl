"""Permit exactly the approved digest-equivalent Config SHA fix and patch version."""
function verify_continuation(reference,project)
    oldproject=joinpath(dirname(reference),"candidate01")
    old=json(joinpath(reference,"fingerprint.json"))
    new=P.batch_fingerprint(load_analysis(joinpath(reference,"analysis.toml")))
    @test Set(keys(old))==Set(keys(new))
    for k in keys(old)
        k=="source" && continue
        @test old[k]==new[k]
    end
    paths=String[]
    for (root,_,names) in walkdir(joinpath(oldproject,"src")), name in names
        push!(paths,relpath(joinpath(root,name),oldproject))
    end
    for (root,_,names) in walkdir(joinpath(oldproject,"bin")), name in names
        push!(paths,relpath(joinpath(root,name),oldproject))
    end
    append!(paths,["Project.toml","Manifest.toml"])
    differences=Any[]
    for path in paths
        a=read(joinpath(oldproject,path));b=read(joinpath(project,path))
        a==b && continue
        push!(differences,Dict("path"=>path,"producer_sha256"=>bytes2hex(sha256(a)),"consumer_sha256"=>bytes2hex(sha256(b))))
        if path=="src/Config/canonical_hash.jl"
            @test replace(String(a),"sha256(canonical_json(x))"=>"sha256(Vector{UInt8}(codeunits(canonical_json(x))))")==String(b)
        elseif path=="Project.toml"
            @test replace(String(a),"version = \"0.6.0\""=>"version = \"0.6.1\"")==String(b)
        else
            @test false
        end
    end
    @test Set(d["path"] for d in differences)==Set(["src/Config/canonical_hash.jl","Project.toml"])
    # Fingerprint's source component includes launchers, Project and Manifest.
    oldmap=Dict(path=>bytes2hex(open(sha256,joinpath(oldproject,path))) for path in paths)
    newmap=Dict(path=>bytes2hex(open(sha256,joinpath(project,path))) for path in paths)
    @test P.batch_hash(oldmap)==old["source"]
    @test P.batch_hash(newmap)==new["source"]
    @test read(joinpath(oldproject,"Manifest.toml"))==read(joinpath(project,"Manifest.toml"))
    return Dict("approved_differences"=>differences,"unchanged_non_source_fingerprint_fields"=>sort!(filter(!=("source"),collect(keys(old)))),
        "producer_fingerprint"=>old,"consumer_fingerprint"=>new,
        "consumer_command"=>"CASCADE_TTBAR_PHASE=reduced-continue; only merge/systematics on checksum-identical completed event artifacts",
        "canonical_wire_semantics"=>"unchanged; goldens/Unicode and actual manifest digest probe required")
end
