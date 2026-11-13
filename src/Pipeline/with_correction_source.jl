"""Run one correction chunk with a lazy owner, or the compatibility fallback."""
function with_correction_source(run, f, sample, path)
    source = correction_chunk_source(f, sample, path)
    try
        return run(source)
    finally
        source === nothing || close_source(source)
    end
end
