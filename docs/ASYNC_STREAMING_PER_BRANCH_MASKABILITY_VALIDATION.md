# Per-branch maskability: final concrete implementation validation

2026-11-07. **Implemented the parent-selected per-branch common-boundary path, NOT legacy_bounded_single_window. Final metadata gate is396/396 eligible,0 fallback,0 hard error. STOPPED for independent concrete delta review before107GB timing. No speedup or storage-ceiling claim; broader user goal remains open.**

## Exact scope and semantics

Archive archive-cf6c preserves accepted source434/runtime699, image/proof and complete project BEFORE edits. Normal exact raw fBasketEntry arrays remain maskable=true. Longer arrays are accepted ONLY when the copied first nb+1 prefix is strictly ordered0..n and the entire extra tail is zero; maskable=false is retained per branch. Short/nonzero-tail/unsupported count remains refusal; bad prefix/count, corruption and all allocation/window/basket/metadata/retained caps remain guarded. No raw branch/LazyBranch index mutation. No cap was raised and no canonical/science hash was weakened.

Common boundaries are intersected from validated copied logical prefixes. Each physical basket fits wholly inside one admitted range, so no adjacent-window repeated decode. In read_stream_branch_owned, ONLY an unmaskable branch discards needed AND offsets, then reads full flat values or reconstructs actual jagged offsets. Exact-index siblings retain masking/canonical counters and preallocation guards. Counter read/cache/checked sums are unchanged and still occur once per collection prefix, including when a target branch is padded. This matches ORIGINAL read_nanoaod_branch, whose LazyBranch.fEntry aliases raw b.fBasketEntry and disables masking when the raw exact-length/end condition fails.

Same ordinary step_select stage-global Threads.@spawn :default READ→owned ANALYSIS pool, one exclusive ROOT reader/file, one ordered persistent-Cutflow analysis continuation/file,≤2 live windows/file and global count/byte/retained credits. No old serial file worker is relabeled as streaming. Defaultfalse, custom/unsupported policy, source identity checks, primary-error/fallback behavior, repeated-interrupt-safe join-before-close and later stage/checkpoint APIs remain. No legacy borrowed-source/counter adapter detour was implemented.

### Coalescing correction discovered by the first all396 gate

The first source revision/native suite passed, but its full metadata gate completed394/396 and refused TWO files as no_bounded_common_boundary. Actual valid common cuts existed; the previous target≥20k aggregation swallowed them when n was just past20k. This was a coalescing edge, not bad indices or a resource issue.

| File / Events | Validated common cuts | Final repair |
| --- | --- | --- |
| TWminusto2L2Nu/d126b000-2b9f-403f-811e-cb12e66d0005.root /20272 | 0,1000,4158,8316,12474,16632,20272 | 1:16632;16633:20272 |
| TTtoLNu2Q/cd109086-c756-4cc4-beb0-dd5b4fb59b8a.root /20850 | 0,1000,3693,7386,11079,14772,18465,20850 | 1:18465;18466:20850 |

stream_window_ranges preserves every established successful group. Only the target-overshoot single-window case chooses an EXISTING interior common cut. The existing single-window refusal still applies when no interior common cut exists. No within-basket split, full-file shortcut or bytes-limit relaxation. Actual cut regressions, unchanged grouping, no-interior refusal path, zero/one population tests pass. First revision/source/image/failed metadata and native outputs remain in round1-before-coalescing-fix plus original logs; final source rebuilt and representative/native gates rerun, not silently reused.

## Focused acceptance

| Gate | Exit | Pass assertions | Source scope |
| --- | --- | --- | --- |
| focused-source | 0 | 557 | First source revision before the extra declared-cap assertion |
| focused-cached | 0 | 558 | First image incl that additional preallocation guard test |
| focused-final | 0 | 565 | Final image, including7 coalescing-edge tests |
| native-padded | 0 | 452 +98 | First revision representative set |
| native-final | 0 | 452 +98 | Final source/image representative set; fresh final workdir |

