# Primitive interpretation/cache prerequisite review — 2026-11-07

Status: implementation and bounded correctness/trace proofs complete. **Stopped before ordinary timing.** No throughput, end-to-end speedup, or physical I/O ceiling claim.

## Minimal change

`decode_prepared_basket` retains its existing validation and calls
`interpret_decoded_basket(raw, offsets, ::Type{T}, ::Type{J}, n) where {T,J}`.
This dispatches the heterogeneous producer's type values into an inferred primitive conversion. Queue/job layouts, assembly implementation, default serial execution, error order, ownership, key generation, and science logic are unchanged.

`precompile_decode.jl` adds a bounded workload automatically executed **only** under `jl_generating_output`. It uses no source files, ROOT inputs, tasks, or renderer. Eleven admitted primitive types each cover flat and regular primitive jagged interpretations, both uncompressed and checked XZ: 44 valid tiny jobs. Assembly covers masked/unmasked and skipped descriptors; jagged fixtures include an empty event. No normal-load warmup occurs. Tests explicitly exercise this workload and infer all 22 primitive interpretation return types.

## Cache prerequisite

Created only these private relocation aliases, targeting the existing pinned installation:

- `baseline/depot/juliaup/julia-1.12.2+0.x64.linux.gnu`
- `candidate/depot/juliaup/julia-1.12.2+0.x64.linux.gnu`
- Target: `/path/to/user/.julia/juliaup/julia-1.12.2+0.x64.linux.gnu`

No Juliaup configuration or home-depot load-path exposure. Candidate compiled files were independently copied, not hard-linked. The six direct external dependency caches and all required transitive/extension caches validate after relocation; remaining metadata false entries were Cascade or already-loaded builtin stdlibs with no cache file. **Zero dependency rebuilds.**

Pinned Julia 1.12.2 direct binary, private-only depot, `LOAD_PATH=["@","@stdlib"]`, compiled-modules `existing`, package images enabled, controller 16 threads/BLAS1. Standard Cascade-only compilecache uses its normal compiler child (1 thread). One owned subject/process group at a time; sampled anonymous-memory and wall watchdogs.

## Actual operations

All current authorized operations exited 0/raw wait status 0; no watchdog fired. Gate evidence root:
`/path/to/user/analisis/Cascade_dev/precompile-selection`.
Each operation below has `.command`, `.command.json`, `.log`, `.exit`, `.receipt.json`.

| Operation stem | Supervised wall seconds | Result |
|---|---:|---|
| dependency-relocated | 5.340826441 | Metadata-only eligibility passes |
| baseline-build-relocated | 9.989193761 | Cascade-only image built |
| baseline-fresh | 3.715782311 | Exact new cachepath consumed |
| candidate-build | 18.202852150 | Cascade-only image built with generating-output workload |
| candidate-fresh | 3.958256325 | Exact new cachepath consumed |
| candidate-focused | 27.765028986 | 349 assertions, including 45 new assertions |
| candidate-cached-native | 41.256220206 | 770 native selection/bitwise/queue assertions + 4 pathname assertions |
| baseline-target-trace | 15.301975290 | Identical 44-job targeted trace |
| candidate-target-trace | 5.025171968 | Identical 44-job targeted trace |

Total supervised native time including historical prerequisite operations (11.467116963 s): **142.022424401 s**, under the 450 s allocation. Native correctness used existing TTto2L2Nu and MuonEG files, widths 1/4/8/16 including repeated 16, all/empty/alternating masks, bitwise columns and nominal selection/cutflow equality, ownership and failure checks. No full pipeline/old-suite restart or ordinary timing run.

### Build costs, separately accounted

| Quantity | Baseline | Candidate |
|---|---:|---:|
| compilecache call wall (s) | 7.619607887 | 15.769774534 |
| supervised build operation wall (s) | 9.989193761 | 18.202852150 |
| build operation user CPU (s) | 9.040659 | 25.546781 |
| build operation system CPU (s) | 1.069648 | 1.308878 |
| `.ji` bytes | 836444 | 840537 |
| native `.so` bytes | 5475016 | 11658456 |
| total image bytes | 6311460 | 12498993 |
| peak sampled process-group RssAnon bytes | 562966528 | 800321536 |

CPU comes from wait4 for the entire supervised build operation including wrapper/eligibility/children, not an isolated compilecache CPU interval. Extra image size and build cost are real tradeoffs; no timing amortization established.

