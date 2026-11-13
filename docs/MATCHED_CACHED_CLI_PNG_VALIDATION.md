# Matched cached ordinary CLI → native PNG — 2026-11-07

## Result and limits

Completed four fresh processes in **ABBA** order: baseline428/decode16, final candidate429/decode16, candidate, baseline. All exit0/raw0, all cache/renderer gates valid, no circuit fired. One bounded after-clock verifier passed **489 science assertions**, four full nonblank PNG decodes, and protected-state checks. Product/runtime/source/tests remained frozen; only new step documentation and external investigation helpers/artifacts were added.

Observed baseline mean/median **92.624366752s**, candidate **89.369832536s**: candidate wall reduction **3.513691191%**, mean baseline/candidate ratio **1.036416474**. These are descriptive results from **two observations per arm**, not stable speedup or statistical/inferential claims. No useful-thread scaling matrix or physical I/O ceiling was established. Package images were cached; native data/page-cache state was neither controlled nor scanned. Whole CLI/process physical read/write bytes are **UNKNOWN**; raw ru_inblock/ru_oublock are retained but not interpreted as byte counts.

## Exact workload and isolation

Gate: validation-host.example, Linux x86_64, kernel5.14.0-687.66.1.el9_8.x86_64.
Evidence/run root (R):
/path/to/user/analisis/Cascade_dev/precompile-selection/matched-cached-cli

R/workload.toml is an unchanged byte copy of frozen PhaseB configs/final-decode16.toml, SHA256 147c1a05ce93a9216b5faf4b145aee6c2d132d7aedea114d4260c26c8fb42233: exact old TTto2L2Nu and MuonEG inputs (32853/104057 entries), SF corrections, nominal-only shapes, emu_ge1j/njet, ordinary skim/select/correct/histogram/merge/systematics/plot, native PNG. Both arms have decode_threads16/column_readers1. Fresh workdirs, --force, all stages skipped=0, no checkpoint reuse, adapter, omitted integrity/source I/O/render stage, warmup, extra input scan or parameter matrix. Old uncached timings were **not** performance controls.

ordinary_cli.jl checks consumed image/build ID, thread/BLAS/depot/load-path/flags/project, then calls Cascade.Pipeline.main(ARGS), exactly the public entrypoint used by bin/cascade.jl; this source has no separate CLI module. All source I/O, integrity checks, native rendering and publication remain in the ordinary pipeline.

Common environment: pinned direct Julia1.12.2, JULIA_THREADS16, OPENBLAS_NUM_THREADS1, JULIA_PKG_PRECOMPILE_AUTO0, JULIA_PKG_OFFLINEtrue, JULIA_LOAD_PATH @:@stdlib; JULIA_DEPOT_PATH/JULIA_PROJECT select only the arm's private depot/project. MATCHED_ARM, MATCHED_CACHE, MATCHED_BUILD_ID select the recorded identity. Same corrected private wrapper/LCG110/ROOT6.40.02; startup-file=no, compiled-modules=existing, pkgimages enabled (asserted). No home-depot fallback.

Canonicalized command (actual argv/environment remain authoritative in each .command/.command.json):

    bash "$ROOT/pinned-private-wrapper.sh" --compiled-modules=existing \
      --project="$ROOT/$ARM/project" "$R/ordinary_cli.jl" run "$R/workload.toml" \
      --steps skim,select,correct,histogram,merge,systematics,plot --force --workdir "$R/$CASE"

ROOT is /path/to/user/analisis/Cascade_dev/precompile-selection. Cases/new workdirs: R/A1-baseline, R/B1-candidate, R/B2-candidate, R/A2-baseline. Each has separate .command, .command.json, .log, .exit, .receipt.json, .validation.json at R. A1's lexical wrapper path contains matched-cached-cli/../; its canonical file/hash is identical. Exact argv, recorded environment, host context, raw stage/progress clocks, cache timestamps and observed native executable identities are retained.

## Clock and watchdog boundary

External monotonic starts immediately before Popen and stops on blocking wait4 normal root exit, including wrapper/package load/public CLI/native PNG/output publication/process cleanup. All SHA/cache/renderer checks are outside ordinary clock. Existing pipeline stage clocks use time() and print rounded hundredths; no stage instrumentation/source change. UNATTRIBUTED is external wall minus the seven reported stage clocks—not assigned to JIT, I/O, renderer or another cause. Stage rounding contributes up to approximately0.035s to that residual. Raw per-file progress clocks remain in logs and are not added again.

One subject group at a time, hard150s/process and sampled group RssAnon16GiB. No deadline growth, retries or invalid/warmed samples. A prospective remaining-sample/verification budget check followed the first pair. Every image/renderer gate passed; all four samples were retained.

## Every raw ordinary wall/stage clock (seconds)