Counts overlap; not a sum of unique science cases. Existing lifecycle/ownership/order/fallback tests remain. Added zero-tail acceptance+unmaskability, nonzero/short/bad prefix rejection, copied-prefix/raw nonaliasing, normal and padded flat/jagged siblings across multiple windows/masks, and before-reader invocation negative/oversize/declared-counter rejection. Synthetic expectations call unchanged ORIGINAL _read_flat/_read_jagged_all/_read_jagged_masked implementations through a test-only type-specific basket provider, not a rewritten physics kernel. Source-free assembly seam and optional no-op basket observer are internal test hooks; production has no full per-basket trace retention overhead.

## Representative native padded inputs and original429 reference

| Sample / ROOT basename | Input bytes | Events | Kept | Original work records |
| --- | --- | --- | --- | --- |
| TWminusto2L2Nu / 14e2e86b-54ad-41f7-939b-e4ac41e485dd.root | 16242576 | 23892 | 1162 | 209 |
| SingleMuon / 524de80c-60b9-4c0f-a1bd-332c51b2341a.root | 11274362 | 26571 | 0 | 168 |
| Muon / 2ab70e9d-5612-4283-8bb5-e80c8e088ab2.root | 22813751 | 53485 | 0 | 288 |

Three unique files50,330,689B /103,948Events /1,162 retained rows. MC includes actual padded jagged Jet_eta/phi/pt alongside regular masked jagged siblings; SingleMuon covers padded jagged data; Muon covers the53,485-event mixed case. Only these missing representative references were generated through original cached429; the old six-file width/repeat matrix and readonly65 probe were NOT restarted. Original429 source/project/ji/build-ID are explicitly proved before reference reads; inputs retain frozen identities.

For each input, ORIGINAL read_selection_columns ran and produced raw Vector/Jagged columns, actual prefix needed, nominal EventTable and scientific metadata. Original basket sets/counts/packed+payload/declared bytes are independently derived from its EXACT raw-index/end masking conditional, actual needed and counter availability—never a sliced-prefix assumption. These are deterministic original call/work contracts, not physical disk-byte observations. Final candidate observer records every decoded/skipped basket request by phase/name/basket with byte lengths.

Candidate window raw columns are concatenated and compared type/bit-exact (including actual offsets) with the original raw artifacts; needed mask also exact. Full decoded/skipped work SETS match, record counts match and duplicates are forbidden. All raw original fEntry arrays are unchanged before/after and retain raw-branch aliasing. Padded decoded counts/packed+declared bytes and all normal/pre/counter/post stats match. Then ordinary step_select runs the same set, with fresh forced artifacts, comparing all entry/order/type/value bits, cutflow/region/scientific EventTable metadata and work counters. No artifact reuse; unchanged skim-signature fixture bytes.

### Final native execution/accounting

3 files,7 windows,15 workers created /6 max active, max6 live windows and3 active files. Accounted queue highwater1,121,407,598B; retained estimate41,322,816B.7 credits and946,352,693 cumulative reservation-bytes reserved/released. All workers joined; final active/live/window/retained credits0; cleanup errors0; no repeated decoded baskets. Same-file neighboring read/analysis interval overlap **0.397993460s**, concurrency evidence—not time saved, global utilization or a speedup.

Final representative modes are common_boundary_per_branch_maskability,2/2/3 windows, explicit unmaskable branch lists and padded branch basket counts. Normal mode is common_boundary_exact_indices. No legacy single-window label, hidden serial route or full postcolumn eager prefetch. Native validation covers selection only; full seven-stage SF/correction/histogram/merge/systematics/nativePNG comparison awaits the later authorized fixed107GB benchmark. Existing Runs/normalization/downstream kernels were not changed.

## Final changed-source ALL396 metadata check

396 files /107,392,191,402B: **396 eligible,0 fallback,0 hard error**,331 exact-index files and65 per-branch files,1,378 unmaskable required branches.9,580 total windows:9,498 normal plus82 padded-file windows. Data remain projected and padded branch work remains original/unmasked; these counts do not imply every small file has multiple windows. No Events basket decode or ROOT input full-SHA scan. Metadata checks original tree/branch/basket headers, identity and conservative charges only. No flush/drop/fadvise, tuning or cold-cache assumption; header reads may page-in containing pages.

