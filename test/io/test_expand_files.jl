module TestExpandFiles
using Test, Cascade.IO

@testset "expand_files" begin
    mktempdir() do d
        for p in ["a/v1/1/x.root", "a/v1/2/y.root", "a/v2/1/z.root", "a/v2/1/w.txt", "b/v1/1/q.root"]
            mkpath(dirname(joinpath(d, p))); write(joinpath(d, p), "")
        end
        got = expand_files([joinpath(d, "a/*/*/*.root")])
        @test got == sort([joinpath(d, p) for p in ["a/v1/1/x.root", "a/v1/2/y.root", "a/v2/1/z.root"]])
        @test expand_files([joinpath(d, "a/v?/1/[xz].root")]) == [joinpath(d, "a/v1/1/x.root"), joinpath(d, "a/v2/1/z.root")]
        @test isempty(expand_files([joinpath(d, "c/*/*.root")]))
        @test expand_files(["/literal/b.root", "/literal/a.root"]) == ["/literal/a.root", "/literal/b.root"]
        @test expand_files([joinpath(d, "a/v1/*/x.root"), joinpath(d, "a/v1/1/*.root")]) == [joinpath(d, "a/v1/1/x.root")]
    end
end
end
