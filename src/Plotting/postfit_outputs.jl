"""
    postfit_outputs(report, store, stack, opts, outdir; render=true, notes=String[], xlabels=Dict()) -> Vector{String}

Postfit outputs from a `Cascade.Fit.fit_report` dictionary: per fit channel a
postfit data/MC plot (`postfit/<channel>`) with the fit's total postfit band and
a postfit yield table (`tables/postfit_yields_<channel>`), both from
[`fit_yields`](@ref) (yields and errors from the fit covariance); and the
pull/impact ranking plot (`impacts`) when the report has impacts. Fit samples
are mapped onto the stack groups of `stack` that contain all their members; a
channel whose fit samples cannot be mapped is reported in `notes`. `xlabels`
gives the x-axis title per variable. Data are the fitted observations recorded
in the report, independent of the prefit plotting data selection.
"""
function postfit_outputs(report::AbstractDict, store::HistogramStore, stack::StackConfig, opts::PlotOptions,
                         outdir::AbstractString; render::Bool = true, notes::Vector{String} = String[],
                         xlabels::AbstractDict = Dict{String,String}())
    files = String[]
    model = report_model(report)
    result = report_result(report, model)
    owner = Dict(s => g.label for g in stack.groups for s in g.samples)
    for ch in report["channels"]
        name = String(ch["name"])
        members = Dict(String(k) => String.(v) for (k, v) in ch["members"])
        bylabel = Dict{String,Vector{String}}()
        ok = true
        for (fs, ms) in members
            labels = unique([get(owner, m, "") for m in ms])
            if length(labels) != 1 || only(labels) == ""
                push!(notes, "postfit $name: fit sample $fs does not map onto one stack group")
                ok = false
                break
            end
            push!(get!(() -> String[], bylabel, only(labels)), fs)
        end
        ok || continue
        pstack = StackConfig([g for g in stack.groups if haskey(bylabel, g.label)], stack.data)
        groups = [g.label => bylabel[g.label] for g in pstack.groups]
        edges = Float64.(ch["edges"])
        fy = fit_yields(model, result, name; edges, groups)
        counts = Float64.(ch["data"])
        data = binned_hist(edges, counts, counts)
        annotation = (get(report, "dataset", "observed") == "asimov" ? "Postfit (Asimov), " : "Postfit, ") *
                     get(opts.region_labels, String(ch["region"]), String(ch["region"]))
        opts.tables && append!(files, write_table(yield_table(fy, pstack; data, caption = format_label(annotation, :text)),
                                                  joinpath(outdir, "tables", "postfit_yields_" * name)))
        (render && opts.postfit) || continue
        if data === nothing
            push!(notes, "postfit $name: no data histogram, plot skipped")
            continue
        end
        try
            res = plot_postfit(data, fy, pstack, joinpath(outdir, "postfit", name); xlabel = get(xlabels, String(ch["variable"]), String(ch["variable"])),
                               lumi = opts.lumi, energy = opts.energy, extra = opts.extra, annotation,
                               format = opts.formats, data_errors = all(isinteger, data.sumw) ? :poisson : :sumw2)
            append!(files, filter(!isnothing, [res.files.png, res.files.pdf]))
        catch e
            e isa ArgumentError || rethrow()
            push!(notes, "postfit $name: " * sprint(showerror, e))
        end
    end
    if render && opts.impacts && !isempty(get(report, "impacts", Any[]))
        poi = String(report["poi"])
        v, e = report["poi_value"], report["poi_error"]
        title = v === nothing ? "" : "#hat{" * poi * "} = " * string(round(v; digits = 4)) * " #pm " *
                                     string(round(something(e, NaN); digits = 4))
        res = plot_impacts(impact_rows(report), joinpath(outdir, "impacts"); poi, title, max_rows = opts.max_impacts,
                           format = opts.formats)
        append!(files, filter(!isnothing, [res.files.png, res.files.pdf]))
    end
    return files
end
