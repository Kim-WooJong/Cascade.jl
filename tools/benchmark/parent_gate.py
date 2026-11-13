#!/usr/bin/env python3
"""Parent-only: exactly one authorized Julia process, <=120s, no package imports."""
import argparse
import json
from pathlib import Path
import sys
import time
from report import build
from run import host_clock, run, write_json

def validate(source):
    source = Path(source)
    receipt = json.loads((source / "receipt.json").read_text())
    if receipt["status"] != "completed":
        raise AssertionError("Julia parent gate did not complete; retain receipt/logs")
    text = (source / "stdout.log").read_text()
    def numbers(prefix):
        return [int(x) for x in next(line for line in text.splitlines() if line.startswith(prefix)).split("=",1)[1].split(",")]
    stamp, = numbers("UV_CLOCK_NS=")
    assert receipt["start_monotonic_ns"] <= stamp <= receipt["end_monotonic_ns"]
    lo, t, hi = numbers("CLOCK_BRACKET=")
    assert lo <= t <= hi
    if sys.platform == "darwin":
        lo, t, hi = numbers("OTHER_CLOCK_BRACKET=")
        assert not lo <= t <= hi
    assert "PARENT_GATE_COMPLETED" in text
    summary = build(source, source.parent / (source.name + "-report"))
    assert summary["trace_status"] == "complete"
    spans = summary["spans"]
    for phase in ("select", "correct", "histogram"):
        assert sum(s["stage"] == phase for s in spans) == 4
    assert {"no_checkpoints_run", "skim", "preparation", "chain_merge", "merge", "publication"} <= {s["stage"] for s in spans}
    failed = [s for s in spans if s["status"] == "failed"]
    assert len(failed) == 1 and failed[0]["stage"] == "failure_fixture"
    write_json(source / "parent-verification.json", dict(schema_version=1, status="passed",
               scope="stdlib-only real production trace library, lowering and host-clock integration; NOT full Cascade", spans=len(spans)))
    return summary

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--julia", required=True, help="already-approved existing Julia executable")
    p.add_argument("--output", required=True, help="new diagnostic output directory")
    p.add_argument("--timeout", type=float, default=120, help="bounded parent gate deadline, at most 120 seconds")
    a = p.parse_args()
    if not 0 < a.timeout <= 120:
        p.error("--timeout must be greater than 0 and at most 120 seconds")
    name, _ = host_clock()
    selected = getattr(time, name)
    other = time.CLOCK_MONOTONIC if sys.platform == "darwin" else getattr(time, "CLOCK_MONOTONIC_RAW", selected)
    helper = Path(__file__).resolve().parents[2] / "test" / "benchmark_telemetry" / "parent_gate.jl"
    run([a.julia, "--startup-file=no", "--history-file=no", "--compiled-modules=no", "--pkgimages=no",
         "--threads=4", "--gcthreads=1", str(helper), str(selected), str(other)],
        a.output, timeout=a.timeout, interval=.1, trace=True)
    validate(a.output)

if __name__ == "__main__":
    main()
