---
phase: 02-infra-hardening
plan: 04
subsystem: infra
tags: [launchd, mlx_vlm, litellm, regression-gate, mirror-sync, docs, macos]

# Dependency graph
requires:
  - phase: 02-infra-hardening (plan 02)
    provides: "--max-num-seqs 1 live on com.ohama.flashnext (INF-01), pid 46573"
  - phase: 02-infra-hardening (plan 03)
    provides: "--host 127.0.0.1 live on com.ohama.litellm (INF-02), pid 48525"
provides:
  - "verify_no_regression.sh — the INF-03 standing regression gate (8 checks: flags-present, all-services-running, hop3/hop2/hop1 health, full-chain via 127.0.0.1, full-chain via localhost hostname, direct-:8000 no-deadlock probe)"
  - "~/local-llm-settings mirror synced live -> mirror, zero diff against both edited plists"
  - "docs/infra-hardening.md — values, rationale, OOM limitation, evidence paths, rollback runbook, house rules"
  - "Phase 2 closed: all three ROADMAP success criteria re-verified simultaneously true"
affects: [phase-05-launchd-services, phase-06-network-exposure]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PlistBuddy ProgramArguments dump lines are indented — grep -qx against a raw value fails; must strip leading whitespace (awk '{$1=$1; print}') before an exact-match grep"
    - "Standing regression gate pattern: order checks cheapest-and-most-diagnostic-first so a FAIL localizes to a hop (flags -> services -> hop3 -> hop2 -> hop1 -> full chain by IP -> full chain by hostname -> deadlock probe), never a single opaque pass/fail"

key-files:
  created:
    - phase-02/infra/verify_no_regression.sh
    - docs/infra-hardening.md
    - phase-02/results/20260829T191031Z-inf03/ (INF-03 first-pass evidence + sync.txt)
    - phase-02/results/20260829T191110Z-inf03/ (post-sync re-verify)
    - phase-02/results/20260829T191241Z/ (verify_queueing.sh --label after, phase-close)
    - phase-02/results/20260829T191249Z-inf02-verify/ (verify_lan_bind.sh, phase-close)
    - phase-02/results/20260829T191251Z/ (preflight.sh --label phase-close)
  modified:
    - ~/local-llm-settings/launchagents/com.ohama.flashnext.plist (mirror, via sync.sh)
    - ~/local-llm-settings/launchagents/com.ohama.litellm.plist (mirror, via sync.sh)
    - ~/local-llm-settings/STATE.md, ~/local-llm-settings/SHA256SUMS (sync.sh auto-regenerated)

key-decisions:
  - "verify_queueing.sh only accepts literal --label before|after (hardcoded validation) — the plan's suggested `--label after-final` is not a valid invocation. Ran `--label after` instead; assertion content is identical (QUEUEING: PASS, max_overlap=1, queued_count=1)"
  - "role-shim implements /v1/models directly (200), so Check 4's TCP-connect fallback path was written but not exercised live — kept in the script as a genuine fallback for any future hop that lacks the route"

patterns-established:
  - "verify_no_regression.sh is the phase's standing health gate: read-only, re-runnable, safe for Phase 5 (Kanban+Telegram) and Phase 6 (network exposure) to call before/after bringing new services up"

# Metrics
duration: ~12min
completed: 2026-08-30
---

# Phase 2 Plan 04: Full-Chain Regression Gate + Mirror Sync + Docs Summary

**INF-03 gate proves the flashnext alias still returns a real completion through litellm:4000 -> role-shim:8011 -> mlx_vlm.server:8000 via both 127.0.0.1 and the localhost hostname; mirror synced live->mirror with drift limited to exactly the two intended plist edits; docs/infra-hardening.md closes Phase 2 with values, rationale, the OOM limitation, evidence paths and a copy-pasteable rollback runbook.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-08-30T04:08Z (approx.)
- **Completed:** 2026-08-30T04:13Z
- **Tasks:** 2/2
- **Files modified:** 1 script created, 1 doc created, 2 live-mirror plists synced (outside repo), ~6 evidence directories

## Accomplishments
- `verify_no_regression.sh` created and run: `INF03: PASS`, all 8 checks PASS, zero FAILs — hardening flags still present, all three services running, all three hops individually healthy, the full chain returns a non-empty completion (`"Hi there! How can I help you"`) via both `127.0.0.1` and the `localhost` hostname, and a direct `:8000` probe confirms `--max-num-seqs 1` serializes without deadlocking the queue
- Confirmed re-runnable: ran the gate 4 times across this plan (initial pass, post-fix pass, post-sync pass, phase-close pass) — identical `INF03: PASS` every time, zero service disturbance (pids unchanged throughout: flashnext=46573, role-shim=75548, litellm=48525)
- `~/local-llm-settings/sync.sh --check` before sync showed exactly 2 items of drift (`com.ohama.flashnext.plist`, `com.ohama.litellm.plist`) — confirming wave 1's "no pre-existing MIRROR_DRIFT" baseline held and this phase's two intended edits are the entirety of the drift. Ran `sync.sh` (live -> mirror only); both `diff` checks against the mirror are now empty and `sync.sh --check` reports "실제 시스템과 일치한다" (matches live system)
- `docs/infra-hardening.md` written: before/after `ProgramArguments`, rationale for both flag choices, the explicit statement that `--max-num-seqs` does NOT fix the single-request 32K Metal OOM, evidence paths for every stage of the phase, and copy-pasteable rollback blocks (with the actual existing backup filenames) for both services, plus the async-bootout house rule for Phase 5
- Phase-close re-verification: all three ROADMAP Phase 2 success criteria confirmed simultaneously true after the sync — `verify_queueing.sh --label after` (`QUEUEING: PASS`, max_overlap=1/queued_count=1), `verify_lan_bind.sh` (`INF02: PASS`), `verify_no_regression.sh` (`INF03: PASS`), `preflight.sh --label phase-close` (`PREFLIGHT: PASS`, zero `MIRROR_DRIFT`)
- No service was restarted at any point in this plan — verified by pid stability across all four gate runs

