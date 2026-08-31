---
phase: 05-kanban-telegram-services
plan: 03
subsystem: infra
tags: [launchd, readiness-gate, bash, kanban, telegram, sandbox, process-hygiene]

# Dependency graph
requires:
  - phase: 05-kanban-telegram-services (05-01)
    provides: phase-05/services/{config.env,wait_for_port.sh,wait_for_upstream.sh,run_kanban_service.sh,run_telegram_service.sh}
  - phase: 05-kanban-telegram-services (05-02)
    provides: phase-02/infra/restart_service.sh portless-label support (referenced in wrapper header comments, not exercised by this plan)
  - phase: 02-infra-hardening
    provides: phase-02/infra/verify_no_regression.sh (INF03 standing gate)
  - phase: 03-sandbox
    provides: phase-03/sandbox/verify_sandbox.sh (standing sandbox gate) and the punched-path convention that explains the stdio SIGABRT class
provides:
  - "phase-05/results/20260830T014424Z-svc04/ — timestamped foreground evidence for the SVC-04 dead-port case, the listening-but-not-ready case (both health and alias sub-cases), the production recovery case, the launchd-shaped stdio pre-check, the empty-token telegram idle proof, and the kanban port inventory, with a README.md three-part verdict for research Open Question 2"
  - "phase-05/services/wait_for_upstream.sh — outer-loop WAITED accounting fixed to use real wall-clock ($SECONDS) instead of only the tail sleep, so the bounded timeout is now accurate when stage 1 (TCP) is the failing stage"