| Maximum / limit | Bytes or events |
| --- | --- |
| Window events / target (not a hard event cap) | 33880 /20000 |
| Window charge / queue8GiB | 334775091 |
| Compressed basket /64MiB | 101393 |
| Declared decoded basket /64MiB | 195120 |
| Raw/window/basket/metadata caps | 64MiB each, unchanged |
| Queue / retained caps | 8GiB each, unchanged |

First serial failed gate108.779434548s is preserved/counts against the subcap. Final full396 source-matched recheck used15 fixed metadata workers with DISTINCT exclusive ROOT handles, no Events decode, shared immutable selection config and controller-ordered record serialization;39.027817729s (plan portion23.343832984s). This observer-only parallelism is not a candidate-reader performance result. **Total396 metadata147.807252277/180s**, including failure. No partial394+2 eligibility substitution. No old331-only proof relabeled as final396.

## Config pair and strict future route check

| Record | Hash |
| --- | --- |
| Original baseline TOML SHA256 | 3d9edf320ca37915f211f895f32a4d59cd0008f794cc52660b999be2fb9decf1 |
| Candidate execution-only TOML SHA256 | 4bde75eef2def760f34d7471724ef4747769e12f9b1a6b3e94893e618a4c3a15 |
| 396 manifest SHA256 | bcc3f8048d8beb95994649dd91e66a68c01110746e9ef57556456883cad73c9b |
| Canonical nonexecution, BOTH configs | 419e9b6e1d6b87685cf38fa226662371e302a63ff4ea929e2ea0c5644867d93e |

Only top-level execution differs (TOML and resolved config assertions), preserving all physics/paths/membership. Baseline429 uses original config because it cannot parse streaming_selection. Default remains false. verify_streamed396.py now requires the FINAL source metadata396-final inventory,396 exact sample/source sidecars, engine stage_global_owned_windows, streaming_selection is true, no streaming_fallback/fallback/stage_file_workers, settled publication,0 repeated baskets, exact expected mode/unmaskable branch set/padded basket counts/window count per source and raw-indices-unchanged flag. This is route proof, not a substitute for the later full science/counter/PNG validation. No107GB arm is launched by the postcheck.

The route verifier also passed a separate contract-only fixture:396 synthetic sidecars/dummy files (clearly labeled NOT ANALYSIS) accepted, and9 invalid cases rejected (false streaming, fallback, old file workers, wrong mode, wrong branch list/counts/window count, repeated baskets, or only395 files). This is NOT scientific output or an ordinary107GB arm. Its0.641341928s receipt and final seal checks are added in completion.json beyond the protection-checkpoint ledger displayed below; no ROOT input/native work was involved.

## Builds, actual costs and ledger

Current source/image was archived before each own-image replacement; archive-cf6c is the accepted source434/runtime699+cf6c image/proof, and round1-before-coalescing-fix preserves first-round source/image/native/failed probe. No blind archive cache relocation claim. All six direct dependency cache eligibility checks true; compilecache only Cascade with existing modules; original/shared and all old/new private dependency image bytes/inventory unchanged. Existing renderer independent-copy keys/bytes/mtime unchanged and not executed here.

Final fresh load proves build-ID0xfafbfcfda12c3b300be782f2deb22fe6, own exact project/source/cache, Julia1.12.2,16T/BLAS1, private LOAD_PATH/depot, compiled-modules existing and pkgimages enabled. ji touched on each final load; image bytes remain frozen.

| Current image | Bytes | SHA256 |
| --- | --- | --- |
| Ye57P_ImX46.so | 11996632 | cb8b93ca40ffd1f6aa904f794d31ccb742f81bf82ca09061ed18b484f802464c |
| Ye57P_ImX46.ji | 877388 | a52153cf9aa1fcb68d8721e40b89b5744d0c247515b801188150c69cae9cd44d |

