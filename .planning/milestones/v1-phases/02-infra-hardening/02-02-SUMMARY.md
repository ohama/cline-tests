---
phase: 02-infra-hardening
plan: 02
subsystem: infra
tags: [launchd, mlx_vlm, concurrency-cap, plist, macos, backpressure]

# Dependency graph
requires:
  - phase: 02-infra-hardening (plan 01)
    provides: config.env, preflight.sh, restart_service.sh, verify_queueing.sh, uncapped queueing baseline
provides:
  - "--max-num-seqs 1 live on com.ohama.flashnext, restarted and verified"
  - "apply_max_num_seqs.sh — idempotent plist writer (backup-first, plutil-lint-gated)"
  - "restart_service.sh async-bootout race fixed (Step 3b: wait for teardown)"
  - "INF-01 after-evidence: max_overlap=1, queued_count=1, contrasted against uncapped baseline"
  - "CHECKPOINT_ANSWER: proceed-1 (user restart consent, covers 02-03's litellm bounce too)"
affects: [02-03-litellm-network-binding, phase-05-launchd-services]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "launchctl bootout is asynchronous — always poll for label deregistration AND port-free before bootstrap, never bootout-then-immediately-bootstrap"
    - "Queueing evidence must come from [prefill_started, decode_completed] interval overlap in the server log, never from HTTP status codes or in_flight counts alone"

key-files:
  created:
    - phase-02/infra/apply_max_num_seqs.sh
    - phase-02/results/20260829T185628Z-inf01/inf01-verdict.txt
    - phase-02/results/20260829T184656Z-inf01/ (failed-attempt evidence)
  modified:
    - phase-02/infra/restart_service.sh (async-bootout fix, commit 0ca2645, landed by orchestrator between continuation attempts)
    - ~/Library/LaunchAgents/com.ohama.flashnext.plist (live edit, outside repo)

key-decisions:
  - "MAX_NUM_SEQS=1 (proceed-1) approved and applied live — full serialization, not the MAX_NUM_SEQS=2 alternative"
  - "User's restart consent explicitly covers BOTH the flashnext bounce (this plan) and the litellm bounce (plan 02-03) — 02-03 must not re-prompt"
  - "restart_service.sh must always wait for launchd teardown confirmation (label deregistered + port free) before bootstrap — codified as Step 3b, not a one-off workaround"

patterns-established:
  - "Restart helper pattern: bootout -> poll-until-torn-down (label gone AND port free, + settle margin) -> bootstrap -> poll-until-healthy (state=running AND port listening). Applies to every future launchd label this project registers (Phase 5)."

# Metrics
duration: ~15min (this continuation segment; ~24min including the two failed attempts from the prior segment)
completed: 2026-08-30
---

# Phase 2 Plan 02: Concurrency Cap Restart Summary

**flashnext restarted live with `--max-num-seqs 1`, proving queueing (max_overlap 2→1, queued_count 0→1) against the wave-1 uncapped baseline, after fixing a real async-bootout race in the shared restart helper.**

CHECKPOINT_ANSWER: proceed-1

## Performance

- **Duration:** ~15 min (this continuation; Task 3 re-attempt through evidence capture and commits)
- **Started:** 2026-08-29T18:56:16Z (re-apply of cap, this continuation)
- **Completed:** 2026-08-29T18:59:58Z
- **Tasks:** 3/3 (Task 1 done in prior segment, Task 2 checkpoint answered `proceed-1` by the user, Task 3 completed this segment)
- **Files modified:** 1 script fixed upstream (restart_service.sh, by orchestrator, commit 0ca2645) + ~18 evidence files + 1 live plist (outside repo)

## Accomplishments
- `--max-num-seqs 1` is live in both the on-disk plist and the running launchd job for `com.ohama.flashnext` (pid 46573), confirmed by two independent oracles (`launchctl print` and `ps -o command=`)
- Diagnosed and fixed (by the orchestrator, between continuation attempts) a real bug in `restart_service.sh`: `launchctl bootout` is asynchronous, so bootstrapping immediately after it raced flashnext's 104 GiB teardown and failed with an opaque `Bootstrap failed: 5: Input/output error` — twice, deterministically
- With the fix, the restart succeeded on the first attempt of this segment: teardown confirmed after 2s, healthy after 28s total
- Captured genuine interval-overlap evidence of queueing (not just HTTP 200s or `in_flight` counts): `max_overlap=1`, `queued_count=1`, contrasted against the wave-1 uncapped baseline (`max_overlap=2`, `queued_count=0`)
- Preserved the two failed live-restart attempts as evidence (`phase-02/results/20260829T184656Z-inf01/`) — the finding that motivated the fix

## Task Commits

Each task was committed atomically:

1. **Task 1: apply_max_num_seqs.sh — idempotent plist writer, backup first, no restart** - `5666ea1` (feat) — from prior segment
2. **Task 2: checkpoint:decision — approve live restart + confirm cap** - (n/a, user answered `proceed-1`) — from prior segment
3. **Task 3: restart flashnext, confirm healthy, capture INF-01 evidence** - `4da4ffe` (feat)

