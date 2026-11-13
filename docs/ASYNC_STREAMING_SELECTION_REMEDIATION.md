# Async streaming selection: narrow remediation and all396 eligibility

2026-11-07. **Three requested fixes implemented and validated. STOPPED for concrete rereview. The required396/396 all-streamed benchmark prerequisite is NOT met:331 eligible,65 explicit padded-index fallbacks. No107GB ordinary arm or performance claim.** Broader throughput task remains open.

## Scope and preserved provenance

Before source/cache changes, copied and verified accepted source434/runtime699, exact twelve-file implementation delta, old image pair and its cache/proof/report records into remediation-2051/archive-434-699. Archive is provenance-only; no claim of blind image relocation/loading. Existing5924-entry sealed evidence, baseline429 project/cache, original/shared/dependency bytes and old107GB results remain unchanged. Only the owned current candidate image was replaced after archiving. Original validation report is not rewritten.

## Requested fixes

1. **Interrupted cleanup joins:** cleanup releases each startup latch once outside the retry loop, then keeps calling injectable waiter(task) while !istaskdone(task). Catching a wait interruption cannot advance to close a still-running source. Every created task settles before remaining-source close. An existing controller primary remains the identical exception; a join interrupt without an earlier controller primary remains cancellation, not ordinary file failure/fallback permission. No throwto or asynchronous native interrupt.

2. **Exact original index/mask contract:** stream_basket_index requires the full fBasketEntry length to equal numbaskets+1 before planning, not a sliced prefix. Padded/unsupported basket-count shapes explicitly return unsupported_basket_index. Only unsupported count dispatch/shape is a fallback; unrelated exceptions, cancellation, malformed metadata, integer/resource and byte-budget failures remain hard errors. No budgets were loosened.

3. **Independent serial fallback attempts:** ordinary joined stream failures carry their deferred inventory in StreamFileError, labeled stream file N rather than decode job N. step_select captures only this ordinary failure, completes independent statically classified plus metadata-discovered serial fallbacks after all stream jobs settle, then reports the stream error. A serial fallback failure is reported alongside the stream failure, not swallowed. Fatal/controller/cancel failures bypass this capture and start no additional fallback work. Default no-pending-error route simply runs the existing serial runner.

### Focused evidence

Held read worker waits on a Channel. Controller throws a known primary; injected waiter throws InterruptException twice then uses real wait. Gate release is protected by finally. Closer asserts reader finished and all created tasks are done. Exact primary identity, cleanup_errors==2, joined workers, balanced count/byte credits and zero final live payloads pass. The ordinary-failure test preserves a completed checkpoint, attempts both static and discovered unsupported fallback checkpoints, then returns the original stream error; secondary fallback failures are observable. Fatal/controller and cancellation cases prove no fallback attempt. Padded-index synthetic gates retain strict versus corrupt/error distinctions.

## Actual validation and image proof

| Gate | Exit | Assertions / result | Scope |
| --- | --- | --- | --- |
| focused01 (source) | 0 | 507 | Full focused suite including the three new regressions |
| build01 | 0 | six direct dependency caches valid | Cascade-only image build; no dependency rebuild |
| focused-cached | 0 | 507 | Same final product/source via fresh corrected image |
| native-once | 0 | 130 +257 | ONE16T six-file native pass: owned snapshots/masks/oversize + ordinary selection parity |
| metadata396 | 1 | 331 eligible /65 fallback /0 hard error | Intentional all396 protocol refusal; all396 metadata records completed |
| fallback-shapes | 0 | 65 files /1378 padded required-branch indices | Supplemental metadata-only root-cause detail, not another396 scan |
| protection | 0 | 25 protection records | Frozen evidence/source/cache/output hashes and exact input stat identities |

