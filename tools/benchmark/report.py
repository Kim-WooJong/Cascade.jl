#!/usr/bin/env python3
"""Reproducible offline JSON/CSV/HTML+SVG report. Standard library only."""
import argparse
import csv
import hashlib
import html
import json
from pathlib import Path
from proc_metrics import IO_KEYS
from run import HOST_CLOCKS, write_json

MAX_ROWS = 1000000
MAX_BYTES = 256 * 1024 * 1024

def load_jsonl(path):
    if path.stat().st_size > MAX_BYTES:
        raise ValueError("input exceeds bounded report size")
    rows = []
    with path.open() as f:
        for line in f:
            if len(rows) >= MAX_ROWS:
                raise ValueError("row bound exceeded")
            row = json.loads(line)
            if row.get("schema_version") != 1 or type(row.get("monotonic_ns")) is not int:
                raise ValueError("unsupported schema or timestamp")
            rows.append(row)
    return rows

def spans_from_events(events):
    opened, closed, spans = {}, set(), []
    for e in sorted(events, key=lambda r: r["monotonic_ns"]):
        if (type(e.get("pid")) is not int or not isinstance(e.get("span_id"), str)
                or not isinstance(e.get("task_id"), str) or not isinstance(e.get("stage"), str)):
            raise ValueError("invalid span identity")
        key = (e["pid"], e["span_id"])
        if e["event"] == "begin":
            if key in opened or key in closed:
                raise ValueError("duplicate span ID")
            opened[key] = e
        elif e["event"] == "end":
            if key not in opened or e.get("status") not in ("completed", "failed"):
                raise ValueError("unmatched end or invalid status")
            begin = opened.pop(key)
            if any(begin.get(k) != e.get(k) for k in ("stage", "sample", "chunk", "task_id")):
                raise ValueError("span identity changed")
            spans.append(dict(begin, end_ns=e["monotonic_ns"], status=e["status"]))
            closed.add(key)
        else:
            raise ValueError("unknown event")
    spans.extend(dict(e, end_ns=None, status="incomplete") for e in opened.values())
    return sorted(spans, key=lambda r: (r["monotonic_ns"], r["span_id"]))

def active(spans, t):
    return [s["span_id"] for s in spans if s["monotonic_ns"] <= t and
            (s["end_ns"] is None or t < s["end_ns"])]

def delta(a, b, key):
    if not a or not b or (a["pid"], a["start_ticks"]) != (b["pid"], b["start_ticks"]):
        return None
    x, y = a.get(key), b.get(key)
    return y - x if x is not None and y is not None and y >= x else None

def interval_rows(samples, spans):
    rows = []
    for a, b in zip(samples, samples[1:]):
        lo, hi = a["monotonic_ns"], b["monotonic_ns"]
        if hi <= lo:
            raise ValueError("nonmonotonic samples")
        # Counters are root-process live brackets, never accumulated across descendants.
        row = dict(schema_version=1, start_ns=lo, end_ns=hi,
                   duration_seconds=(hi-lo)/1e9, resource_scope="root_process_nonadditive",
                   active_at_start=active(spans, lo), active_at_end=active(spans, hi),
                   active_any=[s["span_id"] for s in spans if s["monotonic_ns"] < hi and
                               (s["end_ns"] is None or s["end_ns"] > lo)])
        cpu = delta(a.get("root"), b.get("root"), "cpu_seconds")
        row["cpu_seconds"] = cpu
        row["cpu_cores"] = cpu / row["duration_seconds"] if cpu is not None else None
        for k in IO_KEYS:
            row[k + "_delta"] = delta(a.get("root"), b.get("root"), k)
        rows.append(row)
    return rows

