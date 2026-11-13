# Scale-factor oracle (gate only)

Independent check of the per-event weights produced by
`Cascade.Systematics.apply_corrections` for `analyses/ttbar_emu/analysis.toml (profile "sf")`.
Python (uproot, awkward, correctionlib 2.8.0 from LCG_110) is used only here.

1. Run the analysis with scale factors (any workdir):

       CASCADE_REAL_DATA=1 CASCADE_SF_RUN=1 CASCADE_SF_WORKDIR=$W julia +release --project=. \
           -e 'using Test, Cascade; include("test/systematics/runtests.jl")'

2. List kept events and compute the oracle weights:

       julia +release --project=. tools/oracle/sf_dump_events.jl $W events.tsv 20000 TTto2L2Nu
       (source /cvmfs/sft.cern.ch/lcg/views/LCG_110/x86_64-el9-clang22-dbg/setup.sh; \
           python3 tools/oracle/sf_oracle.py events.tsv oracle.tsv)

3. Compare (relative difference <= 1e-12 for every weight column, >= 1000 events):

       CASCADE_SF_ORACLE=oracle.tsv CASCADE_SF_WORKDIR=$W CASCADE_SF_SAMPLES=TTto2L2Nu \
           julia +release --project=. -e 'using Test, Cascade; include("test/systematics/runtests.jl")'

The oracle re-derives the selected tight electron/muon from the raw NanoAOD
branches (exactly one of each is required) and evaluates the corrections with
the same inputs (SC eta = Float32 `Electron_eta + Electron_deltaEtaSC`).