| ABBA case | External wall | Skim | Select | Correct | Histogram | Merge | Systematics | Plot | Stage sum | UNATTRIBUTED |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| A1 baseline | 93.124700896 | 2.93 | 16.30 | 9.37 | 1.65 | 4.92 | 1.10 | 26.74 | 63.01 | 30.114700896 |
| B1 candidate | 90.309808135 | 3.23 | 14.35 | 9.34 | 1.68 | 4.96 | 1.11 | 25.55 | 60.22 | 30.089808135 |
| B2 candidate | 88.429856938 | 2.88 | 13.19 | 9.16 | 1.53 | 4.84 | 1.09 | 25.80 | 58.49 | 29.939856938 |
| A2 baseline | 92.124032608 | 2.94 | 16.35 | 9.63 | 1.81 | 5.13 | 1.07 | 25.55 | 62.48 | 29.644032608 |

| Arm | Individual wall seconds | Mean = median | Min–max spread | Sample SD |
|---|---|---:|---:|---:|
| Baseline (n2) | 93.124700896,92.124032608 | 92.624366752 | 1.000668288 | 0.707579332 |
| Candidate (n2) | 90.309808135,88.429856938 | 89.369832536 | 1.879951197 | 1.329326240 |

Pairs, baseline/candidate ratio: A1/B1 **1.031169292**, difference2.814892761s (candidate3.022713344% lower); A2/B2 **1.041775208**, difference3.694175670s (candidate4.010002130% lower). Difference of arm means3.254534215s. Mean selection stage16.325→13.770s; mean UNATTRIBUTED29.879366752→30.014832536s. These stage observations are not a mechanism attribution or stable stage-speedup claim.

### Raw CPU/memory and host load context

| Case | User CPU s | System CPU s | wait4 maxRSS KiB | Peak sampled group RssAnon bytes | Loadavg1/5/15 before → after |
|---|---:|---:|---:|---:|---|
| A1 | 106.864690 | 2.119069 | 1407876 | 1203109888 | 1.07/1.17/1.33 → 1.96/1.42/1.40 |
| B1 | 105.116351 | 1.827669 | 1380580 | 1175449600 | 1.07/1.27/1.35 → 1.99/1.53/1.44 |
| B2 | 103.271180 | 1.825131 | 1360068 | 1173299200 | 1.99/1.53/1.44 → 2.81/1.94/1.59 |
| A2 | 109.106123 | 2.093224 | 1491756 | 1298358272 | 2.81/1.94/1.59 → 2.01/1.93/1.63 |

CPU includes waited-for descendants; wait4 maxRSS is not summed group resident memory. Full /proc/stat, /proc/meminfo, /proc/loadavg, sample counts, faults and block counters are in receipts. No stable result is inferred from this shared-host context.

## Exact image and existing renderer pre/post proof

Before every run, outside clock: SHA256/size/mtime of selected .ji/.so, expected build ID, compiled-file inventory and original/private renderer key trees. Inside: actual Base.pkgorigins cachepath and module build ID asserted/logged. After clock: selected .ji touched; image byte hashes unchanged; no compiled-file inventory/size changes; renderer trees/bytes/modes/mtimes identical; native executable observed at correct private exact-key path. No renderer compilation/new key/compile-* directory.

| Arm | Cache suffix | .ji SHA256 | .so SHA256 |
|---|---|---|---|
| Baseline | Ye57P_AEvvJ | 2b8f537ae7858ad435d0d724021bec266bbedcc22f6502ecc11b32ad9e814701 | e27dd9f1773234516e6325ee0bbf0f4e16e3d881163fd0d8dd66ef602fdeb3c2 |
| Final r3 | Ye57P_VUXtU | 07bab9c44d55b18470e5858376e2193d8fc7474c7193086a27487e43b54d6296 | efa03d64193fd4270fa114afbe38baa1861c0f3e4b1bf0e25afc393358e91af6 |

Build IDs: baseline0xfafbfcfd5ad13b3235644e32cf15e1a5; candidate0xfafbfcfde45c9ea78fadedc96684d43e. Images reside under ROOT/ARM/depot/compiled/v1.12/Cascade.

Selected .ji mtime_ns before→after:
- A1:1794035270502641836→1794036190939258223
- B1:1794035455997491975→1794036360237640889
- B2:1794036360237640889→1794036451064893566
- A2:1794036190939258223→1794036539946969502

Renderer: private per-arm native-backends/rootplots-render key d8bac7fa45eb66293877d6362a615a748e3e20c3ac2bdd044623d920e1485b0b; executable SHA256 6a056492dd51b377ad8b75be78fbda3b56c9b6c8ed7db651ed7344029406bfd9,171112 bytes. Compiler/root-config/source identity and all historical renderer keys are in setup/pre-post artifacts; same LCG/compiler/source realpaths as accepted remediation. Compiler subjects/wrong renderer identities would invalidate and stop the sequence; none occurred.

