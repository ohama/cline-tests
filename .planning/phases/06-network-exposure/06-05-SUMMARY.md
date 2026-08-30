---
phase: 06-network-exposure
plan: 05
subsystem: infra
tags: [tailscale, kanban, telegram, cline, sandbox, human-verification]

# Dependency graph
requires:
  - phase: 06-network-exposure (06-04.2)
    provides: network OPEN over https://ohama-2.tail318f12.ts.net:8444/ (Host/Origin-rewriting proxy in front), verify_network.sh standing gate
provides:
  - Kanban status surface proven live over both loopback and the tailnet address (byte-identical board)
  - Telegram typing-indicator static finding recorded as an honest open question (probable-not, but unobserved), user declined the live trial
  - Checkpoint decision (`decline`) recorded verbatim with timestamp
  - A standalone 7-step checklist for a future user-initiated real-token Telegram trial
  - A tracked, out-of-scope sandbox finding: kanban's live server cannot register ANY project because its sandbox denies ~/.gitconfig
affects: [06-06 (phase-close docs/IPAD-CHECKLIST.md must reflect the decline outcome), phase-07, phase-08 (manual must carry both NET-05 halves as human_needed and not overclaim the Telegram indicator)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Honest open-question recording: static/reverse-engineered evidence stated as a probability, never as an observation, when the live client-side behavior was never actually watched"

key-files:
  created:
    - phase-06/results/20260830T071532Z-net05/net05-evidence.md
    - phase-06/results/20260830T071532Z-net05/decision.md
    - phase-06/results/20260830T071532Z-net05/decision-verification.txt
    - phase-06/results/20260830T071532Z-net05/verify_network-out.txt
    - phase-06/results/20260830T071532Z-net05/verify_services-out.txt
    - phase-06/results/20260830T071532Z-net05/kanban-registration-blocker.txt
    - phase-06/results/20260830T071532Z-net05/board-fetch-both-paths.txt
  modified: []

key-decisions:
  - "User declined the project's first real-token Telegram trial. No BotFather token was requested, generated, or fabricated; telegram-connect stays inert with an explicit empty TELEGRAM_BOT_TOKEN."
  - "NET-05's Telegram half recorded as human_needed AND an open question: static evidence makes it PROBABLE the typing indicator does not survive a ~64s wait, but this was never observed by anyone and must never be written as though it were."
  - "The ~/.gitconfig sandbox-denial finding (kanban's live server, running under phase-03's sandbox, cannot register any git-backed project because ~/.gitconfig is outside the sandbox's file-read allowlist) was documented, not fixed -- fixing it means loosening a hardened Phase-3 security boundary or restarting a live service, both out of this plan's scope. Flagged explicitly for Phase 7/8."

patterns-established:
  - "Checkpoint-decline handling: write decision.md with the verbatim answer, confirm zero drift (pgrep/token-slot/git diff), re-run both standing gates, and leave a concrete self-serve checklist for the declined path rather than silently closing the door on it."

# Metrics
duration: ~50min (Task 1 07:15Z-07:21Z across a prior agent turn; checkpoint pause; Task 3 resumed 07:23Z-07:25Z)
completed: 2026-08-30
---

# Phase 6 Plan 05: NET-05 evidence and Telegram trial decision Summary

**Kanban status surface proven live over loopback + tailnet (byte-identical board, both HTTP 200); user declined the first real-token Telegram trial, so NET-05's Telegram half stays an honest open question (probable-not, unobserved) with a self-serve checklist left behind, and a pre-existing kanban sandbox/gitconfig registration blocker was surfaced and flagged for Phase 7/8 rather than silently fixed.**

## Performance

- **Duration:** ~50 min total across the checkpoint pause (Task 1 ~6 min, Task 3 ~2 min of active work)
- **Started:** 2026-08-30T07:15:32Z (Task 1)
- **Completed:** 2026-08-30T07:25:34Z (Task 3)
- **Tasks:** 3/3 (Task 1: auto, Task 2: checkpoint:decision, Task 3: auto)
- **Files modified:** 4 new files in Task 3's commit (16 total across the plan's two commits)

## Accomplishments

- Kanban HTTP surface proven reachable with byte-identical board markup over BOTH
  `http://127.0.0.1:3484/` and `https://ohama-2.tail318f12.ts.net:8444/` — the server-side half
  of NET-05 is proven, not assumed.
