# Async streaming selection: concrete implementation validation

2026-11-07, Mac-authoritative source and gate validation. **Implemented and tested; STOPPED for concrete parent review before any new107GB timing. No speedup claim.** Frozen final429 is the next benchmark baseline, not historical428. Existing107.392191402GB/396-file ABBA evidence is preserved and is not relabeled as a new streaming measurement.

## Implementation and invariants

Ordinary Pipeline.step_select now has an opt-in stage-global default-pool window scheduler. This is not reduced-export-only integration, @async-only CPU work, more permanent file workers, or a stage-DAG/fused-correction rewrite. Each file contributes exclusive READ jobs and ordered ANALYSIS continuations to shared Threads.@spawn :default workers. READ(k+1) can run while ANALYSIS(k) uses detached owned columns. At most nthreads−1 pool workers plus controller; no nested decoder/column-reader pools or file/thread binding.

Read jobs preserve precolumns → existing prefix_pass! mask → counter-derived canonical offsets → needed postcolumn basket projection. They never replace prefix projection with eager all-post EventWindowSource reads. Common boundaries across required pre/counter/post branches are coalesced near the configured event target, so adjacent windows do not split/redecode a basket. The event setting is a coalescing target, not a strict maximum: actual common-cluster boundaries and byte guards determine range size.

READ alone accesses each ROOTFile, LazyBranch and reader diagnostic state. Consumer payload is raw owned primitive Vector/Jagged buffers, window range and mask only; no ROOT/source/cache/window-source escapes into analysis. Canonical malformed offset sizes are rejected before allocation. Header/basket/tree bounds and normal UnROOT decoding remain; no artifact integrity step is omitted. Existing EventWindowSource/reduced-export contracts remain unchanged.

One analysis continuation per file updates a persistent original-event-order Cutflow. No floating window subtotal merge/replay. Append rows in window order, restore checked original Int64 entries, recompute final region sums over the entire ordered retained table, preserve ordinary metadata/schema and per-file .cols/meta publication. Skim/Runs normalization and downstream correction/histogram/merge/systematics/fit/plot APIs are unchanged. No global correction-cache reset runs while this pool is inflight.

### Credits, error and lifetime model

File metadata is reserved before opening; window count/byte reservations cover queued, running and completed-not-consumed payloads through analysis completion. Two live windows/file, bounded active files, global queue and separately guarded retained whole-file output estimates. Reservations include all potential projected branches, offsets/masks/context/growth allowance, selected-window output and one basket scratch workspace. They are conservative accounted payload estimates, **not measured RSS or allocator bounds**; an external sampled64GiB RssAnon guard remains. Mapped input-file length is not incorrectly charged as heap metadata.

Global supervision reuses the audited worker lifecycle/control path, with independent fatal/cancel notification, explicit created-task tracking and protected startup. Failed file payloads are discarded only after its jobs settle; completed other-file checkpoints survive. A lower-entry analysis failure wins over an earlier-arriving higher-window read failure. Controller/interrupt primary errors are not masked by cleanup. Global failure joins all created tasks before closing remaining sources; ordinary per-file publication/close occurs only after that file’s callbacks settle. Result envelopes are cleared before credit reuse. No asynchronous native interruption is used in tests.

### Config, defaults, fallback and cache identity

Default false preserves the existing eager path; one-thread execution explicitly falls back, and two-thread execution has insufficient room for two concurrent pool jobs and falls back with stage_thread_budget. Initial validated scope: nominal builtin local mmap NanoAOD, regular primitive top-level TTree branches and common basket boundaries. Registry replacements/custom hooks, other formats/reduced inputs, shape/theory/weight-variation paths return explicit existing-path fallbacks before window admission. Unsupported branch/layout planning also returns a reason; corruption/resource/drift errors are not silently retried or downgraded. Layouts beyond the six standard Events files were not natively surveyed.

