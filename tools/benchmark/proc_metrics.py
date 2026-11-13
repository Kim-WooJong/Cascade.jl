"""Linux /proc parser. No terminal/tree cumulative counter claims."""
import os
from pathlib import Path

IO_KEYS = ("rchar", "wchar", "syscr", "syscw", "read_bytes", "write_bytes", "cancelled_write_bytes")

def read_process(pid, proc=Path("/proc"), ticks=None, page_size=None, pgrp=None):
    ticks = ticks or os.sysconf("SC_CLK_TCK")
    page_size = page_size or os.sysconf("SC_PAGE_SIZE")
    base = Path(proc) / str(pid)
    try:
        raw = (base / "stat").read_text()
        # comm can contain spaces and parentheses. Remaining fields start at 3.
        fields = raw[raw.rindex(")") + 2:].split()
        result = dict(pid=int(pid), ppid=int(fields[1]), pgrp=int(fields[2]),
                      start_ticks=int(fields[19]), state=fields[0],
                      cpu_seconds=(int(fields[11]) + int(fields[12])) / ticks,
                      rss_bytes=int(fields[21]) * page_size)
    except (OSError, ValueError, IndexError):
        return None
    if pgrp is not None and result["pgrp"] != pgrp:
        return None
    result.update({k: None for k in IO_KEYS})
    try:
        for line in (base / "io").read_text().splitlines():
            k, value = line.split(":", 1)
            if k in IO_KEYS:
                result[k] = int(value)
    except (OSError, ValueError):
        result.update({k: None for k in IO_KEYS})
    return result


def snapshot(root_pid, pgrp, proc=Path("/proc"), supported=None):
    supported = os.uname().sysname == "Linux" if supported is None else supported
    if not supported:
        return dict(supported=False, root=None, tree_rss_bytes=None, members=[],
                    limitation="Linux /proc unavailable; no substitute counters")
    root = read_process(root_pid, proc, pgrp=pgrp)
    members = []
    try:
        candidates = list(Path(proc).iterdir())
    except OSError:
        candidates = []
    # Owned process group, not a host-wide scan attribution. Escaped children excluded.
    for path in candidates:
        if path.name.isdecimal():
            p = read_process(int(path.name), proc, pgrp=pgrp)
            if p and p["pgrp"] == pgrp and p["state"] != "Z":
                members.append(p)
    members.sort(key=lambda p: p["pid"])
    return dict(supported=True, root=root,
                tree_rss_bytes=sum(p["rss_bytes"] for p in members) if members else None,
                members=members,
                limitation="sampled live process-group RSS; shared pages double-counted; escaped/short-lived children excluded")