affects: [05-04, 05-05, phase-close-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Foreground prove-before-register: exercise both crash-loop generators (dead upstream, listening-but-unready upstream) by hand, with the shipped wrapper's own config.env overrides, before any launchd registration exists to retry them unsupervised"
    - "Emulate 'listening but not ready' with a throwaway python3 -m http.server rather than disturbing the real dependency — preflight-check the port free, capture the pid explicitly, tear down by that exact pid"
    - "Sandboxed-child stdio must redirect to a punched path ($HOME/.cline/logs/, or any path under the workspace/bench allow-list) — redirecting to ANY unpunched path (not just under $HOME) reproduces the bare native-stack-trace SIGABRT this project has now hit five times"

key-files:
  created:
    - phase-05/results/20260830T014424Z-svc04/ (evidence dir, ~35 files including README.md)
  modified:
    - phase-05/services/wait_for_upstream.sh (WAITED accounting bug fix)

key-decisions:
  - "wait_for_upstream.sh's WAITED variable now tracks $SECONDS since loop start rather than hand-accumulating only the tail-sleep amount — found live because this plan's dead-port case is the first exercise of stage-1(TCP)-as-failing-stage; 05-01's live checks only forced stage 2/3, where TCP passes near-instantly and the bug never surfaced"
  - "Task 3's kanban-wrapper stdio must redirect to $HOME/.cline/logs/ (proven-punched) rather than phase-05/results/ (outside the sandbox's allowed workspace) — the SIGABRT class is not specific to paths under $HOME, it's any path outside the sandbox's read/write allow-list"

patterns-established:
  - "Pattern: when a readiness-gate's internal stage check is itself a bounded sub-loop, the outer loop's timeout bookkeeping must measure real wall-clock time, not accumulate only its own sleep calls, or the effective bound silently drifts from the configured value"

duration: ~20min
completed: 2026-08-30
---

# Phase 5 Plan 03: Prove-before-register (SVC-03/SVC-04 foreground proof) Summary

**Foreground-only evidence run proving both SVC-04 crash-loop generators (dead port, listening-but-unready upstream) exit bounded and low-CPU rather than spinning, that the wrapper recovers against the real production stack, that the launchd-shaped stdio redirect doesn't reproduce the project's recurring SIGABRT, and that the telegram wrapper idles honestly with zero `cline` invocations — while finding and fixing a real timing bug in the shared readiness gate along the way, all without registering anything or disturbing the live 104 GiB flashnext.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-08-30T01:44Z
- **Completed:** 2026-08-30T01:58Z
- **Tasks:** 3/3
- **Files modified:** 1 (`wait_for_upstream.sh` bug fix) + ~35 evidence files created under `phase-05/results/20260830T014424Z-svc04/`

## Accomplishments

- **Task 1 (SVC-04 dead-port/recovery/stdio):** Preflight gates (`verify_no_regression.sh` INF03:PASS, `verify_sandbox.sh` 16/16 CASES) passed before anything started. Dead-port case: exit 1 at ~36-41s against a 30s configured timeout, every `%cpu` sample `0.0`, 3484 never listened, kanban never spawned. Listening-but-not-ready case (the decisive one): a throwaway `python3 -m http.server` made the TCP stage genuinely succeed while two forced sub-cases showed the health stage and then the alias stage correctly rejecting it (exit 1 at ~20-25s each, correct stage named in both, every `%cpu` sample `0.0` across 9 samples) — a bare TCP probe could never have distinguished this from real readiness. Recovery case: run with zero probe overrides against the live production stack, launchd-shaped stdio redirect (`>>$HOME/.cline/logs/kanban.{log,err}`), gate passed within one interval, kanban bound 127.0.0.1:3484 with its pid preserved through the whole exec chain, zero `Abort trap`/`Unexpected` occurrences.
- **Task 2 (empty-token idle):** telegram wrapper observed for ~96s (6 samples, 15s spacing): same pid throughout, `%cpu` `0.0` on every sample, log line count unchanged start-to-end, `connect telegram` process count `0` for the whole window — proven honest idle, not a disguised crash loop.
- **Task 3 (port inventory + Open Question 2):** kanban's own TCP footprint measured as exactly one endpoint (`127.0.0.1:3484`), machine-wide `listen-all.txt` confirms port 3000 appears nowhere, README.md's three-part verdict resolves the coexistence question (structurally impossible with the token slot empty; kanban's measured footprint; the `--rpc-address`/`CLINE_RPC_ADDRESS` residual named for Phase 6).
- Live stack (flashnext 46573, role-shim 75548, litellm 48525) confirmed unchanged before/after every task. `EXTRA_ALLOW_PATHS` confirmed empty at the end. `cline` invocations: 0/0 (budget was zero). No stray processes left running (verified via `ps aux` sweeps and `lsof` checks after every teardown).

## Task Commits

Each task was committed atomically, plus one deviation-fix commit ahead of Task 1's evidence:

1. **Fix: wait_for_upstream.sh wall-clock accounting** - `4ef64d2` (fix)
2. **Task 1: dead-port, listening-but-not-ready, recovery, stdio pre-check evidence** - `733d1ca` (feat)
3. **Task 2: empty-token idle proof** - `f31f660` (feat)
4. **Task 3: port inventory, RPC coexistence verdict, results README** - `23192ae` (feat)

**Plan metadata:** (this commit, following)

## Files Created/Modified
- `phase-05/services/wait_for_upstream.sh` - outer-loop `WAITED` now uses `$SECONDS`-based real elapsed time instead of hand-accumulated tail-sleep-only bookkeeping
- `phase-05/results/20260830T014424Z-svc04/` - full evidence tree: preflight captures (`pre-inf03/`, `pre-sandbox/`, `final-inf03/`), dead-port (`deadport*`), listening-but-not-ready (`notready*`), recovery (`recovery*`, `kanban.{log,err}`), idle (`idle*`), port inventory (`kanban-ports.txt`, `listen-all.txt`, `port3000-check.txt`, `portinv-kanban.{log,err}`), and `README.md` (the verdict)

## Decisions Made
- Fixed `wait_for_upstream.sh`'s timing bug in place (Rule 1 — bug found while proving this exact plan's own required observation, "exit at roughly the configured timeout") rather than documenting the 72s-vs-30s discrepancy as an accepted fact — the bound must actually mean what it says, since the README this same plan writes states the retry-cadence claim ("one process spawn per ~(timeout + ThrottleInterval)") as evidenced fact.
- Redirected Task 3's kanban-wrapper stdio to `$HOME/.cline/logs/` (the already-proven-punched path from Task 1c) after the first attempt — redirected to `phase-05/results/` — crashed with the documented SIGABRT class; captured to the punched path and copied the logs into `$RES` afterward, following the established capture-then-copy pattern from 03-04/04-02/04-04 rather than widening the sandbox.
- Kept the stray incomplete `phase-05/results/20260830T013906Z-svc04/` and unrelated `phase-01/results/2026-08-29T232117Z-17292/` directories untouched (both untracked, pre-existing before this execution, neither referenced by this plan's own evidence) rather than deleting data this plan didn't create.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `wait_for_upstream.sh`'s outer loop under-counted real elapsed time when stage 1 (TCP) was the failing stage**
- **Found during:** Task 1, first (uncorrected) run of case (a), the dead-port test
- **Issue:** `WAITED` was hand-accumulated by only the tail-of-loop sleep amount. Stage 1 is itself a bounded retry (`wait_for_port.sh` called with `TIMEOUT_S=$INTERVAL_S`), so every outer iteration with TCP failing already spent up to `INTERVAL_S` seconds *inside* that call before the outer tail sleep added another `INTERVAL_S` — silently doubling the effective per-iteration cost without it showing up in `WAITED`. Measured: 30s configured timeout, 72s actual wall time (2.4x over), while the script's own log still claimed "timed out after 30s". Never caught in 05-01 because those live checks only forced stage 2/3 failures, where TCP passes near-instantly.
- **Fix:** Switched `WAITED` to `$SECONDS`-based wall-clock accounting (measured from loop start), correct regardless of which stage fails or how long its checks take.
- **Files modified:** `phase-05/services/wait_for_upstream.sh`
- **Verification:** Sanity-tested against the live stack post-fix — default pass still exits 0 in ~0.08s; forced stage-1 failure now bounds to the configured 10s (measured 10.18s, was ~2x before); forced stage-2 failure unchanged at the configured 10s (measured 9.66s). Re-ran case (a) with the fix: 30s configured -> ~36-41s actual, a reasonable "roughly the bounded timeout" match instead of the prior 2.4x overshoot.
- **Committed in:** `4ef64d2` (separate fix commit, ahead of Task 1's evidence commit)

**2. [Rule 3 - Blocking] Task 3's first kanban-wrapper attempt crashed with the project's recurring sandboxed-stdio SIGABRT**
- **Found during:** Task 3, first attempt at the port-inventory run
- **Issue:** stdio was redirected to `"$RES"/portinv-kanban.{log,err}` — under `phase-05/results/`, a path outside the sandbox's allowed workspace (`workspace/scratch-repo`, `$HOME/.cline`). The sandboxed child died with a bare native stack trace (no application code reached) before printing anything past `resolved allow list:` — the same failure class as 03-03 F8 / 03-04 / 04-02 / 04-04, confirming the hazard generalizes to any unpunched path, not only paths under `$HOME`.
- **Fix:** Re-ran with stdio redirected to `$HOME/.cline/logs/portinv-kanban.{log,err}` (the same punched path Task 1's recovery case already used successfully), then copied the resulting logs into `$RES` for the evidence record. No sandbox widening, `EXTRA_ALLOW_PATHS` untouched.
- **Files modified:** none (execution-only fix, no script changed)
- **Verification:** Second attempt succeeded cleanly — kanban bound 127.0.0.1:3484, zero `Abort trap`/`Native stack trace` in the copied `portinv-kanban.err`.
- **Committed in:** `23192ae` (Task 3 commit; the crashed first attempt produced no artifacts worth preserving and was not separately committed)

---

**Total deviations:** 2 auto-fixed (1 bug in a shared wave-1 artifact, 1 blocking execution mistake self-corrected using an already-established project pattern).
**Impact on plan:** Both fixes were necessary for this plan's own required observations to hold true (an accurate "roughly the configured timeout" bound; a successful, uncrashed port-inventory run). No scope creep — neither touched anything outside `phase-05/`, no sandbox widening, no service registered.

## Issues Encountered

A `pgrep -f 'connect telegram'`/`pgrep -f 'cline'` false-positive was observed during Task 2: a broad `pgrep -f cline` matches this execution harness's own shell wrapper process (its sourced snapshot script's git/cwd commands contain the substring "cline-tests" from this repository's own path). This is not an actual `cline` binary invocation — the substantive check (`connect telegram` count, which stayed `0` for the entire window) was unaffected. Recorded explicitly in `idle-pgrep.txt` so the evidence doesn't misread as a false pass. Not a deviation — no code or plan behavior changed because of it.

## User Setup Required

None - no external service configuration required. This plan registers nothing; no plist installation, no `launchctl bootstrap`, no token injection.

## Next Phase Readiness

- `phase-05/services/wait_for_upstream.sh` now has an accurate bounded timeout regardless of which readiness stage fails — 05-04/05-05 (plist installation) can trust the `(UPSTREAM_WAIT_TIMEOUT + ThrottleInterval)` retry-cadence claim without re-deriving it.
- `phase-05/results/20260830T014424Z-svc04/README.md` hands Phase 6 the exact residual it needs for the RPC-coexistence question: kanban's measured footprint (3484 only) and the named fix (`--rpc-address`/`CLINE_RPC_ADDRESS`) if the telegram connector's future RPC host collides once a real token is injected.
- No blockers. Live pids (flashnext 46573, role-shim 75548, litellm 48525) unchanged throughout; `EXTRA_ALLOW_PATHS` confirmed empty; `git diff --stat phase-01/ phase-02/ phase-03/ phase-04/` empty; no stray processes left running.
- Two untracked, pre-existing artifacts from before this execution remain in `git status` and were deliberately left untouched (not created by this plan, not referenced by its evidence): `phase-01/results/2026-08-29T232117Z-17292/` (unrelated) and `phase-05/results/20260830T013906Z-svc04/` (an incomplete prior attempt at this same evidence — superseded by `20260830T014424Z-svc04/`, the directory this plan actually produced and committed).

---
*Phase: 05-kanban-telegram-services*
*Completed: 2026-08-30*
