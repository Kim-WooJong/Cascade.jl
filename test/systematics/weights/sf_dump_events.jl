function sf_dump_events(work, out, maxev, samples)
    n = 0
    open(out, "w") do io
        println(io, "path\tentry")
        for s in samples
            chunks = sf_chunk_rows(work, s)
            total = sum(length(c.entries) for c in chunks; init = 0)
            stride = maxev > 0 ? max(1, cld(total * length(samples), maxev)) : 1
            for (k, c) in enumerate(chunks)
                (k - 1) % stride == 0 || continue
                for e in c.entries
                    println(io, c.path, '\t', e)
                    n += 1
                end
            end
        end
    end
    println("wrote ", n, " events to ", out)
end
