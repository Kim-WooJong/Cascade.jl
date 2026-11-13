@testset "parse_corrections" begin
    mktempdir() do dir
        setpath = write_fixture_set(joinpath(dir, "fx.json"))
        good = Dict{String,Any}(
            "object_sf" => [Dict{String,Any}("name" => "lep", "set" => "fx", "correction" => "lep_sf", "object" => "muons",
                                             "indices" => [1, 2], "inputs" => Dict{String,Any}("eta" => "eta", "pt" => "pt"),
                                             "systematic" => "syst", "nominal" => "nom", "up" => "up", "down" => "down")],
            "event_weight" => [Dict{String,Any}("name" => "pu", "set" => "fx", "correction" => "pu",
                                                "inputs" => Dict{String,Any}("ntrue" => "Pileup_nTrueInt"),
                                                "systematic" => "which", "nominal" => "nominal")],
            "flat" => [Dict{String,Any}("name" => "trig", "up" => 1.02, "down" => 0.97)])
        spec = parse_corrections(fixture_config(good; setpath))
        @test length(spec.object_sfs) == 1 && length(spec.event_weights) == 1 && length(spec.flat) == 1
        @test spec.sets["fx"] == setpath
        t = spec.object_sfs[1]
        @test t.indices == [1, 2] && t.keys == ("nom", "up", "down") && t.when == ""
        @test spec.event_weights[1].keys == ("nominal", "", "")
        @test spec.flat[1] == FlatWeight("trig", 1.0, 1.02, 0.97)
        @test isempty(parse_corrections(parse_analysis(Dict{String,Any}())))

        # relative set path and paths substitution
        cfg = parse_analysis(Dict{String,Any}("paths" => Dict{String,Any}("pog" => "pogdir"),
                                              "corrections" => Dict{String,Any}("sets" => Dict{String,Any}("a" => "\${pog}/x.json"))); dir)
        @test parse_corrections(cfg).sets["a"] == joinpath(dir, "pogdir", "x.json")

        bad(f) = (c = deepcopy(good); f(c); c)
        msg(c) = try
            parse_corrections(fixture_config(c; setpath, variations = [Dict{String,Any}("name" => "scale", "up" => "1.1", "down" => "0.9")]))
            ""
        catch e
            e isa ArgumentError ? e.msg : rethrow()
        end
        @test occursin("unknown key 'typo'", msg(bad(c -> c["object_sf"][1]["typo"] = 1)))
        @test occursin("unknown set 'nope'", msg(bad(c -> c["object_sf"][1]["set"] = "nope")))
        @test occursin("unknown object 'taus'", msg(bad(c -> c["object_sf"][1]["object"] = "taus")))
        @test occursin("indices", msg(bad(c -> c["object_sf"][1]["indices"] = [0])))
        @test occursin("'nominal' key required", msg(bad(c -> delete!(c["object_sf"][1], "nominal"))))
        @test occursin("both 'up' and 'down'", msg(bad(c -> delete!(c["object_sf"][1], "down"))))
        @test occursin("need a 'systematic'", msg(bad(c -> delete!(c["object_sf"][1], "systematic"))))
        @test occursin("reserved", msg(bad(c -> c["flat"][1]["name"] = "nominal")))
        @test occursin("also a [weights] variation", msg(bad(c -> c["flat"][1]["name"] = "scale")))
        @test occursin("finite number", msg(bad(c -> delete!(c["flat"][1], "up"))))
        @test occursin("when", msg(bad(c -> c["object_sf"][1]["when"] = "pt <")))
        @test occursin("unknown key 'object_sfs'", msg(bad(c -> c["object_sfs"] = Any[])))
        @test msg(good) == ""
    end
end