### One-time build costs, excluded from ordinary samples

Baseline compilecache call7.619607887s; supervised build wall9.989193761s, user/system CPU9.040659/1.069648s, image836444+5475016=6311460 bytes. Final r3 compilecache call16.950218697s; operation wall19.599874182s, user/system CPU27.136088/1.411678s, image840907+11746640=12587547 bytes. CPU includes wrapper/eligibility/compiler children. Larger image/build costs are real tradeoffs; no amortization threshold is established by n2 timing. Shared primitive precompilation benefits serial readers/counters too—not opt-in detached decoding alone.

## After-clock science, publication and native verification

Single bounded final-verifier: wall39.069951796s, exit0/raw0, no circuit; user/system CPU41.138781/1.523275s, maxRSS726148KiB, peak group RssAnon498786304 bytes. Science subtest: **489/489 assertions**. Each of all four runs is compared against frozen PhaseB ordinary reference .../basket-decode/candidate/phase-b-final428/total-t16-d16, not just an in-process serial reader.

Checked exact entries/order/column types/raw bits for selection and nominal SF correction weights; scientific headers/cutflows; skim denominators/exposure; normalization/sample metadata; per-sample raw histograms, raw/normalized merged stores, systematics templates, edges/sumw/sumw2 and existing folded-flow bins; merge/cutflow/yield text; full reconstructed ROOT transport; publication index and every referenced file/sidecar. All five transports (four+reference) byte-identical. Natural content-key invalidation checked separately: repeated-arm keys equal, baseline/candidate selection keys differ.

Ignored **only** top-level sidecar key (natural code invalidation), created_unix, execution (validated separately), plus explicit workdir-prefix normalization for index paths. No broad scientific metadata exclusion.

Both samples/every run: effective actors16, created/decoder workers15, actual max active decoders15, workers joined/tasks done, reservations/bytes fully released, live jobs/bytes/retained payloads/active decoders/cleanup errors/extra opens/closes zero, no phase fallbacks. TTto2L2Nu credits174/174; MuonEG541/541. Queue job highwater32; maximum queue byte highwater11533928. Exact eight diagnostics: evidence/queue-diagnostics.json.

All four PNGs fully decoded: signature/chunk CRCs/zlib/full reverse filtering/IEND/nonblank pixels. Each596×692 RGB,1237296 decoded pixel bytes,36 distinct RGB pixels. Four byte-identical PNG hashes:
8036e6bb63d3e9398e08ac430e6716898ad0fcd4a34421c36b5fca02b151ec5d.
Four indexes verified;116 new files inventoried. No temporary publication files left.

## Protected state, artifacts and completion

Frozen manifests verified unchanged; final candidate Mac↔gate matches:
- candidate source429 3141e2d86aed04444a2e174827db7e9f3f680121b63fd590c8556788ae4989a9
- candidate runtime693 ec45bc7e6bfd30c3551ec221741d604a3e82d588aaa8fc2bab051b9deb66c3c5
- baseline source428 0a0937bf2d98067a01fee8b2c661fe87ee8cfe3b1157363b5ab6e6d42fb19f37
- baseline/frozen decoder runtime691 ce449ec70c81a1995b4f170146faaaa07e5a4ee63d8cb19cf19a966ce9d03615

Original860 shared-cache files,842 dependency images in each private overlay, dependency source/environment records, pinned native inputs,58 old outputs and original/private renderer artifacts unchanged. No installs/resolve/dependency builds/shared-cache writes/RDF/p11/old-suite restart, source/test edits, staging, commit or push. No owned jobs remain. Original validation docs stay historical, unchanged. Setup and initial document-writing tool calls failed before dispatch and were corrected; setup state inspection confirmed no phase/job before successful setup. No benchmark or verifier run failed or was repeated.

Ordinary363.988398577s + verifier39.069951796s = **403.058350373s / final-phase500s**. Including prior375.811147798s: **778.869498171s / overall target900s**. Outside-clock hash/preparation/documentation time is not reported as measured ordinary throughput.

Main new evidence under R:
- evidence/matched-summary.json: raw receipts/stages/UNATTRIBUTED/pairs/aggregates/limits, SHA256 6ee71b36b00eb09c9b2cac090be62a4ab0ffb998f506b4608cf861e6e92e58be
- final-verifier.log/.receipt.json/.validation.json
- evidence/protected.final.json, mac-freeze-final.json, queue-diagnostics.json
- evidence/png-full-decode.jsonl, new-output-inventory.json, natural-key-proof.json, five transport TSVs
- Per-case exact command/environment/log/exit/receipt/pre-post validation; setup/supervisor/thin public-main entrypoint/bounded verifier helpers.

**Authorized timing and validation are complete.** A small descriptive end-to-end improvement was observed; stable superiority, sustained useful-thread scaling and the original physical I/O-limitation goal remain unproven.
