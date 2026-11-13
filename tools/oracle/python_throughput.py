#!/usr/bin/env python3
"""Reference throughput of correctionlib (vectorized evalv) on the successful
points of oracle files, tiled to the same row count as the Julia measurement
(test/corrections/measure_throughput.jl). External test tool only.

Usage: python_throughput.py ORACLE_DIR [--rows N]
"""
import argparse
import glob
import json
import os
import time

import numpy as np
import correctionlib._core as core


def decode(a, t):
    if t == "string":
        return a
    if t == "int":
        return int(a)
    return float.fromhex(a)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--rows", type=int, default=200_000)
    a = ap.parse_args()
    for path in sorted(glob.glob(os.path.join(a.dir, "*.oracle.json"))):
        with open(path) as f:
            o = json.load(f)
        cset = core.CorrectionSet.from_file(o["source"])
        total_rows, total_time = 0, 0.0
        for e in o["corrections"]:
            c = cset.compound[e["name"]] if e["compound"] else cset[e["name"]]
            types = e["input_types"]
            rows = [[decode(x, t) for x, t in zip(args, types)]
                    for args, err in zip(e["args"], e["errors"]) if err is None and len(args) == len(types)]
            if not rows:
                continue
            idx = np.arange(a.rows) % len(rows)
            # evalv takes scalar strings: split the tiled rows by their string values
            sidx = [j for j, t in enumerate(types) if t == "string"]
            groups = {}
            for i in idx:
                groups.setdefault(tuple(rows[i][j] for j in sidx), []).append(i)
            calls = []
            for key, members in groups.items():
                svals = dict(zip(sidx, key))
                cols = []
                for j, t in enumerate(types):
                    if t == "string":
                        cols.append(svals[j])
                    else:
                        cols.append(np.asarray([rows[i][j] for i in members],
                                               dtype=np.int64 if t == "int" else np.float64))
                calls.append(cols)
            for cols in calls:
                c.evalv(*cols)
            best = min(_timed(c, calls) for _ in range(3))
            total_rows += a.rows
            total_time += best
        if total_time > 0:
            print(f"{os.path.basename(path)}: correctionlib evalv {total_rows / total_time / 1e6:.2f} M evals/s "
                  f"({total_rows} rows)")


def _timed(c, calls):
    t0 = time.perf_counter()
    for cols in calls:
        c.evalv(*cols)
    return time.perf_counter() - t0


if __name__ == "__main__":
    main()