def write_csv(path, rows, fields):
    with path.open("x", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({k: json.dumps(v, sort_keys=True) if isinstance(v, (list, dict)) else
                             "null" if v is None else v for k, v in row.items()})

def chart(title, series, start, end, ylabel):
    width, height = 1000, 200
    points = [(t, v) for t, v in series if v is not None]
    ymax = max((v for _, v in points), default=1) or 1
    def xy(t, v):
        return 260 + 720*(t-start)/max(1, end-start), 165 - 125*v/ymax
    # Break at unavailable samples rather than joining over a gap.
    segments, current = [], []
    for t, value in series:
        if value is None:
            if current: segments.append(current)
            current = []
        else:
            current.append(xy(t, value))
    if current: segments.append(current)
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" role="img">',
             '<rect width="100%" height="100%" fill="white"/>',
             f'<text x="10" y="20">{html.escape(title)}</text>',
             f'<text x="10" y="40">{ymax:.4g} {html.escape(ylabel)}</text>',
             '<path d="M260 45 V165 H980" fill="none" stroke="#777"/>']
    for segment in segments:
        pts = " ".join(f"{x:.3f},{y:.3f}" for x, y in segment)
        parts.append(f'<polyline points="{pts}" fill="none" stroke="#1464b4" stroke-width="2"/>')
        for x, y in segment:
            parts.append(f'<circle cx="{x:.3f}" cy="{y:.3f}" r="2" fill="#1464b4"/>')
    if not points:
        parts.append('<text x="100" y="100">Unavailable / unsupported</text>')
    parts.append(f'<text x="260" y="190">0 — {(end-start)/1e9:.6g} seconds since command start</text></svg>')
    return "".join(parts)

