#!/bin/bash
# Explicit bounded validation, never a scheduler/service or package installer.
set -u
: "${CASCADE_TTBAR_PROJECT:?absolute frozen gate project required}"
: "${CASCADE_TTBAR_AREA:?unused absolute gate result area required}"
P="$CASCADE_TTBAR_PROJECT"
A="$CASCADE_TTBAR_AREA"
export CASCADE_TTBAR_REAL=1 OPENBLAS_NUM_THREADS=1 JULIA_THREADS=2
L="$P/integration-logs"
mkdir -p "$L"
run_case() {
    name="$1"; shift
    test ! -e "$L/$name.log" && test ! -e "$L/$name.exit" || { echo "existing $name evidence; inspect, do not restart"; return 99; }
    nice -n10 bash "${CASCADE_ROOTPLOTS_RUNNER:?absolute path to a configured ROOTPlots Julia runner required}" --project="$P" "$@" > "$L/$name.log" 2>&1
    rc=$?
    printf '%s\n' "$rc" > "$L/$name.exit"
    echo "$name exit=$rc"
    tail -12 "$L/$name.log"
    return "$rc"
}
if test -n "${CASCADE_TTBAR_SYNTHETIC_REFERENCE:-}"; then
    R="$CASCADE_TTBAR_SYNTHETIC_REFERENCE"
    test "$(cat "$R/integration-logs/synthetic01.exit")" = 0 || exit 98
    for dir in src bin analyses examples test/config test/pipeline test/selection; do
        diff -qr "$P/$dir" "$R/$dir" || exit 97
    done
    cmp "$P/Project.toml" "$R/Project.toml" && cmp "$P/Manifest.toml" "$R/Manifest.toml" && cmp "$P/test/ttbar_integration/run_synthetic.jl" "$R/test/ttbar_integration/run_synthetic.jl" || exit 96
    echo "Reuse successful synthetic reference $R; relevant sources/config/tests byte-identical"
else
    run_case synthetic01 "$P/test/ttbar_integration/run_synthetic.jl" || exit $?
fi
if test -n "${CASCADE_TTBAR_REFERENCE:-}"; then
    phases="prepare-reuse hash-probe reduced-continue batch events compare inventories fitplot reports final"
else
    phases="prepare original export reduced batch events compare inventories fitplot reports final"
fi
for phase in $phases; do
    export CASCADE_TTBAR_PHASE="$phase"
    run_case "$phase"01 "$P/test/ttbar_integration/run_real.jl" || exit $?
done
(cd "$P" && sha256sum -c snapshot-source.before && sha256sum -c snapshot-inputs.before) > "$L/frozen-check.log" 2>&1
rc=$?
printf '%s\n' "$rc" > "$L/frozen-check.exit"
exit "$rc"
