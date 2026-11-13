#!/usr/bin/env python3
"""Independent oracle for the ttbar_emu scale factors (external tool, gate only).

For every (file, entry) of EVENTS.tsv (written by sf_dump_events.jl) the event is
read from the NanoAOD file with uproot, the selected tight electron and muon are
re-derived from the raw branches (object cuts of analyses/ttbar_emu), and the
weights of the analysis.toml "sf" profile are computed with the Python correctionlib:

  nominal = genWeight * muon_id * muon_iso * electron_reco * electron_id * pileup * trigger_emu
  <name>Up/Down = the same product with the up/down value of term <name>

in the same multiplication order as Cascade. Floats are written with repr()
(shortest round-trip), so the comparison is exact where the values agree.

Usage: sf_oracle.py EVENTS.tsv OUT.tsv [--jsonpog DIR]
"""
import argparse
import collections

import awkward as ak
import correctionlib
import numpy as np
import uproot

POG = "/cvmfs/cms.cern.ch/rsync/cms-nanoAOD/jsonpog-integration/POG"
BRANCHES = ["genWeight", "Pileup_nTrueInt",
            "Electron_pt", "Electron_eta", "Electron_deltaEtaSC", "Electron_cutBased",
            "Muon_pt", "Muon_eta", "Muon_tightId", "Muon_pfRelIso04_all"]
LABELS = ["nominal"] + [n + d for n in ("muon_id", "muon_iso", "electron_reco", "electron_id",
                                        "pileup", "trigger_emu") for d in ("Up", "Down")]


def f64(x):
    return np.asarray(x, dtype=np.float64)


def leading_leptons(ev):
    """Selected electron (pt, SC eta) and muon (pt, eta) of one event, as float64.

    Comparisons are made in float64 (as Cascade promotes Float32 columns against
    Float64 literals); the SC eta is summed in float32 as in NanoAOD.
    """
    ept = np.asarray(ev["Electron_pt"], dtype=np.float32)
    eeta = np.asarray(ev["Electron_eta"], dtype=np.float32)
    esc = eeta + np.asarray(ev["Electron_deltaEtaSC"], dtype=np.float32)
    ecb = np.asarray(ev["Electron_cutBased"])
    sel_e = (f64(ept) > 35.0) & (np.abs(f64(eeta)) < 2.4) & \
        ~((1.444 < np.abs(f64(esc))) & (np.abs(f64(esc)) < 1.566)) & (ecb >= 4)
    mpt = np.asarray(ev["Muon_pt"], dtype=np.float32)
    meta = np.asarray(ev["Muon_eta"], dtype=np.float32)
    sel_m = (f64(mpt) > 35.0) & (np.abs(f64(meta)) < 2.4) & np.asarray(ev["Muon_tightId"], dtype=bool) & \
        (f64(ev["Muon_pfRelIso04_all"]) < 0.15)
    ie = np.nonzero(sel_e)[0]
    im = np.nonzero(sel_m)[0]
    if len(ie) != 1 or len(im) != 1:
        raise RuntimeError(f"expected one tight electron and muon, got {len(ie)}, {len(im)}")
    return float(ept[ie[0]]), float(esc[ie[0]]), float(mpt[im[0]]), float(meta[im[0]])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("events")
    ap.add_argument("out")
    ap.add_argument("--jsonpog", default=POG)
    a = ap.parse_args()
    mu = correctionlib.CorrectionSet.from_file(f"{a.jsonpog}/MUO/2022_Summer22/muon_Z.json.gz")
    el = correctionlib.CorrectionSet.from_file(f"{a.jsonpog}/EGM/2022_Summer22/electron.json.gz")
    pu = correctionlib.CorrectionSet.from_file(f"{a.jsonpog}/LUM/2022_Summer22/puWeights.json.gz")
    mu_id, mu_iso = mu["NUM_TightID_DEN_TrackerMuons"], mu["NUM_TightPFIso_DEN_TightID"]
    egm = el["Electron-ID-SF"]
    pileup = pu["Collisions2022_355100_357900_eraBCD_GoldenJson"]

    by_file = collections.OrderedDict()
    with open(a.events) as f:
        assert f.readline().rstrip("\n").split("\t") == ["path", "entry"]
        for line in f:
            p, e = line.rstrip("\n").split("\t")
            by_file.setdefault(p, []).append(int(e))

    n = 0
    with open(a.out, "w") as out:
        out.write("\t".join(["path", "entry"] + LABELS) + "\n")
        for path, entries in by_file.items():
            arr = uproot.open(path)["Events"].arrays(BRANCHES, library="ak")
            for entry in entries:
                ev = arr[entry - 1]
                ept, esc, mpt, meta = leading_leptons(ev)
                wp_reco = "Reco20to75" if ept < 75.0 else "RecoAbove75"
                ntrue = float(np.float32(ev["Pileup_nTrueInt"]))
                f = collections.OrderedDict()
                f["muon_id"] = [mu_id.evaluate(meta, mpt, k) for k in ("nominal", "systup", "systdown")]
                f["muon_iso"] = [mu_iso.evaluate(meta, mpt, k) for k in ("nominal", "systup", "systdown")]
                f["electron_reco"] = [egm.evaluate("2022Re-recoBCD", k, wp_reco, esc, ept) for k in ("sf", "sfup", "sfdown")]
                f["electron_id"] = [egm.evaluate("2022Re-recoBCD", k, "Tight", esc, ept) for k in ("sf", "sfup", "sfdown")]
                f["pileup"] = [pileup.evaluate(ntrue, k) for k in ("nominal", "up", "down")]
                f["trigger_emu"] = [1.0, 1.0, 1.0]
                base = float(np.float32(ev["genWeight"]))

                def product(name, idx):
                    w = base
                    for term, vals in f.items():
                        w = w * (vals[idx] if term == name else vals[0])
                    return w

                row = [product(None, 0)]
                for name in f:
                    row += [product(name, 1), product(name, 2)]
                out.write("\t".join([path, str(entry)] + [repr(float(x)) for x in row]) + "\n")
                n += 1
    print(f"oracle: {n} events from {len(by_file)} files -> {a.out}")


if __name__ == "__main__":
    main()
