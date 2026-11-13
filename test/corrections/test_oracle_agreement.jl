# Agreement with correctionlib (oracle outputs produced on gate by
# tools/oracle/run_oracle.sh). Needs CASCADE_REAL_DATA=1 and CASCADE_ORACLE_DIR.
include("oracle_compare.jl")

if get(ENV, "CASCADE_REAL_DATA", "0") == "1" && haskey(ENV, "CASCADE_ORACLE_DIR")
    @testset "oracle agreement" begin
        dir = ENV["CASCADE_ORACLE_DIR"]
        files = sort(filter(f -> endswith(f, ".oracle.json"), readdir(dir)))
        @test !isempty(files)
        for f in files
            rows = compare_oracle(joinpath(dir, f))
            t = summarize_oracle(stdout, replace(f, ".oracle.json" => ""), rows)
            @testset "$f" begin
                @test t.mismatches == 0
                @test t.vector_ok
                @test t.points > 0
            end
        end
    end
else
    @info "Skipping correctionlib oracle agreement (set CASCADE_REAL_DATA=1 and CASCADE_ORACLE_DIR)"
end