The one native pass uses the identical six files:3,018,888,095B unique footprint,5,029,882 input events and48,717 retained rows. Every typed value bit, original entry/order, scientific EventTable/cutflow/region metadata and pre/counter/post decoded/skipped basket work matches actual cached429 references.209 windows, zero repeated decoded baskets,15 workers created/max11 active,6 files complete, all workers joined and final active/live/window/retained credits0.209 reserved/released credits and46,083,802,187 cumulative reservation-bytes agree. Peak accounted queue2,979,603,544B, retained estimate83,647,872B. Same-file read-next/analysis-current interval overlap3.346231209s; this is concurrency evidence, not saved wall or a speedup measurement. No old three-repeat/native-width matrix was restarted.

New image remains at candidate/depot/compiled/v1.12/Cascade/Ye57P_ImX46.{ji,so}, in the isolated owned private depot. Fresh processes prove exact source/project/cache/build-ID, private LOAD_PATH/depot, Julia1.12.2,16T/BLAS1, compiled-modules existing and pkgimages enabled before native work. Per-run ji mtime touched and both image byte hashes stay unchanged.

Build-ID:0xfafbfcfd5702772a979bc36cb5bcedf0

| Image | Bytes | SHA256 |
| --- | --- | --- |
| Ye57P_ImX46.so | 11968584 | c620d87aa7f45a7f83dd3116c70d97a907b8cff731a8f50c57da3443dceeeb39 |
| Ye57P_ImX46.ji | 874290 | 287ff512c279e8800bc9d3dc61099ac85b48ff0b77b92194425e3c3fe0455fc4 |

Target compilecache17.074178304s; supervised build18.696796206s; image12,842,874B. Existing generating-output-only synthetic precompile workload remains; no scientific input in build, no installs/network/resolve/world build or dependency image rebuild. Build cost is separate from ordinary-analysis time.

## All396 metadata-only eligibility / charges

Exact frozen manifest:396 files,107,392,191,402B. Exact dev/inode/size/mtime_ns/ctime_ns checked before/after and at final protection; no ROOT input content-SHA rescan. Metadata probe opens original files, parses tree/branch metadata and bounded basket headers, builds admission/reservation plans, but never invokes basketarray/read_stream_branch/read_stream_selection_window or decodes Events baskets. Fixed metadata/header reads may page-in containing pages; no cold-cache claim.

| Population | Files | Whole-file bytes | Original Events from frozen skim |
| --- | --- | --- | --- |
| eligible | 331 | 106942446433 | 233086232 |
| fallback | 65 | 449744969 | 790443 |

331 eligible files plan9,498 windows. Maximum window33,880 events (20k is a common-boundary coalescing target), reservation334,775,091B; maximum compressed basket101,393B / declared decoded195,120B. Configuration stays active_files16, queue_windows32, queue_bytes8GiB, raw_window64MiB, basket64MiB, metadata64MiB and separately retained8GiB. File metadata and window/retained reservations remain accounted across all queue states; these are conservative payload credits, not hard RSS measurements. All65 fallbacks are rejected before window admission: explicitly0 planned windows, null/unplanned bounds and detailed reasons in metadata396-protocol-inventory.jsonl. No corruption or resource/budget failure.

### Why65 fail

Supplemental inspection found1,378 padded index arrays across65 files, **zero unsupported-count exceptions**. Example: TTto2L2Nu/8b738361-7857-435a-b734-46ef21f1a766.root, Electron_charge has6,990 entries,3 baskets, expected4 index entries but raw length10; terminal at expected position is6,990 and six trailing entries are0. Original reader’s exact-length check disables its needed-mask optimization for that branch. Trimming the array then masking would change the original basket-work contract, so this phase deliberately keeps the explicit fallback rather than declaring it eligible. Every affected file/branch/count/raw length/terminal/padding is recorded.

| Sample | Padded-index fallback files |
| --- | --- |
| TTto2L2Nu | 2 |
| TWminusto2L2Nu | 8 |
| TbarWplusto2L2Nu | 6 |
| WWto2L2Nu | 10 |
| WZto3LNu | 13 |
| WZto2L2Q | 12 |
| DYto2L_MLL50 | 6 |
| DYto2L_MLL10to50 | 2 |
| TTtoLNu2Q | 2 |
| MuonEG | 1 |
| SingleMuon | 2 |
| Muon | 1 |

