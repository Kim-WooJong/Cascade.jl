# >=100GiB real-input matched production validation

Completed 2026-11-07 on validation-host.example. This NEW report does not replace the frozen D0 first-touch report or old small-input validation. No product/source/test/original-config changes, additional tuning, installs, dependency builds, staging, commit or push were performed for the warm controls. One fixed ABBA only; no run replacement. All four ordinary runs exited 0, postflight valid, no resource circuit. All subsequent scientific verification passed.

## Result and measured scope

Each arm processed the same **396 unique original nonempty ROOT files, 107,392,191,402 bytes = 107.392191402 decimal GB = 100.016772190 GiB**, with **233,876,675 input events and 522,713 retained rows**. This is input-file footprint, not a claim that every byte/branch was requested or read from storage. No repeated input passes, padding or synthetic volume is counted toward dataset size.

Baseline mean/median **160.148051 s**, candidate **157.278584 s**, candidate-minus-baseline **−2.869467 s (−1.791759%)**, baseline/candidate mean ratio **1.01824448**. Only two observations per arm: descriptive, not a stable universal speedup, an I/O ceiling, or an RDF comparison. Shared primitive precompilation also benefits the production serial reader/counters; this is not an opt-in-only benefit claim.

## Frozen workload, ownership and protocol

Nominal SF, eμ, ge1j, njet, one native PNG; seven ordinary stages skim/select/correct/histogram/merge/systematics/plot, no fit, shape/theory scan or all-observable expansion. Production defaults decode_threads=1 and column_readers=1 on 16 Julia threads, BLAS1, with 16 outer file workers. This is not the earlier decode16 serialized-file setup. Requested/effective production diagnostics were checked, not detached decoder-queue fiction. All stage counts were skim13; select/correct/histogram396 each; merge/systematics/plot1 each, skipped0.

Selection membership remained exactly frozen. Partial MC and EGamma subsets, whole selected files, selected signed Runs normalization, original cross-sections/BR, stream priority and lumimask preserved. Configured luminosity1210 pb^-1 is retained; technical subset exposure is UNKNOWN, not full/proportionally representative physics coverage.

External monotonic clock starts immediately before Popen and ends after blocking wait4 root normal exit, including all checkpoints, native rendering, transport/index publication and tiny unchanged WNOWAIT zombie-observation overhead. Fresh --force workdirs; no artifact reuse, warmup, input full-SHA prescan, cache flush/drop/fadvise, host tuning or unrelated branch read. Stat+ctime and mincore/fincore metadata before/after each arm are outside the ordinary clock. Main-boundary clock/counters are separate and include their own observer overhead.

One owned analysis process group at a time. Fixed per-arm600s, sampled group RssAnon64GiB, filesystem free floor64GiB, output32GiB, 60s durable progress/resource receipts. No load-average-only kill. No cap fired. Warm ordinary sum634.853270s; full bounded crossverification47.418771s; warm monitored682.272041/3000s. Prior D0+its verification204.529213s separate; overall large886.801254/14400s. These are monitored operation sums, not a claim about elapsed chat time.

### Exact invocation and environment

All exact argv/environment/preflight are in W/<arm>.command.json and .command; W is defined in Evidence below. The invocation template was:

    bash P/pinned-private-wrapper.sh --compiled-modules=existing --project=P/<baseline|candidate>/project W/ordinary_warm_cli.jl run O/resolved-workload-D0.toml --steps skim,select,correct,histogram,merge,systematics,plot --force --workdir W/<arm>

The thin external entry calls public Cascade.Pipeline.main(ARGS), adding only cache/build-ID guards and live main-boundary measurement; it does not omit integrity, I/O or rendering. Pinned Julia1.12.2 direct-binary wrapper, original LCG environment and private absolute project/depot paths reused. Env JULIA_THREADS=16, OPENBLAS_NUM_THREADS=1, JULIA_PKG_PRECOMPILE_AUTO=0, JULIA_PKG_OFFLINE=true, JULIA_LOAD_PATH=@:@stdlib, arm-specific JULIA_DEPOT_PATH/JULIA_PROJECT, LARGE_EXPECTED_CACHE/BUILD_ID, LARGE_CLK_TCK=100. Exact wrapper SHA256 0f36bcbd4a762e33185dce6d05cbff08641a74d4ca3e5c28ae7c9ac8532acc34. No relocation or package/renderer builds.

