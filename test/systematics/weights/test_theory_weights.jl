# Explicit conventions, signed weights, failures and histogram-wise recipes.
using Cascade.Histograms
function theory_fixture(; kwargs...)
    d=Dict{String,Any}("name"=>"scale","branch"=>"V","family"=>"scale",
        "normalization"=>"relative","reduction"=>"envelope","convention"=>"synthetic declared members",
        "indices"=>[1,2],"expected_length"=>2,"samples"=>["mc"])
    for (k,v) in kwargs;d[String(k)]=v;end
    d
end
function theory_config(t)
    validate_analysis(parse_analysis(Dict{String,Any}("analysis"=>Dict("name"=>"theory","lumi_pb"=>1.0),
        "samples"=>[Dict("name"=>"mc","kind"=>"mc","format"=>"cols","files"=>["unused"],"xsec_pb"=>1.0)],
        "theory_weights"=>[t])))
end
@testset "theory configuration contracts" begin
    @test length(theory_weights(theory_config(theory_fixture())))==1
    for bad in (Dict("indices"=>[0,1]),Dict("indices"=>[1,1]),Dict("expected_length"=>1),
                Dict("samples"=>["missing"]),Dict("normalization"=>"guess"),Dict("convention"=>""),
                Dict("normalization"=>"central"),Dict("normalization"=>"absolute"),
                Dict("reduction"=>"replica_std","family"=>"pdf"),Dict("name"=>"nominal"),Dict("convention"=>" "),
                Dict("normalization"=>"central","central_index"=>1,"family"=>"pdf","reduction"=>"replica_std","cl_scale"=>1.))
        @test_throws ArgumentError theory_config(merge(theory_fixture(),bad))
    end
    input=Dict("theory_weights"=>[merge(theory_fixture(),Dict("enabled"=>false))])
    before=deepcopy(input);@test isempty(resolve_config(input)["theory_weights"]);@test input==before
end
@testset "vector members and normalization diagnostics" begin
    mktempdir() do dir
        p=joinpath(dir,"v.cols")
        write_column_file(p,Dict("V"=>Jagged([[2.0,4.0],[-3.0,-6.0],[0.0,0.0]]),"genWeight"=>[2.0,-3.0,0.0]))
        r=BranchReader("cols",p,[2,1,2])
        @test vector_members(r,theory_fixture())==[[-3.,2.,-3.],[-6.,4.,-6.]]
        @test vector_members(r,theory_fixture(normalization="central",central_index=1))==[ones(3),fill(2.,3)]
        @test vector_members(r,theory_fixture(normalization="absolute",reference_branch="genWeight"))==[ones(3),fill(2.,3)]
        @test_throws ArgumentError r("V")
        @test_throws ArgumentError vector_members(r,theory_fixture(branch="missing"))
        @test_throws ArgumentError vector_members(r,theory_fixture(branch="genWeight"))
        @test_throws ArgumentError vector_members(r,theory_fixture(expected_length=9))
        close(r)
        for norm in ("central","absolute")
            r=BranchReader("cols",p,[3])
            t=norm=="central" ? theory_fixture(normalization=norm,central_index=1) : theory_fixture(normalization=norm,reference_branch="genWeight")
            @test_throws ArgumentError vector_members(r,t);close(r)
        end
        for x in (NaN,Inf)
            write_column_file(p,Dict("V"=>Jagged([[x,1.]])))
            r=BranchReader("cols",p,[1]);@test_throws ArgumentError vector_members(r,theory_fixture());close(r)
        end
        for len in (8,9)
            write_column_file(p,Dict("V"=>Jagged([collect(1.0:len)])))
            r=BranchReader("cols",p,[1])
            @test vector_members(r,theory_fixture(expected_length=len,indices=[2,len]))==[[2.],[Float64(len)]]
            close(r)
        end
        write_column_file(p,Dict("V"=>Jagged([[1.]])))
        r=BranchReader("cols",p,[1]);@test_throws ArgumentError vector_members(r,theory_fixture());close(r)
        r=BranchReader("cols",p,[2]);@test_throws ArgumentError vector_members(r,theory_fixture());close(r)
        r=BranchReader("cols",p,Int[]);@test vector_members(r,theory_fixture())==[Float64[],Float64[]];close(r)
    end
