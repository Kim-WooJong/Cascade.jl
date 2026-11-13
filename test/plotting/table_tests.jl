@testset "tables" begin
    @test format_fixed(5509.73, 1) == "5509.7"
    @test format_fixed(3, 2) == "3.00"
    @test format_fixed(0.012, 2) == "0.01"
    @test format_fixed(-0.04, 1) == "0.0"
    @test format_fixed(-2.26, 1) == "-2.3"
    @test format_fixed(1.0e12, 1) == "1000000000000.0"
    @test format_fixed(NaN, 1) == "n/a"
    @test format_label("t#bar{t}", :text) == "tt\u0304"
    @test format_label("p_{T} (GeV)", :text) == "p_T (GeV)"
    @test format_label("e#mu, #geq1 jet", :text) == "eμ, ≥1 jet"
    @test format_label("p_{T}", :markdown) == "p\\_T"
    @test format_label("t#bar{t}", :latex) == "\$t\\bar{t}\$"
    @test format_label("DYto2L_MLL50", :latex) == "DYto2L\\_MLL50"
    @test format_label("Eff. (%)", :latex) == "Eff. (\\%)"

    t = fixture_templates()
    c = fixture_config()
    g = group_templates(t, c)
    d = merge_data(t, c)
    yt = yield_table(g; data=d, nuisances=[Nuisance("jes")])
    txt = render_table(yt)
    @test yt.header == ["Process", "Yield", "Stat.", "Syst."]
    @test occursin("60.0", txt) && occursin("± 7.7", txt)            # A: 60 ± sqrt(60)
    @test occursin("+4.0 / -0.0", txt) && occursin("+5.0 / -0.0", txt)
    @test occursin("Total prediction", txt) && occursin("80.0", txt)
    @test occursin("1.067", txt)                                        # 80 / 75
    md = render_table(yt; format=:markdown)
    @test startswith(md, "| Process | Yield | Stat. | Syst. |\n|:---|---:|---:|---:|")
    tex = render_table(yield_table(g; nuisances=[Nuisance("jes")], caption="Yields"); format=:latex)
    @test occursin("\\begin{tabular}{lrrr}", tex) && occursin("\$t\\bar{t}\$", tex)
    @test occursin("\$\\pm 7.7\$", tex) && occursin("\$^{+4.0}_{-0.0}\$", tex) && occursin("\\caption{Yields}", tex)
    nos = yield_table(g; nuisances=Nuisance[])
    @test nos.header == ["Process", "Yield", "Stat."]
    @test sprint(show, MIME"text/plain"(), yt) == txt

    ut = uncertainty_table(g; nuisances=[Nuisance("jes"), Nuisance("toppt"; down=nothing)])
    u = render_table(ut)
    @test ut.header == ["Source (%)", "Bkg B", "t#bar{t}", "Total"]
    @test ut.rows[1][1] == "jes"                                       # sorted by total impact
    @test occursin("+6.67 / -0.00", u)                                  # jes on A: 4 / 60
    @test occursin("+6.67 / -0.00", u) && occursin("± 1.67", u)        # toppt on A: 1 / 60
    @test occursin("MC stat.", u) && occursin("Total syst.", u)
    @test_throws ArgumentError TextTable(["a", "b"], [["x"]])
    @test_throws ArgumentError render_table(yt; format=:html)
end