Metadata caveat: inherited command setup field source_runtime_sha256 describes the original D0 candidate seed, not baseline runtime. Actual per-arm source is established by own explicit project/cache/build-ID guards and independently verified baseline/candidate manifest hashes; no historical command records were rewritten.

## Raw wall and stage clocks (seconds)

| Arm in launch order | External | Public main | Skim | Select | Correct | Histogram | Merge | Systematics | Plot | UNATTRIBUTED |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A1-baseline428 | 159.075910607 | 155.898932930 | 8.10 | 72.16 | 14.92 | 2.50 | 5.33 | 1.11 | 25.26 | 29.695910607 |
| B1-final429 | 156.285203744 | 153.100581252 | 8.77 | 70.18 | 15.16 | 2.32 | 5.13 | 0.99 | 23.00 | 30.735203744 |
| B2-final429 | 158.271964639 | 154.957305928 | 8.69 | 70.69 | 15.83 | 2.30 | 5.32 | 1.06 | 24.98 | 29.401964639 |
| A2-baseline428 | 161.220190975 | 157.992115040 | 8.59 | 71.31 | 15.05 | 2.43 | 5.73 | 1.28 | 27.62 | 29.210190975 |

Stage clocks are ordinary rounded time() wall logs. External residual = external wall − sum(seven stage clocks), with about ±0.035s stage-rounding uncertainty. **UNATTRIBUTED is not labeled JIT, I/O, CPU or GC.** These are sequential stage localization windows, not additive isolated I/O/CPU attribution.

| Phase | Purpose | Baseline mean s | Final mean s | Final−base s | Share base / final |
| --- | --- | --- | --- | --- | --- |
| skim | Input coverage / selected signed Runs bookkeeping | 8.345 | 8.730 | +0.385 | 5.211% / 5.551% |
| select | Read required columns, event/object selection, retained rows | 71.735 | 70.435 | -1.300 | 44.793% / 44.784% |
| correct | Nominal SF / correction weights | 14.985 | 15.495 | +0.510 | 9.357% / 9.852% |
| histogram | Per-file njet histogram filling | 2.465 | 2.310 | -0.155 | 1.539% / 1.469% |
| merge | Merge / scale stored histograms | 5.530 | 5.225 | -0.305 | 3.453% / 3.322% |
| systematics | Nominal template / transport preparation | 1.195 | 1.025 | -0.170 | 0.746% / 0.652% |
| plot | Full Julia plot preparation, transport, native rendering and publication | 26.440 | 23.990 | -2.450 | 16.510% / 15.253% |
| UNATTRIBUTED | Unlocalized residual | 29.453051 | 30.068584 | +0.615533 | 18.391% / 19.118% |
| TOTAL | External ordinary wall | 160.148051 | 157.278584 | -2.869467 | 100% / 100% |

Top timing-based follow-up candidates, not confirmed mechanisms: (1) select, ~44.8% of wall; (2) unlocalized residual, ~18.4–19.1%, requiring attribution before optimization. Plot is next at15.3–16.5%; its −2.450s mean change is descriptive and must not be assigned to the decode primitive or renderer alone.

| Arm | Mean=median s | Min–max s | Spread s | Sample SD s | Mean main s | Mean CPU s | Footprint GB/s | Events/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 160.148051 | 159.075911–161.220191 | 2.144280 | 1.516235 | 156.945524 | 1001.614051 | 0.670580696 | 1460377.906 |
| candidate | 157.278584 | 156.285204–158.271965 | 1.986761 | 1.404852 | 154.028944 | 990.464693 | 0.682815095 | 1487021.747 |