~~~toml
[execution]
streaming_selection = true       # opt-in; default false
decode_threads = 1
column_readers = 1
stream_window_events = 20000    # common-boundary coalescing target
stream_active_files = 16
stream_queue_windows = 32
stream_queue_bytes = 8589934592
stream_window_bytes = 67108864
stream_basket_bytes = 67108864
stream_metadata_bytes = 67108864
stream_retained_bytes = 8589934592
~~~

All fields are validated, including inactive profiles and inherited engine conflicts. Execution switches/budgets stay outside scientific section hashes; full raw config/batch configuration still sees them. Existing Config/IO/Objects/Selection code hashing is retained and explicit hashes of run_window_pipeline.jl and stream_selection.jl are added to selection identity, ensuring natural invalidation for the new scheduler without weakening old hashes.

## Actual input/workload and metadata feasibility

**Six unique original files, 3,018,888,095B = 3.018888095GB = 2.811558633GiB, 5,029,882 input events and 48,717 retained rows per complete six-file selection pass.** These are two frozen small controls plus largest selected Muon/DY/TT/MuonEG files, not a new100GB dataset. Repeated validation passes are not counted as unique input volume.

| # / sample | ROOT basename (full paths in evidence) | Bytes | Events | Kept | Baseline selected signed Runs sum |
| --- | --- | --- | --- | --- | --- |
| 1 | TTto2L2Nu / 66b834d6-61f7-4109-b5ae-54a150d4814b.root | 36001081 | 32853 | 1493 | 2646014.7375000003 |
| 2 | MuonEG / 6c474b9d-4e5c-44ea-b95a-45d21840ea4b.root | 57246031 | 104057 | 45 | missing / unused for data |
| 3 | Muon / b4af60fc-c19f-482a-b99d-f20243810efe.root | 755554385 | 1801077 | 8 | missing / unused for data |
| 4 | DYto2L_MLL50 / 777c4262-6efe-4958-bcfb-faaea6c2230a.root | 535747317 | 1109639 | 27 | 19779047362.9 |
| 5 | TTto2L2Nu / 0a6532d4-23e1-4a51-b815-7fc1c3fa22ae.root | 1097078499 | 1006560 | 46694 | 80963103.62959999 |
| 6 | MuonEG / b739604e-dbba-4cdb-9292-9830df150e0c.root | 537260782 | 975696 | 450 | missing / unused for data |

Cached429 reference generation read the original source once per file for nominal selection and original normalization metadata. Native tests execute ordinary step_select with unchanged frozen skim-signature fixtures, fresh forced workdirs and per-file normal artifacts. SF/eμ/ge1j/njet configuration is retained, but **this phase executes selection, not SF correction/histogram/PNG**. Denominators are recorded references and existing skim evidence is unchanged; new full seven-stage normalization/output parity remains a later gate.

| Sample / events | Required branches | Common cluster windows | Max cluster events | Max aggregate declared decoded B / cluster |
| --- | --- | --- | --- | --- |
| TTto2L2Nu / 32853 | 24 | 10 | 3765 | 794319 |
| MuonEG / 104057 | 23 | 18 | 6294 | 1266860 |
| Muon / 1801077 | 24 | 213 | 8534 | 1460181 |
| DYto2L_MLL50 / 1109639 | 24 | 195 | 5723 | 882123 |
| TTto2L2Nu / 1006560 | 24 | 270 | 3747 | 798259 |
| MuonEG / 975696 | 23 | 149 | 6620 | 1408275 |

Metadata-only probe exited0: 15.962700357s, no Events basket decompression/full payload scan; fixed ROOT/basket headers can page-in containing metadata pages. No input full-SHA prescan, cache flush/fadvise/drop or host tuning.855 common cluster windows coalesce to209 selection windows over six files at the default target. Eligibility/charges for the other390 files are not asserted from this probe.

### Explicit decoded/skipped selection basket work

