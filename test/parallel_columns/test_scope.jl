module TestParallelColumnScope
using Test, Cascade, TOML
using Cascade.Config, Cascade.IO
const I = Cascade.IO
const P = Cascade.Pipeline
struct FakeSource <: AbstractEventSource end
@testset "column reader config and stage budget" begin
    @test column_readers(Dict()) == 1
    for width in 1:4
        @test column_readers(Dict("execution"=>Dict("column_readers"=>width))) == width
    end
    for bad in (true, false, 0, 5, 1.0, "2", nothing)
        @test_throws ArgumentError validate_keys(Dict("execution"=>Dict("column_readers"=>bad)))
        @test_throws ArgumentError validate_keys(Dict("profiles"=>Dict("inactive"=>Dict("execution"=>Dict("column_readers"=>bad)))))
    end
    @test_throws ArgumentError validate_keys(Dict("execution"=>4))
    @test_throws ArgumentError validate_keys(Dict("execution"=>Dict("typo"=>1)))
    raw=Dict("profiles"=>Dict("wide"=>Dict("execution"=>Dict("column_readers"=>4))))
    @test column_readers(resolve_config(raw;profile="wide")) == 4
    root=normpath(joinpath(@__DIR__,"../.."))
    base=TOML.parsefile(joinpath(root,"analyses/ttbar_emu/analysis.toml"))
    a=parse_analysis(base;dir=root,profile="baseline")
    wide=deepcopy(base); wide["execution"]=Dict("column_readers"=>4)
    b=parse_analysis(wide;dir=root,profile="baseline")
    @test section_hash(a,"objects","cuts","histograms") == section_hash(b,"objects","cuts","histograms")
    @test canonical_hash(a.raw) != canonical_hash(b.raw)
    for n in 0:9, threads in 1:8, requested in 1:4
        width=P.column_reader_budget(requested,n;threads)
        @test 1 <= width <= requested
        @test n==0 || width*min(n,threads) <= threads
    end
end
@testset "mapping/path namespace independence and drift rejection" begin
    mapping=(UInt(7),UInt(513),UInt(12345))
    pathstat=(device=UInt(999999),inode=UInt(98765),size=4096,mtime=1.0,ctime=2.0)
    identity=I.column_source_identity(mapping,4096,pathstat)
    @test identity.mapping==(major=mapping[1],minor=mapping[2],inode=mapping[3],length=4096)
    @test identity.path==pathstat
    @test I.column_source_identity(mapping,4096,pathstat;expected=identity)==identity
    for changed in ((UInt(8),mapping[2],mapping[3]),(mapping[1],UInt(514),mapping[3]),(mapping[1],mapping[2],UInt(12346)))
        @test_throws ErrorException I.column_source_identity(changed,4096,pathstat;expected=identity)
    end
    for field in (:device,:inode,:size,:mtime,:ctime)
        changed=merge(pathstat,NamedTuple{(field,)}((getfield(pathstat,field)+1,)))
        @test_throws ErrorException I.column_source_identity(mapping,4096,changed;expected=identity)
    end
    @test_throws ErrorException I.column_source_identity(mapping,4095,pathstat)
    @test_throws ErrorException I.column_source_identity(mapping,4097,pathstat;expected=identity)
    @test I.column_source_identity(nothing,4096,pathstat)===nothing
    @test_throws ErrorException I.column_source_identity(nothing,4096,pathstat;expected=identity)
end
function fake_scope(;width=4, failread=false, failopen=0)
    opened=Int[]; closed=Int[]; completed=String[]
    guard=ReentrantLock(); entered=Threads.Atomic{Int}(0)
    barrier=Channel{Nothing}(width)
    d=Dict{String,Any}("extra_opens"=>0,"extra_closes"=>0,"effective_readers"=>1,
        "branch_jobs"=>0,"max_active_reads"=>0,"fallback"=>"")
    opener=() -> begin
        id=length(opened)+2
        id==failopen && error("open failure")
        push!(opened,id); id
    end
    readbranch=(slot,name,needed,offsets) -> begin
        k=Threads.atomic_add!(entered,1)+1
        if k<=width
            k==width && foreach(_->put!(barrier,nothing),1:width)
            take!(barrier)
        end
        yield()
        lock(guard) do; push!(completed,name); end
        failread && name=="b" && error("read failure")
        [Int(name[1]),slot]
    end
    closer=slot -> begin
        @test length(completed)==8 || failopen>0
        push!(closed,slot)
    end
    scope=I.ColumnReadScope(FakeSource(),width,Any[1],opener,closer,readbranch,()->nothing,d,ReentrantLock(),0)
    return scope,opened,closed,completed
end
@testset "independent slot ownership, overlap and joins" begin
    jobs=[(string(c),nothing) for c in 'a':'h']
    width=min(4,Threads.nthreads())
    for failure in (false,true)
        scope,opened,closed,completed=fake_scope(;width,failread=failure)
        run=() -> I.with_column_read_scope(scope) do s
            result=I.read_column_jobs(s,jobs,nothing)
            @test all(result[string(c)][1]==Int(c) for c in 'a':'h')
            @test length(s.slots)==width
            @test isempty(closed)
            result
        end
        failure ? (@test_throws ErrorException run()) : run()
        @test length(completed)==8
        @test scope.active==0
        @test scope.diagnostics["max_active_reads"]==width
        @test sort(closed)==collect(2:width)
        @test !(1 in closed)
        @test length(opened)==width-1
    end
    if width>2
        scope,opened,closed,completed=fake_scope(;width,failopen=3)
        @test_throws ErrorException I.with_column_read_scope(s->I.read_column_jobs(s,jobs,nothing),scope)
        @test opened==closed==[2]
        @test isempty(completed)
    end
    d=Dict{String,Any}()
    @test with_column_readers(_->:serial,FakeSource();readers=4,diagnostics=d)==:serial
    @test d["fallback"]=="unsupported_source" && d["extra_opens"]==0
    @test with_column_readers(s->s===nothing,FakeSource();readers=1)
    @test_throws ArgumentError with_column_readers(identity,FakeSource();readers=true)
end
end