Footprint/event throughput uses dataset footprint/events divided by mean external wall: **work rates, not disk bandwidth**. Pair A1/B1 ratio1.017856501, difference−2.790706863s (1.754324%); A2/B2 ratio1.018627597, difference−2.948226336s (1.828695%). ABBA reduces simple ordering bias but does not remove shared-host/cache confounders.

## Per-sample verified coverage, normalization and counts

| Sample | Selected / available files | Exact bytes | GB | GiB | Events | Retained rows | Selected signed Runs sum | Normalization |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TTto2L2Nu | 21/386 | 6410153852 | 6.410153852 | 5.969920989 | 5875095 | 271917 | 472607267.3137 | .00025099919574715624 |
| TWminusto2L2Nu | 21/77 | 1595399372 | 1.595399372 | 1.485831451 | 2369680 | 112397 | 9001616.396080002 | .0006268146410301501 |
| TbarWplusto2L2Nu | 21/97 | 1151622185 | 1.151622185 | 1.072531738 | 1708640 | 80929 | 6502747.215300001 | .0008676863428928005 |
| WWto2L2Nu | 21/117 | 1664587451 | 1.664587451 | 1.550267871 | 3274668 | 43366 | 38605748.32799999 | .0004183400270546364 |
| WZto3LNu | 21/109 | 1176911812 | 1.176911812 | 1.096084539 | 2336101 | 7227 | 11502599.890659997 | .0005175525582554551 |
| WZto2L2Q | 21/68 | 1983405360 | 1.983405360 | 1.847190186 | 3660139 | 308 | 27699903.82604 | .00015288861746945057 |
| DYto2L_MLL50 | 21/899 | 3835921606 | 3.835921606 | 3.572480386 | 7935354 | 169 | 141360971343.19998 | .000054319519221168494 |
| DYto2L_MLL10to50 | 21/213 | 3227415101 | 3.227415101 | 3.005764541 | 10257201 | 3 | 359728029368.718 | .00006721249951645425 |
| TTtoLNu2Q | 21/841 | 5407562772 | 5.407562772 | 5.036185283 | 6961060 | 757 | 2327262348.4200006 | .0002110440932168432 |
| MuonEG | 28/28 | 8695721563 | 8.695721563 | 8.098521794 | 15768439 | 5446 | 0 unused | 1 |
| SingleMuon | 35/35 | 8408043001 | 8.408043001 | 7.830600255 | 20162441 | 35 | 0 unused | 1 |
| Muon | 124/124 | 57717746301 | 57.717746301 | 53.753840086 | 138427345 | 140 | 0 unused | 1 |
| EGamma | 20/313 | 6117701026 | 6.117701026 | 5.697553070 | 15140512 | 19 | 0 unused | 1 |

Available metadata inventory has3307 files; only frozen396 membership was analyzed per arm, not all3307. Data normalization1; signed Runs denominator unused for data. These decimal signed sums display recorded binary floating values; crossverification compared scientific values and order exactly, not rounded report text.

## Resources, host context and same-scope kernel I/O

| Arm | CPU user / sys s | wait4 maxRSS KiB | Peak sampled group RssAnon B | Output B | Monitor CPU s | Host load1/5/15 before → after |
| --- | --- | --- | --- | --- | --- | --- |
| A1-baseline428 | 956.301409 / 37.894589 | 9987676 | 7636123648 | 40293004 | 0.799726 | [0.55, 0.92, 1.23] → [6.17, 3.82, 2.31] |
| B1-final429 | 955.102363 / 33.600142 | 8698152 | 7042191360 | 40292993 | 0.823134 | [5.76, 3.77, 2.3] → [7.94, 5.88, 3.33] |
| B2-final429 | 957.373545 / 34.853336 | 9237824 | 7178993664 | 40293023 | 0.771226 | [7.38, 5.8, 3.31] → [6.06, 6.35, 3.92] |
| A2-baseline428 | 972.932026 / 36.100077 | 9871756 | 7335964672 | 40293013 | 0.812370 | [5.97, 6.33, 3.93] → [5.06, 6.32, 4.32] |

