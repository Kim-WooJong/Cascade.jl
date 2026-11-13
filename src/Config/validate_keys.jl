"""
    validate_keys(raw) -> raw

Reject misspelled configuration keys, including in inactive profiles.
User-label dictionaries (paths, variables, input bindings, groups) are open.
"""
function validate_keys(d::AbstractDict; prefix = "")
    schemas = Dict(
        "" => split("analysis paths samples objects variables cuts regions histograms weights triggers data_quality luminosity output merge hooks corrections theory_weights shape_variations fit plot options profiles batch reduced_skim execution counting"),
        "counting" => split("region signal_samples background_samples sigma_ref_pb lumi_mode signal_definition br_convention required_evidence"),
        "reduced_skim" => split("format retention include drop mode streaming max_events max_payload_bytes max_input_bytes max_buffer_bytes"),
        "reduced_skim.streaming" => split("window_events target_shard_events target_shard_payload_bytes max_basket_bytes max_window_bytes max_buffer_bytes max_metadata_bytes"),
        "batch" => split("workers threads"),
        "execution" => split("checkpoints lightweight_skim_metadata event_range_selection memoize_variables memoize_max_bytes stable_selection_kernels windowed_selection windowed_reusable_decoder reusable_shared_offsets reuse_window_buffers reuse_window_accounting memory_handoff column_readers decode_threads decode_queue_jobs decode_queue_bytes streaming_selection stream_window_events stream_active_files stream_queue_windows stream_queue_bytes stream_window_bytes stream_basket_bytes stream_metadata_bytes stream_retained_bytes"),
        "analysis" => split("name lumi_pb workdir"),
        "samples" => split("name kind files format xsec_pb branching_ratio stream group source metadata audit"),
        "samples.source" => split("tree runs_tree gen_sumw gen_weight"),
        "samples.metadata" => split("dataset era campaign xsec_source xsec_note branching_ratio_source provenance"),
        "samples.audit" => split("expected_nfiles expected_nevents expected_sumw sumw_rtol sumw_atol expected_files inventory_source"),
        "objects" => split("name collection cut clean sort_by"), "objects.clean" => split("against dr"),
        "cuts" => split("name expr only"), "regions" => split("name after expr"),
        "histograms" => split("name edges range linspace values when regions xlabel"),
        "weights" => split("mc data variations"), "weights.variations" => split("name up down"),
        "triggers" => split("groups streams priority mc"), "data_quality" => split("run_range golden_json run_branch lumi_branch"),
        "luminosity" => split("mode file unit assume_complete_lumisections"),
        "output" => ["columns"], "merge" => ["yield_variable"], "hooks" => split("correct systematics fit plot"),
        "options" => split("default_profile corrections shape_variations jer_nominal fit"),
        "corrections" => split("sets object_sf event_weight flat trigger_or"),
        "corrections.object_sf" => split("enabled name set correction object indices when inputs systematic nominal up down"),
        "corrections.event_weight" => split("enabled name set correction inputs systematic nominal up down"),
        "corrections.flat" => split("enabled name nominal up down"),
        "corrections.trigger_or" => split("enabled name path topology object indices when data mc"),
        "corrections.trigger_or.data" => split("set correction inputs systematic nominal up down"),
        "corrections.trigger_or.mc" => split("set correction inputs systematic nominal up down"),
        "theory_weights" => split("enabled name branch family normalization reduction convention indices expected_length samples central_index reference_branch cl_scale pdf_template_model"),
        "shape_variations" => split("enabled name collection kind fields samples met met_min_pt corrections source resolution scale_factor smear_file smear rho event genjet genjet_index match_dr match_nsigma nominal up down inputs"),
        "shape_variations.inputs" => split("JetEta JetPt Rho systematic GenPt EventID JER JERSF"),
        "fit" => split("channels poi poi_init poi_bounds signal grouping groups data normsys histosys histosys_exclude histosys_prune staterror normsys_code histosys_code impacts upper_limit significance profile_interval asimov"),
        "fit.channels" => split("name region variable"), "fit.normsys" => split("enabled name size hi lo samples placeholder"),
        "plot" => split("formats lumi_label energy extra regions variables logy region_labels labels colors groups data prefit postfit tables cutflow impacts band_normsys max_impacts"),
        "plot.groups" => split("label color samples"))
    function walk(t,path,label; overlay::Bool = false)
        t isa AbstractDict || return
        if path == "profiles"
            for (k,v) in t
                v isa AbstractDict || throw(ArgumentError("$label.$k must be a table"))
                walk(v,"", "$label.$k"; overlay=true)
            end
            return
        end
        haskey(schemas,path) || return
        path == "" && event_range_selection(t)
        path == "" && memoization_options(t)
        path == "" && stable_selection_kernels(t)
        path == "" && checkpoints_enabled(t)
        path == "" && lightweight_skim_metadata(t)
        path == "" && memory_handoff(t)
        path == "" && windowed_selection(t)
        path == "" && windowed_reusable_decoder(t; validate_relations=!overlay)
        path == "" && reusable_shared_offsets(t; validate_relations=!overlay)
        path == "" && reuse_window_buffers(t; validate_relations=!overlay)
        path == "" && reuse_window_accounting(t; validate_relations=!overlay)
        path == "" && column_readers(t)
        path == "" && decode_options(t)
        path == "" && streaming_selection_options(t; validate_relations=!overlay)
        for (k,v) in t
            k in schemas[path] || throw(ArgumentError("$(isempty(label) ? "root" : label): unknown key '$k'"))
            p = isempty(path) ? k : path*"."*k
            l = isempty(label) ? k : label*"."*k
            if v isa AbstractDict
                walk(v,p,l; overlay)
            elseif v isa AbstractVector && haskey(schemas,p)
                for (i,x) in enumerate(v); walk(x,p,"$l[$i]"; overlay); end
            end
        end
    end
    walk(d,"",prefix)
    # Validate inherited execution conflicts in EVERY profile, not only the
    # eventually selected profile or its isolated overlay.
    base_execution = get(d,"execution",Dict())
    for (_,profile) in get(d,"profiles",Dict())
        profile isa AbstractDict || continue
        execution = merge(Dict{String,Any}(base_execution),get(profile,"execution",Dict()))
        streaming_selection_options(Dict("execution"=>execution))
        event_range_selection(Dict("execution"=>execution))
        memoization_options(Dict("execution"=>execution))
        stable_selection_kernels(Dict("execution"=>execution))
        checkpoints_enabled(Dict("execution"=>execution))
        lightweight_skim_metadata(Dict("execution"=>execution))
        memory_handoff(Dict("execution"=>execution))
        windowed_selection(Dict("execution"=>execution))
        windowed_reusable_decoder(Dict("execution"=>execution))
        reusable_shared_offsets(Dict("execution"=>execution))
        reuse_window_buffers(Dict("execution"=>execution))
        reuse_window_accounting(Dict("execution"=>execution))
    end
    for (k,v) in get(d,"options",Dict())
        k in ("fit","jer_nominal") && !(v isa Bool) && throw(ArgumentError("options.$k must be boolean"))
        k in ("corrections","shape_variations") && !(v isa Bool || (v isa AbstractVector && all(x -> x isa AbstractString,v))) && throw(ArgumentError("options.$k must be boolean or a list of names"))
        k == "default_profile" && !(v isa AbstractString) && throw(ArgumentError("options.default_profile must be a string"))
    end
    return d
end
