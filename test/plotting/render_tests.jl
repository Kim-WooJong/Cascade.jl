@testset "rendering (native ROOT)" begin
    if !ROOTPlots.root_available()
        @test_skip "native ROOT not available"
    else
        dir = mktempdir()
        t = fixture_templates()
        c = fixture_config()
        p = plot_prefit(t, c, joinpath(dir, "prefit"); xlabel="x", lumi="1 fb^{-1}", logy=true)
        @test all(f -> isfile(f) && filesize(f) > 0, (p.files.png, p.files.pdf))
        fy = FitYields(EDGES, Dict("A" => [11.0, 19.0, 34.0], "B" => [5.0, 5.0, 5.0]), [1.0, 1.0, 1.0])
        q = plot_postfit(merge_data(t, c), fy, c, joinpath(dir, "postfit"); xlabel="x", format=:png)
        @test isfile(q.files.png) && q.files.pdf === nothing
        cf = group_cutflow(Cutflow(["all", "sel"], Dict("A" => [100.0, 10.0], "B" => [20.0, 2.0], "D" => [130.0, 13.0]);
                                   data=["D"]), c)
        @test isfile(plot_cutflow(cf, c, joinpath(dir, "cutflow_data"); format=:png).files.png)
        mc = group_cutflow(Cutflow(["all", "sel"], Dict("A" => [100.0, 10.0], "B" => [20.0, 2.0])),
                           StackConfig(c.groups, String[]))
        @test isfile(plot_cutflow(mc, c, joinpath(dir, "cutflow_mc"); format=:png).files.png)
        rows = [(name = "jes", pull = 0.4, constraint = 0.7, postfit_up = 0.03, postfit_down = -0.025,
                 prefit_up = 0.04, prefit_down = -0.035),
                (name = "staterror_SR[0]", pull = -0.2, constraint = 0.95, postfit_up = -0.01, postfit_down = 0.012,
                 prefit_up = -0.011, prefit_down = 0.013),
                (name = "k_dy", pull = NaN, constraint = NaN, postfit_up = 0.005, postfit_down = -0.004,
                 prefit_up = NaN, prefit_down = NaN)]
        im = plot_impacts(rows, joinpath(dir, "impacts"); title = "#hat{#mu} = 1.00 #pm 0.05", format = :both)
        @test all(f -> isfile(f) && filesize(f) > 0, (im.files.png, im.files.pdf)) && length(im.rows) == 3
        @test length(plot_impacts(rows, joinpath(dir, "impacts2"); max_rows = 2, format = :png).rows) == 2
        @test_throws ArgumentError plot_impacts(NamedTuple[], joinpath(dir, "none"))
    end
end
