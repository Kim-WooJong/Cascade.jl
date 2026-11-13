"""
    write_cutflow_tsv(path, sample, cf, gen_weight_sum)

Cutflow table: header comment, then `stage  sumw  n_raw` per stage.
"""
function write_cutflow_tsv(path, sample, cf::Cutflow, gsum)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "# sample=", sample, " gen_sumw=", gsum)
        println(io, "stage\tsumw\tn_raw")
        for k in eachindex(cf.names)
            println(io, cf.names[k], '\t', cf.sumw[k], '\t', cf.n[k])
        end
    end
end
