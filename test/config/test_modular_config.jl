module TestModularConfig
using Test, TOML, SHA
using Cascade.Config
const ROOT = normpath(joinpath(@__DIR__, "../.."))
const ENTRY = joinpath(ROOT, "analyses/ttbar_emu/analysis.toml")
const MONOLITH = joinpath(@__DIR__, "fixtures/ttbar_emu_monolith.toml")
err(f) = try f(); "no error" catch e; sprint(showerror, e) end

# Recursive typed comparison: dictionaries unordered, arrays ordered, floats bit-exact.
function same_value(a, b)
    typeof(a) === typeof(b) || return false
    a isa AbstractDict && return keys(a) == keys(b) && all(same_value(a[k], b[k]) for k in keys(a))
    a isa AbstractArray && return axes(a) == axes(b) && all(same_value(x,y) for (x,y) in zip(a,b))
    a isa AbstractFloat && return bitstring(a) == bitstring(b)
    isstructtype(typeof(a)) && !(a isa AbstractString) && fieldcount(typeof(a)) > 0 &&
        return all(same_value(getfield(a,k),getfield(b,k)) for k in fieldnames(typeof(a)))
    return isequal(a,b)
end

@testset "modular TOML: monolith equivalence, all profiles" begin
    before = TOML.parsefile(MONOLITH)
    after = read_analysis_source(ENTRY)
    @test before == after.raw
    @test !haskey(after.raw, "include")
    @test length(after.provenance["dependencies"]) == 11
    profiles = vcat([""], sort!(collect(keys(before["profiles"]))))
    for profile in profiles
        old = parse_analysis(before; path = ENTRY, dir = dirname(ENTRY), profile)
        new = load_analysis(ENTRY; profile, validate=false)
        @test validate_keys(after.raw) === after.raw
        @test old.raw == new.raw
        for field in fieldnames(AnalysisConfig)
            # Compare every nested typed value, including resolved sample/Golden paths.
            @test same_value(getfield(old, field), getfield(new, field))
        end
        for section in union(keys(old.raw), keys(new.raw))
            @test section_hash(old, section) == section_hash(new, section)
        end
        @test same_value(shape_variations(old), shape_variations(new))
        @test canonical_hash(old.raw) == canonical_hash(new.raw)
    end
    @test parse_analysis(Dict("analysis" => Dict("name" => "dict API"))).name == "dict API"
end

@testset "explicit include semantics and fail-closed errors" begin
    mktempdir() do dir
        mkpath(joinpath(dir,"sub"))
        entry = joinpath(dir,"analysis.toml")
        leaf = joinpath(dir,"sub/leaf.toml")
        middle = joinpath(dir,"sub/middle.toml")
        write(entry, "include = [\"sub/middle.toml\"]\n[analysis]\nname = \"example\"\n")
        write(middle, "include = [\"leaf.toml\"]\n[analysis]\nlumi_pb=1.0\n")
        write(leaf, "[[samples]]\nname=\"data\"\nkind=\"data\"\nfiles=[\"input.root\"]\n[data_quality]\ngolden_json=\"golden.json\"\n[weights]\nmc=[\"second\",\"first\"]\n")
        source = read_analysis_source(entry)
        @test basename.(getindex.(source.provenance["dependencies"],"path")) == ["analysis.toml","middle.toml","leaf.toml"]
        cfg = load_analysis(entry; validate=false)
        @test cfg.samples[1].files == [joinpath(dir,"input.root")]
        @test cfg.data_quality.golden_json == joinpath(dir,"golden.json")
        @test cfg.weights_mc == ["second","first"]
        @test cfg.raw["analysis"]["lumi_pb"] == 1.0
        @test verify_config_provenance(entry,source.provenance) == source.provenance
        write(middle, "include=[\"../analysis.toml\"]\n")
        @test occursin("cycle",err(()->read_analysis_source(entry)))
        write(middle,"include=[\"leaf.toml\",\"./leaf.toml\"]\n")
        @test occursin("more than once",err(()->read_analysis_source(entry)))
        hardlink(leaf,joinpath(dir,"sub/hard.toml"))
        write(middle,"include=[\"leaf.toml\",\"hard.toml\"]\n")
        @test occursin("more than once",err(()->read_analysis_source(entry)))
        symlink(entry,joinpath(dir,"sub/root-alias.toml"))
        write(middle,"include=[\"root-alias.toml\"]\n")
        @test occursin("cycle",err(()->read_analysis_source(entry)))
        symlink(leaf,joinpath(dir,"sub/alias.toml"))
        write(middle,"include=[\"leaf.toml\",\"alias.toml\"]\n")
        @test occursin("more than once",err(()->read_analysis_source(entry)))
        write(middle,"include=[\"missing.toml\"]\n")
        @test occursin("missing.toml",err(()->read_analysis_source(entry)))
        for bad in ("true", "\"leaf.toml\"", "[1]", "[\"\"]", "{}")
            write(middle,"include="*bad*"\n")
            @test occursin("include must be",err(()->read_analysis_source(entry)))
        end
        write(middle,"[analysis]\nname=\"example\"\n")
        message=err(()->read_analysis_source(entry))
        @test occursin("analysis.name",message) && occursin("middle.toml",message) && occursin("analysis.toml",message)
        write(middle,"include=[\"leaf.toml\"]\n[weights]\nmc=[\"same\"]\n")
        @test occursin("weights.mc",err(()->read_analysis_source(entry)))
        write(middle,"include=[\"leaf.toml\"]\n[[samples]]\nname=\"other\"\nfiles=[]\n")
        @test occursin("samples",err(()->read_analysis_source(entry)))
        write(middle,"[profiles.inactive.analysis]\nnot_a_key=true\n")
        message=err(()->read_analysis_source(entry))
        @test occursin("middle.toml",message) && occursin("not_a_key",message)
        write(middle,"broken = [\n")
        @test occursin("middle.toml",err(()->read_analysis_source(entry)))
        write(middle,"[profiles.p.options]\nfit=false\n")
        @test !haskey(load_analysis(entry;validate=false,profile="p").raw,"profiles")
        write(entry,"include=[\"sub/middle.toml\"]\n[profiles.p.options]\nfit=true\n")
        @test occursin("profiles.p.options.fit",err(()->read_analysis_source(entry)))
    end
