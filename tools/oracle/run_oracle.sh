#!/usr/bin/env bash
# Produce correctionlib oracle outputs (gate only). The LCG view is sourced in a
# subshell for the Python oracle; Julia is never run inside that environment.
#   bash tools/oracle/run_oracle.sh [OUTDIR]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$HERE/../../oracle_out}
POG=/cvmfs/cms.cern.ch/rsync/cms-nanoAOD/jsonpog-integration/POG
LCG=/cvmfs/sft.cern.ch/lcg/views/LCG_110/x86_64-el9-clang22-dbg/setup.sh
FILES="MUO/2022_Summer22/muon_Z EGM/2022_Summer22/electron EGM/2022_Summer22/electronHlt
LUM/2022_Summer22/puWeights BTV/2022_Summer22/btagging JME/2022_Summer22/jet_jerc JME/2022_Summer22/jetvetomaps"
mkdir -p "$OUT"
(
    set +u
    source "$LCG" >/dev/null 2>&1
    set -u
    python3 "$HERE/schema_cases.py" "$OUT/schema_cases.json"
    python3 "$HERE/correctionlib_oracle.py" "$OUT/schema_cases.json" "$OUT/schema_cases.oracle.json"
    for f in $FILES; do
        python3 "$HERE/correctionlib_oracle.py" "$POG/$f.json.gz" "$OUT/$(echo "$f" | tr / _).oracle.json"
    done
)
