# Large-input timing audit supplement

This read-only evidence analysis supplements, and does not rewrite, the frozen D0 and matched validation reports. No analysis rerun, product change or input payload read was performed.

## Baseline harness readiness

The old D0-only monitor and entry contain candidate-specific guards. The completed ABBA did not reuse them unchanged: `warm-production-controls/run_arm.py` takes the explicit baseline/candidate arm and chooses the matching private project, depot, cache/build ID and renderer executable. Its byte-identical `ordinary_warm_cli.jl` asserts that arm and calls public `Cascade.Pipeline.main(ARGS)`. The actual four receipts exit0, record the correct private renderer and cache, and all four outputs plus D0 passed 47,397 science/publication assertions. The D0-only baseline traps therefore do not invalidate these warm measurements.

## Localization within the residual

The reported residual remains external wall minus the seven rounded stage clocks; it is not a measured JIT or I/O category. Existing timestamped stdout permits a useful, narrower localization:

| Arm | Launch to observed before-main marker, s | Observed marker to analysis banner, s | Observed after-main marker to exit, s |
| --- | ---: | ---: | ---: |
| A1 baseline | 3.103938 | 26.260437 | 0.324925 |
| B1 final | 3.069980 | 27.289529 | 0.372244 |
| B2 final | 3.121923 | 25.850813 | 0.446519 |
| A2 baseline | 3.083750 | 25.732874 | 0.388589 |

Mean marker-to-banner interval is 25.996655s baseline and 26.570171s final. These are observer-arrival timestamps from the existing timed logs, not new exclusive function instrumentation. Stdout delivery/scheduling and marker/probe overhead apply; do not add them as exact isolated CPU components.

The public entry calls `Pipeline.main` after the before-main marker. `src/Pipeline/run_pipeline.jl` loads the configuration, selects samples and calls `validate_reduced_inputs` before printing the analysis banner and starting the stage clocks. Thus much of the roughly30s residual is localized to the **in-main, pre-stage initialization/configuration/validation path**. How that interval divides among argument dispatch, configuration handling, validation, compilation and allocation is unknown. It is not correct to describe all30s as Julia startup, JIT, or storage I/O.

For the final candidate, the next timing-based investigation priorities are selection (~70.435s), the pre-stage path (~26.57s observed), plot (~23.99s), and correction (~15.495s). These are priorities, not promised savings or permission for another optimization/measurement matrix.

## I/O wording

Live subject-PID counters at the public-main boundaries cover its threads and descendants whose counters were folded into it when reaped within that interval. They exclude startup/load before the boundary, later exit work and unaccounted orphan domains; they are not exact terminal process-tree or device traffic. Warm read_bytes deltas were 0,0,4096,0B; the first-touch D0 main delta was36,734,287,872B. The latter equals the observed input-residency gain, which is a consistency check, not proof that no other file was read or no page was evicted. Per-stage expanded sampling brackets overlap and cannot be summed.

## Independent final acceptance

Read-only final review confirmed that the completed warm harness has neither D0-only baseline trap and found no correctness or protocol blocker. It independently checked the arm paths, actual receipts/postflights, output-only crossverification scope and observed pre-stage timeline. Its wording recommendation is incorporated above: describe pre-stage setup separately from the still-unknown mechanism, and include reaped descendants in the main-window counter scope. This supplement preserves the already frozen report and gate receipt hashes; no rerun is needed.

## Parent endpoint verification

Parent independently read actual raw four receipts, cache proofs, renderer identities and the 47,397-pass crossverification log; verified114/114 final-artifact hashes; matched authoritative Mac429-source/693-runtime records to frozen3141e2d86aed04444a2e174827db7e9f3f680121b63fd590c8556788ae4989a9 / ec45bc7e6bfd30c3551ec221741d604a3e82d588aaa8fc2bab051b9deb66c3c5; verified matched report SHA9577c127eaf8840dc9043c985bc7d5b710a9d5ec1d1aeb4b409804212fa5e656 and no owned Julia processes. `git diff --check` passed before this documentation-only supplement.

Evidence: `/path/to/user/analisis/Cascade_dev/large-input100g/warm-production-controls/{A1-baseline428,B1-final429,B2-final429,A2-baseline428}.timed-log.jsonl`, their receipts, `run_arm.py`, `ordinary_warm_cli.jl`, `crossverify.log`, and `evidence/completion.json`.
