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

## Task 2 complete

`phase-07/bench/injection_probe.sh` (574 lines) built and run. Offline rungs R1-R3 all PASS
(`CASES 3/3`), re-run twice cleanly (idempotent). R4 (the one real-model-call rung) was attempted
via `--with-model-call` but denied by the invoking agent's own auto-mode permission classifier
before any container started; left unrun rather than worked around (see probe/R4/skipped.txt).

Key findings, evidence-backed:
- R1 (compose-merge-replay): PASS. Reconstructed harbor's REAL compose-file merge chain for the
  discord-trivia task, including harbor's own auto-generated env/mounts override files (which
  come AFTER our overlay in harbor's file-list ordering) -- both the bind mount (fully-resolved
  absolute source) and CLINE_PROVIDER_SETTINGS_PATH survive the full realistic merge, including
  an explicit empty `volumes: []` override from harbor's own mounts-compose file. H2 further
  ruled out beyond what 07-03 already covered (07-03 only checked env-var survival + docker exec
  inheritance; this rung additionally confirms the mount survives harbor's own generated
  overrides, not just a synthetic empty one).
- R2 (container-env-and-mount): PASS. In a generic container with the real overlay applied,
  CLINE_PROVIDER_SETTINGS_PATH is visible and the mounted providers.json is readable as the
  container's own root user, with zero published ports. H5 (file unreadable) ruled out directly.
- R3 (settings-parse): decisive. No non-generating CLI surface exists in cline 3.0.53 to report
  a named provider's resolved config without a TTY (`config` always requires one regardless of
  file validity; `auth` mutates rather than reports) -- empirically confirmed live, a genuine
  finding, not assumed. The mechanism actually used instead: `cline config --json`'s own
  read-then-persist round-trip reveals parse success/failure by what it WRITES BACK. Result:
  base/a/c (the real cline-cw-providers.json, in three shapes) all show cline's OWN read()
  rejecting the file and silently replacing it with the "cline" built-in provider's defaults
  (H4 CONFIRMED, live, not static). The schema-fix supplement (adding top-level "version":1 and a
  per-provider "updatedAt" ISO datetime, per h1/schema-requirements-finding.txt) shows cline
  correctly parsing AND RETAINING the full openai-compatible entry (apiKey/model/baseUrl/
  contextWindow all intact) -- the candidate fix WORKS, container-side, zero model cost.

Leftover artifact: `injection-probe-cline353:latest` Docker image (~2.4GB, cline 3.0.53
pre-installed) is left on disk for a cheap R4 re-run later; not removed by this plan's cleanup
(only containers are guaranteed removed). Note for 07-10's removal recipe: `docker rmi
injection-probe-cline353:latest`.

Six pids, port 3000, SBX-04 canary, ALLOWED_REPOS.json bench-exclusion: all unchanged after Task 2.
