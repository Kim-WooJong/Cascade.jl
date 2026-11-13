# First >=100GiB ordinary measurement: D0 production default — 2026-11-07

## Completed actual measurement

D0-final-production-firsttouch completed normally: exit0/raw0, all seven stages, no skipped artifacts or circuit, no scientific rerun. It used **396 distinct, nonempty original ROOT files**, all13 samples, **107392191402 bytes =107.392191402GB =100.016772190GiB**, and **233876675 input events**. No repeated passes, padding, synthetic/reduced logical double-counting or full-input hash prescan was used to qualify the threshold. Retained rows: **522713**. This is the original-file footprint of a selective columnar analysis, not a claim that every file byte was physically read.

Ordinary external monotonic wall: **170.292312304s** (Popen→blocking wait4, including public CLI, checkpoints, native PNG/index publication and process exit). WNOWAIT obtains a zombie snapshot immediately before wait4; this observation's small interval is included, not subtracted. It is a single first-touch calibration, not a paired baseline speedup result.

Area B:
/path/to/user/analisis/Cascade_dev/large-input100g

Fresh workdir: B/D0-final-production-firsttouch. Public entrypoint: Cascade.Pipeline.main(ARGS), via B/ordinary_large_cli.jl and the existing pinned private wrapper. No omitted integrity/source I/O/render stage or adapter.

## Frozen protocol and membership

Production default **decode_threads1 + column_readers1**,16T/BLAS1, sixteen outer file workers. This is deliberately not the earlier decode16 configuration, which serialized decode-file production. The existing final-r3 candidate project/cache stayed at its original absolute precompile-selection paths; no image/source relocation, package build/install/resolve, original config or product/source/test edit.

Same prior SF/eμ/ge1j/njet workload, only file volume/sample membership expanded: nominal muon ID/isolation, electron reconstruction/ID, pileup; configured1210pb^-1, one emu_ge1j region and seven-bin njet/native PNG, no fit/shape/theory scan. Existing per-sample xsec/BR and data stream priority/lumimask retained.

New external B/resolved-workload-D0.toml contains explicit396 filenames, SHA256:
3d9edf320ca37915f211f895f32a4d59cd0008f794cc52660b999be2fb9decf1

Original selected manifest remained byte-identical:
- B/evidence/selected-files.jsonl: bcc3f8048d8beb95994649dd91e66a68c01110746e9ef57556456883cad73c9b
- Separate ctime_ns frozen identity record B/evidence/identity-frozen-before-firstread.jsonl: aa76c29c9d745d8fa774dbe92aac90b9b7df84790c58db9312166f22022160df

All available MuonEG/SingleMuon/Muon files were included; MC and EGamma are partial. This is priority-closed technical coverage, not proportional/statistically representative sampling or a full luminosity-exposure claim. Signed Runs denominators were computed by ordinary skim from the selected complete files; no absolute-weight/full-dataset denominator substituted.

## Actual file/event/retained counts and signed normalization

| Sample | Files | Input bytes | Events | Retained rows | Signed Runs sum | Applied normalization |
|---|---:|---:|---:|---:|---:|---:|
| TTto2L2Nu |21|6410153852|5875095|271917|472607267.3137|0.00025099919574715624|
| TWminusto2L2Nu |21|1595399372|2369680|112397|9001616.396080002|0.0006268146410301501|
| TbarWplusto2L2Nu |21|1151622185|1708640|80929|6502747.215300001|0.0008676863428928005|
| WWto2L2Nu |21|1664587451|3274668|43366|38605748.32799999|0.0004183400270546364|
| WZto3LNu |21|1176911812|2336101|7227|11502599.890659997|0.0005175525582554551|
| WZto2L2Q |21|1983405360|3660139|308|27699903.82604|0.00015288861746945057|
| DYto2L_MLL50 |21|3835921606|7935354|169|141360971343.19998|0.000054319519221168494|
| DYto2L_MLL10to50 |21|3227415101|10257201|3|359728029368.718|0.00006721249951645425|
| TTtoLNu2Q |21|5407562772|6961060|757|2327262348.4200006|0.0002110440932168432|
| MuonEG |28|8695721563|15768439|5446|0 (unused for data)|1|
| SingleMuon |35|8408043001|20162441|35|0 (unused for data)|1|
| Muon |124|57717746301|138427345|140|0 (unused for data)|1|
| EGamma |20|6117701026|15140512|19|0 (unused for data)|1|

