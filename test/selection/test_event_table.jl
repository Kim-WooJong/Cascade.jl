module TestEventTable
using Test, Cascade.Selection

@testset "EventTable round trip" begin
    t = EventTable(Dict{String,Vector}("entry" => Int64[3, 9], "stage" => Int16[5, 6], "weight" => [1.0, -2.5],
                                       "h:x:1" => [NaN, 4.0]), ["entry", "stage", "weight", "h:x:1"],
                   Dict{String,Any}("region_stage" => Dict("r" => 5), "hist_columns" => Dict("x" => ["h:x:1"])))
    mktempdir() do d
        p = write_event_table(joinpath(d, "t.cols"), t)
        b = read_event_table(p)
        @test nrows(b) == 2 && b.order == t.order
        @test b["entry"] == [3, 9] && b["stage"] == Int16[5, 6] && isnan(b["h:x:1"][1])
        @test b.meta["region_stage"]["r"] == 5 && b.meta["hist_columns"]["x"] == ["h:x:1"]
    end
end
end
