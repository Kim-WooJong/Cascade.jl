@testset "build model" begin
    m = HistModel(ws_full())
    names = [p.name for p in m.parameters]
    @test m.channels == ["CR", "SR"]
    @test names == ["cr_mc[0]", "cr_mc[1]", "cr_mc[2]", "cr_mc[3]",
                    "dd_shape[0]", "dd_shape[1]", "dd_shape[2]", "dd_shape[3]",
                    "jes", "k_tt", "lumi", "mu", "other_xs", "shape", "sig_xs",
                    "staterror_SR[0]", "staterror_SR[1]", "staterror_SR[2]", "staterror_SR[3]"]
    @test m.parameters[m.poi].name == "mu"
    p(n) = m.parameters[m.index[n]]
    @test (p("mu").init, p("mu").lower, p("mu").upper, p("mu").constraint) == (1.0, 0.0, 10.0, :none)
    @test (p("k_tt").lower, p("k_tt").upper) == (0.0, 5.0)
    @test (p("lumi").aux, p("lumi").sigma, p("lumi").constraint) == (1.0, 0.017, :gauss)
    @test (p("jes").init, p("jes").lower, p("jes").upper) == (0.0, -5.0, 5.0)
    @test p("cr_mc[0]").tau ≈ (50 / 3)^2
    @test p("cr_mc[0]").constraint === :poisson
    @test p("staterror_SR[0]").sigma ≈ sqrt(0.3^2 + 1.0^2 + 0.5^2) / 27
    @test p("dd_shape[2]").constraint === :none
    @test m.observations == [63.0, 50.0, 39.0, 26.0, 30.0, 24.0, 22.0, 9.0]
    @test expected_main(m, [q.init for q in m.parameters]) ≈
          [60.0, 48.0, 36.0, 24.0, 27.0, 24.0, 21.0, 10.0]

    mm = HistModel(ws_masked())
    pm(n) = mm.parameters[mm.index[n]]
    @test pm("staterror_SR[1]").fixed
    @test pm("bkg_mc[1]").fixed
    @test !pm("staterror_SR[0]").fixed && !pm("bkg_mc[2]").fixed

    # JSON round trip through load_workspace
    path = tempname() * ".json"
    write(path, JSON3.write(ws_full()))
    m2 = HistModel(load_workspace(path))
    @test [q.name for q in m2.parameters] == names
    @test m2.observations == m.observations

    bad = ws_counting()
    bad["channels"][1]["samples"][1]["modifiers"][1]["type"] = "bogus"
    @test_throws ArgumentError HistModel(bad)
    @test_throws ArgumentError HistModel(ws_counting(); poi="nope")
end
