"""Compare every histogram and logical normalization with predefined bounds."""
function compare_outputs(area)
    original=joinpath(area,"original"); reduced=joinpath(area,"reduced")
    batch=json(joinpath(area,"batch-result-path.json"))["path"]
    inventory=json(joinpath(area,"inventory.json")); n=sum(r["nevents"] for r in inventory)
    bound=128eps(Float64)*max(1,ceil(log2(n)))
    maxabs=0.; maxscaled=0.; bins=0; records=Any[]
    for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
        a=read_store(joinpath(original,rel));b=read_store(joinpath(reduced,rel));c=read_store(joinpath(batch,rel))
        @test Set(keys(a))==Set(keys(b))==Set(keys(c))
        for k in keys(a)
            @test a[k].edges==b[k].edges==c[k].edges
            for field in (:sumw,:sumw2)
                x=getfield(a[k],field); y=getfield(b[k],field); z=getfield(c[k],field)
                @test reinterpret(UInt64,y)==reinterpret(UInt64,z)
                for i in eachindex(x)
                    scale=field==:sumw ? max(1.,sqrt(n*max(a[k].sumw2[i],b[k].sumw2[i]))) : max(1.,abs(x[i]),abs(y[i]))
                    delta=abs(x[i]-y[i]); maxabs=max(maxabs,delta);maxscaled=max(maxscaled,delta/scale)
                    @test delta<=bound*scale
                end
            end
            bins+=length(a[k].sumw)
        end
        push!(records,Dict("artifact"=>rel,"histograms"=>length(a),"variations"=>store_axis(a,:variation),
            "samples"=>store_axis(a,:sample),"regions"=>store_axis(a,:region)))
    end
    a=json(joinpath(original,"merge/samples.json")); b=json(joinpath(reduced,"merge/samples.json"));c=json(joinpath(batch,"merge/samples.json"))
    @test a["order"]==b["order"]==c["order"]
    @test a["lumi_pb"]==b["lumi_pb"]==c["lumi_pb"]==1210.
    @test a["luminosity"]["truncated"] && b["luminosity"]["truncated"] && c["luminosity"]["truncated"]
    @test b==c
    for name in a["order"]
        x=a["samples"][name];y=b["samples"][name]
        @test x["nfiles"]==y["nfiles"]==2
        @test x["gen_weight_sum"]==y["gen_weight_sum"]
        @test x["norm"]==y["norm"]
        @test length(y["original_sources"])==2
        @test sum(g["original_nevents"] for g in y["original_sources"])==x["nevents"]
        # Original prefixes are evidence, NOT the reexecuted retained prefixes.
        for field in ("n","sumw","sumw2")
            expected=reduce(+, (Float64.(s["original_cutflows"]["nominal"][field]) for s in y["original_sources"]))
            @test expected==x["cutflow"][field]
        end
        scale=max(1.,sqrt(n*maximum(x["cutflow"]["sumw2"]))*max(1.,abs(x["norm"])))
        for region in keys(x["regions"]), key in keys(x["regions"][region])
            left=x["regions"][region][key];right=y["regions"][region][key]
            if left isa Number
                @test abs(left-right)<=bound*scale
            else
                @test left==right
            end
        end
        for label in keys(get(x,"shape",Dict())), region in keys(x["shape"][label]["regions"]), key in ("n","sumw","yield")
            @test abs(x["shape"][label]["regions"][region][key]-y["shape"][label]["regions"][region][key])<=bound*scale
        end
    end
    writejson(joinpath(area,"comparison-summary.json"),Dict("original_events"=>n,"bins"=>bins,
        "max_absolute_difference"=>maxabs,"max_contribution_scaled_difference"=>maxscaled,
        "predefined_scaled_bound"=>bound,"same_partition_batch_bits"=>true,"stores"=>records))
end