| Phase | Decoded baskets | Decoded packed B incl key | Decoded compressed payload B | Decoded declared B | Skipped baskets | Skipped packed B incl key | Skipped compressed payload B | Skipped declared B |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pre | 4108 | 2424946 | 2030756 | 47801793 | 0 | 0 | 0 | 0 |
| counter | 2565 | 5566384 | 5374009 | 60358584 | 0 | 0 | 0 | 0 |
| post | 14619 | 184121829 | 182944512 | 489280066 | 8175 | 112073723 | 111417705 | 295483038 |

Each4T/16T ordinary pass matches these independently derived whole-file429 counts exactly, including prefix events/pass counts. All six files report zero repeated decoded baskets in ordinary passes. The extra mask/ownership fixture deliberately rereads small windows and is not included in this per-pass table. Counters cover selected Events branches only; ROOT metadata/header staging, Runs, checkpoints, and monitor traffic are excluded. Declared decoded bytes include basket bookkeeping/offset tables. These are requested basket-work counters, **not file footprint or physical disk I/O**.

## Final frozen-image correctness gates

| Gate | Actual exit | Pass count | Scope |
| --- | --- | --- | --- |
| focused-canary-final16 | 0 | 463 | Config/profiles, scheduler bounds/lifecycle/errors, SAME-FILE barrier, ordered sums, atomic checkpoint and fallback cases |
| focused-canary-final1 | 0 | 130 | Serial config/science/decisive float/empty and one-window checks |
| native-final1 | 0 | 134 | Six ordinary selection outputs; explicit one-thread fallback |
| native-final4 | 0 | 257 | Six streamed ordinary outputs plus exact basket work and settled credits |
| native-final16 | 0 | 130 + 771 | 130 real snapshot/mask/counter/oversize checks; three repeated six-file ordinary parity passes |

Counts are overlapping test scopes, not a sum of unique scientific cases. Native checks compare retained entry/order, column types and every stored bit, cutflow/regions and all scientific EventTable metadata against actual cached429 references. Skim-signature fixture bytes stay unchanged; all native select callbacks run, no artifact reuse. Real owned-buffer tests prove vectors are outside the input mmap, snapshots do not alias across windows and no source escapes; all-false/all-true/odd/reversed masks, duplicate branch requests, bad offsets and oversize admission are covered.

The strengthened float test explicitly demonstrates the prohibited subtotal result: original sequential [1e16,1,−1e16,3,−2] sums to1, whereas contiguous window subtotals (1:2,3:5) merge to2. Persistent analysis matches original bits under that and other partitions, including empty and one-window populations.

### Actual same-file overlap and resource accounting

| Final pass | Created pool workers | Peak active workers | Peak windows | Queue/accounted bytes highwater | Read(k+1)/analysis(k) overlap s |
| --- | --- | --- | --- | --- | --- |
| 4T | 3 | 3 | 12 | 2979603544 | 0.533747838 |
| 16T repeat1 | 15 | 11 | 12 | 2979603544 | 4.751781249 |
| 16T repeat2 | 15 | 11 | 11 | 2747956001 | 4.028743359 |
| 16T repeat3 | 15 | 10 | 10 | 2502791186 | 2.690251904 |

Overlap is the sum of per-file neighboring read/analysis interval intersections, not elapsed time saved, physical I/O overlap attribution, CPU utilization or throughput. The synthetic barrier specifically requires read-next and analysis-current for the SAME file, not merely independent files. Every streamed pass completes6 files/209 windows, reserves/releases209 credits and46,083,802,187 cumulative reservation-bytes, with final active workers/windows/live/retained credits0. Cumulative reservation bytes are not simultaneously resident bytes. Maximum six active files here; configured bound16.

## Actual operation costs, not a performance comparison

