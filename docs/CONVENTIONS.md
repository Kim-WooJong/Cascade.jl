# Development conventions

These rules apply to every contribution.

1. Language: Julia only. Python appears only as an external test oracle
   (e.g. correctionlib on a validation host) and never as a runtime dependency.
2. One file = one function/feature. A file holds one public function (with its
   private helpers) or one type with its constructors. Related files are grouped
   in a folder per area (`src/<Area>/`).
3. Entry files only include and call. `src/Cascade.jl`, `src/<Area>/<Area>.jl`
   and CLI/script entry points contain includes, exports and calls only — no logic.
4. Each area is its own submodule (`Cascade.<Area>`) and depends on other areas
   only through their exported API.
5. Tests live in `test/<area>/runtests.jl` (entry, includes only) plus one test
   file per feature. Tests must not need external analysis data unless guarded by an env flag
   (`CASCADE_REAL_DATA=1`).
6. English for code, docstrings and docs. Every exported function has a docstring.
7. No AI tool or assistant names in authorship, commits, comments or docs.
   Author: Kim-WooJong.
8. Keep source checkouts free of execution outputs, logs, ROOT inputs and local
   Manifests. Use a separate validation/execution environment.
9. Numbers are reproduced, not trusted: a refactor must reproduce reference
   yields/cutflows exactly before physics changes are enabled.
10. Versioning: patch = fix, minor = compatible feature, major = breaking; bump
    per verified group of changes.
