# Async streaming 107 GB matched ordinary-production validation

## Status and decision

**COMPOSITE COMPLETED: all four valid ordinary arms,48,189/48,189 stored scientific assertions and five fully decoded/nonblank byte-identical PNGs, plus a newly approved protection-only closure. The original full driver remains failed; no old receipt was reset or forged. No native/science/PNG rerun was used to complete the composite.**

The fixed ABBA comparison is negative for latency: the streaming candidate is slower on this workload. Do not enable streaming by default or claim a faster reader. No posthoc product tuning, rebuild or rerun was performed. This final report combines existing successes with the new protection-only completion; it does not pretend that the original driver succeeded. The immutable provisional snapshot remains failure-handoff/report.md, SHA2564ed6bc61187a70183ecdb8c58d7bc723743c9776e3cf6ee16448c8f077532c61.

The accepted source434/runtime699/private image remain unchanged. No STATE file, frozen evidence, config, existing control script, cache image bytes or dependency was modified. No commit/push/install/resolve/RDF/p11/full3307/cache-flush/fadvise occurred. The earlier final Cascade-only build18.239s is separate from the ordinary timings.

## Workload, frozen controls and conditions

Unique input: **107,392,191,402 bytes = 107.392191402 GB = 100.016772190 GiB**,396 distinct files,233,876,675 events,13 samples;522,713 selected rows per arm. Technical subset, configured1210pb^-1, not full-exposure physics. All seven stages were forced into separate fresh workdirs, no checkpoint reuse.

Baseline is the NEW frozen final429, not historical428: precompile-selection/candidate project+depot, source3141e2d86aed04444a2e174827db7e9f3f680121b63fd590c8556788ae4989a9, runtimeec45bc7e6bfd30c3551ec221741d604a3e82d588aaa8fc2bab051b9deb66c3c5, VUXtU cache/buildfafbfcfde45c9ea78fadedc96684d43e. Candidate is async-streaming/candidate, source132b9f996156475c3c5c0fc4603a2770866951cce5c15b8ef7038ab81e1cc054, runtime29946914a15065e3d2ba039a2e9820f5f499d1c0a844cc2eda74fe75e220ab38, ImX46/buildfafbfcfda12c3b300be782f2deb22fe6.

Baseline config SHA256:3d9edf320ca37915f211f895f32a4d59cd0008f794cc52660b999be2fb9decf1. Candidate:4bde75eef2def760f34d7471724ef4747769e12f9b1a6b3e94893e618a4c3a15. Only execution differs, accepted semantic nonexecution hash419e9b6e1d6b87685cf38fa226662371e302a63ff4ea929e2ea0c5644867d93e. Manifest:bcc3f8048d8beb95994649dd91e66a68c01110746e9ef57556456883cad73c9b.

One owned native process group at a time,16 Julia threads/BLAS1, same exclusive operator lock. Frozen .ji/.so SHA/size/build/source/depot guards passed each arm; selected ji was touched without changed bytes or new compiled files. Renderer keyd8bac7fa45eb66293877d6362a615a748e3e20c3ac2bdd044623d920e1485b0b was consumed from independent private copies with unchanged keys/bytes/mtime. Julia version1.12.2, existing compiled modules/pkgimages, offline/no automatic precompilation. All396 input dev/inode/size/mtime/ctime identities passed pre/post and handoff checks; no input content SHA was performed.

Fincore was exactly60,921,618,432 resident bytes/107,392,191,402 bytes (56.728164%) before and after every arm, with4 fully resident files. This is observed page-residency metadata, **not a cold/first-touch or fully warm claim**. No cache eviction/warming was requested. D0 first-touch evidence is a separate frozen scientific reference, not an observation in the timing mean. Host load is retained as context in raw receipts, not a health criterion or causal explanation.

## Exact commands and outcomes

Reviewed commands executed once, sequentially, stopping at the first failed driver:

~~~sh
python3 run_arm.py --execute-authorized A1-baseline429 baseline
python3 run_arm.py --execute-authorized B1-streaming candidate
python3 run_arm.py --execute-authorized B2-streaming candidate
python3 run_arm.py --execute-authorized A2-baseline429 baseline
python3 cross_driver.py --execute-authorized
# summarize.py was NOT reached because the driver exited1.
~~~

The first four subjects exit0/postflight valid. Julia crossverification exits0; the outer protection driver exits1. The reviewed scripts and23-file preparation seal were not edited to bypass the failure. No failed receipt, pending journal or operation was reset/retried.