| Operation | Exit | External wall s | CPU user / sys s | wait4 maxRSS KiB | Peak sampled group anon B | Monitor CPU s |
| --- | --- | --- | --- | --- | --- | --- |
| focused01 | 1 | 7.411161760 | 8.633959 / 0.563279 | 646324 | 385536000 | 0.029405 |
| focused02 | 1 | 28.666724928 | 31.490001 / 0.902809 | 756368 | 472887296 | 0.124104 |
| focused03 | 0 | 39.079017021 | 41.819090 / 0.983337 | 752684 | 521396224 | 1.626933 |
| references01 | 0 | 40.676797911 | 52.977421 / 1.696848 | 2134420 | 1272819712 | 1.977529 |
| native1T01 | 0 | 63.672761588 | 61.791231 / 1.332683 | 1743964 | 1250689024 | 3.365173 |
| native4T01 | 0 | 68.639324802 | 107.305441 / 3.139091 | 2320164 | 1076314112 | 4.238459 |
| focused04 | 0 | 48.532197652 | 52.198460 / 0.992589 | 904000 | 602025984 | 3.553333 |
| build01 | 0 | 19.681634608 | 27.160869 / 1.264463 | 851592 | 678408192 | 0.144913 |
| focused-final16 | 0 | 43.954709127 | 47.857813 / 1.169294 | 873252 | 574423040 | 0.320718 |
| focused-final1 | 0 | 27.803159981 | 26.793173 / 0.657422 | 731160 | 491524096 | 0.157521 |
| native-final1 | 0 | 56.316199519 | 54.713596 / 1.193504 | 1769168 | 1305862144 | 0.348594 |
| native-final4 | 0 | 63.364612136 | 100.654518 / 3.506423 | 2294244 | 922259456 | 0.457093 |
| native-final16 | 0 | 122.155234553 | 325.193322 / 11.291969 | 3159700 | 1323442176 | 1.313441 |
| focused-canary-final16 | 0 | 45.098507349 | 48.418357 / 1.272143 | 848380 | 570216448 | 0.534144 |
| focused-canary-final1 | 0 | 26.877332093 | 25.983050 / 0.614243 | 728780 | 489746432 | 0.289867 |

External operation clocks cover Popen→blocking wait4, package/source load, runtime kernel compilation, tests, native selection and assertions/publication as applicable. Different passes/repeats/threads and observer scope make these **unmatched correctness costs, not baseline/candidate performance arms**. GC is UNKNOWN. wait4 CPU/maxRSS and sampled group RssAnon are distinct scopes, not added. Initial runner scanned immutable validation snapshots when guarding output size; later runner scopes that scan to scientific output dirs, reducing observer cost. Old logs/runner versions and all failed attempts remain.

Every process used pinned Julia1.12.2, BLAS1, one owned session/group at a time, default pool ≤16T, compiled-modules=existing, pkgimages enabled, offline/private depot and no automatic precompile. Per-operation300s, sampled64GiB anon, filesystem free floor64GiB, conservative cumulative native-output32GiB cap,60s durable resource receipts. No circuits fired; no load-average-only kill. Full raw load-before/after and1Hz process/resource/context samples are in each command/receipt/samples file. Exact device/tree I/O bytes and I/O wait are UNKNOWN; no ru_inblock conversion, disk-bandwidth/ceiling claim or additive I/O/CPU attribution.

Validation operations total **701.929375028/1200s**, including failed/development gates. Final protection verification adds 9.115924508s, combined **711.045299536/1200s**. Metadata separately 15.962700357/120s. Overall elapsed phase at protection checkpoint 2222.367/5400s. No owned Julia jobs remain.

### Failure history and corrections

focused01 exit1: ambiguous IO module name during source load, before any scientific input. Fixed explicit EventIO aliases. focused02 exit1:111 tests passed then empty-stage sum reducer errored; fixed identity/init handling. Subsequent source gates passed; later resource/error-order refinements and test-only decisive canary are separately snapshotted. Native scientific gates did not fail. A build-preparation JavaScript submission had a quoting syntax error before dispatch; corrected submission built once. Read-only shell searches also had quoting/glob/regex errors, with required files read directly afterward. Progress-message typo150 for final1T native assertions is corrected to actual134 here. No failures or old test counts are silently replaced.