Do not drop the65 files/449,744,969B/790,443 events, change the fixed inventory, or relax the strict planner just to get396/396. Current feature remains scientifically valid through explicit existing serial fallback, but that is **not** the requested all-streamed arm.

Recommendation for the next reviewed compatibility step: consider a distinct bounded legacy read-job mode for these small padded-index files, only after conservative full-window metadata reservation proves it fits the same caps; execute original projection/unmasked-branch semantics on an exclusive reader and transfer owned columns into the SAME global analysis pool. Keep normal exact-index planning strict, expose the legacy mode, compare original typed bits and original per-branch work, and do not relabel an existing serial file-worker fallback as streaming. Bounds/eligibility for that alternative are not proved or implemented here; a separately reviewed plan is needed before proceeding.

## Frozen baseline/candidate configs and mandatory future postcheck

| Record | SHA256 / canonical hash |
| --- | --- |
| Baseline resolved TOML | 3d9edf320ca37915f211f895f32a4d59cd0008f794cc52660b999be2fb9decf1 |
| Candidate execution-only TOML | 4bde75eef2def760f34d7471724ef4747769e12f9b1a6b3e94893e618a4c3a15 |
| Selected manifest | bcc3f8048d8beb95994649dd91e66a68c01110746e9ef57556456883cad73c9b |
| Canonical nonexecution content, both configs | 419e9b6e1d6b87685cf38fa226662371e302a63ff4ea929e2ea0c5644867d93e |
| Baseline full canonical | db7418ec220215494b93f695659f07c7c26ee99651bb87aae45a564728690732 |
| Candidate full canonical | da852674976b8acdb2bb2cef8ea97f304c8bf0733a500c4b71dfc9d85b19010a |

Both TOML and resolved-config nonexecution equivalence assertions passed. Exactly one top-level difference: execution. Candidate resolved-candidate-streaming.toml adds streaming_selection=true; baseline429 uses the unmodified original D0 config because it cannot parse this new option. Physics sections, paths and396 membership are unchanged.

Prepared verify_streamed396.py is a postcheck, not a launcher. A future authorized candidate workdir must have exactly396 nominal selection sidecars with exact sample/source membership, streaming_selection is true, stage_global_owned_windows engine, no streaming_fallback/fallback/stage_file_workers old-route fields, settled-file publication and zero repeated decoded baskets. Config=true alone is never proof. It also requires current config/manifest hashes and all396 metadata eligibility. **It currently refuses the arm because metadata eligibility is331/396.** Full science/counter/Runs/normalization/nativePNG verification remains separately required later; this route check cannot substitute for it.

## Clock, budget and resource ledger

Owner20:51 renewed elapsed coordination after the pause. The old seal’s2,497.393864s elapsed and prior711.045299536s validation remain historical facts; this report does **not** pretend work fits the expired old wallclock. New limits are monitored operations, excluding idle/chat pause: additional validation≤450s, separate new metadata≤180s, old+new validation≤1200s, full phase monitored≤5400s, later still-unexecuted ABBA≤3000s. Ledger records actual renewal timestamp and explicit policy.

| Operation | Exit | Supervised wall s | wait4 user / sys s | maxRSS KiB | Peak group sampled anon B | Monitor CPU s |
| --- | --- | --- | --- | --- | --- | --- |
| focused01 | 0 | 60.939752583 | 65.132163 / 1.345846 | 885324 | 585920512 | 0.258981 |
| build01 | 0 | 18.696796206 | 26.202174 / 1.238693 | 849028 | 670175232 | 0.099098 |
| focused-cached | 0 | 50.932853337 | 55.481607 / 1.142601 | 851016 | 547471360 | 0.241013 |
| native-once | 0 | 67.806868857 | 141.139662 / 4.403601 | 2368784 | 1103556608 | 0.353262 |
| metadata396 | 1 | 148.983544104 | 142.801240 / 9.517935 | 2373072 | 547602432 | 0.713894 |
| fallback-shapes | 0 | 10.489211329 | 12.359936 / 0.760523 | 593120 | 359141376 | 0.057604 |
| protection | 0 | 9.499208427 | 8.491628 / 0.967979 | not sampled | not sampled | not sampled |

