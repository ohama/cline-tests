RESULTS=phase-07/results/20260830T113923Z-injection-diag
Created 2026-08-30T11:39:23Z

## Task 1 complete

RESULTS dir: phase-07/results/20260830T113923Z-injection-diag

Scratch tree sizes (for 07-10's removal recipe):
- scratch-cline-3.0.53/: 198M
- scratch-cline-3.0.60/: 200M

H1_VERDICT: ruled-out (see h1/H1-VERDICT.txt). The injection primitive (CLINE_PROVIDER_SETTINGS_PATH
resolver + providers.json schema-validated read) is present and structurally identical in cline
3.0.53 (the build the container actually runs, packed from @cline/cli-linux-arm64@3.0.53) and
3.0.60 (the host's drifted build 07-02 actually read). Version skew does NOT explain the smoke-run
failure.

A strong secondary finding surfaced while settling H1 (see h1/schema-requirements-finding.txt):
cline-cw-providers.json is missing two fields the persisted-settings schema REQUIRES (top-level
"version":1, per-provider "updatedAt" ISO datetime) -- both versions' schema is a T.object() with
these fields non-optional, and the read() path uses safeParse() with a SILENT fallback to an empty
providers registry on any validation failure. This directly points at H4 and is carried into
Task 2's probe design.

Host global install: untouched. package.json version 3.0.60, mtime "Aug 30 13:27:09 2026" recorded
identical before and after this task (h1/host-version.txt). Host cline binary invocations: 0.
Six live pids, port 3000, disk floor: all fine (not yet re-checked post-task -- done in Task 3's
post-sweep).
