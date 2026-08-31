---
phase: 05-kanban-telegram-services
plan: 06
subsystem: infra
tags: [launchd, sync.sh, mirror, standing-gate, kanban, telegram, vmmap]

# Dependency graph
requires:
  - phase: 05-kanban-telegram-services (05-04, 05-05)
    provides: "com.ohama.kanban and com.ohama.telegram-connect registered and live under launchd"
provides:
  - "SVC-05 closed: both plists mirrored byte-identically into ~/local-llm-settings/launchagents/, sync.sh --check exits 0"
  - "phase-05/services/verify_services.sh — the standing Phase 5 gate for Phase 6 to call before/after network exposure"
affects: [06-network-exposure, 05-07-phase-close]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Out-of-repo file edits (outside .git) are captured as before-copy + after-copy + unified diff under phase-05/results/, never assumed recoverable from git log"
    - "anti-orphan proof for a sandbox-exec'd pid uses vmmap (libsandbox.1.dylib mapped into that exact pid), never a ps-args grep for the literal string sandbox-exec — execve() replaces argv"

key-files:
  created:
    - phase-05/services/verify_services.sh
    - phase-05/results/20260830T023144Z-svc05/ (sync.sh before/after/diff, sync-run, synccheck before/after, mirror STATE.md/git-status snapshots, README)
    - phase-05/results/20260830T023720Z-gate/ (run1, run2, negative-control transcripts + verdicts, README)
  modified:
    - "~/local-llm-settings/sync.sh (OUTSIDE this repo's git history — LABELS array + STATE.md port-row list, purely additive; captured as before/after/diff in phase-05/results/20260830T023144Z-svc05/)"

key-decisions:
  - "sync.sh's LABELS array and STATE.md port-row list are the sanctioned, minimal edit point for SVC-05 — the mirrored launchagents/*.plist files themselves are still only ever written by sync.sh, never hand-edited"
  - "verify_services.sh's anti-orphan check for kanban uses vmmap (libsandbox.1.dylib mapped into the live pid) instead of a ps-args grep for the string sandbox-exec, reusing 05-04's already-established finding that execve() makes that string structurally unobservable post-exec"

patterns-established:
  - "verify_services.sh: CHECK: PASS|FAIL <name> per assertion, 0/1/2 exit contract, --out-dir flag, read-only launchctl print only — the template for any future Phase 5/6 standing gate"

# Metrics
duration: 9min
completed: 2026-08-30
---

# Phase 5 Plan 06: SVC-05 mirror registration + standing services gate Summary

**Extended `~/local-llm-settings/sync.sh`'s hardcoded `LABELS` array (an out-of-repo file, edited additively and captured as before/after/diff) to mirror both new plists byte-identically, then wrote `phase-05/services/verify_services.sh`, a 15-check read-only standing gate verified twice live (identical PASS lines) plus once under a deliberate negative control (exit 1).**

## Performance

- **Duration:** 9 min
- **Started:** 2026-08-30T02:31:44Z
- **Completed:** 2026-08-30T02:40:35Z
- **Tasks:** 2
- **Files modified:** 1 (out-of-repo `sync.sh`) + 1 created (`verify_services.sh`) + 17 evidence files

## Accomplishments

- Confirmed the vacuous-pass failure mode was real, not hypothetical: `sync.sh --check` reported
  "일치한다" (exit 0) *before* the edit, while `com.ohama.kanban`/`com.ohama.telegram-connect`
  sat completely untracked in the `LABELS` array.
- Made the minimal, additive edit to `~/local-llm-settings/sync.sh` (two labels appended to
  `LABELS=(...)`, one port row appended to the STATE.md regeneration list) — nothing else in the
  213-line file changed. Captured as `sync.sh.before` / `sync.sh.after` / `sync.sh.diff` since git
  here will never see this edit.
- Ran `sync.sh` (live → mirror, the only sanctioned direction): both plists now byte-identical
  (`cmp` exit 0 both ways) under `~/local-llm-settings/launchagents/`; `sync.sh --check` now exits
  0 with the vacuous-pass mode closed for real; the regenerated mirror `STATE.md` lists both
  labels `running`/`✅ 자동` and the new `3484` port row shows a live listener.
- Documented pre-existing, unrelated mirror drift (uncommitted `flashnext`/`litellm` plist and
  `STATE.md`/`SHA256SUMS` changes inside `~/local-llm-settings`'s own git repo, from Phase 2's
  earlier `sync.sh` run) without deciding whether to commit it — that repo is the user's, not
  ours.
- Wrote `phase-05/services/verify_services.sh` (453 lines): per-label running+settled pid sampling
  (3 samples over ~20s), kanban port+HTTP, anti-orphan (kanban confinement via `vmmap`, telegram
  empty-token orphan sweep with the relaxed non-empty-token branch), port-3000 hygiene, both
  plists' pin gates, `EXTRA_ALLOW_PATHS` emptiness, log growth watch (WARN not FAIL), and SVC-05
  mirror freshness — 15 checks total.
- Ran the gate twice live: both exit 0, `diff` of the two runs' `CHECK:` lines is empty (15/15
  identical). Ran a deliberate negative control (`KANBAN_PORT=39999`): exit 1, exactly the two
  port/HTTP checks FAIL, all 13 others — including the pid-stability samples against the real,
  unaffected kanban process — still PASS.
