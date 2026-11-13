module TestProfiles
using Test, TOML, Cascade.Config
const DIR = normpath(joinpath(@__DIR__, "..", "..", "analyses", "ttbar_emu"))
# The unified file defines every section once; profiles only flip [options].
# Each resolved profile must equal its frozen pre-merge file in every section
# that changes physics or outputs. Selection-only additions (SF kinematics in
# [variables]/[output], payload [paths]) and [plot] may be extra.
const PHYSICS = ("samples", "objects", "cuts", "regions", "histograms", "weights", "triggers",
                 "data_quality", "merge", "corrections", "shape_variations", "fit", "hooks")
@testset "Resolved ttbar profiles reproduce frozen analyses" begin
    for (p,f) in [("baseline","analysis.toml"),("sf","analysis_sf.toml"),("phase2","analysis_phase2.toml"),("jer_candidate","analysis_jer_candidate.toml")]
        cfg = load_analysis(joinpath(DIR,"analysis.toml"); profile=p)
        old = parse_analysis(TOML.parsefile(joinpath(@__DIR__,"fixtures",f)); dir=DIR)
        a, b = cfg.raw, old.raw
        @testset "$p" begin
            norm(x) = x isa AbstractVector && isempty(x) ? nothing : x   # disabled = absent
            for k in PHYSICS
                @test norm(get(a, k, nothing)) == norm(get(b, k, nothing))
            end
            for k in ("variables", "paths")
                @test all(haskey(a[k], x) && a[k][x] == y for (x, y) in b[k])
            end
            @test a["analysis"]["lumi_pb"] == b["analysis"]["lumi_pb"]
            @test cfg.workdir == joinpath("cascade_out/ttbar_emu",p)
        end
    end
    @test load_analysis(joinpath(DIR,"analysis.toml")).raw == load_analysis(joinpath(DIR,"analysis.toml"); profile="baseline").raw
end
@testset "Profile merge and switches" begin
    d=Dict{String,Any}("analysis"=>Dict("name"=>"a","workdir"=>"out"), "variables"=>Dict("x"=>"1","y"=>"2"), "cuts"=>[Dict("name"=>"a","expr"=>"true")], "profiles"=>Dict("p"=>Dict("variables"=>Dict("x"=>"3"),"cuts"=>Any[])))
    r=resolve_config(d;profile="p")
    @test r["variables"]==Dict("x"=>"3","y"=>"2")
    @test isempty(r["cuts"])
    @test d["variables"]["x"]=="1"
    @test_throws ArgumentError resolve_config(d;profile="missing")
    for path in (Dict("analysys"=>Dict()),Dict("analysis"=>Dict("lumy"=>1)),Dict("profiles"=>Dict("bad"=>Dict("objects"=>[Dict("bad"=>1)]))))
        @test_throws ArgumentError resolve_config(path)
    end
    d=Dict{String,Any}("options"=>Dict("fit"=>false,"jer_nominal"=>true,"corrections"=>["b"],"shape_variations"=>["jer"]), "corrections"=>Dict("flat"=>[Dict("name"=>"a","enabled"=>false), Dict("name"=>"b","nominal"=>1)]), "shape_variations"=>[Dict("name"=>"jes","kind"=>"jes"),Dict("name"=>"jer","kind"=>"jer")],"fit"=>Dict("normsys"=>[Dict("enabled"=>false)]))
    r=resolve_config(d)
    @test only(r["corrections"]["flat"])["name"]=="b"
    @test only(r["shape_variations"])["nominal"]===true
    @test !haskey(r,"fit")
    @test !haskey(r,"options")
    d["corrections"]["flat"][1]["enabled"]="yes"
    @test_throws ArgumentError resolve_config(d)
    @test resolve_config(Dict("fit"=>Dict("normsys"=>[Dict("name"=>"a","enabled"=>false)])))["fit"]["normsys"]==[]
end
end