Final image total12,874,020B. Build-only generating-output synthetic precompile workload has no scientific input. No dependency rebuild/installation/resolve/network or home/shared writes. Target compilecache costs from final build log:

~~~text
DEPENDENCY_CACHE UnROOT true
DEPENDENCY_CACHE ROOTPlots true
DEPENDENCY_CACHE ForwardDiff true
DEPENDENCY_CACHE SpecialFunctions true
DEPENDENCY_CACHE CodecZlib true
DEPENDENCY_CACHE JSON3 true
CASCADE_ONLY_COMPILECACHE_SECONDS 16.692819703
CASCADE_ONLY_RESULT ("/path/to/user/analisis/Cascade_dev/async-streaming/candidate/depot/compiled/v1.12/Cascade/Ye57P_ImX46.ji", "/path/to/user/analisis/Cascade_dev/async-streaming/candidate/depot/compiled/v1.12/Cascade/Ye57P_ImX46.so")
CACHEBUILT /path/to/user/analisis/Cascade_dev/async-streaming/candidate/depot/compiled/v1.12/Cascade/Ye57P_ImX46.ji
~~~

| Operation | Exit | External wall s | CPU user/sys s | wait4 maxRSS KiB | Peak sampled group anon B | Observer CPU s |
| --- | --- | --- | --- | --- | --- | --- |
| focused-source | 0 | 58.160948176 | 62.817862/1.210486 | 876096 | 583864320 | 0.265467 |
| build | 0 | 17.891026338 | 25.538845/1.121759 | 854588 | 788119552 | 0.100619 |
| references429 | 0 | 22.725083259 | 25.240432/0.883582 | 727868 | 474025984 | 0.089859 |
| focused-cached | 0 | 54.937893424 | 59.354076/1.234402 | 891168 | 598421504 | 0.262013 |
| native-padded | 0 | 49.284976671 | 60.977332/1.217344 | 1076096 | 832286720 | 0.246019 |
| metadata396 | 1 | 108.779434548 | 137.159457/4.011340 | 2372020 | 545353728 | 0.629255 |
| build-final | 0 | 18.239320859 | 26.271546/1.169377 | 849152 | 773300224 | 0.135046 |
| focused-final | 0 | 56.988050724 | 61.249593/1.266476 | 868608 | 586797056 | 0.327669 |
| native-final | 0 | 48.517701459 | 59.944594/1.074987 | 1085432 | 841969664 | 0.286522 |
| metadata396-final | 0 | 39.027817729 | 180.028401/9.559818 | 7318108 | 1202520064 | 0.266845 |
| protection | 0 | 9.730465372 | 8.669662/1.022007 | not sampled | not sampled | not sampled |

Costs are unmatched validation scopes including startup/load/JIT/assertions/extra raw fixtures; no ratio is a performance arm. Reference raw/science/work uses old429; candidate manual raw and ordinary step_select are distinct validations in the same representative set. No repeated old width/three-repeat matrix. GC, exact disk I/O/device ceiling and per-stage full-run throughput are unmeasured; no ru_inblock conversion or additive I/O/CPU claim. File footprint, requested basket bytes, decoded declared bytes, wait4 maxRSS and sampled anon are distinct scopes, never conflated.

New material lane including final protection **484.282718559/650s**. Source/build/failed gate/reference/native/retests all counted.396 metadata total **147.807252277/180s**. Prior cumulative starts1118.750475411; current monitored total incl protection **1603.033193970/5400s**. Old919.292/1200 validation,159.473/180 prior metadata and24.023/60 readonly65 remain historical separate accepted ledgers, not overwritten/relabelled. The owner20:51 elapsed renewal is retained; idle/chat excluded, no attempt to fit the expired old wallclock. Generic raw runner prior_validation_seconds is a legacy label for the prior phase base in this lane; ledger.json supplies exact category meanings. Later still-unexecuted ABBA≤3000s/600s arm remains separate.