- Live pids (flashnext 46573, role-shim 75548, litellm 48525, kanban 53894,
  telegram-connect 56669) confirmed unchanged before, during, and after both tasks. `cline`
  invocations: 0.

## Task Commits

Each task was committed atomically:

1. **Task 1: SVC-05 — track both labels in sync.sh and mirror the plists** - `9d6075e` (feat)
2. **Task 2: phase-05/services/verify_services.sh — the standing gate for Phase 6** - `a75d75e` (feat)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified

- `~/local-llm-settings/sync.sh` (outside this repo) — `LABELS` array + STATE.md port-row list
  gain the two new entries; nothing else changed.
- `phase-05/results/20260830T023144Z-svc05/` — `sync.sh.before`, `sync.sh.after`, `sync.sh.diff`,
  `sync-run.txt`, `synccheck-before.txt`, `synccheck-after.txt`, `mirror-state-md.txt`,
  `mirror-git-status-before.txt`, `mirror-git-status-after.txt`, `README.md` — the full
  before/after evidence trail for the out-of-repo edit.
- `phase-05/services/verify_services.sh` — new standing gate.
- `phase-05/results/20260830T023720Z-gate/` — `run1/`, `run2/`, `negative-control/` (each with
  `transcript.txt` + `verify_services-verdict.txt`), `README.md`.

## Decisions Made

- Treated `sync.sh`'s tracked-label array and its STATE.md port-row list as the two sanctioned
  edit points for SVC-05 — both are hardcoded bash arrays inside the tool itself, not the mirrored
  snapshot, so editing them (additively, nothing removed/reordered) does not violate the
  live→mirror-only house rule; the mirrored `launchagents/*.plist` files were still only ever
  written by `sync.sh`'s own copy step.
- Left the pre-existing drift inside `~/local-llm-settings`'s own git repo (uncommitted
  `flashnext`/`litellm` plist changes from Phase 2) untouched and undecided — recorded as fact in
  the README, not resolved, since that repo belongs to the user.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — plan-authoring trap, not a code bug] Anti-orphan kanban check rewritten to use `vmmap`, not a `ps args` grep for "sandbox-exec"**
- **Found during:** Task 2 (writing `verify_services.sh`'s assertion 4)
- **Issue:** The plan's own text for assertion 4 said the check should show "the sandbox-exec/kanban chain" via `ps -o args=`. Measured directly against the live kanban pid (53894): `ps -o args=` reads `node /opt/homebrew/bin/kanban --no-open --host 127.0.0.1 --port 3484` — no `sandbox-exec` substring anywhere. This is not a bug in the sandbox or the wrapper; `sandbox-exec` performs a real `execve()` into the wrapped command, and `execve()` replaces the process's own recorded argv. 05-04's decision log already established this exact fact for the same pid family; writing the grep the plan described would have repeated that already-diagnosed authoring mistake and produced a gate check that could never pass regardless of correctness.
- **Fix:** Split the check into two sub-assertions that together prove what the plan's assertion actually needs: identity via a plain `ps args` substring match on `kanban` (which the true argv does contain), and confinement via `vmmap <pid> | grep -i sandbox` showing `libsandbox.1.dylib` mapped into that exact pid's own memory — the same method 05-04 used to prove `sandbox_init()` actually ran inside a post-exec pid.
- **Files modified:** `phase-05/services/verify_services.sh` (written directly with the corrected check; no separate fix-up commit needed since this was caught before the first commit)
- **Verification:** `anti-orphan-kanban-sandboxed` PASSed identically in both live gate runs (`run1`, `run2`); in the negative-control run it still PASSed (correctly unaffected by the unrelated `KANBAN_PORT` override), proving the check measures what it claims to.
- **Committed in:** `a75d75e` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 Rule 1 — plan-authoring trap)
**Impact on plan:** The fix was necessary for the gate to be meaningfully checkable at all (the plan's literal wording described an assertion that could never pass by construction). No scope creep — same evidence class (05-04's `vmmap` precedent) already established in this project.

## Issues Encountered

None beyond the one documented deviation above.

## User Setup Required

None — no external service configuration required. (The existing Telegram token-injection recipe from 05-05 remains the only outstanding manual step, and it is out of this plan's scope.)

## Next Phase Readiness

- SVC-05 (ROADMAP Phase 5 criterion 4) holds by measured evidence: both plists live under
  `~/local-llm-settings/launchagents/`, byte-identical to the installed originals, `sync.sh --check`
  exits 0, and the mirror `STATE.md` reflects both labels as running/boot-enabled.
- `phase-05/services/verify_services.sh` is ready for Phase 6 to call before and after opening
  anything to the network — it is read-only, re-runnable, has a proven non-vacuous negative
  control, and spends zero `cline` invocations.
- Remaining Phase 5 work is 05-07 (docs/services.md + full gate sweep + reboot-verification
  checkpoint) — out of this plan's scope.
- No blockers. Live pids unchanged throughout; `EXTRA_ALLOW_PATHS` empty; `cline` invocations: 0.

---
*Phase: 05-kanban-telegram-services*
*Completed: 2026-08-30*