Additional commits this segment (not a plan task, but real evidence worth keeping per orchestrator instruction):
- `4c34cbc` (fix) — captured the pre-fix failed-restart evidence dir
- Fix for the root cause itself (`restart_service.sh` Step 3b, teardown wait) was already committed by the orchestrator as `0ca2645` before this continuation started

**Plan metadata:** (this commit, to follow)

## Files Created/Modified
- `phase-02/infra/apply_max_num_seqs.sh` - idempotent plist writer (unchanged this segment, re-run only)
- `phase-02/infra/restart_service.sh` - async-bootout fix landed upstream (commit `0ca2645`), exercised successfully this segment
- `~/Library/LaunchAgents/com.ohama.flashnext.plist` - live edit, `--max-num-seqs 1` applied (outside repo, backed up first)
- `phase-02/infra/backups/com.ohama.flashnext.plist.20260829T185616Z` - fresh pre-edit backup for this segment's re-apply (gitignored)
- `phase-02/results/20260829T185628Z-inf01/` - restart log, loaded-arguments (both oracles), queueing probe raw output + log slice, `inf01-verdict.txt`
- `phase-02/results/20260829T185843Z/preflight-post-inf01.txt` - post-restart preflight, PASS
- `phase-02/results/20260829T184656Z-inf01/` - preserved evidence of the two pre-fix failed attempts

## Decisions Made
- **CHECKPOINT_ANSWER: proceed-1** — user approved `MAX_NUM_SEQS=1` (full serialization) and the live restart of `com.ohama.flashnext`. This approval explicitly covers plan 02-03's later `com.ohama.litellm` restart as well; 02-03 must not re-prompt and instead greps this file for `^CHECKPOINT_ANSWER: proceed-[12]$`.
- `restart_service.sh` now unconditionally waits for launchd teardown confirmation (label deregistered via `launchctl print` returning non-zero, AND the port having no listener, plus a 3s settle margin) before every bootstrap, not just for flashnext. This is now a durable property of the shared helper that plan 02-03 (litellm) and Phase 5 (new launchd services) both inherit for free.
- Evidence of queueing must be judged strictly on `[prefill_started, decode_completed]` interval overlap in the server log (`max_overlap`, `queued_count`), never on HTTP status codes or `in_flight` counts, which look identical capped and uncapped.

## Deviations from Plan

### Auto-fixed Issues (documented for completeness — the fix itself landed in a prior orchestrator turn, before this continuation)

**1. [Rule 3 - Blocking] `launchctl bootout` is asynchronous; restart_service.sh raced teardown**
- **Found during:** Task 3, first two live attempts (prior continuation segment)
- **Issue:** `bootout` returns as soon as unload is *requested*, not once the process is actually gone. flashnext holds a 104 GiB model, so teardown takes a few seconds; bootstrapping immediately into a still-registered label produced `Bootstrap failed: 5: Input/output error`, deterministically, twice. A control test on a throwaway label (no heavy process) always succeeded, confirming the timing hypothesis rather than an unrelated macOS issue.
- **Fix:** Added Step 3b to `restart_service.sh`: after bootout, poll (default up to `TEARDOWN_TIMEOUT=120s`) until `launchctl print` no longer finds the label AND the port has no listener, plus a 3s settle margin, before calling bootstrap.
- **Files modified:** `phase-02/infra/restart_service.sh`
- **Verification:** This segment's live restart succeeded on the first attempt with the fix in place: `teardown confirmed after 2s`, healthy after `waited=28s`.
- **Committed in:** `0ca2645` (landed by the orchestrator before this continuation started)

---

**Total deviations:** 1 auto-fixed (1 blocking), landed upstream of this continuation
**Impact on plan:** Necessary correctness fix to the shared restart helper that both this plan and 02-03/Phase 5 depend on. No scope creep — the fix stayed inside `restart_service.sh`, no other files touched.

## Issues Encountered
- Two live restart attempts failed before the fix was diagnosed and applied (see Deviations above). Both times the plan's ROLLBACK block was executed correctly and the service returned to healthy before stopping — no service was left down.
- None encountered in this continuation segment; the restart succeeded on the first attempt with the fix in place.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 02-03 (litellm network binding) can proceed immediately: this plan's `CHECKPOINT_ANSWER: proceed-1` covers its restart consent, and it inherits the fixed `restart_service.sh` — its bounce is documented as sub-second with no model load, so the teardown-wait Step 3b should resolve near-instantly there, but the poll logic handles it either way.
- Phase 5, which will register additional launchd services (Kanban, Telegram), should reuse `restart_service.sh` as-is rather than open-coding bootout/bootstrap — the async-teardown lesson applies to any service with a nontrivial shutdown, not just flashnext.
- No blockers. `role-shim` and `litellm` were untouched by this plan; all three protected services confirmed running post-restart (`preflight --label post-inf01`: PREFLIGHT: PASS).

---
*Phase: 02-infra-hardening*
*Completed: 2026-08-30*