- The Telegram typing-indicator static finding (one non-repeating `sendChatAction("typing")`
  call site in the pinned cline 3.0.53 binary, ~5s Telegram-side decay, no resend loop, message
  streaming only after output tokens exist i.e. after the ~64s prefill wait) was copied
  verbatim into the evidence record and left as an open question, never asserted either way.
- The one genuine escalation of this plan — running the project's first real-token Telegram
  trial — was put to the user with full risk disclosure. The user chose `decline`. Nothing was
  injected, generated, or fabricated; no live bot was started.
- NET-05's Telegram half is now recorded with an honest, bounded conclusion: the static
  evidence makes it **probable** the indicator does not survive a ~64s wait, but this was never
  **observed**, and the record says so explicitly rather than blurring the two.
- A standalone 7-step checklist (BotFather token → numeric user id → plist injection → argv-error
  watch → timed observation → cleanup) was left in `decision.md` so the user can run this trial
  themselves later, independent of and in addition to 06-06's formal iPad checklist.
- A pre-existing, out-of-scope finding surfaced during Task 1 — the live kanban server's sandbox
  (`phase-03/sandbox/run_sandboxed.sh`) denies `~/.gitconfig`, so it cannot register ANY
  git-backed project regardless of path — was fully diagnosed, its exploratory write
  side-effects reverted byte-for-byte, and it is preserved here and flagged below for Phase 7/8.
- Both standing gates re-verified after the decline decision: `verify_services.sh` 15/15,
  `verify_network.sh --baseline 20260830T051403Z-baseline` 24/24. Six live pids and network
  posture (tailnet OPEN via `:8444`, port 3000 unbound, `AllowFunnel` single `:8443` key)
  unchanged throughout.

## Task Commits

1. **Task 1: Prove the Kanban status surface, record the Telegram finding honestly** - `ef8db88` (feat)
2. **Task 2: Decide whether to run the project's first real-token Telegram trial** - checkpoint, no commit (user answered `decline` out-of-band)
3. **Task 3: Execute the decision and record it verbatim** - `a67e790` (feat)

**Plan metadata:** (this commit, following) `docs(06-05): complete NET-05 evidence + declined-trial plan`

## Files Created/Modified

- `phase-06/results/20260830T071532Z-net05/net05-evidence.md` - Kanban proof (A), Telegram static finding as open question (B), NET-05 status table (C)
- `phase-06/results/20260830T071532Z-net05/kanban-registration-blocker.txt` - `~/.gitconfig` sandbox-denial root cause transcript
- `phase-06/results/20260830T071532Z-net05/board-fetch-both-paths.txt` - loopback + tailnet board fetch transcript
- `phase-06/results/20260830T071532Z-net05/kanban-list-column-inprogress.txt`, `kanban-list-before.txt`, `kanban-task-create.txt`, `kanban-task-list-help.txt`, `kanban-task-start-help.txt`, `kanban-workspaces-index-BEFORE/AFTER-restore.json`, `scratch-repo-gitinit.txt`, `telegram-current-state.txt` - Task 1 supporting evidence
- `phase-06/results/20260830T071532Z-net05/decision.md` - the checkpoint decision recorded verbatim, NET-05 status table, 7-step self-serve checklist
- `phase-06/results/20260830T071532Z-net05/decision-verification.txt` - zero-drift confirmation (pgrep, token slots, `git diff --stat`)
- `phase-06/results/20260830T071532Z-net05/verify_services-out.txt` - `verify_services.sh` re-run, 15/15
- `phase-06/results/20260830T071532Z-net05/verify_network-out.txt` - `verify_network.sh` re-run, 24/24

## Decisions Made

- **User declined the real-token Telegram trial (`decline`).** No BotFather token was requested,
  generated, or fabricated. No live bot was started. `telegram-connect` stays exactly as Phase 5
  and 06-02 left it — registered, NET-04-guarded, and inert on an explicit empty
  `TELEGRAM_BOT_TOKEN`.
- **NET-05's Telegram half is recorded as `human_needed` AND an open question**, in the same
  spirit as Phase 5's reboot-persistence gap. The static evidence supports a *probable*
  conclusion (the indicator likely does not survive a ~64s wait) but this must never be written
  as an *observed* one — no agent ever ran the trial, no human ever watched a live client.
