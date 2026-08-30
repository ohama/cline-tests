---
phase: 05-kanban-telegram-services
plan: 02
subsystem: infra
tags: [launchd, plutil, python3, kanban, cline, drift-detection, restart-helper]

# Dependency graph
requires:
  - phase: 01-cline-config-and-32k-compaction
    provides: check_versions.sh (Check A/B/C version-pin + plist EnvironmentVariables scanner)
  - phase: 02-infra-hardening
    provides: restart_service.sh (bootout -> teardown-poll -> bootstrap -> health-poll helper, async-bootout fix)
provides:
  - "check_versions.sh Check C now enforces KANBAN_NO_AUTO_UPDATE=1 in addition to CLINE_NO_AUTO_UPDATE=1, closing a previously-invisible drift gap on any plist that invokes kanban"
  - "restart_service.sh now accepts <port|none>, extended in place (not forked) to restart portless launchd labels using >=10s pid-stability as the health proof instead of port-listen"
  - "two throwaway fixture plists (phase-05/fixtures/launchagents/) proving both Check C branches (missing var FAILs, both vars present PASSes) in one scanner run"
affects: [05-03, 05-04, 05-05, phase-close-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Extend the single sanctioned house tool in place rather than forking a parallel copy (restart_service.sh gains a PORTLESS branch, no new restart helper created anywhere)"
    - "Portless launchd health proof: state=running is necessary but not sufficient; require the SAME pid across two samples >=10s apart to rule out a job stuck in a KeepAlive restart loop"

key-files:
  created:
    - phase-05/fixtures/launchagents/com.ohama.fixture-kanban-good.plist
    - phase-05/fixtures/launchagents/com.ohama.fixture-kanban-bad.plist
    - phase-05/results/2026-08-30T012819Z-40906-check-c/checkc.txt
    - phase-05/results/2026-08-30T012819Z-40906-check-c/rc.txt
  modified:
    - phase-01/config/check_versions.sh
    - phase-02/infra/restart_service.sh

key-decisions:
  - "Check C's embedded python now emits one PASS/FAIL line per required env var per matching plist (CLINE_NO_AUTO_UPDATE always, KANBAN_NO_AUTO_UPDATE additionally whenever 'kanban' appears in the haystack) rather than one line for a single hardcoded variable"
  - "restart_service.sh's numeric-port code paths are wrapped in an if/else on PORTLESS rather than rewritten, so the pre-existing behavior for flashnext/litellm/kanban(with-port) is provably unchanged"
  - "Portless health check samples twice with a >=10s gap and requires the identical pid both times; a pid change between samples is treated as failure ('restarting rather than settling'), not success"

patterns-established:
  - "Pattern: house drift/restart tooling is extended per-plan, never duplicated into phase-specific forks, even under wave-1 parallel execution pressure"

duration: 10min
completed: 2026-08-30
---

# Phase 5 Plan 02: Extend house version-drift and restart tooling for kanban/telegram Summary

**Extended `check_versions.sh` Check C to enforce kanban's own separate `KANBAN_NO_AUTO_UPDATE=1` auto-update gate (previously invisible drift gap), and generalized `restart_service.sh` to restart portless launchd labels using a >=10s same-pid stability proof instead of port-listen, without forking or regressing either tool.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-08-30T01:20Z (approx, first file read)
- **Completed:** 2026-08-30T01:30Z
- **Tasks:** 2/2
- **Files modified:** 2 (check_versions.sh, restart_service.sh); 4 files created (2 fixture plists, 2 result artifacts)

## Accomplishments
- `check_versions.sh` Check C scans for both `CLINE_NO_AUTO_UPDATE=1` and, for any plist whose haystack matches "kanban", `KANBAN_NO_AUTO_UPDATE=1` — proven with a fixture pair (good: both vars present, PASS; bad: `KANBAN_NO_AUTO_UPDATE` absent, FAIL) run in a single scanner invocation against `LAUNCHAGENTS_DIR` override.
- `restart_service.sh` accepts `<port|none>`; for `none`, Step 3b's teardown poll drops the `lsof` probe (keeping the async-bootout wait itself fully intact) and Step 5's health poll requires the same pid across two samples >=10s apart rather than accepting `state = running` alone.
- Confirmed via git diff that both edits are additive/guarded — no behavioral change to the existing numeric-port paths that flashnext/litellm/kanban(with-port) depend on.
- No new restart helper created anywhere under `phase-05/`; `grep -rc 'launchctl bootstrap' phase-05/` shows zero hits outside the one sanctioned helper.
- Live stack undisturbed throughout: flashnext=46573, role-shim=75548, litellm=48525 unchanged before/after both tasks; no service registered or restarted.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend check_versions.sh Check C to enforce KANBAN_NO_AUTO_UPDATE=1** - `e7ab02b` (feat)
2. **Task 2: Generalize restart_service.sh for portless labels** - `a23c1f1` (feat)

**Plan metadata:** (this commit, following)

## Files Created/Modified
- `phase-01/config/check_versions.sh` - Check C python emits one PASS/FAIL line per required env var; header/echo comments updated to name both gates; Checks A and B byte-identical
- `phase-02/infra/restart_service.sh` - accepts `none` as `<port>`; Step 3b/Step 5 branch on `PORTLESS`; header comment documents the pid-stability rationale
- `phase-05/fixtures/launchagents/com.ohama.fixture-kanban-good.plist` - throwaway fixture, both auto-update vars present, `plutil -lint` OK
- `phase-05/fixtures/launchagents/com.ohama.fixture-kanban-bad.plist` - throwaway fixture, `KANBAN_NO_AUTO_UPDATE` deliberately omitted, `plutil -lint` OK
- `phase-05/results/2026-08-30T012819Z-40906-check-c/{checkc.txt,rc.txt}` - captured single scanner run (rc=1), evidence for both Check C branches

## Decisions Made
- Check C's python now loops over a `required` list per plist rather than checking one hardcoded variable, so a third gate (if ever needed) would be a one-line addition, not a restructure.
- `restart_service.sh`'s numeric-port loop and the new portless loop are two separate `while` blocks inside an `if/else`, not one loop with scattered conditionals — chosen so the diff against the pre-existing numeric-port behavior is trivially auditable (confirmed via `git diff`, see verification below) rather than requiring line-by-line reasoning through interleaved branches.
- Stability window is a `STABILITY_WAIT` variable (default 10, overridable) rather than a literal `10` sprinkled in two places, matching the existing `TEARDOWN_TIMEOUT`/`TIMEOUT` override convention already in the file.

## Deviations from Plan

None — plan executed exactly as written. Both tasks matched their `<action>` blocks; all `<verify>` criteria passed on the first attempt with no fix-forward needed.

## Issues Encountered

None. One observation worth recording per the parent context's instruction (not a deviation, not an issue): `verify_config.sh` passed on the first run after Check C's single `cline config --json` invocation (Check B), with no heal cycle needed — consistent with the 2026-08-30 correction that `contextWindow` is a top-level `settings` field that survives `cline config --json` normalization (only the old `models[]`-based override vanished in the previously-observed Pitfall 5 pattern). The config-guard heal path in `apply_provider_config.sh` remains in place and untouched; it simply wasn't exercised this run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `check_versions.sh` and `restart_service.sh` are both ready for 05-01's plists/services (which own `phase-05/services/` and `phase-05/plists/`) to be checked and restarted through, respectively — the telegram connector's portless restart path (`restart_service.sh <label> none`) is proven to parse and flow, pending the actual label registration in a later plan.
- No blockers. Live pids (flashnext 46573, role-shim 75548, litellm 48525) unchanged; `EXTRA_ALLOW_PATHS` confirmed empty; `phase-05/services/` (owned by the parallel 05-01 plan) was not touched by this plan.

---
*Phase: 05-kanban-telegram-services*
*Completed: 2026-08-30*