## Frozen source/cache identities and exact delta

| Record | Count / SHA256 |
| --- | --- |
| Accepted old source | 429 /3141e2d86aed04444a2e174827db7e9f3f680121b63fd590c8556788ae4989a9 |
| Accepted old runtime | 693 /ec45bc7e6bfd30c3551ec221741d604a3e82d588aaa8fc2bab051b9deb66c3c5 |
| Final product source | 434 /53c4c0ac2f7d6bbbcecc6c540737fba9300243e30fe2d769a65af46be1b34046 |
| Final runtime/test bundle | 699 /a8942b73186d12b9eff856e3d9044e28ce3a3a5ef5dd87a64b4686269d83bdf7 |

Mac and gate match every listed record. Runtime699 is the original693 scope plus five new production source files and one test file; Project/Manifest are additionally protected under their existing environment contracts. Earlier665 subset and before-canary699 manifests are retained as historical scopes, not claimed as the final bundle. Only the test changed after the native matrix; source434 and its image stayed identical, and final focused gates were rerun at1T/16T.

| Changed file versus final429 | Final SHA256 |
| --- | --- |
| src/Config/Config.jl | cfa2e71f7fbb47d5959a22f9545364232fdd4ec3f3cb9233543eefd2005d9fa7 |
| src/Config/streaming_selection_options.jl | 6fa0c75e9dd8968729574f1a155a1cc8753d76fbe75ea2e717e3a369ee5b2226 |
| src/Config/validate_keys.jl | d8fec25475c6729cb6221fb967d92b9b1332dfbe3915562ec4e44c3ced8619a6 |
| src/IO/IO.jl | f27bd5b9200d90f2876f7d769ee77aac02dee92c9f3f471069e489e1d6bd8bde |
| src/IO/StreamWindowReader.jl | 297b187e96d63f6fd991b7e88f7e2391e0fcbe5fa67e52c9f979e0c73eca6bec |
| src/Pipeline/Pipeline.jl | 0352909a26e36fa77997f11bd03ccef3617200e249828609b09c6b073b7c83f9 |
| src/Pipeline/run_window_pipeline.jl | 4c6ab4c131475fbde0253d8cd51ed54596ff550bbc961eb1cb914b58f792c978 |
| src/Pipeline/step_select.jl | 3e0f93f42fc470efb323837b526c5a53da2169f78081a043bc155e6b3c2e60c5 |
| src/Pipeline/stream_selection.jl | 67557ec1d743bb2e6b92818b10428d5d50384f28704a11c25651380734b7363b |
| src/Selection/Selection.jl | ffa31dc699f9ee7650a581f0ae50497b73b749b42d57d96bca5db07fcf797e46 |
| src/Selection/read_stream_selection_window.jl | 2b7fd29d52b98518ec6cd0df7ddca2627902d22a66ea530defe457e242790f4d |
| test/stream_selection/runtests.jl | 417e0eeed3c906531811b48881099183ebb783ffda2c9c76d01dcac3654a4a42 |

Twelve-file implementation/test delta: six existing wiring/config/stage files, five new production sources, one new focused test. No original analysis config, dependency, existing runtime kernel, downstream stage implementation, RDF plan or p11 edits. New report only; no rewrite of historical validation docs/state, stage/commit/push or installs. Exact old/new digests and patch: evidence/implementation-delta.json and implementation.delta.patch.

### New candidate image, target-only build cost

Private existing absolute source/project/depot paths are used; no blind package-cache relocation.842 dependency images and existing native-backends were independently copied (no hardlinks), with only the allowed pinned Juliaup tree symlink. All six external dependency eligibility checks passed. Only Cascade was compilecached, with existing-dependency mode; dependency bytes/inventory stayed unchanged. Build had no scientific input; inherited precompile workload is bounded generating-output-only synthetic work.

