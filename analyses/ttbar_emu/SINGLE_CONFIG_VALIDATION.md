# Single-config migration validation

Scratch: `gate:~/analisis/Cascade_dev/p4-single-config`, archived from Git HEAD
115436b, with only this lane's scoped changes rsynced over it and Manifest.toml
copied from `~/analisis/Cascade`. All execution used the gate wrapper and nice 10.
No commit or push was made. The parallel DY analysis was not edited.

## API/schema

`load_analysis` and `parse_analysis` accept `profile`; `RunOptions` has `profile`.
`resolve_config` deep-merges one overlay, replaces arrays, filters enabled entries
and option switches, and removes the unused catalog before section hashing.
Default profile workdirs append the profile name; an explicit runtime workdir
is exact. `cascade check` validates expressions, correction input bindings and
shape payload signatures and prints resolved input/model summaries.
`cascade init` copies the commented template without overwriting.

Reader overrides are in `samples.source`: `gen_weight` for cols;
`tree`, `runs_tree`, `gen_sumw` for NanoAOD. They enter skim and select keys and
are propagated to correction branch readers. JES/JER `inputs` maps semantic
payload names to aliases, preserving positional order and the default contract.

## Commands and results

Scratch preparation:

```sh
git -C /path/to/user/.openclaw/workspace-main/artifacts/Cascade.jl archive HEAD | ssh gate 'mkdir -p ~/analisis/Cascade_dev/p4-single-config && tar -x -C ~/analisis/Cascade_dev/p4-single-config'
ssh gate 'cp ~/analisis/Cascade/Manifest.toml ~/analisis/Cascade_dev/p4-single-config/Manifest.toml'
```

Scoped rsyncs copied `src/{Config,Pipeline,IO,Systematics}/`, `test/{config,pipeline}/`,
`analyses/ttbar_emu/`, and `analyses/TEMPLATE.toml` (with deletion for the removed
standalone production TOMLs).

Final targeted execution (inside scratch):

```sh
JULIA_THREADS=2 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/targeted.jl"
```

`targeted.log`, exit 0: 99 named assertions plus four successful CLI `main`
checks (103 total): config 86, init/check/custom generator weight 8, JES/JER
payload input aliases 5, and four `cascade check ... --profile` commands.
Profile equivalence checks compare every resolved raw section with the frozen
old parsed definitions, excluding only analysis name/workdir. Every profile
finds 13 samples / 3307 input files. Default and explicit baseline agree.

Full-suite command (effective wrapper thread count 4):

```sh
JULIA_NUM_THREADS=8 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/runtests.jl"
```

Full baseline command (8 threads):

```sh
CASCADE_REAL_DATA=1 CASCADE_REAL_WORKDIR="$PWD/out_baseline" JULIA_THREADS=8 nice -n 10 bash ~/packages/rootplots-gate.sh --project="$PWD" "$PWD/test/pipeline/test_real_reproduction.jl"
```

Full baseline: exit 0, 350/350 assertions, 13m05.1s on all 3307 files.
Data yields are exactly 5905 and 3836; MC yields are exactly
6434.931560809516 and 4235.210227397772. The reported maximum MC
bin/cutflow relative difference is exactly zero.

The separate exact-zero oracle ran with the same environment/workdir and
`test/pipeline/test_bitexact_profiles.jl`: exit 0, 50/50 assertions.

The migrated SF profile contract in `test/config/test_sf_profile_contract.jl`
ran standalone through the same wrapper with JULIA_THREADS=2: exit 0, 32/32
assertions. It provides a replacement for the obsolete out-of-scope config test.

Final full suite: exit 1, 47,659 passing assertions, two errors and one
existing broken plotting assertion. The only errors are the two obsolete
standalone-file testsets in `test/systematics/weights/test_ttbar_sf_config.jl`.
All implementation-facing testsets pass: config 86, corrections 209, fit 305,
histograms 28, IO 41, objects 20,011, pipeline 166, plotting 187, selection 115,
systematics 26,511. The separate migrated SF contract adds 32 passing checks.
A clean full-suite claim is blocked until the coordinator migrates the
out-of-scope stale test references listed below.
The additional `test/pipeline/test_bitexact_profiles.jl` tightens the existing
real-data tolerance oracle to zero difference on every reported quantity.

## Framework audit / remaining boundaries

No runtime ttbar/sample/era names were found beyond examples/docstrings.
NanoAOD collection fields (`pt`, `eta`, `phi`, `mass`) and `n<collection>` counters
remain format conventions. `Selection.read_selection_columns` still names
`run`/`luminosityBlock` for the lumimask builtin (outside this lane's write scope).
JES/JER alias mappings rename input contracts but do not reorder payload inputs
or change the smearing algorithm. Custom source options are constrained to the
currently documented built-in source keys by the central schema.

Two existing files outside the assigned write scope still refer to deleted
standalone production configurations:
`test/systematics/weights/test_ttbar_sf_config.jl` and
`test/systematics/weights/test_ttbar_sf_real.jl`. Their paths/raw TOML comparisons
must migrate to `load_analysis(analysis.toml; profile="sf").raw`; the trigger
fragment now lives in `test/config/fixtures/trigger_normsys.toml`. These test
files were deliberately not edited by this lane.
