# Contribution conventions

1. Use English for code, docstrings and repository documentation. Document exported
   APIs. Keep the core Julia-only; Python is allowed for optional external oracles
   and developer measurement tools, not as an analysis runtime requirement.
2. Use one file per public function/feature (with private helpers), or one type
   with constructors, grouped under `src/<Area>`. Keep module/script entry points
   limited to includes, exports and calls; communicate through exported area APIs.
   Prefer small, reviewable changes over unrelated refactors.
3. Put tests under `test/<area>`, with a thin runtests.jl entry where appropriate.
   Keep synthetic fixtures independent of external analysis data; enable real-input
   and oracle checks explicitly. A flag does not supply the missing input or license.
4. Preserve selected-entry order, primitive precision, cutflows, sumw/sumw2,
   signed normalization populations, mask behavior, ownership and failure paths.
   Establish reference parity before enabling a physics change. Do not weaken an
   admission check or replace a real certification mask to make tests pass.
5. Treat optimized readers as version/platform-specific contracts. Retain opt-in
   defaults, conservative fallback and cleanup rules. Do not infer speed, memory
   safety or physical validity from recording fakes or one warm timing.
6. Keep ROOT inputs, generated outputs/logs, credentials, local paths and local
   Manifests out of source contributions. Preserve upstream notices in
   [THIRD_PARTY.md](../THIRD_PARTY.md); external payload/data terms are separate.
7. Report exact validation scope, prerequisites, skipped checks and failures.
   Follow [VALIDATION.md](VALIDATION.md), not historical execution receipts.
   Full-suite, Pkg.test, fresh-install and version-matrix status remains unverified
   until independently completed for the current tree.
8. Use semantic versioning for verified changes: patch fixes, compatible minor
   features and breaking major changes. Keep authorship factual; do not add tool
   or assistant attribution to code, documentation or commit authorship.

See [architecture](DESIGN.md), [configuration](CONFIG.md) and the
[documentation index](README.md) for current contracts.
