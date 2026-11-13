module TestChannelOverlap
using Test, JSON3
using Cascade.Config, Cascade.Selection, Cascade.Histograms, Cascade.Fit

function config(; regions = [Dict("name" => "A", "after" => "all", "expr" => "x < 2"),
                             Dict("name" => "B", "after" => "all", "expr" => "x >= 2"),
                             Dict("name" => "inclusive", "after" => "all")],
                  histograms = [Dict("name" => "x", "edges" => [0., 1., 3.], "values" => ["x"])],
                  channels = [Dict("name" => "a", "region" => "A", "variable" => "x"),
                              Dict("name" => "b", "region" => "B", "variable" => "x")])
    return parse_analysis(Dict{String,Any}(
        "analysis" => Dict("lumi_pb" => 1.),
        "samples" => [Dict("name" => "sig", "kind" => "mc", "xsec_pb" => 1., "files" => ["sig.cols"]),
                      Dict("name" => "data", "kind" => "data", "files" => ["data.cols"])],
        "regions" => regions, "histograms" => histograms,
        "fit" => Dict("signal" => ["sig"], "channels" => channels, "staterror" => false)))
end

function inputs(cfg; x = [-1., 0., 1., 2., Inf, NaN])
    table, _ = select_events(compile_selection(cfg, :data), Dict("x" => x), length(x); sample = "data")
    vals = Dict(h.name => Vector{Float64}[table[c] for c in table.meta["hist_columns"][h.name]] for h in cfg.histograms)
    masks = [r.name => region_masks(table)[r.name] for r in cfg.regions]
    store = HistogramStore()
    for sample in ("data", "sig")
        fill_store!(store, sample, cfg.histograms, vals, masks, [NOMINAL => table["weight"]])
    end
    store.meta["fit_channel_provenance"] = channel_overlap_provenance(table, cfg)
    return table, store
end

@testset "actual selected-event fit channel overlap" begin
    cfg = config()
    table, store = inputs(cfg)
    fc = fit_config(cfg)
    p = store.meta["fit_channel_provenance"]
    @test only(p["samples"]["data"]["overlaps"])["n"] == 0
    @test p["samples"]["data"]["channel_events"] == Dict("a" => 2, "b" => 2)
    @test validate_channel_disjointness(store, fc) === nothing
    @test length(build_workspace(store, fc).workspace["channels"]) == 2
    # An unused inclusive histogram region does not make an exclusive fit invalid.
    @test count(region_masks(table)["inclusive"]) == 6
    @test haskey(store, HistKey("inclusive", "data", NOMINAL, "x"))

    copied = Dict{String,Any}()
    @test merge_channel_provenance!(copied, p) === copied
    merge_channel_provenance!(copied, p)
    @test copied["samples"]["data"]["channel_events"] == Dict("a" => 4, "b" => 4)
    @test p["samples"]["data"]["channel_events"]["a"] == 2 # deep copy, no mutation of source
    path = write_store(joinpath(mktempdir(), "store.json"), store)
    @test validate_channel_disjointness(read_store(path), fc) === nothing

    delete!(store.meta, "fit_channel_provenance")
    @test_throws ArgumentError build_workspace(store, fc)
    expected = deepcopy(cfg.raw); expected["fit"]["asimov"] = true
    @test length(build_workspace(store, fit_config(parse_analysis(expected))).workspace["channels"]) == 2
    single = deepcopy(cfg.raw); single["fit"]["channels"] = single["fit"]["channels"][1:1]
    @test length(build_workspace(store, fit_config(parse_analysis(single))).workspace["channels"]) == 1

    nested = config(channels = [Dict("name" => "a", "region" => "A", "variable" => "x"),
                                Dict("name" => "all", "region" => "inclusive", "variable" => "x")])
    _, ns = inputs(nested)
    err = try build_workspace(ns, fit_config(nested)); nothing catch e; e end
    @test err isa ArgumentError
    @test occursin("'a' and 'all' overlap in 2", sprint(showerror, err))
    # Exact entry masks reject overlap even if all observation weights cancel.
    ns["A", "data", NOMINAL, "x"].sumw .= 0.
    @test_throws ArgumentError build_workspace(ns, fit_config(nested))
end

@testset "two histogram channels in the same region" begin
    common = [Dict("name" => "R", "after" => "all")]
    channels = [Dict("name" => "low", "region" => "R", "variable" => "x"),
                Dict("name" => "high", "region" => "R", "variable" => "y")]
    histograms = [Dict("name" => "x", "edges" => [0., 1., 3.], "values" => ["x"], "when" => "x < 1"),
                  Dict("name" => "y", "edges" => [0., 1., 3.], "values" => ["x"], "when" => "x >= 1")]
    cfg = config(; regions = common, channels, histograms)
    _, store = inputs(cfg)
    @test validate_channel_disjointness(store, fit_config(cfg)) === nothing
    @test store.meta["fit_channel_provenance"]["samples"]["data"]["channel_events"] == Dict("low" => 1, "high" => 3)
    histograms[1]["when"] = "true"
    cfg2 = config(; regions = common, channels, histograms)
    _, store2 = inputs(cfg2)
    @test only(store2.meta["fit_channel_provenance"]["samples"]["data"]["overlaps"])["n"] == 3
    @test_throws ArgumentError build_workspace(store2, fit_config(cfg2))
    @test_throws ArgumentError merge_channel_provenance!(deepcopy(store.meta["fit_channel_provenance"]),
        channel_overlap_provenance(first(inputs(config())), config()))
    # A subset fit checks only active channels, not recorded overlap elsewhere.
    one = deepcopy(cfg2.raw); one["fit"]["channels"] = channels[1:1]
    @test validate_channel_disjointness(store2, fit_config(parse_analysis(one))) === nothing
end
end
