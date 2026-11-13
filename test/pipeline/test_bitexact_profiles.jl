module TestBitexactProfiles
using Test
# Run after test_real_reproduction.jl, with its same workdir. This tightens the
# original tolerance-based oracle to exact equality on every reported quantity.
if get(ENV,"CASCADE_REAL_DATA","0")=="1"
    @testset "Default profile bit-exact reference" begin
        work=get(ENV,"CASCADE_REAL_WORKDIR",joinpath(homedir(),"analisis","Cascade_dev","core","scratch","real"))
        rows=readlines(joinpath(work,"reproduction.tsv"))
        @test length(rows)>30
        for line in rows[2:end]
            @test parse(Float64,last(split(line,'\t')))==0.0
        end
    end
end
end