Resource supervision: one owned Julia/native group,16T/BLAS1,≤300s/process, metadata≤180s (second final recheck≤70s to keep combined180), anon64GiB sampled, free-disk floor64GiB, new output32GiB, durable60s resource records. No circuits fired; no load-only kill. Metadata final parser/group maxRSS includes mmap/shared pages and differs from anon; not summed. Remaining owned jobs0.

### Preserved failures

Original reference runner setup expected the NEW test in old429; that file correctly does not exist. Failure was before Popen/Julia/ROOT reads; command/source snapshot and references-setup-failure.json retained. Fixed optional baseline test snapshot only, did not add anything to baseline. references429 is the separately recorded successful launch. Initial all396 exit1 was394 eligible/two coalescing refusals, not corruption/resource/circuit; complete records and108.779s cost are retained. Final code/image/native and full396 were revalidated after the fix. No tests/results quietly replaced; first-round source/native artifacts remain.

## Final source/runtime and exact delta

| Bundle | Files | SHA256 |
| --- | --- | --- |
| Accepted before lane | 434 | cf6c0ced279786438ebbfee316fc809d055a1565531b7ac51071bb0cfc942216 |
| Accepted runtime before lane | 699 | eeaf73855a43d1ef312e64947a80956604c9145bf44a00d818753be4814940f8 |
| Final product source | 434 | 132b9f996156475c3c5c0fc4603a2770866951cce5c15b8ef7038ab81e1cc054 |
| Final runtime/test bundle | 699 | 29946914a15065e3d2ba039a2e9820f5f499d1c0a844cc2eda74fe75e220ab38 |

| Changed file versus archivedcf6c | Final SHA256 |
| --- | --- |
| src/IO/StreamWindowReader.jl | 000880230a3e42eab0233a130fdf4734fc33889511b60731b5e61a44f5f0d2fc |
| src/Selection/read_stream_selection_window.jl | cedd6a11acae22419c4d70579f77e48a43f526aa07fe9c37112143ea054424ba |
| test/stream_selection/runtests.jl | 5774250eaeb445337a0411ca7a408e60bfffcdd2a7a70cc920f6f756be883f8b |

Exactly THREE implementation/test files changed: IO reader/planner, Selection read-observer forwarding, focused tests. No Pipeline/global scheduler change in this lane; previous interrupted joins/ordinary fallback behavior preserved. No borrowed legacy adapter, original eager reader change, Config/canonical_hash/analysis config/downstream kernel/RDF/p11 edits, STATE overwrite, staging/commit/push or new dependency. New validation document only; all prior docs/proofs remain historical and immutable. Mac and gate match all434/699 records.

32 protection records pass: old5924 evidence, remediation2713 and readonly452 seals, old429/428 sources/runtimes/images, source/image archives, original/shared860 and old/new private842 dependency bytes, own844 image inventory, renderer keys/copies,58 old outputs, original114-file warm107GB seal and2508 D0 files,396 exact input stat identities/config pair. No input content-SHA scan.

## Review handoff

Gate L=/path/to/user/analisis/Cascade_dev/async-streaming/per-branch-maskability

L/{source-final.sha256,runtime-final.sha256,Mac-freeze.json,implementation-delta.json,implementation.delta.patch,verification-summary.json,protected.final.json,ledger.json}; archive-cf6c/ and round1-before-coalescing-fix/; cache-proof.json/images.before.json and per-operation imageguards; representatives.json/reference-summary.json/references/; representative-*-final-candidate-work.json/final-diagnostics.json; native-padded-final/ and native-summary-final.json; metadata396-final.jsonl/final-summary.json, both preserved first-gate files, metadata396_final_parallel.jl, config-pair-proof.json/resolved-candidate-streaming.toml, strict verify_streamed396.py; all command/log/samples/receipt/source/test snapshots. final-review.md mirrors this report; final-artifacts.sha256/completion.json seal the handoff.

**No remaining eligibility/native planner blocker in this phase. Required next step is independent CONCRETE final delta review. Only after parent acceptance may the fixed396-file107GB ordinary baseline429-vs-new-candidate ABBA run, with full scientific/Runs/histogram/counter/PNG crosscheck and396/396 route proof. No timings run yet; original throughput goal stays open.**
