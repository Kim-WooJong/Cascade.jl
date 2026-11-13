# Workload volume and stage-time breakdown

Reporting supplement requested by the owner on 2026-11-07 at 18:02 KST. This is a read/stat-only reconstruction of the completed ABBA experiment, not a new analysis execution or product change. The frozen original report and evidence remain unchanged.

## 1. How much data was analyzed?

The ordinary end-to-end comparison used **0.093247112 GB of unique input (93.247112 MB; 0.086843140 GiB)**: two ROOT files, two samples and 136,910 original events. This is a small-input startup/complete-workflow test, **not a multi-GB sustained-throughput or storage-saturation measurement**.

GB/MB are decimal (10^9/10^6 bytes); GiB is 2^30 bytes. File footprint is not measured physical storage traffic.

| Unique input | Files | Original events | Exact file bytes | GB | Retained rows |
|---|---:|---:|---:|---:|---:|
| TTto2L2Nu MC | 1 | 32,853 | 36,001,081 | 0.036001081 | 1,493 |
| MuonEG data | 1 | 104,057 | 57,246,031 | 0.057246031 | 45 |
| **Total per invocation** | **2** | **136,910** | **93,247,112** | **0.093247112** | **1,538** |

All four ordinary processes used these same two files. Their repeated file-footprint sum is 372,988,448 bytes (0.372988448 GB), not a larger unique dataset and not measured disk reads. The separate approximately 573 MB warm decoding pilot is excluded from this workload.

### Selection-only logical payload, per ordinary invocation

| Sample | Requested compressed payload bytes | Declared decoded bytes |
|---|---:|---:|
| TTto2L2Nu | 2,567,900 | 6,516,744 |
| MuonEG | 2,178,908 | 6,438,661 |
| **Total** | **4,746,808** | **12,955,405** |

All four select sidecars report the same totals: 456 basket requests, **0.004746808 GB requested compressed payload** and **0.012955405 GB declared decoded payload**. These cover detached selection jobs only. They exclude the six serial counter reads (three per sample), metadata/key/index reads, skim/denominator reads, correction-source reads and other pipeline activity. They are not a unique physical-range union or whole-pipeline read count. Whole-process physical disk bytes/rate and I/O wait remain **unmeasured**; do not substitute file size, logical payload, RSS or ru_inblock.

## 2. What work was performed?

- Host: validation-host.example, Linux x86_64; pinned Julia 1.12.2, 16 process threads and BLAS1. Both arms use decode_threads=16 and column_readers=1; up to 15 decoder workers were actually active.
- Fresh ordinary public CLI, all seven stages forced with fresh workdirs. No analysis-checkpoint reuse. Both arms consumed their own valid prebuilt Julia package images and the same already-built native renderer identity. Data/page-cache state was not controlled or scanned.
- Selection: lumimask/trigger handling, electron-muon objects, lepton veto/opposite-sign/mll/jet cuts; publish one emu_ge1j region. The cutflow also records >=2 jets, but does not create another plotted region.
- Nominal MC corrections: muon ID/isolation, electron reconstruction/ID, pileup; original signed generator-weight normalization. Configured luminosity 1210 pb^-1 and MC generator-weight denominator 2646014.7375000003.
- Per sample: nine-column retained selection table and matching Float64 nominal correction weights; seven-bin njet histogram, raw/normalized merged stores and nominal templates.
- Output: one native PNG plus transport/index/sidecars per run. No fit, JES/JER shape scan, PDF/scale/PS member scan or full-dataset run.

MC event cutflow: 32,853 all -> 20,881 trigger -> 1,631 two leptons -> 1,620 veto -> 1,616 opposite-sign -> 1,604 mll -> 1,493 >=1 jet -> 1,026 >=2 jets.

Data event cutflow: 104,057 all -> 28,279 lumimask -> 6,473 trigger -> 54 two leptons -> 53 veto -> 49 opposite-sign -> 49 mll -> 45 >=1 jet -> 33 >=2 jets.

The exact cuts/triggers/payload definitions are in the frozen evidence workload.toml; these are technical benchmark selections, not a new physics validation.

## 3. Where did the time go?

Means of two observations per arm, with ABBA order baseline/candidate/candidate/baseline. Seconds below are wall-clock regions, not isolated additive CPU or I/O costs. Delta = candidate minus baseline; a negative delta is less observed time. Candidate shares use the external mean of 89.369832536 s.

