# Per-event weights of a real run vs the independent Python correctionlib oracle
# (tools/oracle/sf_oracle.py). Enabled with CASCADE_SF_ORACLE=<oracle output TSV>
# and CASCADE_SF_WORKDIR=<workdir of the analysis.toml --profile sf run>.
include("sf_artifacts.jl")

if haskey(ENV, "CASCADE_SF_ORACLE")
    @testset "scale factors vs Python correctionlib oracle" begin
        work = ENV["CASCADE_SF_WORKDIR"]
        lines = readlines(ENV["CASCADE_SF_ORACLE"])
        hdr = split(lines[1], '\t')
        @test hdr[1:2] == ["path", "entry"]
        labels = String.(hdr[3:end])
        ref = Dict{Tuple{String,Int},Vector{Float64}}()
        for l in lines[2:end]
            f = split(l, '\t')
            ref[(String(f[1]), parse(Int, f[2]))] = parse.(Float64, f[3:end])
        end
        samples = unique(String.(split(get(ENV, "CASCADE_SF_SAMPLES", "TTto2L2Nu"), ',')))
        nmatch = 0; maxrel = Dict(l => 0.0 for l in labels); nexact = 0; nval = 0
        for s in samples, c in sf_chunk_rows(work, s)
            @test sort(c.labels) == sort(labels)
            for (i, e) in enumerate(c.entries)
                r = get(ref, (c.path, e), nothing)
                r === nothing && continue
                nmatch += 1
                for (j, l) in enumerate(labels)
                    a = c.weights[l][i]; b = r[j]
                    d = a == b ? 0.0 : abs(a - b) / max(abs(a), abs(b))
                    nval += 1; nexact += (a == b)
                    maxrel[l] = max(maxrel[l], d)
                end
            end
        end
        println("oracle rows: ", length(ref), ", matched: ", nmatch, ", values: ", nval, ", bit-identical: ", nexact)
        for l in labels
            println("  ", rpad(l, 20), " max rel diff ", maxrel[l])
        end
        @test nmatch == length(ref)
        @test nmatch >= 1000
        @test all(v <= 1e-12 for v in values(maxrel))
    end
end