## Ordinary wall and stages

Monotonic native wall is immediately before Popen through root wait4, including public-main startup, all seven stages, native PNG, checkpoints/index publication. Untimed guards/fincore/postchecks are outside that native wall but inside durable operation budgets. Two observations per arm are descriptive only, not a universal/stable performance conclusion.

| Order | Arm | Native wall s | Full operation s | Main boundary s | Exit/postflight |
|---|---|---:|---:|---:|---|
|A1-baseline429|baseline|157.450497209|171.101031104|154.028001707|0/valid|
|B1-streaming|candidate|455.354149623|468.893666507|452.085136575|0/valid|
|B2-streaming|candidate|475.804602392|490.074050364|472.127402502|0/valid|
|A2-baseline429|baseline|167.181292605|180.990949237|163.437355223|0/valid|

Baseline mean **162.315894907s**, spread9.730795396s; candidate mean **465.579376007s**, spread20.450452769s. Candidate/baseline mean ratio **2.868354**, or **+186.835% wall**. Mean total delta303.263481100s.

|Stage/purpose|A1 s|B1 s|B2 s|A2 s|Baseline mean s|Candidate mean s|Delta s|Baseline share %|Candidate share %|
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|skim: input metadata/Runs/inventory|7.96|8.47|8.43|8.73|8.345|8.450|+0.105|5.141|1.815|
|select: selection/materialization/cutflow/publication|67.99|364.87|378.11|71.47|69.730|371.490|+301.760|42.959|79.791|
|correct: correction weights/columns|15.72|14.76|15.59|15.75|15.735|15.175|-0.560|9.694|3.259|
|histogram: per-file histograms and sumw2|2.49|2.47|2.69|2.54|2.515|2.580|+0.065|1.549|0.554|
|merge: normalization/sample and total aggregation|5.59|5.75|6.43|6.12|5.855|6.090|+0.235|3.607|1.308|
|systematics: nominal/template publication|1.14|1.33|1.21|1.22|1.180|1.270|+0.090|0.727|0.273|
|plot: transport/native renderer/PNG/index|26.83|27.60|28.81|28.53|27.680|28.205|+0.525|17.053|6.058|
|Unattributed residual|29.730497|30.104150|34.534602|32.821293|31.275895|32.319376|+1.043481|19.269|6.942|
|Total|157.450497|455.354150|475.804602|167.181293|162.315895|465.579376|+303.263481|100|100|

Most of the observed wall delta is in select (+301.760s mean). This localizes the regression but does not identify its cause. No profile, tuning or compensating arm was run.

### Observed timeline and residual uncertainty

|Arm|Cache proof s|Public-main entry marker s|Analysis banner s|Public-main return marker s|Residual s|
|---|---:|---:|---:|---:|---:|
|A1-baseline429|2.620845|3.415460|29.435223|157.155670|29.730497|
|B1-streaming|2.469140|3.237678|29.751166|455.002619|30.104150|
|B2-streaming|2.822258|3.678783|34.200073|475.472605|34.534602|
|A2-baseline429|2.748655|3.576462|32.368696|166.740703|32.821293|

Marker/stdout observation includes scheduler/pipe latency and marker overhead; stage clocks are printed rounded internal clocks. The difference between external wall and stage-clock sum includes startup/config/compilation/dispatch/publication not attributed by those clocks. It is **not pure JIT**; GC was not separately recorded. Stage IO samples remain raw, approximate and non-additive.

## Real streaming route, work and pool observations

Both candidate arms have396/396 source/sample-exact streaming selection metas,9580 windows,331 exact-index files and65 per-branch-maskability files with1378 padded branches; no old file-worker/fallback route. Expected modes, padded branch sets/counts/windows and unchanged raw indices matched the final source-bound396 plan. Baseline has396 serial_requested,stage_file_workers16 records and no stream summary.

Candidate basket and prefix counts/bytes are exactly equal between B1 and B2:

|Phase/action|Baskets|Compressed bytes incl keys|Compressed payload bytes|Declared decoded bytes|
|---|---:|---:|---:|---:|
|pre decoded|159,487|82,706,335|67,577,945|2,438,881,684|
|counter decoded|96,018|233,400,018|226,198,668|2,806,520,100|
|post decoded|387,550|4,523,909,198|4,492,738,049|12,611,577,744|
|post skipped|563,250|7,620,901,662|7,575,699,320|21,054,256,398|

