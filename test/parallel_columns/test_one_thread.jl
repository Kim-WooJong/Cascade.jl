module TestColumnOneThread
using Test, Cascade
using Cascade.IO
if get(ENV,"CASCADE_PARALLEL_ONE_THREAD","0")=="1"
@testset "native one-thread fallback" begin
    @test Threads.nthreads()==1
    src=NanoAODSource(ENV["CASCADE_PARALLEL_MC"])
    try
        d=Dict{String,Any}()
        @test with_column_readers(s->s===nothing,src;readers=4,diagnostics=d)
        @test d["fallback"]=="one_thread"
        @test d["extra_opens"]==d["extra_closes"]==0
        @test d["effective_readers"]==1 && d["max_active_reads"]==0
    finally
        close_source(src)
    end
end
end
end
