"""
    Cascade.IO

Event input behind the `AbstractEventSource` interface (NanoAOD via UnROOT,
Cascade column files and verified standalone reduced ROOT RNTuple bundles), the Cascade column-file format used for intermediate
artifacts, input-file discovery and the certified-luminosity mask.
"""
module IO

using UnROOT
using JSON3
using SHA
using ..Config: canonical_hash

include("AbstractEventSource.jl")
include("Jagged.jl")
include("open_source.jl")
include("file_signature.jl")
include("ReusableBasketScratch.jl")
include("read_reusable_basket.jl")
include("read_nanoaod_branch.jl")
include("NanoAODSource.jl")
include("write_column_file.jl")
include("read_column_file.jl")
include("ColumnFileSource.jl")
include("export_column_count.jl")
include("export_column_offsets.jl")
include("export_column_bools.jl")
include("open_export_columns.jl")
include("normalization_metadata.jl")
include("LazyEventSource.jl")
include("source_population.jl")
include("population_identity.jl")
include("reduced_metadata_hash.jl")
include("read_reduced_metadata.jl")
include("reduced_column_schema.jl")
include("write_reduced_rntuple.jl")
include("ReducedRNTupleSource.jl")
include("read_nanoaod_window.jl")
include("EventWindowSource.jl")
include("reduced_safe_path.jl")
include("read_reduced_group.jl")
include("read_reduced_shard.jl")
include("ReducedGroupSource.jl")
include("ReducedShardSource.jl")
include("validate_source_populations.jl")
include("builtin_source_readers.jl")
include("ColumnReadScope.jl")
include("column_read_eligibility.jl")
include("column_source_identity.jl")
include("open_column_reader.jl")
include("with_column_read_scope.jl")
include("with_column_readers.jl")
include("column_read_jobs.jl")
include("read_column_jobs.jl")
include("read_parallel_columns.jl")
include("decode_dependency_contract.jl")
include("skim_nanoaod_entrycount.jl")
include("decode_source_identity.jl")
include("validate_decode_xz_index.jl")
include("validate_decode_blocks.jl")
include("validate_decode_checksum.jl")
include("DecodePipeline.jl")
include("decode_worker_loop.jl")
include("run_decode_queue.jl")
include("decode_interpretation_supported.jl")
include("prepare_nanoaod_decode.jl")
include("decode_prepared_basket.jl")
include("assemble_decoded_basket.jl")
include("read_decoded_columns.jl")
include("with_decode_pipeline.jl")
include("precompile_decode.jl")
include("stream_plan_branch_lookup.jl")
# Production support for stream_plan_branch_index (opt-in reusable planner only). It replicates
# the public "tree/name" lookup and the ROOTFile cache/lock internals of EXACTLY UnROOT 0.11.11;
# matching types alone do not cover other versions, so any other version or field layout makes
# every ROOTFile unsupported and the planner uses the public lookup. Defined here, not in
# StreamWindowReader.jl, so that file still loads under the stub-UnROOT focused test harnesses.
stream_plan_unroot_layout_supported() = Base.pkgversion(UnROOT) == v"0.11.11" &&
    hasfield(UnROOT.ROOTFile, :cache) && fieldtype(UnROOT.ROOTFile, :cache) === Dict{Any,Any} &&
    hasfield(UnROOT.ROOTFile, :lock) && fieldtype(UnROOT.ROOTFile, :lock) === ReentrantLock
stream_plan_file_supported(::UnROOT.ROOTFile) = stream_plan_unroot_layout_supported()
stream_plan_tree_supported(::UnROOT.TTree) = true
stream_plan_container_supported(::UnROOT.TObjArray) = true
stream_plan_branch_supported(::Union{UnROOT.TBranch,UnROOT.TBranchElement}) = true
include("StreamWindowReader.jl")
include("stream_reusable_decoder.jl")
include("expand_files.jl")
include("LumiMask.jl")
include("load_lumimask.jl")
include("lumimask_column.jl")

export with_decode_pipeline, read_decoded_columns, with_column_readers, read_parallel_columns, AbstractEventSource, LazyEventSource, nevents, column_names, read_columns, gen_weight_sum,
       source_signature, close_source, normalization_metadata, builtin_source_readers,
       Jagged, open_source, register_source_format!, source_formats,
       NanoAODSource, ColumnFileSource, ReducedRNTupleSource, file_signature,
       source_population, population_identity, validate_source_populations, read_reduced_metadata,
       reduced_column_schema, write_reduced_rntuple, EventWindowSource, read_nanoaod_window,
       ReducedGroupSource, ReducedShardSource, read_reduced_group, read_reduced_shard,
       write_column_file, read_column_file, open_export_columns,
       expand_files, LumiMask, load_lumimask, in_lumimask, lumimask_column

end # module