wait4 maxRSS is a resource-usage maximum, not summed simultaneous tree RSS; sampled group RssAnon is the guard. Monitor ~0.49–0.53% of one core wall. CPU scopes are not added to each other. GC time is UNKNOWN/not recorded. Host load includes ours and possible other work; no claim it measures external contention alone. Detailed host memory/free disk and filesystem guards are preserved in per-arm samples/progress/commands.

All eight pre/post input residency snapshots were exactly36,827,557,888 resident bytes (34.2925844116% of107,392,191,402B), four fully resident files. Thus relevant-path warm observation, **not all100GiB resident**, not a cold paired comparison. mincore samples are metadata, not reads/warmup; residency does not prove which physical bytes the job fetched.

| Arm | Main wall s | rchar Δ B | wchar Δ B | read_bytes Δ B | write_bytes Δ B | cancelled Δ B | syscr / syscw Δ |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A1-baseline428 | 155.898932930 | 85068396 | 44044839 | 0 | 48558080 | 45056 | 8170 / 14896 |
| B1-final429 | 153.100581252 | 85072076 | 44046346 | 0 | 48558080 | 45056 | 8245 / 14836 |
| B2-final429 | 154.957305928 | 85071982 | 44053441 | 4096 | 48558080 | 40960 | 8297 / 14844 |
| A2-baseline428 | 157.992115040 | 85068732 | 44057855 | 0 | 48558080 | 45056 | 8297 / 14925 |

| Arm | rchar B/s | wchar B/s | read_bytes B/s | write_bytes B/s | cancelled B/s |
| --- | --- | --- | --- | --- | --- |
| A1-baseline428 | 545663.747668 | 282521.747726 | 0.000000 | 311471.535356 | 289.007751 |
| B1-final429 | 555661.352193 | 287695.485150 | 0.000000 | 317164.569872 | 294.290196 |
| B2-final429 | 549002.717171 | 284294.055941 | 26.433087 | 313364.250296 | 264.330873 |
| A2-baseline428 | 538436.566777 | 278861.100055 | 0.000000 | 307344.958245 | 285.178789 |

Every above rate divides by its own public-main monotonic boundary duration, not external wall. Scope: live root-PID /proc/self/io before and after public main; may include waited-child roll-up, not exact final process-tree I/O. rchar/wchar count syscall character traffic and omit mmap consumption; read_bytes is kernel-accounted storage fetches, write_bytes dirtying/accounted write traffic, not physical device writeback. Counters may include checkpoint/meta/transport and observer overhead. Tiny read_bytes does not mean tiny logical ROOT work. Physical device/job bytes, exact terminal root/tree bytes and I/O wait are UNKNOWN/NULL; ru_inblock was not converted to bytes. Host diskstats are context only.

| Arm | Main self user / sys s | Main waited-child user / sys s | Self minor / major faults | Waited-child minor / major faults |
| --- | --- | --- | --- | --- |
| A1-baseline428 | 951.84 / 37.08 | 1.07 / 0.25 | 10447522 / 0 | 26097 / 0 |
| B1-final429 | 950.65 / 32.78 | 1.10 / 0.24 | 8681454 / 1 | 26093 / 0 |
| B2-final429 | 952.57 / 33.79 | 1.05 / 0.22 | 8853046 / 0 | 26110 / 0 |
| A2-baseline428 | 968.61 / 35.24 | 0.95 / 0.23 | 9221825 / 0 | 26115 / 0 |

CPU/fault boundaries match the main window; OS tick frequency100Hz. These are separate diagnostics from external wait4 CPU, never added to it.

External fixture validated subreaper/session and pid+starttime tracking for child/grandchild/orphan. Zombie /proc/io was unavailable even with WNOWAIT before wait4; exact final tree aggregation could not be proven. The authorized fallback is used honestly: live root boundary counters, no dead-last-sample plus parent double sum and no rusage+proc addition. Missing final counters remain NULL. Stage I/O brackets are in evidence/<arm>.stage-io-windows.json:1Hz sampled windows overlap and have ±sampling interval/stdout delivery/reap-race uncertainty; not summed or used for isolated CPU/I/O attribution. Logical compressed_requested/declared_decoded basket payload sums are unavailable in production decode1 (not zeros); they must not be substituted for input footprint or physical disk traffic.