Unique decoded baskets643,055, repeated0. Padded decoded subset4,987 baskets/32,450,121 compressed bytes/95,045,136 declared bytes (subset, not additional to the phase totals). Prefix233,876,675 events,32,548,847 pass. Maximum observed owned raw window9,277,575 bytes. The per-branch padded compatibility path is explicitly not prefix-optimized; regular siblings remain masked.

These are logical reader counters, not disk traffic. Original baseline429 ordinary metadata does not expose matching phase basket counters, so full396 baseline-vs-candidate basket-set equality is **not established by this run**. The earlier three-representative665-record exact original-reader work/bit comparison remains preserved, not rerun. No speed claim is made from changed work.

|Pool/interval observation|B1|B2|
|---|---:|---:|
|created_workers|15|15|
|max_active_workers|15|15|
|active_files_highwater|16|16|
|queue_windows_highwater|32|32|
|queue_bytes_highwater|8563936100|8564281880|
|retained_bytes_highwater|237686400|237948024|
|credits_reserved|9580|9580|
|credits_released|9580|9580|
|bytes_reserved|2113860848405|2113860848405|
|bytes_released|2113860848405|2113860848405|
|completed_files|396|396|
|read_job_seconds|3681.3684641179975|3808.0578544479986|
|analysis_job_seconds|93.39010429500004|90.23192917000002|
|same_file_read_analysis_overlap_seconds|28.682861205000005|26.344659226999987|
|files_with_positive_same_file_overlap|328|328|

Both pools report joined workers, zero cleanup errors, balanced9580 credits and2,113,860,848,405 cumulative reserved/released bytes, and zero final live/retained/active/windows. Highwater max_active15 is an instantaneous observation, **not generic saturation or15 fully busy cores throughout**. Same-file overlap is a sum of interval intersections across328 files, not saved wall or independent CPU time. Read/analysis job durations are cumulative concurrent intervals and cannot be added to infer wall. Conservative reservation bytes are not actual RSS.

## CPU, memory, outputs and IO scope

|Arm|CPU user s|CPU sys s|Sampled max group anon GiB|Sampled max group RSS GiB|Monitor CPU s|Output bytes|
|---|---:|---:|---:|---:|---:|---:|
|A1-baseline429|946.770665|28.399478|6.905525|8.752872|3.014248|40,293,005|
|B1-streaming|3125.219838|183.335405|1.856293|6.386967|22.825753|40,816,577|
|B2-streaming|3186.521278|185.129607|1.799854|6.412617|42.726449|40,816,456|
|A2-baseline429|964.815779|33.338302|7.027863|9.008419|21.839824|40,293,037|

Candidate peak sampled anonymous memory is lower in these observations, while CPU cost and selection latency are higher. mmap/file-backed pages are distinguished from anonymous memory; group RSS is not claimed bounded by raw credits. Global new output at A2 postflight173,043,787 bytes, far below32GiB; exact final sealed inventory will include subsequent reports/logs as well. No guard circuit fired. No physical-device IO ceiling claim follows.

|Arm|Main-window root rchar|Main-window root read_bytes|Main-window root write_bytes|Main-window root wchar|
|---|---:|---:|---:|---:|
|A1-baseline429|85,072,301|0|48,558,080|44,042,459|
|B1-streaming|111,930,685|0|48,558,080|45,677,393|
|B2-streaming|111,574,577|0|48,562,176|45,675,981|
|A2-baseline429|85,072,350|0|48,558,080|43,926,571|

All read_bytes deltas are zero in this kernel accounting scope; that is **not proof of zero physical-device traffic**. rchar omits mmap accesses, kernel write_bytes is dirtying rather than device writeback, and waited-child counters may roll into root accounting. Raw receipts retain live/zombie root snapshots and separately labeled adopted terminal domains; they are not naively summed. Exact final whole-tree/device bytes and device IOwait are unknown. Dataset107.392GB divided by wall is a footprint work rate, not disk bandwidth. Main-window counters share the measured public-main boundary, not full external wall. Stage windows have1Hz/stdout/reap uncertainty and overlapping brackets.

## Scientific/PNG verification actually completed

Julia crossverification exit0:48,189/48,189 assertions,40.314611218s external (21.9s printed testset). All four arms were compared against frozen D0 for exact typed selected/corrected columns, names/order/global entries, metadata/science fields, cutflow, skim/Runs/gen sums and luminosity normalization, histogram edges/sumw/sumw2, merge, yields, systematics templates and native plotting transport. Science metadata exclusions stayed exactly key/created_unix/execution. Natural selection keys satisfied A1=A2=D0;B1=B2!=D0 for all396 files. This does not imply byte identity for execution metadata files, whose sizes naturally differ.