end

@testset "existing typed validation remains active" begin
    mktempdir() do dir
        p=joinpath(dir,"analysis.toml"); f=joinpath(dir,"samples.toml")
        write(p,"include=[\"samples.toml\"]\n[analysis]\nname=\"validation\"\n")
        sample="[[samples]]\nname=\"data\"\nkind=\"data\"\nfiles=[\"not-opened.root\"]\n"
        write(f,sample)
        @test load_analysis(p).name == "validation"
        write(f,sample*sample)
        @test occursin("duplicate sample name",err(()->load_analysis(p)))
        write(f,"[profiles.inactive]\ninclude=[]\n")
        @test occursin("unknown key 'include'",err(()->read_analysis_source(p)))
        # Depth limit is tested using only tiny TOMLs, no data access.
        for i in 1:65
            write(joinpath(dir,"depth$i.toml"), i==65 ? "[analysis]\nname=\"depth\"\n" : "include=[\"depth$(i+1).toml\"]\n")
        end
        @test occursin("depth exceeds 64",err(()->read_analysis_source(joinpath(dir,"depth1.toml"))))
    end
end

@testset "cross-fragment relations validate only after composition" begin
    mktempdir() do dir
        entry=joinpath(dir,"analysis.toml"); a=joinpath(dir,"a.toml"); b=joinpath(dir,"b.toml")
        write(entry, "include=[\"a.toml\",\"b.toml\"]\n")
        write(a,"[execution]\nwindowed_reusable_decoder=true\n")
        write(b,"[execution]\nwindowed_selection=true\n")
        @test read_analysis_source(entry).raw["execution"]["windowed_reusable_decoder"] === true
        write(b,"[execution]\nwindowed_selection=false\n")
        @test occursin("requires execution.windowed_selection",err(()->read_analysis_source(entry)))
        write(a,"[execution]\nstream_metadata_bytes=4096\n[profiles.valid.execution]\nevent_range_selection=true\n")
        write(b,"[profiles.valid.execution]\nstream_queue_bytes=8192\n")
        @test read_analysis_source(entry).raw["profiles"]["valid"]["execution"]["stream_queue_bytes"] == 8192
        write(b,"[profiles.valid.execution]\nstream_queue_bytes=2048\n")
        @test_throws ArgumentError read_analysis_source(entry)
    end
end

@testset "config closure identity: batch and source provenance" begin
    mktempdir() do dir
        entry=joinpath(dir,"analysis.toml"); a=joinpath(dir,"a.toml"); b=joinpath(dir,"b.toml")
        write(a,"[analysis]\nname=\"closure\"\n")
        write(b,"[profiles.inactive.options]\nfit=false\n")
        text="include=[\"a.toml\",\"b.toml\"]\n"; write(entry,text)
        p=config_provenance(entry)
        manifest=Dict("config_sha256"=>p["sha256"],"config_sha256_scope"=>p["scope"],"config_dependencies"=>p["dependencies"])
        @test verify_config_manifest(entry,manifest)==p
        @test occursin("closure-v1",p["scope"])
        @test_throws ArgumentError verify_config_manifest(entry,Dict("config_sha256"=>p["sha256"]))
        cfg=load_analysis(entry;validate=false)
        write(b,"[profiles.inactive.options]\nfit=true\n")
        @test load_analysis(entry;validate=false).raw == cfg.raw
        @test config_provenance(entry)["sha256"] != p["sha256"]
        @test_throws ArgumentError verify_config_manifest(entry,manifest)
        @test_throws ArgumentError verify_config_sources(p)
        @test_throws ArgumentError verify_config_provenance(entry,p)
        write(b,"[profiles.inactive.options]\nfit=false\n")
        write(entry,"include=[\"b.toml\",\"a.toml\"]\n")
        @test load_analysis(entry;validate=false).raw == cfg.raw
        @test config_provenance(entry)["sha256"] != p["sha256"]
        @test_throws ArgumentError verify_config_manifest(entry,manifest)
        write(entry,text); rm(b)
        @test_throws ArgumentError verify_config_manifest(entry,manifest)
        write(entry,"include=[\"a.toml\"]\n")
        @test config_provenance(entry)["sha256"] != p["sha256"]
        single=config_provenance(a)
        @test single["sha256"] == bytes2hex(sha256(read(a)))
        @test verify_config_manifest(a,Dict("config_sha256"=>single["sha256"]))==single
        write(entry,"include=[]\n[analysis]\nname=\"single\"\n")
        @test config_provenance(entry)["sha256"] == bytes2hex(sha256(read(entry)))
    end
end
end