def build(source, output):
    source, output = Path(source), Path(output)
    receipt = json.loads((source / "receipt.json").read_text())
    if receipt.get("schema_version") != 1:
        raise ValueError("unsupported receipt")
    if receipt.get("clock") not in HOST_CLOCKS.values():
        raise ValueError("unsupported receipt host clock")
    samples = load_jsonl(source / "samples.jsonl")
    trace_paths = sorted((source / "trace").glob("stages-*.jsonl"))
    if sum(p.stat().st_size for p in trace_paths) > MAX_BYTES:
        raise ValueError("trace size bound exceeded")
    events = [r for p in trace_paths for r in load_jsonl(p)]
    if len(events) > MAX_ROWS:
        raise ValueError("combined trace row bound exceeded")
    spans = spans_from_events(events)
    if receipt.get("mode") == "traced_diagnostic" and (not trace_paths or not spans):
        raise ValueError("traced diagnostic missing stage records")
    trace_status = ("incomplete" if any(s["status"] == "incomplete" for s in spans) else
                    "complete" if spans else "not_requested")
    intervals = interval_rows(samples, spans)
    start, end = receipt["start_monotonic_ns"], receipt["end_monotonic_ns"]
    if type(start) is not int or type(end) is not int or end < start:
        raise ValueError("invalid receipt clock window")
    for sample in samples:
        if not start <= sample["monotonic_ns"] <= sample["sample_end_ns"]:
            raise ValueError("invalid sample clock bracket")
    for s in spans:
        if s["monotonic_ns"] < start or (s["end_ns"] is not None and s["end_ns"] > end):
            raise ValueError("span outside measured clock window")
        s["wall_seconds"] = (s["end_ns"]-s["monotonic_ns"])/1e9 if s["end_ns"] else None
        # Deliberately null: process counters cannot identify task consumption.
        s.update(cpu_seconds=None, read_bytes=None, write_bytes=None, allocation_bytes=None)
        inside = [r for r in samples if r.get("root") and r["monotonic_ns"] >= s["monotonic_ns"] and
                  s["end_ns"] is not None and r["sample_end_ns"] <= s["end_ns"]]
        s["process_scope_sampled_rss_max_bytes"] = max((r["root"]["rss_bytes"] for r in inside), default=None)
    hashes = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in [source/"receipt.json", source/"samples.jsonl"] + trace_paths}
    summary = dict(schema_version=1, trace_status=trace_status, receipt=receipt, input_sha256=hashes, spans=spans,
                   intervals=intervals, terminal_tree_totals=None,
                   caveat="Overlapping/nested spans are nonadditive wall intervals. Root process CPU/I/O timeline is NOT per-task attribution. RSS is resident memory, not allocation. Tree RSS double-counts shared pages. No physical device bandwidth or exact terminal tree totals.")
    output.mkdir()
    write_json(output / "summary.json", summary)
    write_csv(output/"spans.csv", spans, ["schema_version", "span_id", "pid", "task_id", "stage", "sample", "chunk", "monotonic_ns", "end_ns", "status", "wall_seconds", "resource_scope", "cpu_seconds", "read_bytes", "write_bytes", "allocation_bytes", "process_scope_sampled_rss_max_bytes"])
    fields = ["schema_version", "start_ns", "end_ns", "duration_seconds", "resource_scope", "active_at_start", "active_at_end", "active_any", "cpu_seconds", "cpu_cores"] + [k+"_delta" for k in IO_KEYS]
    write_csv(output/"intervals.csv", intervals, fields)
    views = [chart("Root process CPU (sampled live counter deltas)", [(r["end_ns"], r["cpu_cores"]) for r in intervals], start, end, "cores"),
             chart("Root process RSS (sampled, NOT allocations)", [(r["monotonic_ns"], r["root"]["rss_bytes"] if r.get("root") else None) for r in samples], start, end, "bytes"),
             chart("Live owned process-group RSS (shared pages double-counted)", [(r["monotonic_ns"], r["tree_rss_bytes"]) for r in samples], start, end, "bytes")]
    for key, label in (("rchar", "syscall read characters"), ("wchar", "syscall written characters"),
                       ("read_bytes", "process-attributed storage read"), ("write_bytes", "process-attributed storage dirtying")):
        views.append(chart("Root " + label + " (NOT physical device bandwidth)",
                           [(r["end_ns"], r[key+"_delta"]/r["duration_seconds"] if r[key+"_delta"] is not None else None) for r in intervals], start, end, "bytes/s"))
    # A task/stage timeline aligns with all process resource plots.
    h = max(100, 35 + len(spans)*22)
    timeline = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 {h}"><rect width="100%" height="100%" fill="white"/>']
    for i, s in enumerate(spans):
        x = 260 + 720*(s["monotonic_ns"]-start)/max(1,end-start)
        w = 720*((s["end_ns"] or end)-s["monotonic_ns"])/max(1,end-start)
        label = html.escape(str(s["stage"])+" "+str(s.get("sample") or "")+" "+str(s.get("chunk") or ""))
        timeline.append(f'<text x="5" y="{25+i*22}">{label}</text><rect x="{x:.3f}" y="{12+i*22}" width="{max(w,1):.3f}" height="16" fill="{"#1464b4" if s["status"] == "completed" else "#bb3333"}"><title>{html.escape(s["span_id"]+" "+s["status"])}</title></rect>')
    timeline.append('</svg>')
    views.insert(0, "".join(timeline))
    for i, svg in enumerate(views):
        (output/f"graph-{i}.svg").write_text(svg)
    table = "<table><tr><th>Stage/sample/chunk</th><th>Wall seconds (nonadditive)</th><th>Status</th></tr>" + "".join(
        f'<tr><td>{html.escape(str(s["stage"])+" / "+str(s.get("sample"))+" / "+str(s.get("chunk")))}</td><td>{s["wall_seconds"]}</td><td>{s["status"]}</td></tr>' for s in spans) + "</table>"
    (output/"index.html").write_text('<!doctype html><meta charset="utf-8"><title>Cascade diagnostic</title><style>body{font:14px system-ui;max-width:1200px;margin:auto}svg{width:100%}td,th{padding:6px;text-align:left}</style><h1>Cascade diagnostic (offline)</h1><p>'+html.escape(summary["caveat"])+ '</p><p>Status: '+html.escape(receipt["status"])+ '; trace status: '+html.escape(trace_status)+'; wall: '+str(receipt["wall_seconds"])+ ' s; trace overhead: unmeasured.</p>'+"".join(views)+table)
    return summary

if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("source")
    p.add_argument("output")
    a = p.parse_args()
    build(a.source, a.output)
