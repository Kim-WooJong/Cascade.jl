# Public source publication scope

This repository is an experimental Cascade.jl 0.1.0 source snapshot under MIT.
Third-party portions retain the notices in THIRD_PARTY.md. It is not a stable
release, General registry package or final physics analysis.

## External certification input

The file below is intentionally not redistributed with this source snapshot:

- analyses/ttbar_emu/Cert_Collisions2022_355100_362760_Golden.json
- Historical source SHA-256: ba4feb79a5b39a15a73ca0279b1bf9be4966ec816e5263f92fdee086662f73a9

Obtain an authorized CMS certification mask from its official distributor and
place it at the relative path expected by the reference analysis, or explicitly
configure a valid external path (including documented ENV bindings). Verify its
provenance, era and hash before reproducing an old analysis. The data license is
not supplied by the Cascade MIT license. Do not replace the mask by an empty or
synthetic one, disable the lumimask, or claim calibrated luminosity from this
source release. Reference configuration and integration tests requiring this
mask cannot run until that prerequisite is satisfied.

## Historical and site-specific material

Private .project state, old development Git history, ROOT inputs, artifacts and
raw execution records are not distributed. Home directories and a private
validation hostname in documentation are anonymized placeholders; historical
numbers are retained as scoped records, not freshly reproduced results.
The historical pinned real-input decoder harness is omitted because its exact
path/device/inode contract is site-specific. Its opt-in dispatcher raises a
clear error rather than pretending that a modified pin was validated. The
technical integration shell runner takes CASCADE_ROOTPLOTS_RUNNER instead of
a private wrapper location.

## Validation boundary

Fifteen standalone areas passed across the earlier focused development runs;
that does not establish a passing test run of this exported snapshot. Full
canonical-suite attempts were incomplete at their time limits in batch tests.
Pkg.test(), fresh-install and supported-version matrix validation remain open.
The public export was checked statically for paths, licenses, source integrity,
file references and syntax where available. No passing CI badge, speed guarantee
or final cross-section result is asserted.