All396 files have positive event counts; there are no empty-tree bytes qualifying this volume. MC events44377938/retained517073; data events189498737/retained5640. Complete per-sample cutflows, region yields, signed per-file evidence and production diagnostics are in B/evidence/D0-science-summary.json and workdir skim/merge files.

## Raw wall/stage clocks and bottleneck localization

| Phase / purpose | Seconds | External-wall share |
|---|---:|---:|
| Skim: index396 files, metadata/counts/signed Runs |8.90|5.23%|
| Select: ordinary branch reads, objects/cuts, retained tables |82.05|48.18%|
| Correct: nominal SF weights |15.18|8.91%|
| Histogram:396 chunk stores |2.46|1.44%|
| Merge: signed normalization, stores/yields/cutflows |5.63|3.31%|
| Systematics: nominal templates |1.13|0.66%|
| Plot: preparation/transport/native ROOT/publication |25.15|14.77%|
| Stage sum |140.50|82.51%|
| UNATTRIBUTED external-minus-stage residual |29.792312304|17.49%|
| External total |170.292312304|100%|

Stage counts: skim13; select/correct/histogram396 each; merge/systematics/plot1 each; all skipped0. Existing time() stage clocks are rounded to hundredths; residual is not labeled JIT, I/O or another mechanism. Top timing-localization candidates are selection and the unlocalized outside-stage path; plot is next. These are not confirmed bottleneck mechanisms or additive isolated CPU/I/O components.

Input-footprint-normalized rate0.630634407GB/s, event rate1373383.636 events/s. **Neither is physical disk throughput.** No I/O-ceiling or stable speedup claim; no baseline100GiB comparison has yet run.

## Resource guards and observer overhead

One analysis group,16T/BLAS1, sampled group RssAnon64GiB, filesystem-free floor64GiB, output cap32GiB, initial hard7200s. No deadline growth or loadavg-based healthy-arm kill. Three durable minute-progress receipts; runtime did not reach the15-minute inspection threshold.

User CPU1078.882211s + system44.578751s; average6.59725 process CPU cores across entire wall. wait4 maxRSS8715832KiB; sampled group RssAnon maximum6525358080 bytes. MaxRSS is not summed group RSS. Final output40293001 bytes across2426 published artifacts. No surviving process/group members or adopted orphans.

Monitor CPU0.858791s over170.292s, about0.5043% of one CPU core's wall time (not subtracted from result),170 resource/I/O samples. Initial fixture full-/proc scanning was replaced by targeted child/thread descendant discovery; both fixture attempts preserved. Host load1/5/15 before0.76/0.86/0.94, after6.08/3.82/2.09; own analysis contributes load, so no external-contention inference from load alone. Full host CPU/memory/diskstats/pressure context remains in receipt/progress artifacts.

## Residency and I/O scope: honest fallback

Metadata-only fincore/mincore over all396 files, outside ordinary clock; no flush/fadvise/drop-caches/tuning/input SHA scan:
- Before:93270016 resident bytes,22771 pages,2 fully resident files; **0.0868499%** of file footprint.
- After:36827557888 resident bytes,8991103 pages,4 fully resident files; **34.2925844%**.

Label: observed low-residency first touch, **not assumed wholly cold and not a cold paired comparison**. Residency measures pages, not an independent physical-I/O counter.

Untimed Python fixtures exercised a reaped child, reaped grandchild and adopted orphan under subreaper/session and pid/starttime identities. This kernel exposed live /proc/io counters but zombie counters were unavailable after WNOWAIT, before wait4. Exact terminal tree known-character aggregation therefore did NOT validate; missing counters remain NULL. The explicitly permitted fallback was used: live Julia-PID kernel accounting, not guessed whole-tree/final/device bytes; no dead last-sample sums with parents and no rusage/proc addition.

Live root-PID counters bracketing public main (includes ordinary work/publication, excludes subsequent process-exit cleanup):

