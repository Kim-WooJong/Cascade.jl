# Precompile selection: final review remediation — 2026-11-07

**Final candidate is r3. Stopped before ordinary timing.** This supersedes the active candidate results in `PRECOMPILE_SELECTION_VALIDATION.md`; the first candidate, intermediate r2, their images, manifests, logs and receipts remain preserved.

## Exact narrow delta from the first reviewed candidate

Only two production/test files changed:

```text
6dae13517211057cba50a8ab1afb69062556ae01998cf3bae36b937a688dbf23  src/IO/precompile_decode.jl
32f404b020dc8a03a30eec60a6804f96c4a0a7d76860b514f88bcc6084a8372a  test/basket_decode/test_precompile.jl
```

- Add the requested compressed producer `SubArray` validation assertion.
- Add registry preservation and parsed-call/macro regression guards against workload source/open/read/mmap/process/task APIs. Guard tests distinguish executable calls from comments. This is a regression check, not a security sandbox.
- Real-input r2 trace exposed one standalone `UnROOT.interped_data(::Vector{UInt8},::Vector{Int32},::Type{Bool},::Type{UnROOT.Nojagg})` residual, not visible in the synthetic probe. Add that **exact** precompile signature inside the existing generating-output guard. Final r3 real-input trace verifies its removal.

No queue, assembly, ownership, error-order, default, key, science, dependency or environment source edits. **Shared `interped_data` precompilation also benefits serial readers/counters; this is not an opt-in-only optimization.** No runtime warmup.

Final manifests, independently verified identical across Mac and gate, then verified unchanged after tests:

- source429: `3141e2d86aed04444a2e174827db7e9f3f680121b63fd590c8556788ae4989a9`
- runtime693: `ec45bc7e6bfd30c3551ec221741d604a3e82d588aaa8fc2bab051b9deb66c3c5`

## Renderer protocol readiness

Independently copied only the existing six files under
`~/.julia/scratchspaces/ac0f0d6f-e18a-4015-835e-9978869e88bb/native-backends`
to each private depot. No hard links, renderer compilation, install, build call or renderer execution. All original and copied bytes/modes remain unchanged. This scratch provision is not a scientific cache.

`renderer_eligibility.jl` recomputes the exact ROOTPlots identity/key without calling its builder and verifies an executable independent copy in each private depot:

- renderer key: `d8bac7fa45eb66293877d6362a615a748e3e20c3ac2bdd044623d920e1485b0b`
- executable: 171112 bytes, SHA256 `6a056492dd51b377ad8b75be78fbda3b56c9b6c8ed7db651ed7344029406bfd9`
- compiler/realpath: `/cvmfs/sft.cern.ch/lcg/releases/clang/22.1.0-95893/x86_64-el9/wrappers/clang++`
- compiler identity: clang22.1.0, SHA256 `ecf9e5415c2ee0e60b88272eb5f785c9accfa1c66ab4e773ff150af8f91ef749`
- root-config realpath: `/cvmfs/sft.cern.ch/lcg/releases/ROOT/6.40.02-6fb7c/x86_64-el9-clang22-dbg/bin/root-config`, ROOT6.40.02
- render source realpath: `/path/to/user/.julia/packages/ROOTPlots/hvuKg/backend/root/render.cpp`

`evidence/renderer-eligibility.json` captures full flags, source/header realpaths and hashes, compiler version/hash, root-config hash, key identity representation and both private paths. `renderer-copy.before.json` records all six historical keys/artifacts and inodes. Metadata eligibility is proven; this step did not newly validate graphics output.

## Real-runtime proof, not synthetic coverage

`cached_native_real_r2.jl baseline` and `cached_native_real_r3.jl candidate` load their exact private cache images and run the same frozen `test_actual.jl` on the two protected TTto2L2Nu/MuonEG files with `--trace-compile`. They do **not** invoke the synthetic workload. Each traced process compares decoded columns, masks, selection tables and cutflows against its serial reference, including bitwise comparisons, masks, repeated widths, errors and ownership. This is not a cross-process digest comparison.

| Actual trace entry match | Baseline | Interim r2 | Final r3 |
|---|---:|---:|---:|
| decode_prepared_basket | 0 | 0 | 0 |
| interpret_decoded_basket | 0 | 0 | 0 |
| interped_data | 9 | 1 | 0 |
| assemble_decoded_basket! | 13 | 0 | 0 |
| validate_decode_blocks | 1 | 0 | 0 |
| validate_decode_xz_index | 0 | 0 | 0 |
| all trace lines | 648 | 624 | 627 |
| explicit `# recompile` markers | 5 | 6 | 5 |

