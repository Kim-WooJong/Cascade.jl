# Image-generation-only precompile declarations for the CLI entry and the checkpoints=false body.
# Executed ONLY while a package image is being generated (jl_generating_output == 1): no data, files, tasks or
# configuration are touched, and ordinary runtime loading/behavior is unchanged. Each declaration must succeed.
# Exception (last block): the stable-selection training workload reads its two tracked files
# (spec + bundled analysis TOML, both include_dependency'd); still no data, inputs or tasks.
if ccall(:jl_generating_output, Cint, ()) == 1
    let ok = (precompile(main, (Vector{String},)),
              precompile(run_no_checkpoints, (Config.AnalysisConfig, String, Vector{Config.SampleConfig}, RunOptions)),
              precompile(_run_no_checkpoints_traced, (Config.AnalysisConfig, String, Vector{Config.SampleConfig}, RunOptions)))
        all(ok) || error("Pipeline precompile declaration failed: $(ok)")
    end
    # Exact per-file work instances reached by OrderedWindow's dynamic call `w.f(w.items[k])`
    # (types: no_checkpoint_file_work_hint_types). Type-level only: no config, source or task.
    let item = no_checkpoint_file_item_type(),
        ok = map(W -> isconcretetype(W) && precompile(Tuple{W,item}), no_checkpoint_file_work_hint_types())
        isconcretetype(item) && all(ok) || error("Pipeline file-work precompile declaration failed: $(ok)")
    end
    # Opt-in stable selection kernels: bounded training workload over the bundled analysis
    # TOML and column schema (both tracked as image dependencies). Zero-event typed columns
    # only; no input files, golden JSON, ROOT data, tasks or environment.
    let spec = STABLE_SELECTION_WORKLOAD
        include_dependency(spec)
        include_dependency(stable_selection_workload_analysis(spec))
        stable_selection_workload(spec)
    end
    # Post-select families of the first work unit (R16 trace) behind dynamic boundaries
    # (JSON3.read results, Any-typed hooks/sources). Types come from the production JSON3 reader
    # on one literal synthetic document and from named concrete product types; Broadcasted types
    # are only constructed (never materialized). No file, data, task or environment.
    let j = JSON3.read("{\"o\":{\"a\":1},\"s\":[\"x\"],\"f\":[1.5],\"i\":[1],\"u\":[1,2.5]}"),
        bc(x...) = typeof(Base.Broadcast.broadcasted(x...)),
        ok = (precompile(Histograms._store_from_json, (typeof(j), String)),
              precompile(Base.Broadcast.materialize, (bc(Float64, j[:f]),)),
              precompile(Base.Broadcast.materialize, (bc(Float64, j[:i]),)),
              precompile(Base.Broadcast.materialize, (bc(Float64, j[:u]),)),
              precompile(Base.Broadcast.materialize, (bc(|, falses(0), Bool[]),)),
              precompile(Base.Broadcast.materialize, (bc(|, falses(0), falses(0)),)),
              precompile(EventIO._plain, (typeof(j),)),
              precompile(EventIO._plain, (typeof(j[:o]),)),
              precompile(EventIO._plain, (typeof(j[:s]),)),
              precompile(EventIO._plain, (typeof(j[:f]),)),
              precompile(EventIO._plain, (typeof(j[:i]),)),
              precompile(default_correct, (CorrectionContext,)),
              precompile(Core.kwcall, (NamedTuple{(:source,),Tuple{EventIO.LazyEventSource}}, typeof(Systematics.theory_member_weights),
                  Config.AnalysisConfig, Config.SampleConfig, String, Selection.EventTable, Dict{String,Vector{Float64}})),
              precompile(Config.validate_theory_manifest, (Dict{String,Any}, Vector{Tuple{String,String}})),
              precompile(EventIO.stream_basket_index, (UnROOT.TBranch_13,)))
        all(ok) || error("Pipeline post-select precompile declaration failed: $(ok)")
    end
end

# Reviewed named reusable barriers; pool/branch types are trained source-aware.
include("precompile_reusable_coverage.jl")
