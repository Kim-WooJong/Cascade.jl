# Development and validation

Read [development conventions](docs/CONVENTIONS.md) and [AGENTS.md](AGENTS.md)
before changing code. Preserve existing scientific results, floating-point
reduction order, resource ownership and opt-in execution defaults.

## Environment

Activate this checkout and instantiate its `Project.toml` in the execution
environment, as shown in the README. Do not copy a machine-specific Manifest
or execution outputs into the source repository. Keep source checkouts separate from outputs; run Julia validation in an
explicitly configured execution environment.
No dependency installation, registry update or global environment mutation
is implied by a documentation-only change.

The declared Julia compatibility is 1.11 and later 1.x. Some low-level reader
contracts require an exact audited UnROOT release/source layout; the current
optimized decode contract audits UnROOT 0.11.11. A compat entry such as
`UnROOT = "0.11.11"` is a compatible range, not an exact lock. Compiler IR and
allocation checks may be runtime-specific; record the exact Julia version.
Do not broaden a scientific or resource guard merely to make a test pass.

## Tests

The standard entry point discovers `test/<area>/runtests.jl`. Fifteen
standalone recording-fixture areas run sequentially in fresh Julia processes
to preserve their own `Main` bindings; legacy package areas retain their
shared fixture/include order. Child failures propagate to the parent. The
active project, compiler/bounds/cache options and default thread count are
preserved; interactive thread-pool equivalence is not promised. The entry
argument is consumed before the fixture runs. Environment variables are
inherited: the dispatcher never enables real-data or probe flags. Child
assertion summaries remain on stdout; the parent subprocess check counts
one area, not its scientific assertions.

Commands for validation in the configured execution environment:

```sh
julia --startup-file=no --project=. --threads=4 test/runtests.jl
# Package-manager entry point (may resolve a temporary test environment):
julia --startup-file=no --project=. -e 'using Pkg; Pkg.test()'
```

Do not interpret a focused standalone harness as full-package validation.
Some harnesses replace dependencies with small recording fakes: retain that
qualification in reports. Tests requiring actual ROOT data, native rendering,
external oracles or site-specific files have separate prerequisites. In
particular, `test/ttbar_integration/validate_gate.sh` is an explicitly enabled
real-input integration driver, not a default test directory. See
[technical integration](docs/TTBAR_INTEGRATION_VALIDATION.md) and
[oracle instructions](tools/oracle/README.md). Do not enable real-input flags
unless the required inputs and a fresh output directory are available.

Python is tooling/oracle-only, not a Cascade runtime dependency. The bounded
benchmark report/runner has an independent standard-library test suite:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/benchmark/tests -v
```

Before reporting success, state which suites actually ran, their exit status
and pass/skip/fail counts, plus untested integration/runtime combinations.

### Current release-validation gaps

All fifteen standalone areas passed across the recorded focused runs after
fixture maintenance. This does not establish a passing full-package or
`Pkg.test()` run. An initial no-compiled-modules attempt exceeded 360 seconds;
a later repaired-area plus canonical-suite run with existing dependency caches
reached its combined 480-second limit during batch execution tests. These are
incomplete runs, not full-suite passes or proof of scientific regressions.
Keep the full-suite gate open until a complete run is recorded.
The exact-version Julia 1.12.2 compiler check in
`test/reusable_basket_offsets` and the audited UnROOT source checks also
mean the declared compatibility range is not yet a validated test matrix.
Do not publish a passing CI badge or broader support claim from focused tests.

## Changes and review

- Keep one feature/function or type per file, grouped by subsystem.
- Keep code, docstrings and repository documentation in English.
- Add semantic/guard tests before making performance claims. Keep real-input
  comparisons separate from synthetic fixtures and compiler microchecks.
- Preserve pre-existing dirty work. Do not reset, clean, or stage the whole
  checkout as a shortcut. Review added files and generated artifacts explicitly.
- Use [the Git preparation checklist](docs/REPOSITORY.md) before publishing.
  License selection and remote publication are owner decisions.

## Public source snapshot prerequisites

The real CMS certification mask is not redistributed. Obtain an authorized copy
and place it at the relative path expected by the reference analysis before
running configuration/reference-analysis tests. See PUBLICATION.md for the exact
filename and provenance hash. A missing mask remains an error; quality selection
is never disabled or replaced by synthetic data. The historical site-pinned
windowed decoder harness is excluded and an explicit request for it fails.
