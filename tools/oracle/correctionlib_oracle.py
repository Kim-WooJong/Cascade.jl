#!/usr/bin/env python3
"""Test oracle for Cascade.Corrections (external tool, not a runtime dependency).

For every correction and compound correction of a correctionlib JSON file,
generate input points (bin edges and their neighbours, flow regions, category
keys and missing keys, random values, plus points sampled by walking the node
tree so that the leaves are reached), evaluate them with the Python
correctionlib, and write points + results/errors to a JSON file that the Julia
comparison (test/corrections/oracle_compare.jl) reads.

Floats are written as float.hex() strings so values round-trip exactly.

Usage: correctionlib_oracle.py INPUT.json[.gz] OUTPUT.json [--seed S]
                               [--min-points N] [--max-points M]
"""
import argparse
import bisect
import gzip
import json
import math
import random

import correctionlib
import correctionlib._core as core

MISSING_STRING = "__oracle_missing_key__"


def load_raw(path):
    with open(path, "rb") as f:
        magic = f.read(2)
    opener = gzip.open if magic == b"\x1f\x8b" else open
    with opener(path, "rt") as f:
        return json.load(f)


def parse_edge(e):
    if isinstance(e, str):
        return math.inf if e in ("inf", "+inf") else -math.inf
    return float(e)


def axis_edges(edges):
    """Edge list of a Binning/MultiBinning axis (uniform axes expanded)."""
    if isinstance(edges, dict):
        n, lo, hi = int(edges["n"]), float(edges["low"]), float(edges["high"])
        return [lo + i * (hi - lo) / n for i in range(n)] + [hi]
    return [parse_edge(e) for e in edges]


def is_node(x):
    return isinstance(x, dict) and "nodetype" in x


