# Lightweight skim metadata (opt-in)

execution.lightweight_skim_metadata=true enables the no-checkpoint full-chain NanoAOD route with configured luminosity and no variations. Default false. Checkpoint and unsupported routes keep ordinary nevents. No GC/runtime default changes.

Audited UnROOT0.11.11 source hashes and supported TTree20/TKey framing are required. Existing versioned base readers precede the Int64 fEntries read. The serialized metadata object is still decoded, not merely eight disk bytes. Runs normalization/source identity are unchanged. Unsupported formats decline before admission; malformed admitted prefixes throw.

Important: branch-tail parsing/error detection moves from skim to the unchanged mandatory select parser before final publication. This is not full-tree validation during skim. Original data are never modified.

Validation:396/396 real files activated,233876675 total events, exact entry counts/signed Runs Float64 bits, no Events tree cache insertion. Publicskim396 records/exposure and four full science17 sets identical. R32 adapter OFF→ON mean wall64.117→62.502s,body52.991→51.634s,Julia cumulativeallocation59.572→56.605GB. Two runs perarm/sharedhost; final native CLI comparison separate.

Standalone: CASCADE_UNROOT_SOURCE=<audited UnROOT/src> julia --startup-file=no --threads=2 test/skim_entrycount/pipeline_gate.jl
Primitive excerpts are synthetic fixtures. Native evidence: workspace artifacts/cascade-skim-entrycount-20261113/native-validation.
