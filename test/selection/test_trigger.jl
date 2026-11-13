module TestTrigger
using Test, Cascade.Config, Cascade.Selection

# Reference decision table (TTbarEmu.pass_trigger).
function ref_pass(emu, smu, sele, stream)
    stream == "MC" && return emu || smu || sele
    stream == "MuonEG" && return emu
    stream == "Muon" && return smu && !emu
    stream == "EGamma" && return sele && !emu && !smu
end

@testset "trigger_column (PD overlap removal)" begin
    t = TriggerConfig(Dict("emu" => ["A", "B"], "single_mu" => ["M"], "single_e" => ["E"]),
                      ["MuonEG", "Muon", "EGamma"],
                      Dict("MuonEG" => ["emu"], "Muon" => ["single_mu"], "EGamma" => ["single_e"]),
                      ["emu", "single_mu", "single_e"])
    combos = vec(collect(Iterators.product((false, true), (false, true), (false, true), (false, true))))
    cols = Dict{String,Any}("A" => [c[1] for c in combos], "B" => [c[2] for c in combos],
                            "M" => [c[3] for c in combos], "E" => [c[4] for c in combos])
    for (kind, stream, refname) in ((:mc, "", "MC"), (:data, "MuonEG", "MuonEG"), (:data, "Muon", "Muon"),
                                    (:data, "EGamma", "EGamma"))
        got = trigger_column(cols, t, kind, stream)
        @test got == [ref_pass(c[1] || c[2], c[3], c[4], refname) for c in combos]
    end
    @test sort(trigger_paths(t, :data, "EGamma")) == ["A", "B", "E", "M"]
    @test trigger_paths(t, :data, "MuonEG") == ["A", "B"]
    @test_throws ArgumentError trigger_paths(t, :data, "Nope")
    # every event lands in at most one primary dataset
    ds = [trigger_column(cols, t, :data, s) for s in t.priority]
    @test all(count(d[i] for d in ds) <= 1 for i in eachindex(combos))
    @test [any(d[i] for d in ds) for i in eachindex(combos)] == trigger_column(cols, t, :mc, "")
end
end