class Space:
    """Interesting values collected per input name."""

    def __init__(self):
        self.reals = {}
        self.ints = {}
        self.strs = {}

    def add_real(self, name, v):
        if math.isfinite(v):
            self.reals.setdefault(name, set()).add(v)

    def add_edges(self, name, edges):
        if len(edges) > 2000:
            edges = edges[:: len(edges) // 1000] + [edges[-1]]
        finite = [e for e in edges if math.isfinite(e)]
        for e in finite:
            self.add_real(name, e)
            self.add_real(name, math.nextafter(e, -math.inf))
            self.add_real(name, math.nextafter(e, math.inf))
            if e == 0.0:
                self.add_real(name, -0.0)
        for a, b in zip(finite, finite[1:]):
            self.add_real(name, 0.5 * (a + b))
        if finite:
            lo, hi = min(finite), max(finite)
            self.add_real(name, lo - 1.0 - abs(lo))
            self.add_real(name, hi + 1.0 + abs(hi))


def collect(node, space):
    if not is_node(node):
        return
    t = node["nodetype"]
    if t == "binning":
        space.add_edges(node["input"], axis_edges(node["edges"]))
        for c in node["content"]:
            collect(c, space)
        collect(node["flow"], space)
    elif t == "multibinning":
        for name, e in zip(node["inputs"], node["edges"]):
            space.add_edges(name, axis_edges(e))
        for c in node["content"]:
            collect(c, space)
        collect(node["flow"], space)
    elif t == "category":
        name = node["input"]
        for item in node["content"]:
            k = item["key"]
            if isinstance(k, str):
                space.strs.setdefault(name, set()).add(k)
            else:
                space.ints.setdefault(name, set()).add(int(k))
            collect(item["value"], space)
        if node.get("default") is not None:
            collect(node["default"], space)
    elif t == "transform":
        collect(node["rule"], space)
        collect(node["content"], space)


def random_real(rng, space, name):
    r = rng.random()
    vals = space.reals.get(name)
    if vals and r < 0.35:
        return rng.choice(sorted(vals))
    if r < 0.55:
        return rng.uniform(-5.0, 5.0)
    if r < 0.80:
        return math.exp(rng.uniform(math.log(1e-2), math.log(1e4)))
    if r < 0.88:
        return -math.exp(rng.uniform(math.log(1e-2), math.log(1e4)))
    if r < 0.94:
        return float(rng.randint(-10, 200))
    return rng.choice([0.0, -0.0, 1.0, -1.0, 1e-300, 1e300])


def random_int(rng, space, name):
    vals = space.ints.get(name)
    if vals and rng.random() < 0.8:
        k = rng.choice(sorted(vals))
        return k + rng.choice([0, 0, 0, 0, -1, 1])
    return rng.randint(-5, 400000)


def random_str(rng, space, name):
    vals = space.strs.get(name)
    if vals and rng.random() < 0.9:
        return rng.choice(sorted(vals))
    return MISSING_STRING


def value_in_bin(rng, lo, hi):
    if not math.isfinite(lo):
        lo = hi - 10.0 * (1.0 + abs(hi))
    if not math.isfinite(hi):
        hi = lo + 10.0 * (1.0 + abs(lo))
    r = rng.random()
    if r < 0.5:
        v = rng.uniform(lo, hi)
        return v if v < hi else lo
    if r < 0.65:
        return lo
    if r < 0.8:
        return math.nextafter(hi, -math.inf)
    if r < 0.9:
        return 0.5 * (lo + hi)
    return math.nextafter(lo, math.inf)


class Walker:
    """Assigns input values by walking the node tree along random branches."""

    def __init__(self, rng, space, types, generic):
        self.rng = rng
        self.space = space
        self.types = types
        self.generic = generic

    def coerce(self, name, v):
        return int(math.floor(v)) if self.types[name] == "int" else v

    def pick_axis_value(self, name, edges):
        rng = self.rng
        r = rng.random()
        n = len(edges) - 1
        if r < 0.86:
            i = rng.randrange(n)
            return self.coerce(name, value_in_bin(rng, edges[i], edges[i + 1])), i
        hi, lo = edges[-1], edges[0]
        if r < 0.93:
            if math.isfinite(hi):
                v = hi if rng.random() < 0.5 else hi + 1.0 + abs(hi)
            else:
                v = 1e300
            return self.coerce(name, v), None
        if math.isfinite(lo):
            v = math.nextafter(lo, -math.inf) if rng.random() < 0.5 else lo - 1.0 - abs(lo)
        else:
            v = -1e300
        return self.coerce(name, v), None

    @staticmethod
    def locate(edges, v):
        if v != v:
            return None
        pos = bisect.bisect_right(edges, v)
        if pos == 0 or pos == len(edges):
            return None
        return pos - 1

    def walk(self, node, assign):
        if not is_node(node):
            return
        t = node["nodetype"]
        rng = self.rng
        if t == "category":
            name = node["input"]
            items = node["content"]
            default = node.get("default")
            if name in assign:
                for it in items:
                    if it["key"] == assign[name]:
                        self.walk(it["value"], assign)
                        return
                if default is not None:
                    self.walk(default, assign)
                return
            if items and rng.random() < 0.9:
                it = rng.choice(items)
                assign[name] = it["key"]
                self.walk(it["value"], assign)
                return
            if self.types[name] == "string":
                assign[name] = MISSING_STRING
            else:
                ints = [int(it["key"]) for it in items] or [0]
                assign[name] = max(ints) + 1 + rng.randint(0, 3)
            if default is not None:
                self.walk(default, assign)
        elif t == "binning":
            name = node["input"]
            edges = axis_edges(node["edges"])
            if name in assign:
                i = self.locate(edges, float(assign[name]))
            else:
                v, i = self.pick_axis_value(name, edges)
                assign[name] = v
            self.walk(node["flow"] if i is None else node["content"][i], assign)
        elif t == "multibinning":
            axes = [axis_edges(e) for e in node["edges"]]
            locs = []
            for name, edges in zip(node["inputs"], axes):
                if name in assign:
                    i = self.locate(edges, float(assign[name]))
                else:
                    v, i = self.pick_axis_value(name, edges)
                    assign[name] = v
                locs.append(i)
            if any(i is None for i in locs):
                self.walk(node["flow"], assign)
                return
            idx, stride = 0, 1
            for i, edges in reversed(list(zip(locs, axes))):
                idx += i * stride
                stride *= len(edges) - 1
            self.walk(node["content"][idx], assign)
        elif t == "formula":
            for name in node["variables"]:
                if name not in assign:
                    assign[name] = random_real(rng, self.space, name)
        elif t == "formularef":
            for name in self.generic[node["index"]]["variables"]:
                if name not in assign:
                    assign[name] = random_real(rng, self.space, name)
        elif t == "transform":
            name = node["input"]
            self.walk(node["rule"], assign)
            inner = dict(assign)
            inner.pop(name, None)
            self.walk(node["content"], inner)
            for k, v in inner.items():
                if k != name and k not in assign:
                    assign[k] = v
        elif t == "hashprng":
            for name in node["inputs"]:
                if name not in assign:
                    if self.types[name] == "int":
                        assign[name] = random_int(rng, self.space, name)
                    else:
                        assign[name] = random_real(rng, self.space, name)


def fill(rng, space, inputs, assign):
    args = []
    for var in inputs:
        name, t = var["name"], var["type"]
        if name in assign:
            v = assign[name]
        elif t == "real":
            v = random_real(rng, space, name)
        elif t == "int":
            v = random_int(rng, space, name)
        else:
            v = random_str(rng, space, name)
        if t == "real":
            v = float(v)
        elif t == "int":
            v = int(v)
        else:
            v = str(v)
        args.append(v)
    return args


def encode_arg(v):
    return float.hex(v) if isinstance(v, float) else v


def count_nodes(node):
    if isinstance(node, dict):
        return 1 + sum(count_nodes(v) for v in node.values())
    if isinstance(node, list):
        return sum(count_nodes(v) for v in node)
    return 0


def run_correction(evaluator, inputs, datas, generics, rng, npoints):
    types = {v["name"]: v["type"] for v in inputs}
    space = Space()
    for d in datas:
        collect(d, space)

    def walked(assign):
        for d, g in zip(datas, generics):
            Walker(rng, space, types, g).walk(d, assign)
        return assign

    points = []
    for p in range(npoints):
        points.append(fill(rng, space, inputs, walked({}) if p % 10 < 7 else {}))
    # edge sweep: every collected value of every real input once, rest tree-guided
    for var in inputs:
        if var["type"] == "real":
            for v in sorted(space.reals.get(var["name"], ()))[:5000]:
                assign = walked({var["name"]: v})
                points.append(fill(rng, space, inputs, assign))
    # wrong number of arguments
    points.append(fill(rng, space, inputs, {}) + [0.0])
    results, errors = [], []
    for args in points:
        try:
            r = evaluator.evaluate(*args)
            results.append(float.hex(float(r)))
            errors.append(None)
        except Exception as exc:  # noqa: BLE001 - every failure is recorded
            results.append(None)
            errors.append(f"{type(exc).__name__}: {exc}")
    return {
        "input_types": [v["type"] for v in inputs],
        "args": [[encode_arg(a) for a in args] for args in points],
        "results": results,
        "errors": errors,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("output")
    ap.add_argument("--seed", type=int, default=12345)
    ap.add_argument("--min-points", type=int, default=1000)
    ap.add_argument("--max-points", type=int, default=20000)
    a = ap.parse_args()

    raw = load_raw(a.input)
    cset = core.CorrectionSet.from_file(a.input)
    rng = random.Random(a.seed)
    out = {"source": a.input, "correctionlib": correctionlib.__version__, "seed": a.seed, "corrections": []}
    by_name = {c["name"]: c for c in raw["corrections"]}
    for c in raw["corrections"]:
        n = max(a.min_points, min(a.max_points, 2 * count_nodes(c["data"])))
        entry = run_correction(cset[c["name"]], c["inputs"], [c["data"]],
                               [c.get("generic_formulas") or []], rng, n)
        entry.update(name=c["name"], compound=False)
        out["corrections"].append(entry)
        print(f"{c['name']}: {len(entry['args'])} points, "
              f"{sum(e is not None for e in entry['errors'])} errors", flush=True)
    for c in raw.get("compound_corrections") or []:
        stack = [by_name[s] for s in c["stack"]]
        entry = run_correction(cset.compound[c["name"]], c["inputs"], [s["data"] for s in stack],
                               [s.get("generic_formulas") or [] for s in stack], rng, 2 * a.min_points)
        entry.update(name=c["name"], compound=True)
        out["corrections"].append(entry)
        print(f"{c['name']} (compound): {len(entry['args'])} points, "
              f"{sum(e is not None for e in entry['errors'])} errors", flush=True)
    with open(a.output, "w") as f:
        json.dump(out, f)


if __name__ == "__main__":
    main()