| Phase | Work included | Baseline s | Candidate s | Delta s | Candidate share |
|---|---|---:|---:|---:|---:|
| Skim | Index inputs; signatures, event counts and MC denominator (not reduced ROOT export) | 2.935 | 3.055 | +0.120 | 3.42% |
| Select | Decode branches; build objects, apply cuts and write retained tables | 16.325 | 13.770 | -2.555 | 15.41% |
| Correct | Evaluate nominal muon/electron/pileup SF weights | 9.500 | 9.250 | -0.250 | 10.35% |
| Histogram | Fill per-sample weighted njet bins | 1.730 | 1.605 | -0.125 | 1.80% |
| Merge | Merge stores; normalize MC and publish yields/cutflows | 5.025 | 4.900 | -0.125 | 5.48% |
| Systematics | Write nominal templates; no shape/theory variation scan | 1.085 | 1.100 | +0.015 | 1.23% |
| Plot | Prepare transport, native ROOT rendering and PNG/index publication | 26.145 | 25.675 | -0.470 | 28.73% |
| Unattributed | Outside printed stage clocks; wrapper/loading/config/finalization not separately attributed | 29.879 | 30.015 | +0.135 | 33.58% |
| **External total** | **Launch through native PNG publication and normal process exit** | **92.624** | **89.370** | **-3.255** | **100%** |

Printed stage clocks are rounded to 0.01 s. The residual is external wall minus their sum; it is not measured JIT time. The plot stage includes preparation, transport and rendering, not a separately timed renderer-only call.

Raw total observations: baseline 93.124700896 / 92.124032608 s; candidate 90.309808135 / 88.429856938 s. Observed mean reduction is 3.513691%, with only two observations per arm on a shared host. This is not stable superiority or a scaling/I/O-ceiling result.

## 4. What should be investigated next?

1. **Outside-stage work: 30.015 s / 33.58%.** First split wrapper/startup/package loading/configuration/inter-stage/finalization boundaries; the current data cannot assign these seconds to JIT.
2. **Plot phase: 25.675 s / 28.73%.** It is the largest named stage; separate Julia preparation/transport from native child startup/rendering/publication before choosing a fix.
3. Selection (13.770 s / 15.41%) and corrections (9.250 s / 10.35%) follow. Current stage clocks cannot identify their exclusive decoder, compiler, allocation or physical-I/O contributions.

These are timing-based investigation priorities, not confirmed bottleneck mechanisms or promised savings. The first two envelopes cover about 62.31% of observed total wall. Small input size makes startup/plot overhead prominent; a large-data throughput test would answer a different question and has not been run here.

## 5. Costs and correctness outside ordinary timing

| Separate one-time/verification operation | Baseline | Candidate |
|---|---:|---:|
| compilecache call wall | 7.619608 s | 16.950219 s |
| Whole supervised cache-build operation | 9.989194 s | 19.599874 s |
| Package image bytes | 6,311,460 | 12,587,547 |

After all four ordinary clocks ended, a 39.069952 s verifier passed 489 science assertions against the frozen reference. Entry/order/type/raw bits, SF weights, cutflows, denominator/normalization, histograms/sumw2/flow, stores/templates/transport/publication were checked. Four PNGs fully decoded, nonblank and byte-identical. Prior focused354/native774 tests are separate overlapping scopes, not additions to a single test total.

## Evidence

R = /path/to/user/analisis/Cascade_dev/precompile-selection/matched-cached-cli

- Input bytes/events: R/A1-baseline/skim/{TTto2L2Nu,MuonEG}.json plus read-only file stat.
- Logical bytes/retained counts: R/{A1-baseline,B1-candidate,B2-candidate,A2-baseline}/select/*/*.cols.meta.json; R/evidence/queue-diagnostics.json.
- Workload: R/workload.toml; cutflows/normalization: R/A1-baseline/merge/samples.json.
- Times/resources: R/evidence/matched-summary.json and each case's .log/.receipt.json.
- Correctness: R/final-verifier.log, R/verify_science.jl and R/evidence/png-full-decode.jsonl.
- Frozen detailed original: docs/MATCHED_CACHED_CLI_PNG_VALIDATION.md (unchanged).

Future performance reports must lead with data volume and exact operation scope, then the stage breakdown and unattributed share, rather than total time alone.
