"""Compare nested fit workspaces with explicit absolute-plus-relative bounds."""
function compare_workspace(a,b)
    differences=Float64[]
    function visit(x,y)
        if x isa AbstractDict
            @test Set(keys(x))==Set(keys(y))
            for k in keys(x);visit(x[k],y[k]);end
        elseif x isa AbstractVector
            @test length(x)==length(y)
            for (u,v) in zip(x,y);visit(u,v);end
        elseif x isa Real && !(x isa Bool)
            @test isapprox(x,y;atol=1e-9,rtol=1e-10)
            push!(differences,abs(Float64(x)-Float64(y)))
        else
            @test x==y
        end
    end
    visit(a,b)
    return Dict("numeric_values"=>length(differences),"max_absolute_difference"=>maximum(differences;init=0.))
end