New validation including protection **207.875479410/450s**. Prior711.045299536 +new = **918.920778946/1200s**. New metadata148.983544104 +10.489211329 = **159.472755433/180s**, including the intentional protocol-failing exit. Current all-phase monitored total including old metadata/protection **1094.356234736/5400s**. No old/native work is relabeled or omitted.

At most one owned Julia/native process group,16T/BLAS1,≤300s/process, sampled64GiB RssAnon, free-disk floor64GiB, output cap32GiB;60s durable resource snapshots. No circuits fired. Raw command/limit/env/load/samples/receipts are kept. GC, exact storage I/O and per-stage throughput are unmeasured; no ru_inblock byte conversion, saturation or I/O-ceiling claim. Correctness-gate walls include startup/load/JIT/assertions, different scopes and extra fixtures, and are not matched performance arms.

## Final frozen source and five-file delta

| Bundle | Files | SHA256 |
| --- | --- | --- |
| Archived accepted source | 434 | 53c4c0ac2f7d6bbbcecc6c540737fba9300243e30fe2d769a65af46be1b34046 |
| Archived accepted runtime | 699 | a8942b73186d12b9eff856e3d9044e28ce3a3a5ef5dd87a64b4686269d83bdf7 |
| Remediated source | 434 | cf6c0ced279786438ebbfee316fc809d055a1565531b7ac51071bb0cfc942216 |
| Remediated runtime | 699 | eeaf73855a43d1ef312e64947a80956604c9145bf44a00d818753be4814940f8 |

| Changed versus archived434 | Final file SHA256 |
| --- | --- |
| src/IO/StreamWindowReader.jl | b4a45b944ce6990f989bcee9fb7f52f764e2d06dcd24900554ae985880dbeb0a |
| src/Pipeline/run_window_pipeline.jl | 4c7f13a5a44e52203232871fe9b166194823cc64e968dc0b82c54183ce292e3a |
| src/Pipeline/step_select.jl | b44a227d862499834bd11ff1e8edbee395c0f1e04ab1c6cd1dce9941cb27f466 |
| src/Pipeline/stream_selection.jl | c0be372cca0acc6b99532b25c0bed552f339b63f07e6ad8f918e86c5ac2a57b0 |
| test/stream_selection/runtests.jl | 8d1a7aba03beb1e8de95298eb2092479b7c8b10edd0934f785741760f1639f0c |

Mac/gate match every source/runtime record. Five files changed: four production files and the existing focused test; no unrelated worker-queue refactor, original EventWindowSource change, downstream/stage DAG/kernel/config/dependency/RDF/p11 edit, install, stage/commit/push or new107GB arm. New doc only; prior validation doc/evidence remain immutable.

25 protection records pass, including old5924 artifact seal, archived source/image, old429/428 source/runtime/cache and environment, original/shared860 and old/new private842 dependency bytes, new target inventory844, renderer keys/bytes/mtime/independent copies,58 old outputs and396 input exact stat identities. No owned jobs remain.

## Evidence and handoff

Gate root M = /path/to/user/analisis/Cascade_dev/async-streaming/remediation-2051

M/{archive-434-699/,source-final.sha256,runtime-final.sha256,Mac-freeze.json,remediation-delta.json,remediation.delta.patch,verification-summary.json,protected.final.json,ledger.json}; images.before.json, cache-proof.json, per-run imageguards; per-operation command/log/samples/receipt and attempts source/test snapshots. Metadata396 raw JSONL +summary, protocol-inventory JSONL, exact input pre/postflight, fallback-index-shapes JSONL/summary, eligibility-populations.json, config-pair-proof.json and both frozen config paths are recorded. ONE native workdir: M/native-16T-final-1. final-review.md mirrors this doc; final-artifacts.sha256 and completion.json seal the rereview handoff.

**Next: narrow concrete rereview of fixes and evidence, then decide a bounded legacy compatibility strategy for65 padded files. No107GB timing until parent acceptance and the all396 protocol prerequisite truly passes. Goal stays open.**
