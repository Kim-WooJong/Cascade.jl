# Reuse-aware package image coverage

Image-generation-only declarations now include reusable basket barriers and actual
buffer/accounting-enabled keyword shapes, retaining previous OFF coverage. Types
come from tracked analysis/spec and zero-event WindowBufferReuse; observer type
comes from existing typed IR helper, not printed generated closure names.
No ROOT input, data warm-up, task launch or runtime GC setting is added.

Pinned Julia1.12.2 Linux image build accepted28reuse-keyword+16basket+14named
precompile calls. These are declaration calls, not unique methods or saved wall.
R28 real6case smoke and4full396-file runs preserve all17 scientific outputs exactly.
Baseline/candidate sameGC4,0; adapter wall73.107→68.647s, body61.141→56.968s.
R27 candidate68.664s was similar, so R28 percentage is NOT additionalrev2speedup.
Sharedhost,2runs/arm, compilation counters nonadditive. Build95.400s separately.
Production flags/defaults unchanged. Workspace evidence:
artifacts/cascade-compile-coverage-20261112/rev2/native-validation/.
