@testset "fit result adapter and impact rows" begin
    F = Cascade.Fit
    mod(n, t, d = nothing) = Dict{String,Any}("name" => n, "type" => t, "data" => d)
    ws = Dict{String,Any}(
        "channels" => [Dict{String,Any}("name" => "SR", "samples" => [
            Dict{String,Any}("name" => "tt", "data" => [10.0, 20.0, 30.0],
                             "modifiers" => [mod("mu", "normfactor"), mod("st", "staterror", [1.0, 1.5, 2.0])]),
            Dict{String,Any}("name" => "dy", "data" => [5.0, 5.0, 5.0],
                             "modifiers" => [mod("dy_norm", "normsys", Dict("hi" => 1.1, "lo" => 0.9)),
                                             mod("st", "staterror", [0.5, 0.5, 0.5])])])],
        "observations" => [Dict{String,Any}("name" => "SR", "data" => [17.0, 27.0, 38.0])],
        "measurements" => [Dict{String,Any}("name" => "m", "config" => Dict{String,Any}("poi" => "mu", "parameters" => Any[]))],
        "version" => "1.0.0")
    m = F.HistModel(ws)
    r = F.fit(m, F.observed_data(m))
    fy = fit_yields(m, r, "SR"; edges = EDGES)
    cy = only(F.postfit_yields(m, r))
    @test fy.yields["tt"] ≈ cy.yields[1, :] && fy.yields["dy"] ≈ cy.yields[2, :]
    @test fy.errors_high ≈ cy.total_errors && fy.errors_low == fy.errors_high
    g = F.group_yields(m, r.parameters, r.covariance, "SR")
    @test fy.yield_errors["tt"] ≈ g.integrated_errors[1] && fy.total_error ≈ g.total_integrated_error
    one = fit_yields(m, r, "SR"; edges = EDGES, groups = ["all" => ["tt", "dy"]], label = "x")
    @test collect(keys(one.yields)) == ["all"] && one.yields["all"] ≈ cy.total && one.label == "x"
    c = StackConfig([SampleGroup("Z", "#1F77B4", ["dy"]), SampleGroup("t#bar{t}", "#C5001A", ["tt"])], ["D"])
    @test [x.name for x in postfit_groups(fy, c)] == ["Z", "t#bar{t}"]
    @test occursin("Total prediction", render_table(yield_table(fy, c)))
    @test_throws ArgumentError fit_yields(m, r, "SR"; edges = [0.0, 1.0])

    rows = impact_rows(Dict("parameters" => [Dict("name" => "a", "pull" => 0.5, "constraint" => 0.8),
                                             Dict("name" => "k", "pull" => nothing, "constraint" => nothing)],
                            "impacts" => [Dict("name" => "k", "postfit_up" => 0.2, "postfit_down" => -0.1,
                                               "prefit_up" => nothing, "prefit_down" => nothing),
                                          Dict("name" => "a", "postfit_up" => -0.05, "postfit_down" => 0.04,
                                               "prefit_up" => -0.06, "prefit_down" => 0.05)]))
    @test [x.name for x in rows] == ["k", "a"] && isnan(rows[1].pull) && isnan(rows[1].prefit_up)
    @test rows[2].pull == 0.5 && rows[2].postfit_down == 0.04
end
