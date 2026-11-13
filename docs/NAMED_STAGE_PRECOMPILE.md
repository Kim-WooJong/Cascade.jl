# Named no-checkpoint stages

Three inner select/correct/histogram closures now have immutable typed callable
names. Runtime stage bodies, guards, order, ownership, telemetry spans and timing
boundaries are unchanged. Eight generation-only precompile declarations cover the
four stage types and their span keyword calls. No new runtime flag, data warm-up,
world-age bypass, input decoding or task execution during image generation.

Actual R29 strict image build, six-case smoke and four full107GB analyses passed.
All17 science outputs are byte-identical; parent rehashed68 files. SameGC16/CPU0–15,
traced adapter mean wall64.082→62.761s and body53.343→52.022s (two runs perarm).
This is not directly comparable to the ordinary native CLI clock. Runtime flags
and production GC defaults are unchanged. No commit/push.

Standalone test: julia --startup-file=no --threads=2 test/named_stages/final_validation.jl
Synthetic recording fakes verify stage routing; actual physics proof is R29 receipts.
Preimage fixtures are reference oracles, not active product code.
