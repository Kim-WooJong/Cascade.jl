import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock
import xml.etree.ElementTree as ET
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from proc_metrics import read_process, snapshot
from report import build, delta, interval_rows, spans_from_events
from run import host_clock, run

class ProcFixtures(unittest.TestCase):
    def test_proc_stat_and_io(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/"12"; p.mkdir()
            f = ["0"]*22
            f[0:3] = ["S", "1", "12"]
            f[11:13] = ["100", "50"]
            f[19], f[21] = "20", "3"
            (p/"stat").write_text("12 (odd ) name) " + " ".join(f))
            (p/"io").write_text("rchar: 123\nwchar: 45\nread_bytes: 4096\nwrite_bytes: 0\n")
            r = read_process(12, Path(d), 100, 4096)
            self.assertEqual(r["cpu_seconds"], 1.5)
            self.assertEqual(r["rss_bytes"], 12288)
            self.assertEqual(r["rchar"], 123)
            self.assertIsNone(r["syscr"])
            self.assertEqual(snapshot(12, 12, Path(d), True)["tree_rss_bytes"], 3 * os.sysconf("SC_PAGE_SIZE"))
            (p/"io").unlink()
            self.assertIsNone(read_process(12, Path(d))["read_bytes"])
            self.assertIsNone(read_process(99, Path(d)))
    def test_io_parse_failure_resets_all(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"12";p.mkdir()
            fields=["0"]*22;fields[0:3]=["S","1","12"]
            (p/"stat").write_text("12 (fixture) "+" ".join(fields))
            (p/"io").write_text("rchar: 123\nwrite_bytes: invalid\n")
            from proc_metrics import IO_KEYS
            self.assertTrue(all(read_process(12,Path(d))[k] is None for k in IO_KEYS))
    def test_foreign_group_skips_io_open(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"12";p.mkdir()
            fields=["0"]*22;fields[0:3]=["S","1","99"]
            (p/"stat").write_text("12 (fixture) "+" ".join(fields))
            original=Path.read_text
            def checked(path,*args,**kwargs):
                self.assertNotEqual(path.name,"io")
                return original(path,*args,**kwargs)
            with mock.patch.object(Path,"read_text",checked):
                self.assertIsNone(read_process(12,Path(d),pgrp=12))
    def test_unsupported(self):
        r = snapshot(1, 1, supported=False)
        self.assertFalse(r["supported"])
        self.assertIsNone(r["root"])
        self.assertIsNone(r["tree_rss_bytes"])
    def test_no_reaped_tree_sums(self):
        a = dict(pid=1, start_ticks=1, read_bytes=100)
        b = dict(pid=1, start_ticks=1, read_bytes=150)
        self.assertEqual(delta(a,b,"read_bytes"),50)
        self.assertIsNone(delta(a,dict(b,start_ticks=2),"read_bytes"))
        self.assertIsNone(delta(b,a,"read_bytes"))

class RunnerFixtures(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
    def test_exact_argv_streams_and_report(self):
        argv = [sys.executable,"-c","import sys,time;print(sys.argv[1]);print('ERR',file=sys.stderr);time.sleep(.08)","a b;not shell"]
        out = self.base/"run"
        r = run(argv,out,interval=.01)
        self.assertEqual(r["status"],"completed")
        self.assertEqual(r["argv"],argv)
        self.assertEqual((out/"stdout.log").read_text().strip(),"a b;not shell")
        self.assertEqual((out/"stderr.log").read_text().strip(),"ERR")
        self.assertFalse(r["process_group_present_after_cleanup"])
        with self.assertRaises(FileExistsError): run(argv,out)
        summary = build(out,self.base/"report")
        self.assertIsNone(summary["terminal_tree_totals"])
        for svg in (self.base/"report").glob("*.svg"): ET.parse(svg)
        build(out,self.base/"report2")
        for p in (self.base/"report").iterdir():
            self.assertEqual(p.read_bytes(),(self.base/"report2"/p.name).read_bytes())
    def test_nonzero_and_timeout(self):
        self.assertEqual(run([sys.executable,"-c","raise SystemExit(7)"],self.base/"bad")["status"],"nonzero")
        r = run([sys.executable,"-c","import time;time.sleep(10)"],self.base/"timeout",timeout=.1,interval=.01)
        self.assertEqual(r["status"],"timeout")
        self.assertFalse(r["process_group_present_after_cleanup"])
    def test_failure_receipts_after_clock(self):
        for i,exc in enumerate((RuntimeError("injected"),KeyboardInterrupt())):
            def fail(): raise exc
            out = self.base/str(i)
            with self.assertRaises(type(exc)):
                run([sys.executable,"-c","pass"],out,_postprocess=fail)
            r=json.loads((out/"receipt.json").read_text())
            self.assertIn(r["status"],("failed","interrupted"))
            self.assertEqual(r["returncode"],0)
            self.assertGreater(r["wall_seconds"],0)
    def test_spawn_failure(self):
        with self.assertRaises(FileNotFoundError): run(["/no/such/telemetry-fixture"],self.base/"missing")
        self.assertEqual(json.loads((self.base/"missing"/"receipt.json").read_text())["status"],"failed")
    def check_external_signal(self, sig):
        out = self.base/"interrupt"
        runner = Path(__file__).resolve().parents[1]/"run.py"
        command = [sys.executable,str(runner),"--output",str(out),"--timeout","5","--",
                   sys.executable,"-c","import time;print('ready',flush=True);time.sleep(10)"]
        p = subprocess.Popen(command,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        deadline = time.monotonic()+3
        try:
            while time.monotonic()<deadline:
                log=out/"stdout.log"
                if log.exists() and "ready" in log.read_text(): break
                time.sleep(.01)
            else: self.fail("fixture child did not start")
            p.send_signal(sig)
            p.wait(timeout=3)
            receipt=json.loads((out/"receipt.json").read_text())
            self.assertEqual(receipt["status"],"interrupted")
            self.assertFalse(receipt["process_group_present_after_cleanup"])
        finally:
            if p.poll() is None: p.kill();p.wait()

    def test_external_interrupt_cleans_child(self): self.check_external_signal(signal.SIGINT)
    def test_sigterm_cleans_child(self): self.check_external_signal(signal.SIGTERM)
    def test_sighup_cleans_child(self): self.check_external_signal(signal.SIGHUP)
    def test_shared_host_clock(self):
        name, _ = host_clock()
        out=self.base/"clock"
        r=run([sys.executable,"-c","import time;print(time.clock_gettime_ns(time."+name+"))"],out)
        t=int((out/"stdout.log").read_text())
        self.assertLessEqual(r["start_monotonic_ns"],t)
        self.assertLessEqual(t,r["end_monotonic_ns"])
        self.assertEqual(r["clock"],name)
    def test_clock_fail_before_directory(self):
        with mock.patch("run.sys.platform","unknown"):
            with self.assertRaisesRegex(ValueError,"unsupported host clock"):
                run(["x"],self.base/"clock-failed")
        self.assertFalse((self.base/"clock-failed").exists())
    def test_capacity_preflight(self):
        with self.assertRaisesRegex(ValueError,"sample capacity"):
            run(["x"],self.base/"capacity",timeout=20000,interval=.1)
        self.assertFalse((self.base/"capacity").exists())
    def test_signal_handlers_restored(self):
        before={s:signal.getsignal(s) for s in (signal.SIGTERM,signal.SIGHUP)}
        run([sys.executable,"-c","pass"],self.base/"restore")
        self.assertEqual(before,{s:signal.getsignal(s) for s in before})
    def test_validation(self):
        for kw in (dict(timeout=float("nan")),dict(interval=0),dict(max_samples=1)):
            with self.assertRaises(ValueError): run(["x"],self.base/"invalid",**kw)
        self.assertFalse((self.base/"invalid").exists())
    def test_sampler_bound_is_failure(self):
        with mock.patch("run.snapshot",side_effect=RuntimeError("injected sampler failure")):
            with self.assertRaisesRegex(RuntimeError,"sampler failed"):
                run([sys.executable,"-c","import time;time.sleep(10)"],self.base/"bounded",interval=.01)
        r=json.loads((self.base/"bounded"/"receipt.json").read_text())
        self.assertEqual(r["status"],"failed")
        self.assertFalse(r["process_group_present_after_cleanup"])
    @unittest.skipUnless(sys.platform.startswith("linux"),"live Linux /proc workload")
    def test_live_cpu_memory_file_io(self):
        script = "import time; x=bytearray(8*1024*1024);p='payload';f=open(p,'wb');f.write(x);f.close();end=time.monotonic()+.4\nwhile time.monotonic()<end: sum(range(30000))\nf=open(p,'rb');f.read();f.close();time.sleep(.05)"
        # All fixture I/O lives in a temporary directory; no external input.
        script = "import os;os.chdir("+repr(str(self.base))+ ");" + script
        out=self.base/"live";run([sys.executable,"-c",script],out,interval=.01)
        rows=[json.loads(l) for l in (out/"samples.jsonl").read_text().splitlines()]
        roots=[r["root"] for r in rows if r["root"]]
        self.assertGreater(max(r["rss_bytes"] for r in roots),8*1024*1024)
        self.assertGreater(max(r["cpu_seconds"] for r in roots),0)
        self.assertGreater(max(r["wchar"] for r in roots),0)

class TraceFixtures(unittest.TestCase):
    def event(self,id,t,event="begin",stage="select"):
        return dict(schema_version=1,pid=1,span_id=id,task_id=id,stage=stage,sample="s",chunk="c",monotonic_ns=t,event=event,status="completed")
    def test_overlap_and_incomplete(self):
        ev=[self.event("a",0),self.event("b",5),self.event("a",10,"end"),self.event("b",15,"end"),self.event("c",20)]
        spans=spans_from_events(ev)
        self.assertEqual(spans[2]["status"],"incomplete")
        rows=interval_rows([dict(monotonic_ns=t,root=None) for t in (0,8,16)],spans)
        self.assertEqual(rows[0]["active_at_end"],["a","b"])
        self.assertIsNone(rows[0]["cpu_seconds"])
        with self.assertRaises(ValueError): spans_from_events([ev[0],ev[0]])
        with self.assertRaises(ValueError): spans_from_events([ev[2]])
    def test_trace_completeness_and_clock_validation(self):
        with tempfile.TemporaryDirectory() as d:
            source=Path(d)/"run"
            run([sys.executable,"-c","pass"],source,trace=True)
            with self.assertRaisesRegex(ValueError,"missing stage"):
                build(source,Path(d)/"missing")
            begin=self.event("a",json.loads((source/"receipt.json").read_text())["start_monotonic_ns"]+1)
            (source/"trace"/"stages-fixture.jsonl").write_text(json.dumps(begin)+"\n")
            summary=build(source,Path(d)/"incomplete")
            self.assertEqual(summary["trace_status"],"incomplete")
            self.assertIn("trace status: incomplete",(Path(d)/"incomplete"/"index.html").read_text())
            receipt=json.loads((source/"receipt.json").read_text());receipt["clock"]="CLOCK_GUESSED"
            (source/"receipt.json").write_text(json.dumps(receipt))
            with self.assertRaisesRegex(ValueError,"unsupported receipt host clock"):
                build(source,Path(d)/"badclock")

    def test_offline_overlapping_graphs(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d);source=base/"fixture";source.mkdir();(source/"trace").mkdir()
            (source/"receipt.json").write_text(json.dumps(dict(schema_version=1,clock=host_clock()[0],mode="traced_diagnostic",start_monotonic_ns=0,end_monotonic_ns=30,wall_seconds=3e-8,status="completed")))
            root=dict(pid=1,start_ticks=1,cpu_seconds=0,rss_bytes=4096,rchar=10,wchar=5,read_bytes=0,write_bytes=0)
            samples=[dict(schema_version=1,monotonic_ns=t,sample_end_ns=t+1,root=dict(root,cpu_seconds=t/1e9),tree_rss_bytes=8192) for t in (1,8,16,25)]
            (source/"samples.jsonl").write_text("".join(json.dumps(r)+"\n" for r in samples))
            events=[self.event("a",2,stage="select<script>"),self.event("b",5),self.event("a",20,"end",stage="select<script>"),self.event("b",22,"end")]
            (source/"trace"/"stages-fixture.jsonl").write_text("".join(json.dumps(r)+"\n" for r in events))
            result=build(source,base/"report")
            self.assertIsNone(result["spans"][0]["cpu_seconds"])
            self.assertEqual(result["spans"][0]["process_scope_sampled_rss_max_bytes"],4096)
            self.assertEqual(result["intervals"][1]["active_at_start"],["a","b"])
            self.assertIn("&lt;script&gt;",(base/"report"/"index.html").read_text())
            for svg in (base/"report").glob("*.svg"):ET.parse(svg)
            (source/"trace"/"stages-fixture.jsonl").write_text('{invalid}\n')
            with self.assertRaises(json.JSONDecodeError):build(source,base/"bad")

if __name__ == "__main__": unittest.main()