end
@testset "histogram-wise theory bands and sumw2" begin
    st=HistogramStore()
    st.hists[HistKey("r","mc","nominal","x")]=BinnedHist([0.,1.,2.],[2.,2.],[2.,2.])
    st.hists[HistKey("r","mc","__theory_scale_1","x")]=BinnedHist([0.,1.,2.],[4.,1.],[10.,1.])
    st.hists[HistKey("r","mc","__theory_scale_2","x")]=BinnedHist([0.,1.,2.],[1.,4.],[1.,10.])
    st.meta["theory_extraction"]=theory_extraction(theory_config(theory_fixture()))
    frozen=deepcopy(st)
    out=reduce_theory(theory_config(theory_fixture()),st)
    @test out["r","mc","scaleUp","x"].sumw==[4.,4.]
    @test out["r","mc","scaleDown","x"].sumw==[1.,1.]
    @test out["r","mc","scaleUp","x"].sumw2==[10.,10.]
    @test out.meta["theory_weights"][1]["yields"][1]["yield_up"]==5.0
    @test out.meta["theory_weights"][1]["yields"][1]["template_up"]==8.0
    @test st.hists==frozen.hists
    @test !any(k->startswith(k.variation,"__theory"),keys(out))
    @test_throws ArgumentError reduce_theory(theory_config(theory_fixture()),out)
    for (r,delta) in (("replica_std",sqrt(4.5)),("hessian_symmetric",sqrt(5.)),("hessian_pairs",1.5))
        t=theory_fixture(family="pdf",reduction=r,cl_scale=0.5,pdf_template_model="rank_one")
        o=reduce_theory(theory_config(t),st)
        @test o["r","mc","scaleUp","x"].sumw≈[2+0.5delta,2+0.5delta]
        @test o["r","mc","scaleDown","x"].sumw≈[2-0.5delta,2-0.5delta]
        @test o["r","mc","scaleUp","x"].sumw2==[2.,2.]
    end
    p=reduce_theory(theory_config(theory_fixture(reduction="pair")),st)
    @test p["r","mc","scaleUp","x"]==st["r","mc","__theory_scale_1","x"]
    delete!(st.hists,HistKey("r","mc","__theory_scale_1","x"))
    @test_throws ArgumentError reduce_theory(theory_config(theory_fixture()),st)
end

@testset "theory signed corrected weights and immutable inputs" begin
    mktempdir() do dir
        p=joinpath(dir,"v.cols")
        write_column_file(p,Dict("V"=>Jagged([[2.,4.],[-3.,-6.],[0.,0.]]),"genWeight"=>[2.,-3.,0.]))
        cfg=theory_config(theory_fixture())
        table=EventTable(Dict{String,Vector}("entry"=>[1,2,3],"weight"=>[2.,-3.,0.]),["entry","weight"],Dict{String,Any}())
        weights=Dict("nominal"=>[4.,-6.,0.],"scalarUp"=>[5.,-7.,0.])
        before=deepcopy(weights)
        out=theory_member_weights(cfg,cfg.samples[1],p,table,weights)
        @test out["__theory_scale_1"]==[8.,18.,0.]
        @test out["scalarUp"]==before["scalarUp"]
        @test weights==before
        @test table["weight"]==[2.,-3.,0.]
        write_column_file(p,Dict("V"=>Jagged([[1e200,1e200],[1.,1.],[1.,1.]])))
        @test_throws ArgumentError theory_member_weights(cfg,cfg.samples[1],p,table,weights)
    end
end
