# Repository scope and publication checklist

## Source layout

| Path | Role |
|---|---|
| `Project.toml`, `src/` | Package metadata and runtime Julia modules |
| `bin/` | Command-line entry points |
| `analyses/` | Template and reference analysis configurations |
| `examples/` | Fit/plot/export examples and their scoped evidence |
| `test/` | Unit, synthetic, compiler-level and opt-in real-input checks |
| `tools/` | Optional benchmark tooling and independent external oracles |
| `docs/` | User guides, design history and validation records |
| `AGENTS.md`, `CONTRIBUTING.md` | Development and scientific-preservation rules |

Keep generated analysis products, local state, execution logs, credentials and
machine environments outside the source tree. `.gitignore` covers local
`artifacts/`, `reports/`, `.project/`, `cascade_out/`, ROOT files, local `.env`
files and tooling caches. Do not ignore whole source/test/documentation areas.

**Ignore rules are not a privacy boundary.** They do not untrack previously
committed files or remove historical copies. Private development
repositories may already track `.project/STATE.md`; this public snapshot does not. `git add .` or `git add -u`
can therefore stage its current contents even though `.project/` is ignored.
Use an explicit reviewed file list, and inspect the index before committing.

`.gitattributes` excludes local state/artifacts/reports from source archives;
`export-ignore` does not scrub clones or Git history. A fresh source-only
repository avoids importing old development history, while the original private history remains local. This publication does not
rewrite or discard that development history.

## Before a local commit

1. Inspect `git status --short`, including new source/test/doc files. Preserve
   unrelated or unfinished work; review logical groups instead of blind staging.
2. Review documentation links against the exact proposed file set, not merely
   the working tree. Several feature guides may be newly added files.
3. Inspect source/config/docs and reachable Git history for secrets and private
   information. Pattern scans are heuristic: no finding is not a guarantee.
4. Review site-specific analysis/payload paths and historical evidence paths.
   They are not bundled datasets, portable defaults or proof readers can access
   the corresponding evidence. Do not replace them with invented payloads.
5. Check whitespace (`git diff --check`), then execute the relevant tests in the
   configured environment. That command alone does not inspect untracked files.
6. Inspect `git diff --cached --stat`, `git diff --cached --name-only` and
   `git diff --cached` before creating a commit. Do not stage local state,
   secrets, environments, generated reports or raw ROOT inputs.

## Before public publication or a package release

- The owner selects the repository destination, visibility and license. No
  license is inferred from the package author, dependency licenses or GitHub.
- Decide whether development history (including old internal-state commits)
  should be published or only a separately reviewed source snapshot.
- Verify fresh-checkout dependency resolution and package loading, including
  the ROOTPlots source override; check downstream installation separately.
- Verify the standard test entry point and supported Julia/dependency matrix.
  Record exact audited versions for optimized reader/compiler checks.
- Keep native ROOT rendering, real-input science closure, correctionlib/pyhf
  comparisons and performance evidence distinct from synthetic CI.
- Audit reference-data redistribution rights and analysis/calibration
  provenance. A technical example is not a final physics result.
- Review publication contents and obtain explicit approval before configuring
  a remote or pushing. This checklist is not authorization to publish.

An initial private development upload and an endorsed public release are
different milestones. Do not label the latter complete while compatibility,
license or scientific-validation questions remain unresolved.
