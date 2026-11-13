module TestDataQualityAliases
using Test
using Cascade.Config, Cascade.IO, Cascade.Selection

@testset "Configurable certification branch names" begin
    mktempdir() do dir
        maskpath = joinpath(dir, "golden.json")
        write(maskpath, "{\"10\":[[2,3]]}")
        raw = Dict{String,Any}(
            "samples" => [Dict("name" => "data", "kind" => "data", "format" => "cols", "files" => ["unused.cols"])],
            "data_quality" => Dict("golden_json" => maskpath, "run_range" => [10, 10],
                                   "run_branch" => "run_id", "lumi_branch" => "ls_id"),
            "cuts" => [Dict("name" => "certified", "expr" => "lumimask")])
        cfg = validate_analysis(parse_analysis(raw; dir))
        @test cfg.data_quality.run_branch == "run_id"
        @test cfg.data_quality.lumi_branch == "ls_id"
        p = joinpath(dir, "events.cols")
        write_column_file(p, Dict{String,Any}("run_id" => [10, 10, 10, 11], "ls_id" => [1, 2, 3, 2]))
        src = ColumnFileSource(p)
        try
            sel = compile_selection(cfg, :data)
            table, cf = run_selection(sel, src; lumimask = load_lumimask(maskpath; run_min = 10, run_max = 10))
            @test nrows(table) == 2
            @test table["entry"] == [2, 3]
            @test last(cf.n) == 2
        finally
            close_source(src)
        end
        for field in ("run_branch", "lumi_branch")
            bad = deepcopy(raw); bad["data_quality"][field] = ""
            @test_throws ArgumentError validate_analysis(parse_analysis(bad; dir))
        end
        @test DataQualityConfig().run_branch == "run"
        @test DataQualityConfig(1, 2, "").lumi_branch == "luminosityBlock"
    end
end
end
