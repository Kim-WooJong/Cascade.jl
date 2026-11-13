# The old inline extraction oracle remains immutable. Check the current named
# stages against the preserved preimage as well; semantic/call-order/error
# comparisons below still execute the current production callable.
old = read(joinpath(@__DIR__, "..", "named_stages", "baseline_file_work.jl"), String)
new = read(H.src("Pipeline", "no_checkpoint_file_work.jl"), String)
for (name, label) in (("Select", "select"), ("Correct", "correct"), ("Histogram", "histogram"))
    start = findfirst("benchmark_span(:" * label, old).start
    body_start = findnext(" do" * Char(10), old, start).stop + 1
    body_end = findnext(Char(10) * "    end", old, body_start).start - 1
    oldbody = dedent(split(old[body_start:body_end], Char(10)))
    method = "function (stage::NoCheckpoint" * name * "Stage)()"
    start = findfirst(method, new).stop + 1
    alias_end = findnext(Char(10), new, start + 1)
    stop = findnext(Char(10) * "end", new, alias_end).start - 1
    newbody = dedent(split(new[alias_end+1:stop], Char(10)))
    @test oldbody == newbody
end
body_start = findfirst("function (unit::NoCheckpointFileWork)", new).start
body_end = findfirst("no_checkpoint_file_item_type() =", new).start
@test !occursin(" do" * Char(10), new[body_start:body_end])