| Field | After-main minus before-main |
|---|---:|
| rchar |85072051|
| wchar |43941736|
| read_bytes |36734287872|
| write_bytes |48558080|
| cancelled_write_bytes |45056|
| syscr/syscw |8252 /14823|

These are kernel-accounted live root-PID values, possibly including waited-child roll-up. rchar omits mmap data access; write_bytes is dirtying/accounted storage, not device writeback. Root final/zombie I/O, exact tree totals and physical device job bytes remain **UNKNOWN/NULL**. No ru_inblock→byte conversion and no per-task I/O-wait inference. read_bytes36.734287872GB is not the100GiB input-file footprint.

Ordinary stdout lines are timestamped and1Hz root/process samples preserved. B/evidence/D0-stage-io-windows.json brackets stage observations with nearest samples. Uncertainty includes ±sample interval, stdout scheduling and child-reap/counter-rollup races; expanded brackets overlap adjacent stages and are not additive exclusive stage I/O. Device/partition diskstats are shared-host context only, never summed or attributed as exact job traffic. Serial production mode does not emit detached-basket payload counters, so a whole-run compressed/declared-decoded logical payload total is unavailable.

## Bounded postclock verification

Fresh output-only Julia verifier exit0/raw0 in34.236900493s; **8552/8552 assertions**, no circuit. It verified all396 manifest paths/signature sizes/event counts; retained tables/ordered unique in-range entries/weights; signed file-order Runs sums and normalization; cutflow reaggregation; bit-exact reconstruction of all396 chunk histograms; raw/scaled merged stores and nominal templates; seven-bin transport and publication index. It reads outputs, not original ROOT inputs. This is bounded internal consistency, not an independent correction oracle or matched baseline result.

Production diagnostics for all files report requested decode1, effective reader1, serial_requested, stage_file_workers16. Detached queue fields are absent because no detached queue was started—not reported as observed zero-valued counters. Normal @sync/file-stage completion and normal process exit leave no in-flight workers.

Native PNG fully decoded/nonblank:596×692 RGB,1237296 decoded pixel bytes,49 distinct colors; SHA256 f113ea0f6657ce4e9582601c724ec7dacb883652a0dae65b6c2b711d08221fca. Existing exact-key private renderer executable was observed; no compiler/new renderer key or cache inventory change. Transport TSV is reconstructed/validated; ordinary backend temporary transport is not retained.

## Protected state and concrete next checkpoint

All396 input realpath/device/inode/size/mtime/ctime identities unchanged; original selected manifest intact. Mac/native source429 and runtime693 still match3141e2d86aed04444a2e174827db7e9f3f680121b63fd590c8556788ae4989a9 / ec45bc7e6bfd30c3551ec221741d604a3e82d588aaa8fc2bab051b9deb66c3c5. Baseline428/frozen691, original860 shared-cache files,842 dependency images per private arm, environment/native old-input records,58 old outputs, renderer originals/private copies and selected image bytes unchanged. No p11/RDF/plans edits, installs/dependencies/cachebuilds/shared writes, staging, commit, push or delegation.

Main evidence:
- B/D0-final-production-firsttouch.command.json, .log, .timed-log.jsonl, .samples.jsonl, .progress-history.jsonl, .receipt.json, .postflight.json
- B/evidence/D0-result.json, D0-science-summary.json, D0-stage-io-windows.json
- B/evidence/D0-before.* and D0-after.* identity/residency records
- B/evidence/io-fixture-validation.json and preserved initial fixture diagnostic
- B/D0-verify.log/.receipt.json; B/evidence/D0-protected-final.json, D0-Mac-freeze-final.json, D0-nonempty-original-coverage.json, D0-output-inventory.json, D0-png-full-decode.jsonl

Actual D0 measurement is complete. Parent may now freeze a warm matched baseline428 decode1 versus final429 decode1 pair on the identical396-file set, same16T/BLAS1 and guards. Calibration suggests600s/arm as a conservative proposal, not an active authorization. No further arm has started. Configured1210pb^-1 remains technical exposure UNKNOWN for this partial dataset; stable superiority, physical disk throughput and I/O limitation remain unestablished.
