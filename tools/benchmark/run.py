#!/usr/bin/env python3
"""One-shot diagnostic runner, not the mature scientific benchmark guard."""
import argparse
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import threading
import time
from proc_metrics import snapshot

SCHEMA = 1
HOST_CLOCKS = {"linux": "CLOCK_MONOTONIC", "darwin": "CLOCK_UPTIME_RAW"}

def host_clock():
    name = HOST_CLOCKS.get(sys.platform)
    clock = getattr(time, name, None) if name else None
    if clock is None or not hasattr(time, "clock_gettime_ns"):
        raise ValueError("unsupported host clock")
    # Fail before creating output if a named host clock is not implemented.
    time.clock_gettime_ns(clock)
    return name, lambda: time.clock_gettime_ns(clock)

class Terminated(BaseException):
    pass

def terminated(signum, frame):
    raise Terminated("received signal " + str(signum))

def write_json(path, value):
    with Path(path).open("x") as f:
        json.dump(value, f, sort_keys=True, indent=2, allow_nan=False)
        f.write("\n")

def group_exists(pgid):
    try:
        os.killpg(pgid, 0)
        return True
    except ProcessLookupError:
        return False

def kill_group(pgid):
    try:
        os.killpg(pgid, signal.SIGKILL)
    except ProcessLookupError:
        pass

def run(argv, output, timeout=60, interval=0.1, trace=False, max_samples=100000,
        _postprocess=None):
    if not argv or not all(isinstance(a, str) and a for a in argv):
        raise ValueError("nonempty exact argv required")
    if not math.isfinite(timeout) or not 0 < timeout <= 86400:
        raise ValueError("timeout must be 0..86400 seconds")
    if not math.isfinite(interval) or not 0.01 <= interval <= 60:
        raise ValueError("interval must be 0.01..60 seconds")
    if not 2 <= max_samples <= 1000000:
        raise ValueError("sample bound must be 2..1000000")
    if timeout / interval + 2 > max_samples:
        raise ValueError("sample capacity must cover timeout / interval + 2")
    clock_name, now_ns = host_clock()
    output = Path(output).absolute()
    output.mkdir()  # create-new only, including failure receipts
    env = os.environ.copy()
    env.pop("CASCADE_BENCHMARK_TRACE_DIR", None)
    env.pop("CASCADE_BENCHMARK_TRACE_MAX_RECORDS", None)
    if trace:
        (output / "trace").mkdir()
        env["CASCADE_BENCHMARK_TRACE_DIR"] = str(output / "trace")
    receipt = dict(schema_version=SCHEMA, argv=argv, cwd=os.getcwd(),
                   mode="traced_diagnostic" if trace else "ordinary_timed_diagnostic",
                   status="failed", clock=clock_name, timeout_seconds=timeout, interval_seconds=interval,
                   max_samples=max_samples,
                   terminal_tree_cpu_seconds=None, terminal_tree_read_bytes=None,
                   terminal_tree_write_bytes=None, trace_overhead="not measured",
                   units=dict(time="seconds", monotonic="nanoseconds", memory="bytes", io="bytes"))
    process = timer = sampler = None
    stop = threading.Event()
    timed_out = threading.Event()
    sampler_errors = []
    start = end = None
    previous_handlers = {}
    try:
        for sig in (signal.SIGTERM, signal.SIGHUP):
            previous_handlers[sig] = signal.signal(sig, terminated)
        with (output / "stdout.log").open("xb") as stdout, (output / "stderr.log").open("xb") as stderr:
            start = now_ns()
            process = subprocess.Popen(argv, stdout=stdout, stderr=stderr, env=env,
                                       start_new_session=True)
            receipt["pid"] = process.pid
            def expire():
                timed_out.set()
                kill_group(process.pid)
            timer = threading.Timer(timeout, expire)
            timer.start()
            def sample():
                try:
                    with (output / "samples.jsonl").open("x") as f:
                        for _ in range(max_samples):
                            if stop.is_set():
                                return
                            begin = now_ns()
                            row = snapshot(process.pid, process.pid)
                            row.update(schema_version=SCHEMA, event="sample", monotonic_ns=begin,
                                       sample_end_ns=now_ns())
                            f.write(json.dumps(row, sort_keys=True) + "\n")
                            f.flush()
                            if stop.wait(interval):
                                return
                        raise RuntimeError("sample bound exhausted")
                except BaseException as e:
                    sampler_errors.append(repr(e))
                    kill_group(process.pid)
            sampler = threading.Thread(target=sample, daemon=True)
            sampler.start()
            # Blocking wait4: no polling latency. Do not add child CPU to root CPU.
            _, status, usage = os.wait4(process.pid, 0)
            end = now_ns()  # before parsing, cleanup, joins or graphs
            process.returncode = os.waitstatus_to_exitcode(status)
            timer.cancel()
            timer.join()
            stop.set()
            sampler.join()
            receipt.update(returncode=process.returncode, timed_out=timed_out.is_set(),
                           wait4_cpu_seconds=usage.ru_utime + usage.ru_stime,
                           wait4_cpu_scope="wait4 subject usage, including waited descendants; never add to live counters",
                           wait4_maxrss_bytes=usage.ru_maxrss * (1 if sys.platform == "darwin" else 1024),
                           wait4_maxrss_scope="OS wait4 maxrss, NOT simultaneous process-tree peak",
                           process_group_present_after_exit=group_exists(process.pid))
            if receipt["process_group_present_after_exit"]:
                kill_group(process.pid)
            receipt["process_group_present_after_cleanup"] = group_exists(process.pid)
            if sampler_errors:
                raise RuntimeError("sampler failed: " + "; ".join(sampler_errors))
            receipt["status"] = ("timeout" if timed_out.is_set() else
                                 "nonzero" if process.returncode else
                                 "incomplete_process_group" if receipt["process_group_present_after_exit"] else "completed")
        if _postprocess:
            _postprocess()
    except BaseException as e:
        receipt["status"] = "interrupted" if isinstance(e, (KeyboardInterrupt, Terminated)) else "failed"
        receipt["error"] = type(e).__name__ + ": " + str(e)
        raise
    finally:
        # Ignore repeated termination while cleanup owns the group; restore below.
        for sig in previous_handlers:
            signal.signal(sig, signal.SIG_IGN)
        try:
            if end is None and start is not None:
                end = now_ns()
            stop.set()
            if timer:
                timer.cancel()
                timer.join()
            if process:
                kill_group(process.pid)
                if process.returncode is None:
                    process.wait()
                receipt["process_group_present_after_cleanup"] = group_exists(process.pid)
            if sampler:
                sampler.join()
            receipt.update(start_monotonic_ns=start, end_monotonic_ns=end,
                           wall_seconds=(end - start) / 1e9 if end is not None else None)
            write_json(output / "receipt.json", receipt)
        finally:
            for sig, handler in previous_handlers.items():
                signal.signal(sig, handler)
    return receipt

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--output", required=True)
    p.add_argument("--timeout", type=float, default=60)
    p.add_argument("--interval", type=float, default=0.1)
    p.add_argument("--max-samples", type=int, default=100000)
    p.add_argument("--trace", action="store_true")
    p.add_argument("argv", nargs=argparse.REMAINDER)
    args = p.parse_args()
    argv = args.argv[1:] if args.argv[:1] == ["--"] else args.argv
    result = run(argv, args.output, args.timeout, args.interval, args.trace, args.max_samples)
    return 0 if result["status"] == "completed" else 1

if __name__ == "__main__":
    sys.exit(main())