The actual baseline producer validation signature is
`validate_decode_blocks(::SubArray{UInt8,1,Vector{UInt8},Tuple{UnitRange{Int64}},true},::Int64)`.
The interim residual is exactly the standalone flat-Bool signature above. Final r3 has no targeted argument-type or multi-block residual. Unobserved multi-block arities are not claimed covered. Zero entries for a function can also reflect inlining or existing code, not absence of execution.

Five final **non-target** recompile markers remain, matching baseline families: upstream `UnROOT.readfields!(...,::Type{UnROOT.TBranch_13})`, two Base.Compiler closures, the profile listener and temporary-file exit cleanup. Thus this is not zero-JIT/full-selection compilation elimination. Full matched signature/marker lines are preserved in `evidence/real-runtime-trace-proof.json`.

Trace SHA256:
- `baseline-real-r2.trace.jl`: `cdf4ec87c8e39e8fd68d9900fadc0d86a87d69522a735f760371f83f90463f5b`
- `candidate-real-r3.trace.jl`: `ecb7f5d9651749c81ff9d9f4ce71f417e6d6fd9e710324507e277dd19010cf51`

## Actual gates and costs — do not mix candidate revisions

Every operation below has its own `.command`, `.command.json`, `.log`, `.exit`, `.receipt.json` under `/path/to/user/analisis/Cascade_dev/precompile-selection`. All exit0/raw0; no circuit fired. Native controllers16T/BLAS1, pinned Julia1.12.2 direct binary, private depot/LOAD_PATH, compiled-modules `existing`; standard Cascade compiler child1T. One owned subject group at a time.

| Operation | Wall seconds | Proof |
|---|---:|---|
| renderer-eligibility | 3.455152833 | Existing exact shared renderer key eligible privately |
| candidate-r2-build | 18.856972334 | Interim Cascade-only build |
| candidate-r2-fresh | 4.159859055 | Interim exact image consumed |
| candidate-r2-focused | 27.193665454 | 354 assertions |
| baseline-real-r2-trace | 42.854518473 | 774 assertions; baseline real trace |
| candidate-real-r2-trace | 42.955499854 | 774 assertions; one Bool residual retained |
| candidate-r3-build | 19.599874182 | Final Cascade-only build |
| candidate-r3-fresh | 3.977161882 | Final exact image consumed |
| candidate-r3-focused | 27.082323352 | Final354 assertions, including50 workload/inference/guard assertions |
| candidate-real-r3-trace | 43.653695978 | Final774 assertions; zero six-function target residuals |

Total supervised native time, including all initial142.022424401 seconds and both remediation revisions: **375.811147798 seconds**, within450. These traced diagnostics/build costs are not ordinary throughput timing.

Final r3 build: compilecache call wall16.950218697s; entire operation wall19.599874182s, user CPU27.136088s + system CPU1.411678s; peak sampled process-group RssAnon814571520 bytes. CPU includes wrapper/eligibility/compiler children, not an isolated compilecache CPU interval. Final native test peak943681536 bytes.

| Image | `.ji` bytes | `.so` bytes |
|---|---:|---:|
| First reviewed candidate (archived) | 840537 | 11658456 |
| Interim r2 (archived) | 840645 | 11744632 |
| Final r3 | 840907 | 11746640 |

Final total image12587547 bytes. First candidate and r2 images/source/manifests are independently preserved at `evidence/pre-remediation429` and `evidence/pre-remediation-r2`. Cache filenames are reused by Julia; use the recorded build IDs/hashes to distinguish revisions.

Final cachepath: `candidate/depot/compiled/v1.12/Cascade/Ye57P_VUXtU.ji`.
Fresh consumed module build ID: `0xfafbfcfde45c9ea78fadedc96684d43e`.
- `.ji` SHA256: `07bab9c44d55b18470e5858376e2193d8fc7474c7193086a27487e43b54d6296`
- `.so` SHA256: `efa03d64193fd4270fa114afbe38baa1861c0f3e4b1bf0e25afc393358e91af6`

## Protected before/after and review boundary

`evidence/protected.phase.r3.final.json` verifies baseline source428/runtime691, original860 shared-cache files,842 private dependency images in each depot, pinned environment/native inputs, dependency source records and58 historical outputs unchanged. Both archived429/693 revisions are checked against their own manifests. Original renderer artifacts and both private copies are byte-identical with distinct inodes. No dependency rebuild, shared-cache write, old-suite/full-pipeline restart, install/resolve/world precompile, scientific output replacement, staging, commit or push. No owned jobs remain.

Authoritative aggregate: `evidence/phase-remediation-completion.json`. A verifier-only string-serialization syntax preflight was corrected before verification execution; invalid helper text is retained. No remediation native operation failed. `git diff --check` passes.

**Stop for narrow re-review. No ordinary matched CLI/timing launched.** Useful-thread scaling, sustained throughput and storage limitation remain unmeasured.