## Task Commits

Each task was committed atomically:

1. **Task 1: verify_no_regression.sh — the INF-03 gate, and run it** - `cc8cadb` (test)
2. **Task 2: Sync the mirror and write docs/infra-hardening.md** - `b013343` (docs)

## Files Created/Modified
- `phase-02/infra/verify_no_regression.sh` - the INF-03 standing regression gate, 8 ordered checks, PASS/FAIL per check into `inf03-verdict.txt`, non-zero exit on any FAIL
- `docs/infra-hardening.md` - Phase 2 closing record (Korean prose, English code/paths): 무엇을 바꿨나 / 왜 이렇게 골랐나 / 한계 / 증거 / 롤백 / 하우스 룰
- `~/local-llm-settings/launchagents/com.ohama.flashnext.plist` - mirror updated via `sync.sh`, now byte-identical to live
- `~/local-llm-settings/launchagents/com.ohama.litellm.plist` - mirror updated via `sync.sh`, now byte-identical to live
- `~/local-llm-settings/STATE.md`, `~/local-llm-settings/SHA256SUMS` - auto-regenerated by `sync.sh` (not hand-edited)
- `phase-02/results/20260829T191031Z-inf03/` - first INF-03 PASS evidence (post-fix) + `sync.txt` (sync.sh output)
- `phase-02/results/20260829T191110Z-inf03/` - INF-03 re-run confirming sync did not disturb anything live
- `phase-02/results/20260829T191241Z/` - `verify_queueing.sh --label after` phase-close evidence
- `phase-02/results/20260829T191249Z-inf02-verify/` - `verify_lan_bind.sh` phase-close evidence
- `phase-02/results/20260829T191251Z/` - `preflight.sh --label phase-close` evidence, zero `MIRROR_DRIFT`

## Decisions Made
- Used `--label after` (not the plan-suggested `--label after-final`) for the final `verify_queueing.sh` re-check, because the script hard-validates the label against the literal set `{before, after}` and rejects anything else with a usage error. The assertion itself (`QUEUEING: PASS`, `max_overlap=1`, `queued_count=1`) is identical regardless of label spelling.
- Kept `verify_no_regression.sh` strictly read-only per the plan's HARD constraint — every check is a `curl`/`launchctl print`/`PlistBuddy` read, no plist edit, no restart, anywhere in either task.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Check 1 (hardening-flags-present) false-negative on first run**
- **Found during:** Task 1, first live run of `verify_no_regression.sh`
- **Issue:** `PlistBuddy -c "Print :ProgramArguments"` output indents every array element with leading whitespace (e.g. `    1`, not `1`). The script's Check 1 used `grep -qx "$MAX_NUM_SEQS"` / `grep -qx "$LITELLM_BIND_HOST"` for an exact-line match against the raw value, which never matches an indented line — the check failed even though both flags were genuinely present and correct, producing `INF03: FAIL hardening-flags-present`.
- **Fix:** Piped the `ProgramArguments` dump through `awk '{$1=$1; print}'` (trims leading/trailing whitespace) before the exact-match `grep -qx`.
- **Files modified:** `phase-02/infra/verify_no_regression.sh` (fixed before the Task 1 commit — no separate fix commit needed)
- **Verification:** Re-ran the script; `INF03: PASS`, Check 1 now `CHECK: PASS hardening-flags-present`. Re-ran a second and third time with the same result.
- **Committed in:** `cc8cadb` (Task 1 commit — fixed before commit)

---

**Total deviations:** 1 auto-fixed (1 bug, self-contained to the new script, found and fixed before the task commit — same class of self-inflicted verification-string bug as 02-03's `verify_lan_bind.sh` fix, but this time on the write side of the comparison rather than the log-message side).
**Impact on plan:** Cosmetic-adjacent parsing fix inside a brand-new script; no behavior change to any live service, no scope creep.

## Issues Encountered
None beyond the deviation above. `sync.sh` ran clean on the first attempt; both post-sync diffs were empty immediately.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- **Phase 2 (INF-01, INF-02, INF-03) is fully closed.** All three ROADMAP success criteria hold simultaneously as of the phase-close re-verification in this plan, not just sequentially across plans 02-02/02-03/02-04.
- `phase-02/infra/verify_no_regression.sh` is the standing health gate for the rest of the project. **Phase 5** (Kanban + Telegram both live) and **Phase 6** (network exposure) should call it before and after bringing new services up — it is read-only, re-runnable at any time, and fails loudly (non-zero exit, `INF03: FAIL <check>`) with a hop-localized reason if either hardening flag reverts or the chain breaks.
- The async-bootout lesson (`launchctl bootout` is asynchronous; always wait for teardown confirmation before `bootstrap`) is now written into `docs/infra-hardening.md`'s 하우스 룰 section for Phase 5 to find without re-deriving it. `restart_service.sh` already encodes the fix; any *new* restart helper Phase 5 writes for its own launchd services must reuse the same bootout -> teardown-poll -> bootstrap -> healthy-poll sequence.
- `~/local-llm-settings/` mirror is clean (`sync.sh --check` reports zero drift). No plan after this one should need to run `sync.sh` again unless a future phase edits another live plist.
- No blockers for Phase 3.

---
*Phase: 02-infra-hardening*
*Completed: 2026-08-30*
