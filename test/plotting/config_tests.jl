@testset "stack configuration" begin
    toml = """
    [plotting]
    data = ["D"]
    [[plotting.groups]]
    label = "Bkg B"
    color = "#1F77B4"
    samples = ["B"]
    [[plotting.groups]]
    label = "t#bar{t}"
    color = "#C5001A"
    samples = ["A"]
    """
    path = tempname() * ".toml"
    write(path, toml)
    c = stack_config(path)
    @test [g.label for g in c.groups] == ["Bkg B", "t#bar{t}"] && c.data == ["D"]
    @test stack_config(Dict("groups" => [Dict("label" => "x", "color" => "#000000", "samples" => ["s"])])).data == String[]
    @test_throws ArgumentError SampleGroup("x", "red", ["a"])
    @test_throws ArgumentError StackConfig([SampleGroup("x", "#000000", ["a"]), SampleGroup("y", "#000000", ["a"])], String[])
    @test_throws ArgumentError StackConfig([SampleGroup("x", "#000000", ["a"])], ["a"])
    @test_throws ArgumentError stack_config(Dict("groups" => [Dict("label" => "x", "samples" => ["s"])]))

    t = fixture_templates()
    g = group_templates(t, c)
    @test [x.name for x in g] == ["Bkg B", "t#bar{t}"]
    @test g[2].nominal.sumw == [10.0, 20.0, 30.0]
    @test merge_data(t, c).sumw == [16.0, 24.0, 40.0]
end
