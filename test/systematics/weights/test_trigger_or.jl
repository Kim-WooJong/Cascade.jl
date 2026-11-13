# All efficiencies in this file are synthetic test inputs, not measured data.
function write_trigger_fixture(path; data = (0.8, 0.9, 0.7), mc = (0.5, 0.6, 0.4))
    corrections = [Dict("name" => name, "version" => 1, "output" => fx_var("eff"),
        "inputs" => [fx_var("pt"), fx_var("syst", "string")],
        "data" => fx_category("syst", [(key, Dict("nodetype" => "binning", "input" => "pt",
            "edges" => [0.0, 50.0, 1000.0], "content" => [value / 2, value], "flow" => "error"))
            for (key, value) in zip(("nom", "up", "down"), vals)]))
        for (name, vals) in (("data_eff", data), ("mc_eff", mc))]
    open(path, "w") do io
        JSON3.write(io, Dict("schema_version" => 2, "corrections" => corrections))
    end
    return path
end

function trigger_fixture_term(; name = "trigger")
    binding(correction) = Dict{String,Any}("set" => "fx", "correction" => correction,
        "inputs" => Dict("pt" => "pt"), "systematic" => "syst",
        "nominal" => "nom", "up" => "up", "down" => "down")
    return Dict{String,Any}("name" => name, "path" => "HLT_TestSingleMuon",
        "topology" => "independent_single_path_or", "object" => "muons", "indices" => [1, 2],
        "data" => binding("data_eff"), "mc" => binding("mc_eff"))
end