## Correctness, actual caches, PNGs and protections

Output-only crossverifier: **47,397/47,397 assertions**, exit0 (testset19.6s, supervised Julia35.365513s). All four warm outputs plus frozen D0: exact retained typedbits/order/entries, cutflows, SFweights, scientific headers, selected signed Runs per-file order, denominator/normalization,396 nonempty-file coverage/all13 samples, raw chunk plus merged scaled sumw/sumw2/bins/flows/templates, transport and indices. Ignore only explicitly volatile top-level key/created_unix/execution, normalize index workdir prefix. No originalROOT reread as oracle. Natural key proof separately checked396 keys: A1=A2, B1=B2=D0, baseline≠candidate. Production diagnostic1584 records: requesteddecode1/effectivereader1/outer16/serial_requested, no detached queue fiction.

All five transport reconstructions byte-identical. All five native PNGs fully decoded/nonblank and byte-identical:596×692 RGB,1,237,296 decoded bytes,49 unique colors, SHA256 **f113ea0f6657ce4e9582601c724ec7dacb883652a0dae65b6c2b711d08221fca**.9704 new output files inventoried (2426/arm). Ordinary process clocks included full native PNG/index publication.

Before each timed process selected .ji/.so SHA, build-ID/origin, image sizes and mtime recorded; actual own image consumption asserted inside ordinary entry. After: selected .ji touched, bytes/SHA unchanged, no new compiled cache files or renderer keys/compile directories. Actual renderer exec identity observed every arm. Historical command JSON and postflight contain full cache inventory and mtimes.

| Frozen identity | SHA256 / build ID |
| --- | --- |
| Baseline428 source manifest | 0a0937bf2d98067a01fee8b2c661fe87ee8cfe3b1157363b5ab6e6d42fb19f37 |
| Baseline691 runtime manifest | ce449ec70c81a1995b4f170146faaaa07e5a4ee63d8cb19cf19a966ce9d03615 |
| Final429 source manifest | 3141e2d86aed04444a2e174827db7e9f3f680121b63fd590c8556788ae4989a9 |
| Final693 runtime manifest | ec45bc7e6bfd30c3551ec221741d604a3e82d588aaa8fc2bab051b9deb66c3c5 |
| Baseline Ye57P_AEvvJ.ji | 2b8f537ae7858ad435d0d724021bec266bbedcc22f6502ecc11b32ad9e814701 |
| Baseline .so | e27dd9f1773234516e6325ee0bbf0f4e16e3d881163fd0d8dd66ef602fdeb3c2 |
| Baseline build-ID | 0xfafbfcfd5ad13b3235644e32cf15e1a5 |
| Candidate Ye57P_VUXtU.ji | 07bab9c44d55b18470e5858376e2193d8fc7474c7193086a27487e43b54d6296 |
| Candidate .so | efa03d64193fd4270fa114afbe38baa1861c0f3e4b1bf0e25afc393358e91af6 |
| Candidate build-ID | 0xfafbfcfde45c9ea78fadedc96684d43e |

ROOTPlots renderer key d8bac7fa45eb66293877d6362a615a748e3e20c3ac2bdd044623d920e1485b0b; executable171112B SHA2566a056492dd51b377ad8b75be78fbda3b56c9b6c8ed7db651ed7344029406bfd9. clang22.1.0 compiler realpath /cvmfs/sft.cern.ch/lcg/releases/clang/22.1.0-95893/x86_64-el9/wrappers/clang++; compilerSHA ecf9e5415c2ee0e60b88272eb5f785c9accfa1c66ab4e773ff150af8f91ef749. ROOT6.40.02 root-config/source-key exact hashes recorded in each command JSON; shared/private original renderer bytes unchanged. No new render compilation.

