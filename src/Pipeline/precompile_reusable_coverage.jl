# R26 reviewed named barriers retained; image generation ONLY.
if ccall(:jl_generating_output, Cint, ()) == 1
    # R26 trace line 467 (inclusive root 53.5 ms; NOT saved wall).
    precompile(Tuple{typeof(EventIO._decode_xz_window!), Array{UInt8, 1}, Array{UInt8, 1}, Int64, Int64, Int64, Int64, NamedTuple{(:scratch, :codec), Tuple{EventIO._NanoAODScratch, Base.RefValue{Any}}}}) || error("Reusable named precompile root 467 rejected")
    # R26 trace line 496 (inclusive root 66.5 ms; NOT saved wall).
    precompile(Tuple{typeof(EventIO._validate_basket_offsets), Array{UInt8, 1}, Int64, Int64, Int64, Int64, Array{Int64, 1}, Int64, Type{UInt8}}) || error("Reusable named precompile root 496 rejected")
    # R26 trace line 501 (inclusive root 69.9 ms; NOT saved wall).
    precompile(Tuple{typeof(EventIO._validate_basket_offsets), Array{UInt8, 1}, Int64, Int64, Int64, Int64, Array{Int64, 1}, Int64, Type{Float32}}) || error("Reusable named precompile root 501 rejected")
    # R26 trace line 504 (inclusive root 64.8 ms; NOT saved wall).
    precompile(Tuple{typeof(EventIO._validate_basket_offsets), Array{UInt8, 1}, Int64, Int64, Int64, Int64, Array{Int64, 1}, Int64, Type{Bool}}) || error("Reusable named precompile root 504 rejected")
    # R26 trace line 506 (inclusive root 70.4 ms; NOT saved wall).
    precompile(Tuple{typeof(EventIO._validate_basket_offsets), Array{UInt8, 1}, Int64, Int64, Int64, Int64, Array{Int64, 1}, Int64, Type{Int32}}) || error("Reusable named precompile root 506 rejected")
    # R26 trace line 480 (inclusive root 32.1 ms; NOT saved wall).
    precompile(Tuple{typeof(EventIO._validate_basket_offsets), Array{UInt8, 1}, Int64, Int64, Int64, Int64, Nothing, Int64, Type{Float32}}) || error("Reusable named precompile root 480 rejected")
    # R26 trace line 484 (inclusive root 33.4 ms; NOT saved wall).
    precompile(Tuple{typeof(EventIO._validate_basket_offsets), Array{UInt8, 1}, Int64, Int64, Int64, Int64, Nothing, Int64, Type{Bool}}) || error("Reusable named precompile root 484 rejected")
    # R26 trace line 481 (inclusive root 37.8 ms; NOT saved wall).
    precompile(Tuple{typeof(EventIO._copy_primitive_endian!), Array{Float32, 1}, Int64, Array{UInt8, 1}, Int64}) || error("Reusable named precompile root 481 rejected")
    # R26 trace line 487 (inclusive root 30.7 ms; NOT saved wall).
    precompile(Tuple{typeof(EventIO._copy_primitive_endian!), Array{Bool, 1}, Int64, Array{UInt8, 1}, Int64}) || error("Reusable named precompile root 487 rejected")
    # R26 trace line 427 (inclusive root 160.0 ms; NOT saved wall).
    precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:expected,), Tuple{NamedTuple{(:identity, :mapped_path), Tuple{NamedTuple{(:mapping, :path), Tuple{NamedTuple{(:major, :minor, :inode, :length), Tuple{UInt64, UInt64, UInt64, Int64}}, NamedTuple{(:device, :inode, :size, :mtime, :ctime), Tuple{UInt64, UInt64, Int64, Float64, Float64}}}}, String}}}}, typeof(EventIO.decode_source_identity), EventIO.NanoAODSource}) || error("Reusable named precompile root 427 rejected")
    # R26 trace line 538 (inclusive root 80.5 ms; NOT saved wall).
    precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:validate,), Tuple{Bool}}, typeof(finish_stream_selection!), StreamSelectionAnalysis, Int64}) || error("Reusable named precompile root 538 rejected")
    # R26 trace line 558 (inclusive root 30.3 ms; NOT saved wall).
    precompile(Tuple{typeof(handoff_table_metadata), Selection.EventTable}) || error("Reusable named precompile root 558 rejected")
    # R26 trace line 591 (inclusive root 143.6 ms; NOT saved wall).
    precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:table, :weights, :persist), Tuple{Selection.EventTable, Tuple{Base.Dict{String, Any}, Base.Dict{String, Any}, Array{String, 1}}, Bool}}, typeof(execute_histogram_chunk), StepContext, NamedTuple{(:cfg, :code, :chash), Tuple{Config.AnalysisConfig, String, String}}, Tuple{Config.SampleConfig, String, String, String, String, String, Array{String, 1}}}) || error("Reusable named precompile root 591 rejected")
    # R26 trace line 604 (inclusive root 62.3 ms; NOT saved wall).
    precompile(Tuple{typeof(Histograms._fill_columns!), Histograms.BinnedHist, Base.BitArray{1}, Array{Array{Float64, 1}, 1}, Array{Float64, 1}}) || error("Reusable named precompile root 604 rejected")
end
