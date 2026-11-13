# Included inside EventRangeHarness. Only the metadata codec is stubbed: use
# plain key bytes with the real Pipeline is_up_to_date predicate and real files.
read_meta(out::AbstractString) = isfile(string(out,".meta.json")) ?
    Dict{String,Any}("key"=>read(string(out,".meta.json"),String)) : nothing
include(src("Pipeline","is_up_to_date.jl"))

@testset "same-key stale metadata is detached before replacement" begin
    mktempdir() do dir
        out=joinpath(dir,"target.cols"); other=joinpath(dir,"other.cols")
        key="same-key"
        oldmarker="same-key"; othermarker="other-key"
        write(out,"old-table"); write(out*".meta.json",oldmarker)
        write(other,"other-table"); write(other*".meta.json",othermarker)
        @test is_up_to_date(out,key)
        backup=Ref{Union{Nothing,String}}(nothing)
        hook=(stage,path)->begin
            if stage==:invalidated
                backup[]=path
                @test !is_up_to_date(out,key)
                @test read(out,String)=="old-table"
                @test read(path,String)==oldmarker
                @test is_up_to_date(other,"other-key")
            end
        end
        # Failure AFTER artifact replacement must not leave the old same key.
        @test_throws ErrorException publish_event_range_checkpoint(
            ()->write(out,"new-table"),()->error("fresh metadata failure"),out;
            publication_hook=hook)
        @test read(out,String)=="new-table"
        @test !is_up_to_date(out,key)
        @test !ispath(out*".meta.json")
        @test read(backup[],String)==oldmarker
        @test is_up_to_date(other,"other-key")
        @test read(other,String)=="other-table"
        @test read(other*".meta.json",String)==othermarker

        # Even a metadata callback that writes and THEN fails cannot commit.
        write(out*".meta.json",oldmarker)
        @test_throws ErrorException publish_event_range_checkpoint(
            ()->write(out,"third-table"),()->begin
                write(out*".meta.json",key)
                error("failure after creating marker")
            end,out)
        @test !is_up_to_date(out,key)
        @test read(other,String)=="other-table"
        @test is_up_to_date(other,"other-key")

        # A successful attempt installs metadata last and retires only its backup.
        write(out*".meta.json",oldmarker)
        successbackup=Ref{Union{Nothing,String}}(nothing)
        publish_event_range_checkpoint(()->write(out,"complete-table"),
            ()->begin
                @test read(out,String)=="complete-table"
                @test !is_up_to_date(out,key)
                write(out*".meta.json",key)
            end,out;publication_hook=(stage,path)->begin
                stage==:invalidated && (successbackup[]=path)
            end)
        @test is_up_to_date(out,key)
        @test !ispath(successbackup[])
        @test ispath(backup[]) # failed attempt's original bytes remain diagnostic
        @test read(other*".meta.json",String)==othermarker
    end
end

@testset "held reader survives interrupted join until same-task retry" begin
    started=Base.Event(); release=Base.Event()
    done=Threads.Atomic{Bool}(false)
    privateclosed=Ref(0); originalclosed=Ref(0); waits=Task[]
    diag=Dict{String,Any}()
    data=(windows=[1:1],charges=[1000],retained_charges=[1000])
    opener=_ -> data
    rangeopener=(d,k)->(owner=Ref(0),)
    analyzer=(c,k)->begin
        notify(started)
        wait(release) # reader remains borrowed across the first interrupted join
        done[]=true
        1
    end
    controller=(stage,value)->begin
        if stage==:after_admit
            wait(started)
            throw(InterruptException())
        end
    end
    waiter=task->begin
        push!(waits,task)
        if length(waits)==1
            @test !done[]
            @test privateclosed[]==originalclosed[]==0
            throw(InterruptException())
        end
        notify(release)
        wait(task)
    end
    rangecloser=c->begin
        @test done[]
        privateclosed[]+=1
    end
    closer=d->begin
        @test done[]
        @test privateclosed[]==1
        originalclosed[]+=1
    end
    @test_throws InterruptException run_event_range_pool([1],opener,rangeopener,
        analyzer,(d,r,k)->0,d->error("must not publish"),closer,rangecloser;
        options=OPTIONS,workers=1,diagnostics=diag,controller_hook=controller,waiter=waiter)
    @test length(waits)>=2
    @test all(t->t===first(waits),waits)
    @test privateclosed[]==originalclosed[]==1
    @test diag["workers_joined"]
    @test diag["credits_reserved"]==diag["credits_released"]==1
end

@testset "worker fatal after completion publication is observed after join" begin
    published=Base.Event(); diag=Dict{String,Any}(); checkpoints=Ref(0)
    closes=Ref(0); privatecloses=Ref(0)
    data=(windows=[1:1],charges=[1000],retained_charges=[1000])
    hook=(stage,k)->begin
        if stage==:after_publish
            wait(published)
            error("fatal after result publication")
        end
    end
    publisher=d->begin
        checkpoints[]+=1
        notify(published)
    end
    @test_throws EventIO.DecodeWorkerError run_event_range_pool([1],_ -> data,
        (d,k)->Ref(0),(c,k)->1,(d,r,k)->0,publisher,
        d->(closes[]+=1),c->(privatecloses[]+=1);
        options=OPTIONS,workers=1,diagnostics=diag,worker_hook=hook)
    @test checkpoints[]==1 # completed unrelated/settled checkpoint is not rolled back
    @test closes[]==privatecloses[]==1
    @test diag["workers_joined"]
    @test diag["completed_files"]==1
    @test diag["credits_reserved"]==diag["credits_released"]==1
end