17 protected final records verified: frozen sharedcache860; dependencies/private842 each arm; baseline428/runtime691; candidate429/runtime693; pinned env/native/dependencies;58 old outputs;6 original/private renderer executables; all2508 original D0 files/evidence/helpers;396 input dev/inode/size/mtime_ns/ctime_ns identities; no owned Julia jobs. Mac authoritative429/693 separately rehashed and matched final freeze. Original p11/RDF plans were not touched. Optional full396 input content SHA **SKIPPED**, trusted metadata identity contract, no unnecessary100GiB scan. No content-hash measurement is counted as analyzed volume.

## Separate historical costs and D0

D0 first-touch calibration remains separate:170.292312304s, same396files/233,876,675events/522,713rows,8552 assertions and same PNG. Residency93,270,016B (0.0868499%) before,36,827,557,888B after; no assumption of perfectly cold inputs. D0 main live read_bytes36,734,287,872B has no matching main timestamp duration, so no same-scope rate is inferred from its external wall. D0 stages8.90/82.05/15.18/2.46/5.63/1.13/25.15s and residual29.792312304s. Not included in warm means.

| Historical compilecache only | Compilecache wall s | Supervised operation wall s | CPU user / sys s | ji B | so B | Image total B |
| --- | --- | --- | --- | --- | --- | --- |
| Baseline | 7.619607887 | 9.989193761 | 9.040659 / 1.069648 | 836444 | 5475016 | 6311460 |
| Finalr3 | 16.950218697 | 19.599874182 | 27.136088 / 1.411678 | 840907 | 11746640 | 12587547 |

These builds occurred before current benchmark; no build cost hidden in ordinary time and no n2 amortization/generalization claim.

## Evidence and reproducibility

O = /path/to/user/analisis/Cascade_dev/large-input100g

W = /path/to/user/analisis/Cascade_dev/large-input100g/warm-production-controls

P = /path/to/user/analisis/Cascade_dev/precompile-selection

Frozen manifest: O/evidence/selected-files.jsonl SHA256bcc3f8048d8beb95994649dd91e66a68c01110746e9ef57556456883cad73c9b. Identity: O/evidence/identity-frozen-before-firstread.jsonl SHA256aa76c29c9d745d8fa774dbe92aac90b9b7df84790c58db9312166f22022160df. Config: O/resolved-workload-D0.toml SHA2563d9edf320ca37915f211f895f32a4d59cd0008f794cc52660b999be2fb9decf1. Original D0 report docs/LARGE_INPUT_100G_D0_VALIDATION.md SHA256edf749db69b845e31427cf1fee576fdbb65535603d2bba6338305bb1a45c1b35 unchanged.

For each of A1-baseline428, B1-final429, B2-final429, A2-baseline428: W/<arm> fresh workdir; W/<arm>.command(.json), .log, .timed-log.jsonl, .samples.jsonl, .progress.json, .progress-history.jsonl, .receipt.json, .postflight.json and .supervisor.log. All exact commands/env/exits/resources/counters/image mtimes there.

W/run_arm.py, ordinary_warm_cli.jl, crossverify.jl, cross_driver.py, summarize.py are external harnesses only. W/crossverify.log, crossverify.julia.receipt.json, crossverify.receipt.json, crossverify.command.json and crossverify.driver.log prove output-only gate. W/evidence/matched-summary.json is numerical source, with per-arm same-scope counters/rates and stage shares; evidence/protocol.json, production-diagnostics.json, natural-key-proof.json, png-full-decode.jsonl, protected.final.json, new-output-inventory.json, Mac-freeze-final.json, per-arm stage-io-windows.json and transport TSVs provide details. W/evidence/final-review.md mirrors this report; final-artifacts.sha256 and completion.json bind final artifacts.

No scientific run failed or was retried. One final read-only inspection tool submission had a JavaScript syntax error before dispatch; corrected inspection succeeded, no benchmark rerun. Final git diff --check passed. No owned jobs remain. All authorized warm measurements and bounded validation are complete.
