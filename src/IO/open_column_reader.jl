"""Open one independent reader and reject a different input generation."""
function open_column_reader(src::NanoAODSource, expected)
    column_source_identity(src; expected)
    extra = NanoAODSource(src.path; tree = src.tree, runs_tree = src.runs_tree, gen_sumw = src.gen_sumw)
    try
        column_source_identity(extra; expected)
        return extra
    catch
        close_source(extra)
        rethrow()
    end
end