Fresh-load proofs check `Base.pkgorigins[pkg].cachepath`, not just eligibility:

- Baseline: `baseline/depot/compiled/v1.12/Cascade/Ye57P_AEvvJ.ji`
- Candidate: `candidate/depot/compiled/v1.12/Cascade/Ye57P_VUXtU.ji`

## Targeted trace proof and residuals

`targeted_trace.jl` is identical for baseline/candidate, asserts exact consumed cache, then decodes/assembles the same 44 valid in-memory jobs. These are diagnostic compilation traces, not ordinary performance measurements.

| Runtime trace match | Baseline | Candidate |
|---|---:|---:|
| decode_prepared_basket | 2 | 0 |
| interpret_decoded_basket | absent | 0 |
| UnROOT.interped_data | 22 | 0 |
| assemble_decoded_basket! | 88 | 0 |
| all lines mentioning Cascade | 91 | 0 |
| total trace lines | 284 | 139 |

Candidate retains 139 non-Cascade lines, including fixture construction/Base code and the TBasketKey keyword constructor; this is not a zero-JIT/full-selection proof. Candidate build trace records 22 typed interpretation and 88 assembly specializations. Arbitrary multi-block arities and full cold selection compilation remain outside this trace's scope.

Trace SHA256:
- Baseline `evidence/baseline-target.trace.jl`: `e22c8d331a8bd7559f2d4ab0dd8951022e12a5eb6729e826f9cafc6bdffe669e`
- Candidate `evidence/candidate-target.trace.jl`: `8a7f13500ae88947e7ac2dd17029e997c6234952c8ca4bb8cf286b43a75f2dfb`

## Protected state and exact inventories

`evidence/protected.phase.final.json` and `protected.phase.verify.log` confirm:
- Baseline source428: `0a0937bf2d98067a01fee8b2c661fe87ee8cfe3b1157363b5ab6e6d42fb19f37` unchanged.
- Baseline/frozen decoder runtime691: `ce449ec70c81a1995b4f170146faaaa07e5a4ee63d8cb19cf19a966ce9d03615` unchanged.
- Candidate source429: `ae0e28999cab82f7582271b44730690af89d2acc68e2ac5db3fcf552888e76fe`.
- Candidate runtime693: `227d4609e9cae4ae0fa697f0392a34105797c8733af62eed9c6cf6812f605e58`.
- Original monitored 860 shared-cache files unchanged; all 842 non-Cascade copied cache files in **each** overlay unchanged. This is the original monitored set, not an inventory of unrelated depot packages.
- Dependency source/environment records, pinned wrapper/binary/native inputs, original frozen project and 58 historical outputs unchanged. Historical outputs are rooted at `basket-decode/candidate/phase-b-final428`, not its parent.
- No owned subjects remain. No install/resolve/network/Pkg precompile/world build/sysimage/shared-cache writes, staging, commit or push.

Mac-authoritative product/test files and SHA256 (verified against native candidate):

```text
3c359537fbf5278f60bf661e5675bb06773a4c1a868e90b5c19aa293011d6533  src/IO/IO.jl
1e91d9ec01cae8ba117b9a5e59186fa307beaea382e89e929077165f99ab59e2  src/IO/decode_prepared_basket.jl
632303bac68fab9bebd01cfecd1214b27fc72f7c89cefca6f09dbd002d52fe4e  src/IO/precompile_decode.jl
12e0511f7481e269b3f78b123925ab8aaf67815ad95dc87442805eec1138c48d  test/basket_decode/runtests.jl
74d70fc7e3373abb6899af7cdbfee3b3f4f5b6ac3700a6f7ed5ee516b9f869d1  test/basket_decode/test_precompile.jl
```

`evidence/phase-completion.json` records operation receipts, digests, trace counts and caveats. Existing earlier failed prerequisite logs remain untouched. Two **verifier-only** failures were preserved: incorrect historical output root, then an overbroad comparison of the original860 set against unrelated shared cache files. Corrected verification exits0; no product/build/test failure occurred. Candidate build log inherits baseline labels and a controller-only "no decoder execution" sentinel: the explicitly authorized generating-output child **did** execute the source-free decoder workload.

## Review boundary

Correctness and targeted package-image coverage are supported. Cachebuild costs roughly doubled and native image grows by 6183440 bytes; useful-thread throughput/scaling benefit remains unmeasured. Parent review/authorization is required before ordinary timing.
