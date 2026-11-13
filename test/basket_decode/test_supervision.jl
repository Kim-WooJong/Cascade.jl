function settled(d)
    @test d["workers_joined"] && d["tasks_done"]
    @test d["active_decoders_final"]==0
    @test d["live_jobs_final"]==d["live_bytes_final"]==d["retained_payloads_final"]==0
    @test d["credits_reserved"]==d["credits_released"]
    @test d["bytes_reserved"]==d["bytes_released"]
end
@testset "whole-worker fatal supervision and partial scheduling" begin
    for stage in (:before_start_wait,:before_input,:before_active,:after_active,:before_decode,:after_decode,:before_publish,:after_publish)
        d=Dict{String,Any}();failure=ErrorException("lifecycle $stage")
        hook=(where,k)->(where==stage && throw(failure))
        e=try
            I.run_decode_queue([1],identity,identity,(k,v)->nothing;actors=2,max_jobs=1,max_bytes=1,diagnostics=d,worker_hook=hook)
            nothing
        catch e;e;end
        @test e isa I.DecodeWorkerError
        @test e.exception===failure
        @test !isempty(e.backtrace)
        settled(d)
    end
    for point in (:before_create,:before_start,:after_start)
        d=Dict{String,Any}();tasks=Task[];entered=Channel{Bool}(1);calls=Threads.Atomic{Int}(0)
        worker=(where,k)->(where==:before_input && Threads.atomic_add!(calls,1)==0 && put!(entered,true))
        failure=ErrorException("partial schedule $point")
        spawn=function(where,slot,task)
            where==:before_start && push!(tasks,task)
            if where==point && slot==2
                take!(entered);throw(failure)
            end
        end
        e=try
            I.run_decode_queue([1,1],identity,identity,(k,v)->nothing;actors=3,max_jobs=2,max_bytes=2,diagnostics=d,worker_hook=worker,spawn_hook=spawn)
            nothing
        catch e;e;end
        @test e===failure
        @test length(tasks)==(point==:before_create ? 1 : 2) && all(istaskdone,tasks)
        @test d["created_workers"]==(point==:before_create ? 1 : 2)
        settled(d)
    end
end
@testset "fatal notifier independent of full result capacity" begin
    d=Dict{String,Any}();release=Channel{Bool}(1);observer=Ref{Task}();seen=Ref(false)
    control=function(where,value)
        if where==:ready
            state=value
            observer[]=@async begin
                try
                    lock(state.guard) do
                        while isempty(state.fatals);wait(state.ready);end
                        seen[]=length(state.completed)==1
                    end
                finally
                    put!(release,true)
                end
            end
        elseif where==:after_admit
            take!(release)
        end
    end
    hook=(where,k)->(where==:after_publish && error("fatal after full publication"))
    e=try
        I.run_decode_queue([1],identity,identity,(k,v)->nothing;actors=2,max_jobs=1,max_bytes=1,diagnostics=d,worker_hook=hook,controller_hook=control)
    catch e;e;end
    wait(observer[])
    @test e isa I.DecodeWorkerError
    @test seen[]
    settled(d)
end
@testset "safe cancellation at input/result parks and decoder boundary" begin
    for stage in (:before_input,:before_publish,:decoder)
        d=Dict{String,Any}();parked=Channel{Bool}(1);release=Channel{Bool}(1);assembled=Ref(false)
        hook=function(where,k)
            if where==stage
                put!(parked,true);take!(release);throw(InterruptException())
            end
        end
        control=function(where,value)
            if where==:before_wait && stage!=:decoder
                take!(parked);put!(release,true)
            end
        end
        decoder=x->(stage==:decoder ? throw(InterruptException()) : x)
        @test_throws InterruptException I.run_decode_queue([1],identity,decoder,(k,v)->(assembled[]=true);
            actors=2,max_jobs=1,max_bytes=1,diagnostics=d,worker_hook=hook,controller_hook=control)
        @test !assembled[]
        settled(d)
    end
    d=Dict{String,Any}();started=Channel{Bool}(1);release=Channel{Bool}(1);observer=Ref{Task}()
    control=function(where,value)
        if where==:ready
            observer[]=@async begin
                try
                    take!(started);I.cancel_decode_queue!(value)
                finally
                    put!(release,true)
                end
            end
        end
    end
    decoder=x->(put!(started,true);take!(release);x)
    @test_throws InterruptException I.run_decode_queue([1,1],identity,decoder,(k,v)->nothing;
        actors=2,max_jobs=1,max_bytes=1,diagnostics=d,controller_hook=control)
    wait(observer[]);settled(d)
end
@testset "lower assembly error wins over higher decode failure" begin
    done2=Channel{Bool}(1);d=Dict{String,Any}()
    decoder=k->(k==2 ? (put!(done2,true);error("upper decode")) : (take!(done2);sleep(0.01);k))
    e=try
        I.run_decode_queue([1,1],identity,decoder,(k,v)->error("lower assembly");actors=3,max_jobs=2,max_bytes=2,diagnostics=d)
    catch e;e;end
    @test e isa I.DecodeJobError
    @test e.ordinal==1
    @test occursin("lower assembly",sprint(showerror,e))
    settled(d)
end
@testset "controller primary survives cleanup and payloads are released" begin
    d=Dict{String,Any}();primary=ErrorException("controller primary");secondary=ErrorException("cleanup secondary")
    refs=WeakRef[];tasks=Task[]
    prepare=k->begin x=zeros(UInt8,4096);push!(refs,WeakRef(x));x end
    control=(where,value)->(where==:after_admit && throw(primary))
    spawn=(where,k,task)->(where==:before_start && push!(tasks,task))
    e=try
        I.run_decode_queue([4096],prepare,identity,(k,v)->nothing;actors=2,max_jobs=1,max_bytes=4096,
            diagnostics=d,controller_hook=control,spawn_hook=spawn,cleanup_hook=()->throw(secondary))
    catch e;e;end
    @test e===primary
    @test d["cleanup_errors"]==1
    @test all(istaskdone,tasks)
    settled(d)
    GC.gc()
    @test all(x->x.value===nothing,refs)
end

@testset "cancellation is not masked by secondary cleanup" begin
    d=Dict{String,Any}()
    @test_throws InterruptException I.run_decode_queue([1],identity,k->throw(InterruptException()),(k,v)->nothing;
        actors=2,max_jobs=1,max_bytes=1,diagnostics=d,cleanup_hook=()->error("secondary cleanup"))
    @test d["cleanup_errors"]==1
    settled(d)
end