All five native PNGs (D0 and four arms) were fully decoded/nonblank,596x692 RGB,49 distinct pixels; SHA256f113ea0f6657ce4e9582601c724ec7dacb883652a0dae65b6c2b711d08221fca, byte-identical. These stored successful checks were reused by the approved composite closure without another Julia/science/PNG execution.

## Historical blocker, durable failure and approved resolution

The outer cross_driver stopped AFTER science/PNG/cache+input postchecks, while traversing historical protection manifests. Its SHA guard correctly forbids reading input ROOT contents. Historical basket-decode/evidence/native.before contains two such entries, incompatible with that new no-input-content-SHA guard.

- Manifest /path/to/user/analisis/Cascade_dev/basket-decode/evidence/native.before, line1: /path/to/user/nano_slim/mc/Run3Summer22NanoAODv12/TTto2L2Nu_TuneCP5_13p6TeV_powheg-pythia8/NANOAODSIM/130X_mcRun3_2022_realistic_v5-v2/2520000/66b834d6-61f7-4109-b5ae-54a150d4814b.root (36,001,081 bytes). Identified by path/stat only; not hashed.
- Manifest /path/to/user/analisis/Cascade_dev/basket-decode/evidence/native.before, line2: /path/to/user/nano_slim/data/Run2022C/MuonEG/NANOAOD/22Sep2023-v1/2520000/6c474b9d-4e5c-44ea-b95a-45d21840ea4b.root (57,246,031 bytes). Identified by path/stat only; not hashed.

The first entry triggers AssertionError:input content SHA forbidden in cross_driver.py sha(), before any protected ROOT content is opened. This is a harness protection-policy mismatch, not a reported scientific mismatch or ROOT corruption. At that historical stop, later protections/output-inventory publication were incomplete. The approved separate protection-only controller has now completed them under the explicit two-input trusted-stat policy below. The original driver is still not labeled successful. crossverify.operation.json remains complete:false,57.466080688s charged; crossverify.julia.receipt.json remains exit0. There is no pending journal, no owned Julia job, no full crossverify.receipt.json, and summarize.py was not run.

Parent review912e19f9 approved the narrowly corrected protection-only closure and explicitly authorized its execution. That closure completed successfully, preserving the failed operation/all costs and reusing stored science/PNG successes. No ordinary/Julia/science/renderer/PNG/metadata rerun or performance tuning occurred; general corruption/resource/SHA guards were not weakened. The two stat substitutions are explicitly weaker than content-SHA revalidation, not silent omissions.

## Ledger, protection and evidence

Four native walls total1255.790541829s. Four full arm operations total1311.059697212s. Failed full verification operation57.466080688s includes successful Julia40.314611218s; not counted twice. Warm operations total1368.525777900/3000s. Cumulative phase through failed verification3035.693482143/5400s, starting1667.167704243 (including prep63.362478080s, of which40s was explicitly conservative rather than measured). Failure inspection adds its new collection receipt plus an explicit conservative coordination charge; final seal receipt gives the updated total. Old919.292/159.473/24.023 ledgers and the20:51 elapsed-guard renewal are historical, not reset/relabelled. Idle/chat time is excluded.

The handoff collector rechecked current frozen source/runtime/image bytes, both compiled inventories, renderer keys/bytes/mtime/independent copies, both configs/manifest and all396 input stat/ctime identities without another Julia process. The five original harness files and23-file prep seal remain byte-identical. Prior5739-product evidence and all frozen outputs remain untouched; the old full-driver sweep remains historically incomplete, while the new protection-only sweep and composite summary are complete.

Evidence root:/path/to/user/analisis/Cascade_dev/async-streaming/warm-production-controls. Raw per-arm command/environment, stdout/timeline, resource samples, progress, native receipt, postflight and full-operation receipt are preserved. failure-handoff/observations.json contains exact scoped fields; failure-handoff/collection.receipt.json records the inspection. A new failure-handoff manifest/completion seals current outputs/logs/report without overwriting the preparation completion. The final narrow validation status is COMPOSITE COMPLETE with a valid negative performance result. Main retains broader-goal acceptance/coordination; no additional optimization is authorized by this report.

## Approved protection-only composite completion

Executed exactly once, after review and parent authority, with no native/Julia/scientific/PNG/renderer/Events-metadata work:

