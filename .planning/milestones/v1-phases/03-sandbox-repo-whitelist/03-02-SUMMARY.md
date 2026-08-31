---
phase: 03-sandbox-repo-whitelist
plan: 02
subsystem: testing
tags: [sandbox-exec, seatbelt, macos, security-testing, node, bash]

# Dependency graph
requires:
  - phase: 03-sandbox-repo-whitelist (plan 03-01, parallel wave 1)
    provides: gen_sandbox_profile.py / run_sandboxed.sh (consumed by plan 03-03, not by this plan)
provides:
  - phase-03/sandbox/make_fixtures.sh — idempotent permanent regression fixture tree builder
  - phase-03/sandbox/assert_denied.sh — false-pass-discriminating denial assertion helper
  - phase-03/sandbox/probe_fs.js — in-process fs + subprocess EPERM/ERROR probe
  - unsandboxed control baseline at phase-03/results/20260829T200201Z-control/
affects: [03-03 (wires these to the real generator), 03-04 (single budgeted cline smoke test)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Unsandboxed control run before every denial assertion, so a denial can never be credited to a broken/missing fixture"
    - "Signal exit code (>128) and empty stderr classified as CRASHED, distinct from a real EPERM denial"
    - "fs error code EPERM is the only DENIED signal; ENOENT/EACCES/everything else is ERROR"
    - "Permanent regression fixtures (prefix-trap sibling dir, symlink-spelled whitelist entry, escape symlink) instead of one-off manual checks"

key-files:
  created:
    - phase-03/sandbox/make_fixtures.sh
    - phase-03/sandbox/assert_denied.sh
    - phase-03/sandbox/probe_fs.js
    - phase-03/results/20260829T200201Z-control/ (fixture-manifest.txt, probe-output.txt, host-facts.txt, README.md)
  modified: []

key-decisions:
  - "assert_denied.sh classification order is fixed: exit>128 (crashed-signal) checked before exit==0 (not-denied) before empty-stderr (crashed-silent) before wrong-error, so a crash can never fall through to a lower-priority verdict"
  - "probe_fs.js DENIED gate for execSync requires both non-zero status AND an 'Operation not permitted' stderr match, mirroring assert_denied.sh's fs-side EPERM-only rule"
  - "All three artifacts stay parameterized (--root, env vars) and never source config.env, preserving independence from the parallel 03-01 plan"

patterns-established:
  - "Every denial test in phase 3 routes through assert_denied.sh, never a raw exit-code check"
  - "Fixture pollution (probe-write.txt etc.) is always cleared by re-running make_fixtures.sh after any run, unsandboxed or sandboxed"

# Metrics
duration: ~10min
completed: 2026-08-30
---

# Phase 3 Plan 02: Sandbox Test Fixtures and Assertion Machinery Summary

**Built the fixture tree, the in-process+subprocess fs probe, and the false-pass-discriminating assertion helper that makes it impossible to mistake a `(deny default)` SIGABRT crash for a real sandbox denial — self-tested against a deliberate SIGABRT self-kill, a fail-open profile, and a missing-fixture control failure, all producing distinct FAIL verdicts rather than a spurious PASS.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-08-30T04:58Z (approx, directory scaffold present from wave-1 kickoff)
- **Completed:** 2026-08-30T05:03Z (last verification + fixture cleanup)
- **Tasks:** 3/3
- **Files modified:** 3 new scripts + 4 files in one new control-baseline results directory

## Accomplishments
- `make_fixtures.sh` builds an idempotent, re-runnable fixture tree containing both bugs 03-RESEARCH.md actually reproduced as permanent regressions: the prefix-trap sibling directory (`allowed_extra_should_not_match`) and the symlink-canonicalization case (`symlinked/link` -> `symlinked/real`), plus an escape-symlink inside an allowed dir pointing at forbidden.
- `assert_denied.sh` implements all five required discriminations and was self-tested against all five, including deliberately killing a sandboxed process with `kill -ABRT $$` to prove a crash is reported as `FAIL crashed-signal` (exit 2), never as a passing denial.
- `probe_fs.js` proves the SBX-02/SBX-03 collapse (in-process `fs` calls and `execSync` subprocesses denied identically under one profile) while strictly classifying only `EPERM` as DENIED — verified live under an actual `sandbox-exec` wrapper that ENOENT is always ERROR, never DENIED.
- Unsandboxed control baseline recorded and asserted `denied=0 error=0` — every operation later denial tests will claim as blocked is proven to work when nothing is restricting it.

## Task Commits

Each task was committed atomically:

1. **Task 1: make_fixtures.sh — the permanent regression fixture tree** - `89a2694` (feat)
2. **Task 2: assert_denied.sh — the false-pass-discriminating assertion helper** - `eebc247` (feat)
3. **Task 3: probe_fs.js plus the unsandboxed control baseline** - `541f01d` (feat)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified
- `phase-03/sandbox/make_fixtures.sh` - idempotent fixture-tree builder, `--root`-parameterized, never sources config.env
- `phase-03/sandbox/assert_denied.sh` - the phase's quality-critical assertion helper; unsandboxed control + 6-way deny classification (crashed-signal / not-denied / crashed-silent / wrong-error / error-names-wrong-path / write-succeeded) before a PASS is ever printed
- `phase-03/sandbox/probe_fs.js` - Node probe covering 7 checks (in-proc read/write allowed+forbidden, subproc read/write forbidden, escape-symlink read); EPERM-only DENIED gate
- `phase-03/results/20260829T200201Z-control/` - fixture manifest, probe output (`succeeded=7 denied=0 error=0`), host facts (macOS 26.3, node v25.9.0, sandbox-exec present), README explaining the baseline's purpose

## Decisions Made
- Kept `assert_denied.sh`'s classification order exactly as specified (signal check first, then not-denied, then silent-crash, then wrong-error, then target/write checks) since reordering would let a crash fall through and be misclassified by a later, less-specific rule.
- Used parallel plain variables (no `declare -A`) throughout, consistent with the macOS `/bin/bash` 3.2 constraint; no associative arrays were actually needed since each script handles one case/process at a time.
- Left fixture pollution cleanup (`probe-write.txt` etc.) as an explicit re-run of `make_fixtures.sh` after every verification pass rather than building cleanup into the scripts themselves, matching the plan's stated pattern for the control-baseline capture.

## Deviations from Plan

None - plan executed exactly as written. One self-inflicted issue was caught and fixed before committing (see below), not a deviation from the plan's design.

### Auto-fixed Issues

**1. [Rule 1 - Bug] make_fixtures.sh's own header comment tripped the plan's own verification grep**
- **Found during:** Task 1, immediately after first fixture build, before commit
- **Issue:** The explanatory comment describing why the script doesn't source plan 03-01's config file literally contained the string `config.env`, which is exactly what the plan's overall verification step 4 (`grep -n 'config\.env' ...`) checks is absent from all three artifacts. The script's behavior was already correct (it never actually sources the file) — only the comment text would have failed the grep.
- **Fix:** Reworded the comment to say "plan 03-01's sandbox config-env file" instead of the literal filename.
- **Files modified:** phase-03/sandbox/make_fixtures.sh
- **Verification:** `grep -n 'config\.env' phase-03/sandbox/make_fixtures.sh phase-03/sandbox/probe_fs.js phase-03/sandbox/assert_denied.sh` returns nothing (confirmed after the fix and again in final verification pass)
- **Committed in:** `89a2694` (part of Task 1 commit — caught before the first commit was made)

---

**Total deviations:** 1 auto-fixed (1 self-inflicted verification-grep collision, caught pre-commit)
**Impact on plan:** No scope change; a wording-only fix with zero behavioral effect.

## Issues Encountered
- Ran entirely in parallel with plan 03-01, which independently commits to `.gitignore`, `phase-03/sandbox/config.env`, `phase-03/sandbox/gen_sandbox_profile.py`, and `phase-03/sandbox/run_sandboxed.sh`. Staged only this plan's own files at each commit (never `git add .`/`-A`) to avoid sweeping up 03-01's in-flight staged work; confirmed after each commit that 03-01's files were untouched and, by the final commit, that 03-01 had itself landed two commits (`7092a0a`, `925e9f9`) concurrently with no interference either direction.
- Verified the sandboxed-run classification paths beyond the plan's mandatory five self-tests as extra assurance (write-target denial path, EVIDENCE_DIR recording, probe_fs.js under a live `sandbox-exec` wrapper showing DENIED for forbidden ops and SUCCEEDED for allowed ones, and probe_fs.js against a nonexistent forbidden path showing ERROR/ENOENT rather than DENIED) — all behaved correctly; no fixes needed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All three artifacts this plan owns exist, are self-tested, and are proven independent of plan 03-01's `config.env`/`.gitignore` (both empirically, via grep, and by observing 03-01 land its own commits concurrently without collision).
- Plan 03-03 (wave 2) can now wire `assert_denied.sh` and `probe_fs.js` to the real `gen_sandbox_profile.py`/`run_sandboxed.sh` generator plan 03-01 built, and can rely on `EVIDENCE_DIR` for durable per-case transcripts.
- The fixture tree (`phase-03/fixtures/`) is rebuildable on demand via `make_fixtures.sh --root`; no state needs to be preserved between plans beyond the scripts and the recorded control baseline.
- No blockers. One environment note carried forward from STATE.md still applies to any later plan invoking the real `cline` binary: it self-updates on nearly every invocation and can strip `providers.json` custom fields — not relevant to this plan, which never invoked `cline`.

---
*Phase: 03-sandbox-repo-whitelist*
*Completed: 2026-08-30*