- **The `~/.gitconfig` sandbox finding is documented, not fixed** (Rule 4 — architectural/
  security-boundary change, out of this plan's declared scope of `phase-06/results/` only, and
  out of its house rules which forbid service/plist changes here). It is a genuine,
  Phase-3-scoped gap: the live kanban server cannot register ANY git-backed project while
  running under the current sandbox profile, because `~/.gitconfig` sits outside
  `workspace/sandbox.sb`'s file-read allowlist and this git version refuses even
  `rev-parse --is-inside-work-tree` without touching it. **This is unrelated to NET-05 or any of
  Phase 6's other four criteria, and does not affect network posture at all — it is preserved
  here so it is not rediscovered from scratch, and is explicitly flagged for Phase 7/8 to pick
  up as its own decision** (loosen the sandbox allowlist, or restart kanban with a scoped
  `GIT_CONFIG_GLOBAL`).

## Deviations from Plan

### Auto-fixed Issues (Task 1, carried into this record)

**1. [Rule 1 - Bug] `kanban task list --column in_progress` returned exit 1, not the plan's assumed exit 0**
- **Found during:** Task 1
- **Issue:** The plan assumed "exit 0 with a (possibly empty) list." The actual result was exit
  1, because no project has ever been registered with this kanban install in this project's
  history.
- **Root cause chased three layers deep:** (1) no registered workspace, (2)
  `workspace/scratch-repo` is not its own git repo (Phase 5's already-documented Pitfall 6), (3)
  registering it hits the live kanban server's sandbox denying `~/.gitconfig` — a systemic,
  path-independent block on registering ANY git-backed project under the current sandbox
  profile.
- **Fix:** Not fixed (Rule 4 territory — an architectural/security-boundary decision, out of
  this plan's declared file scope of `phase-06/results/` only). Documented in full instead,
  with all exploratory write side-effects (the `git init` inside the gitignored
  `workspace/scratch-repo/`, an orphaned entry in `~/.cline/kanban/workspaces/index.json`)
  reverted byte-for-byte, confirmed via before/after diffs.
- **Files modified:** none outside `phase-06/results/` (net zero footprint)
- **Verification:** `kanban-workspaces-index-BEFORE-restore.json` /
  `-AFTER-restore.json` byte-diffed equal to the pristine state; `git status --porcelain
  workspace/` unchanged before/after.
- **Committed in:** `ef8db88` (Task 1 commit)
- **Flagged forward:** explicitly carried into this SUMMARY and into STATE.md for Phase 7/8 —
  this must not be silently lost or rediscovered.

No new deviations occurred during Task 3 (decline branch) — it executed exactly as the plan's
`IF decline:` block specifies.

---

**Total deviations:** 1 auto-fixed/documented (1 Rule 4 — architectural, flagged forward, not
fixed in-plan), carried from Task 1.
**Impact on plan:** No scope creep. The gitconfig finding does not touch network posture, NET-05,
or any of Phase 6's other criteria; it is preserved as a tracked handoff item only.

## Issues Encountered

None beyond the documented deviation above. The checkpoint itself was answered cleanly
(`decline`) with no ambiguity requiring further clarification.

## User Setup Required

None required now. **Optional, self-serve, for later:** if the user wants to resolve NET-05's
open Telegram question themselves, the 7-step checklist in
`phase-06/results/20260830T071532Z-net05/decision.md` (§"Checklist item for later") covers
BotFather token issuance, numeric user id lookup, plist injection point, the known argv-parsing
hazard on first launch, the timed observation protocol (t=10s/30s/64s), and cleanup back to the
inert steady state.

## Next Phase Readiness

- Both NET-05 halves are unambiguous on disk: Kanban status surface = proven server-side;
  Kanban visual-during-wait = `human_needed`; Telegram typing survival = open question
  (probable-not, unobserved); Telegram visual = `human_needed` regardless of the trial decision.
- Network posture, all six live pids, and all standing gates (`verify_services.sh` 15/15,
  `verify_network.sh` 24/24) are unchanged and re-confirmed after this plan.
- `cline` budget spent this plan: 0 (decline branch spends 0, per the plan's own budget table).
- **06-06 must reflect the `decline` outcome accurately** in `phase-06/IPAD-CHECKLIST.md` item
  4b — the Telegram line stays "아직 아무도 확인하지 않았다" (nobody has checked yet), never a
  predicted or assumed result.
- **Phase 7/8 handoff item, not to be rediscovered from scratch:** kanban's live server cannot
  register any git-backed project because its sandbox denies `~/.gitconfig`
  (`phase-06/results/20260830T071532Z-net05/kanban-registration-blocker.txt` has the full
  root-cause transcript). This is a Phase-3-owned sandbox-allowlist decision, unrelated to
  Phase 6's scope.

---
*Phase: 06-network-exposure*
*Completed: 2026-08-30*