~~~sh
PYTHONDONTWRITEBYTECODE=1 python3 close_protections.py --execute-authorized --review-seal-sha256 fd3eba128570c864708fa4f452307f25ed150148b363d60dac0853e7926a3998
~~~

The controller exited0. It verified42 protection/provenance records, all17 manifest provenance paths, the frozen9836-file failure evidence and35-file reviewed closure package, old23-file harness, both source/runtime/cache/dependency inventories/images, renderer identities/keys/bytes/mtime, D0/older evidence, configs, all396 stat identities, routes/pool settlement and9704 arm-output artifacts. All17 manifest rows have explicit provenance:16 prior JSON paths and one helper-root exception honestly marked root_without_later_anchor. The helper chain is not sole native trust.

Independent native-stat trust is anchored by original async completion9e1d6e2a -> original seal3c7c0b8c -> protected-native-stat.jsonb6171922. Its exact2 path/old-SHA mappings match native.before and EXPECTED; device/inode/bytes/mtime/ctime match frozen396 AND current stats. Exactly2 distinct historical ROOT inputs use trusted stat rather than a new content hash. Their old expected SHAs are recorded as NOT revalidated, explicitly NOT equivalent to content SHA. All other hashes remain strict, including rejection of input aliases/hardlinks. No ROOT content was opened/hashed in this closure.

The old failed crossverify.operation stays complete:false57.466080688s, SHA256a01dd2dc9802d3f7daf111cc5e40f286fc5b4445bbe2b7dfa560613682a99c08. Existing successful Julia receipt SHA2568b24b9c7602428fb996ca5c84f74c639c5ed89f223c42c57fbc19d46ad829bf6 and old PNG/science logs remain immutable. No successful crossverify.receipt.json was fabricated. New composite-summary.json records both that old failure and the new protection success, preserving the2.868354x negative result/defaultfalse and every scope limitation.

Arm .ji touches are independently recorded in their postflights. The crossverification Julia .ji touch cannot be independently re-proved post-failure; its existing exact consumed cache/build proof and successful assertions remain recorded. The Python-only closure changed no cache mtime or bytes.

Protection-only controller wall **45.495502623s**, within remaining153.306254190s. Preparation **26.693745810s** is additive (original15.462433833 plus measured provenance fix1.231311977 and conservative10s, never relabeled measured). Lane through controller **72.189248433/180s**, warm **1459.645257459/3000s**, phase **3126.812961702/5400s**. Its peak sampled self RssAnon37,117,952 bytes; no resource circuit, owned subjects or pending journal remain. Final report/publication gets a separately charged finalization receipt in the SAME180s category, not a reset.

Closure operation SHA256:e5b7c2a6bd73d7ead797d59def189578b95e9ee30527cc9a1e15dfb721f248be.
Composite completion SHA256:95dcb9ca7ccf5f263886c08926933ba7d7300e68919310b3e7af906972fd5a91.
Closure43-file manifest SHA256:026287e8bb5676e17dd24aae1b78d2f0632268e479b3693a3e1424cedf4ef571.
Stored summary SHA256:c1b5a97c4afe432e5db4d51b21f00400a837489a7fed6bbedaebf8851e59b27c.
Protections SHA256:d9c4c2e93c0d88f54fff04d6c5e8d6be1fb1e6694fa01382883a583b0fbf44ac.

Current Mac434 source and699 runtime files were individually matched to the frozen final manifests; gate closure checks and final publication proof bind the same bytes. Final source132b9f996156475c3c5c0fc4603a2770866951cce5c15b8ef7038ab81e1cc054/runtime29946914a15065e3d2ba039a2e9820f5f499d1c0a844cc2eda74fe75e220ab38. Candidate .ji SHA256a52153cf9aa1fcb68d8721e40b89b5744d0c247515b801188150c69cae9cd44d (877388B), .so SHA256cb8b93ca40ffd1f6aa904f794d31ccb742f81bf82ca09061ed18b484f802464c (11996632B); buildfafbfcfda12c3b300be782f2deb22fe6. Source/config/test/image/STATE remain untouched; only this authorized report status changes. The provisional failure report remains immutable.

Final report/artifact receipt and seal are under protection-closure/final-report. They include the successful composite, exact new budgets, current freeze/no-owned-job/no-pending proof and report hashes. The reviewed controller completion and old failed record remain separate immutable artifacts. The broader goal is handed back to main for verification; no RDF, IO-ceiling, stable superiority or full396 baseline basket-set equality claim is made.