Cache: /path/to/user/analisis/Cascade_dev/async-streaming/candidate/depot/compiled/v1.12/Cascade/Ye57P_ImX46.ji

Build-ID:0xfafbfcfd2f2bbc16fed046ab378777c8

Ye57P_ImX46.so: 11937752B; SHA256 54c138cfd152b903b5b52ea3a22955d52d0fe52420567a63d07462c32bf16561

Ye57P_ImX46.ji: 871550B; SHA256 a319f2720681d98f7e68dcfcbfaca9496dcc57839011afbd83228be6ed118913

Compilecache wall18.082036549s; supervised build19.681634608s; CPU27.160869user +1.264463sys; image871550ji +11937752so =12809302B. These are separate build costs, not ordinary-analysis time or an amortization/speedup claim. Every final fresh process proves own cache/source/project/build-ID and flags; selected .ji mtime touched, ji/so bytes unchanged and no new compiled files after build. Exact mtime/SHA checks: newcache-images.before/final.json and per-operation .imageguards.json.

ROOTPlots renderer key remains d8bac7fa45eb66293877d6362a615a748e3e20c3ac2bdd044623d920e1485b0b, executable171112B SHA2566a056492dd51b377ad8b75be78fbda3b56c9b6c8ed7db651ed7344029406bfd9. Independent new private scratch copy has identical key inventory/bytes/mtime, no compile-* or new keys. Renderer was NOT executed by these selection-only native gates; its full nativePNG use is reserved for the later ordinary benchmark.

## Protection proof and next review gate

24 final protection records pass: original sharedcache860; old private dependency842 each and new842; old428/429 source/runtime/images; original env/native/dependencies;58 old outputs; all2508 frozenD0 files/helpers/evidence; sealed114-file old warm107GB evidence; all396 input dev/inode/size/mtime_ns/ctime_ns identities (107392191402B); new source434/runtime699 and cache inventory844; original/private/new renderer identities and exact keys. Old native-input content hashes were not rescanned: unchanged stat/ctime predates their frozen verified hash record; this trust scope is explicit in protected-native-stat.json. No full selected-input SHA scan was performed.

Required next step: concrete review of this frozen implementation/proof. Only after parent acceptance, prepare a NEW external candidate workload differing from frozen resolved-workload-D0.toml solely by execution.streaming_selection=true/budget settings; baseline429 keeps its supported original execution config. Freeze physics-section and396-membership equivalence. Then authorize the fixed full ordinary107GB baseline429-vs-candidate434 ABBA with matching16T/BLAS1, fresh workdirs, same-scope lightweight I/O clocks, nativePNG and full scientific crossmatch. **No such timing has run in this phase; the broad throughput goal remains open.**

## Evidence

Gate root B = /path/to/user/analisis/Cascade_dev/async-streaming

B/evidence/{source-final.sha256,runtime-final.sha256,Mac-freeze-final.json,implementation-delta.json,implementation.delta.patch,validation-summary.json,protected.final.json,new-native-output-inventory.json}; metadata-probe.json/probe-files.json/large-metadata-files.json; reference-summary.json and B/references/*.cols/*.basket-work.json; cache-proof.json and newcache-images.before/final.json.

For every operation: B/<name>.command.json, .log, .samples.jsonl, optional .progress.json, .receipt.json and final cached .imageguards.json. B/evidence/attempts/<name> captures exact source snapshot and invocation script. B/native-1T-final-1, native-4T-final-1 and native-16T-final-{1,2,3} are fresh native outputs. B/native_snapshot_checks.jl contains real ownership/mask checks; cached_guard.jl and native_cached.jl bind actual image and ordinary entry. B/protection-final.log/.receipt.json show bounded final read-only verification. final-review.md mirrors this document; final-artifacts.sha256 plus completion.json seal the final handoff.
