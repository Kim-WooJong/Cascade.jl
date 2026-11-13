@testset "typed primitive interpretation and source-free cache workload" begin
    registry = copy(I.SOURCE_FORMATS)
    @test I._precompile_decode_workload() == 44
    @test I.SOURCE_FORMATS == registry
    @test I.builtin_source_readers()
    # Inspect parsed calls/macros: comments and docstrings are not executable.
    function forbidden_workload_calls(source)
        forbidden = Set((:open,:read,:read!,:write,:mmap,:include,:eval,:run,:pipeline,
            :Task,:Channel,:schedule,:addprocs,:spawn,Symbol("@spawn"),Symbol("@async"),Symbol("@threads"),
            :ROOTFile,:LazyBranch,:NanoAODSource,:open_source,:read_columns,
            :read_selection_columns,:read_nanoaod_branch,:prepare_nanoaod_decode))
        violations = Symbol[]
        name(x::Symbol) = x
        name(x::QuoteNode) = name(x.value)
        name(x) = x isa Expr && x.head in (:.,:curly) ? name(x.head == :. ? last(x.args) : first(x.args)) : nothing
        function visit(x)
            x isa Expr || return
            if x.head in (:call,:macrocall) && !isempty(x.args)
                n = name(x.args[1])
                n in forbidden && push!(violations,n)
            end
            foreach(visit,x.args)
        end
        visit(Meta.parseall(source))
        return violations
    end
    workload = read(joinpath(dirname(pathof(Cascade)),"IO/precompile_decode.jl"),String)
    @test isempty(forbidden_workload_calls(workload))
    @test isempty(forbidden_workload_calls("# open(path); Threads.@spawn work()\n1"))
    @test forbidden_workload_calls("Base.open(path); Threads.@spawn work()") == [:open,Symbol("@spawn")]
    for T in (Bool, Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Float32, Float64)
        values=T[zero(T),one(T)]
        raw=collect(reinterpret(UInt8,hton.(values)))
        @test (@inferred I.interpret_decoded_basket(raw,Int32[],T,UnROOT.Nojagg,2)) == values
        basket=@inferred I.interpret_decoded_basket(raw,Int32[0,sizeof(T),2sizeof(T)],Vector{T},UnROOT.Nooffsetjagg,2)
        @test basket.data == values
        @test collect(basket.elem_ptr) == [1,2,3]
        @test_throws ErrorException I.interpret_decoded_basket(raw,Int32[],T,UnROOT.Nojagg,3)
    end
end