@testset "independent single-path trigger OR" begin
    @test trigger_or_ratio([0.8, 0.8], [0.5, 0.5]) ≈ 0.96 / 0.75
    @test trigger_or_ratio([0.8, 0.8], [0.5, 0.5]) != (0.8 / 0.5)^2
    @test trigger_or_ratio([0.0, 1.0], [0.0, 1.0]) == 1.0
    @test trigger_or_ratio([0.0], [0.5]) == 0.0
    @test trigger_or_ratio([2e-200], [1e-200]) == 2.0
    @test_throws ArgumentError trigger_or_ratio([0.5], [0.0])
    @test_throws ArgumentError trigger_or_ratio(Float64[], Float64[])
    @test_throws ArgumentError trigger_or_ratio([0.5, 0.6], [0.5])
    for bad in (NaN, Inf, -0.1, 1.1, true)
        @test_throws ArgumentError trigger_or_ratio([bad], [0.5])
        @test_throws ArgumentError trigger_or_ratio([0.5], [bad])
    end
    mktempdir() do dir
        setpath = write_trigger_fixture(joinpath(dir, "trigger.json"))
        source = write_fixture_source(joinpath(dir, "source.cols"))
        term = trigger_fixture_term()
        corr = Dict{String,Any}("trigger_or" => [term])
        cfg = fixture_config(corr; setpath)
        spec = parse_corrections(cfg)
        @test !isempty(spec) && length(spec.trigger_ors) == 1
        @test spec.trigger_ors[1].path == "HLT_TestSingleMuon"
        table = fixture_table()
        weights = correction_weights(cfg, cfg.samples[1], source, table)
        ref(vals) = [begin
            d, m = vals
            ds = [table["v:mu$(k)_pt"][r] < 50 ? d / 2 : d for k in (1, 2)]
            ms = [table["v:mu$(k)_pt"][r] < 50 ? m / 2 : m for k in (1, 2)]
            table["weight"][r] * (1 - prod(1 .- ds)) / (1 - prod(1 .- ms))
        end for r in 1:nrows(table)]
        @test weights["nominal"] ≈ ref((0.8, 0.5))
        @test weights["triggerUp"] ≈ ref((0.9, 0.6))
        @test weights["triggerDown"] ≈ ref((0.7, 0.4))
        @test correction_weights(cfg, cfg.samples[2], source, table) == Dict("nominal" => table["weight"])
        # A nuisance shared with another correction varies both coherently.
        shared = deepcopy(corr)
        shared["flat"] = [Dict("name" => "trigger", "nominal" => 1.0, "up" => 1.1, "down" => 0.9)]
        ws = correction_weights(fixture_config(shared; setpath), cfg.samples[1], source, table)
        @test ws["nominal"] == weights["nominal"]
        @test ws["triggerUp"] ≈ weights["triggerUp"] .* 1.1
        @test ws["triggerDown"] ≈ weights["triggerDown"] .* 0.9
        # One payload can remain nominal while its counterpart varies.
        one_side = deepcopy(corr)
        delete!(one_side["trigger_or"][1]["mc"], "up")
        delete!(one_side["trigger_or"][1]["mc"], "down")
        wo = correction_weights(fixture_config(one_side; setpath), cfg.samples[1], source, table)
        @test wo["triggerUp"] ≈ ref((0.9, 0.5))
        @test wo["triggerDown"] ≈ ref((0.7, 0.5))
        # Eligibility changes the OR inputs, not a product of per-object SFs.
        eligible = deepcopy(corr); eligible["trigger_or"][1]["when"] = "pt > 50"
        @test_throws ArgumentError correction_weights(fixture_config(eligible; setpath), cfg.samples[1], source, table)
        subset = fixture_table(; n = 2); subset.columns["v:mu1_pt"] = [60.0, 60.0]
        subset.columns["v:mu2_pt"] = [15.0, 55.0]
        we = correction_weights(fixture_config(eligible; setpath), cfg.samples[1], source, subset)
        @test we["nominal"] ≈ subset["weight"] .* [0.8 / 0.5, 0.96 / 0.75]
        empty = fixture_table(; n = 0, entries = Int[])
        @test all(isempty, values(correction_weights(cfg, cfg.samples[1], source, empty)))
        for (key, bad) in (("topology", "double_leg"), ("indices", [1, 1]), ("indices", [true]),
                           ("object", "missing"), ("path", ""), ("when", 1))
            invalid = deepcopy(corr); invalid["trigger_or"][1][key] = bad
            @test_throws ArgumentError parse_corrections(fixture_config(invalid; setpath))
        end
        for invalid_value in (-0.1, 1.1)
            badpath = write_trigger_fixture(joinpath(dir, "bad$(invalid_value).json"); data = (invalid_value, 0.9, 0.7))
            @test_throws ArgumentError correction_weights(fixture_config(corr; setpath = badpath), cfg.samples[1], source, table)
        end
        # Invalid variation probabilities are rejected even when nominal is valid.
        badup = write_trigger_fixture(joinpath(dir, "badup.json"); data = (0.8, 1.2, 0.7))
        @test_throws ArgumentError correction_weights(fixture_config(corr; setpath = badup), cfg.samples[1], source, table)
        zero = write_trigger_fixture(joinpath(dir, "zero.json"); mc = (0.0, 0.6, 0.4))
        @test_throws ArgumentError correction_weights(fixture_config(corr; setpath = zero), cfg.samples[1], source, table)
        zero_up = write_trigger_fixture(joinpath(dir, "zero_up.json"); mc = (0.5, 0.0, 0.4))
        @test_throws ArgumentError correction_weights(fixture_config(corr; setpath = zero_up), cfg.samples[1], source, table)
        badkey = deepcopy(corr); badkey["trigger_or"][1]["data"]["nominal"] = 1
        @test_throws ArgumentError parse_corrections(fixture_config(badkey; setpath))
        # Option filtering preserves nested efficiency set aliases.
        raw = deepcopy(cfg.raw); raw["corrections"]["sets"]["unused"] = "unused.json"
        raw["options"] = Dict("corrections" => ["trigger"])
        resolved = Cascade.Config.resolve_config(raw; check_keys = false)
        @test collect(keys(resolved["corrections"]["sets"])) == ["fx"]
        raw["options"] = Dict("corrections" => String[])
        @test isempty(parse_corrections(parse_analysis(raw)))
        raw["options"] = Dict("corrections" => true)
        raw["corrections"]["trigger_or"][1]["enabled"] = false
        @test isempty(parse_corrections(parse_analysis(raw)))
    end
end
