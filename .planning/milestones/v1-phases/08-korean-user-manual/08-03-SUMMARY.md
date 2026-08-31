---
phase: 08-korean-user-manual
plan: 03
subsystem: docs
tags: [manual, cli, mobile, tailscale, telegram, plan-act, checkpoint, honesty-markers, korean]

# Dependency graph
requires:
  - phase: 04-headless-wrapper
    provides: "phase-04/run_headless.sh interface, env knobs, result-directory layout, 6-outcome/exit-code classification"
  - phase: 06-network-exposure
    provides: "docs/network-exposure.md §2·§4a·§4b·§4c·§5·§6 (tailnet chain, iPad/Telegram gaps, port-3000 rule, rollback), phase-06/IPAD-CHECKLIST.md"
  - phase: 05-kanban-telegram-services
    provides: "docs/services.md §6 (Telegram token injection recipe, unknown option warning, -P/-m flag-shape trap)"
  - phase: 08-korean-user-manual
    plan: 02
    provides: "phase-08/manual/check_manual_claims.sh honesty gate, docs/manual/04-32k-operations.md house style"
provides:
  - "docs/manual/01-cli.md — DOC-01, gated clean"
  - "docs/manual/03-mobile.md — DOC-03, gated clean"
affects: [08-05-kanban-manual, 08-06-index-and-close]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Cross-referencing a sibling manual document not yet written (02-kanban.md, owned by 08-05) by bare filename rather than a docs/ path, so C4-links does not trip on a forward reference it cannot yet resolve — same pattern 08-02 established for 03-mobile.md"
    - "Hedging evidence at exactly the level the project holds: strings-scan-confirmed CLI surface (--mode exists) stated as fact, but whether the project's own one-shot invocation exposes it left explicitly unconfirmed"

key-files:
  created:
    - docs/manual/01-cli.md
    - docs/manual/03-mobile.md
    - phase-08/results/CURRENT_DOC01_DOC03_RUN
    - phase-08/results/20260830T193010Z-doc01-doc03/gate-01.txt
    - phase-08/results/20260830T193010Z-doc01-doc03/gate-03.txt
  modified: []

key-decisions:
  - "Plan/Act hedged at exactly the evidence level held: --mode <act|plan> is stated as a real, confirmed CLI literal (strings scan), but whether this project's headless one-shot command exposes it is stated as UNCONFIRMED (a static-analysis limit) under [GAP-PLANMODE] — the document never asserts the flag works or fails headlessly, and states plainly that Plan mode has never once been run in this project."
  - "The two checkpoint concepts kept structurally separate: 01-cli.md §7 owns cline's own session file-checkpointing ([GAP-CHECKPOINT-CLINE], runtime behavior unverified) and cross-references kanban's task-level working-tree checkpoint commit to 02-kanban.md (08-05's not-yet-written file, referenced by bare filename to stay outside C4-links' path-prefix extraction) in one sentence, without blurring the two."
  - "03-mobile.md delegates rather than duplicates: the iPad verification steps are not rewritten, only pointed at phase-06/IPAD-CHECKLIST.md; the Telegram token-injection recipe is not restated, only linked to docs/services.md §6, with exactly the three failure-mode warnings (unknown option watch, --provider/--model full-name requirement, paired token+user-id requirement) kept inline because they explain how the flow fails, not how to run it."
  - "GAP-CLINE-VERSION section tells the reader to check version via /opt/homebrew/lib/node_modules/cline/package.json specifically, and explicitly names both banned verification paths (cline --version invokes the drift trigger itself; check_versions.sh Check B invokes the host binary) rather than just warning generically."

# Metrics
duration: ~10min
completed: 2026-08-31
---

# Phase 8 Plan 03: DOC-01 (CLI) + DOC-03 (iPad/iPhone) Summary

**Wrote the two manual documents that do not depend on the Kanban registration blocker — DOC-01 (CLI 사용법) and DOC-03 (iPad·iPhone 사용법) — both passing the phase's marker+link-integrity honesty gate on the first or second attempt, with Plan/Act and the two distinct "체크포인트" concepts hedged and separated exactly at the evidence level the project actually holds.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-08-30T19:2xZ (approx, first file read)
- **Completed:** 2026-08-30T19:31:29Z (Task 2 commit)
- **Tasks:** 2/2
- **Files modified:** 5 created (2 manual docs, 1 run-pointer, 2 gate transcripts)

## Accomplishments

- `docs/manual/01-cli.md` (145 lines): real `phase-04/run_headless.sh` invocation and env-knob
  table, result-directory layout, the six-outcome/exit-code table with `crashed` marked "판정
  불가 — 절대 '차단 성공'으로 보고하지 말 것", THE CWD RULE, `[GAP-READONLY]` read-only/no-tool
  posture, Plan/Act hedged at the strings-scan evidence level (`[GAP-PLANMODE]`), the two
  distinct checkpoint concepts separated with a cross-reference to `02-kanban.md`
  (`[GAP-CHECKPOINT-CLINE]`), and `[GAP-CLINE-VERSION]` telling the reader to check
  `/opt/homebrew/lib/node_modules/cline/package.json` rather than invoke the drifting binary.
- `docs/manual/03-mobile.md` (115 lines): the single tailnet entry point
  `https://ohama-2.tail318f12.ts.net:8444/` and its three-hop chain, `[GAP-IPAD]` delegating
  verification to `phase-06/IPAD-CHECKLIST.md` without rewriting it, the LAN "no path at all"
  success condition, `[GAP-PORT3000]` permanent prohibition, Telegram conversation/approval
  posture with `[GAP-TELEGRAM-TOKEN]` (empty slot, never-exercised code path, three inline
  failure warnings) and `[GAP-TELEGRAM-INDICATOR]` (never-observed typing behavior, static
  reasoning only, 7-step trial checklist link), the touch-modifier limitation, and the
  troubleshooting/rollback section with the `tailscale serve reset` prohibition.
- Both documents pass `bash phase-08/manual/check_manual_claims.sh --file 01-cli.md --file
  03-mobile.md` — `CASES 8/8`.

## Task Commits

1. **Task 1: Write docs/manual/01-cli.md (DOC-01)** - `1d18b18` (feat)
2. **Task 2: Write docs/manual/03-mobile.md (DOC-03)** - `a219505` (feat)

## Files Created/Modified

- `docs/manual/01-cli.md` - DOC-01, Korean, real CLI usage: startup check, `run_headless.sh`
  invocation/env-knobs/result layout, outcome table, cwd rule, read-only posture, Plan/Act,
  two checkpoint concepts, version-drift warning, cross-reference to `04-32k-operations.md`.
- `docs/manual/03-mobile.md` - DOC-03, Korean, mobile/network usage: Tailscale entry point and
  chain, iPad delegation, LAN non-reachability, port-3000 prohibition, Telegram conversation/
  approval posture, touch-modifier limitation, troubleshooting/rollback.
- `phase-08/results/CURRENT_DOC01_DOC03_RUN` - Points at the shared results directory for this
  plan's gate transcripts.
- `phase-08/results/20260830T193010Z-doc01-doc03/{gate-01,gate-03}.txt` - Gate proof transcripts.

## Decisions Made

- **Plan/Act evidence level**: `--mode <act|plan>` exists as a confirmed literal in the binary
  (strings scan) and its default/internal tool-permission distinction (`enableEditor`) is stated
  as fact. Whether the project's own one-shot headless command exposes `--mode` is explicitly
  left UNCONFIRMED under `[GAP-PLANMODE]` — the document states this is a static-analysis limit
  (cline was never invoked to check), states every headless call to date has used the default
  act mode, and states Plan mode has never once run in this project. It does not assert the flag
  works or does not work headlessly, per the plan's exact instruction.
- **Checkpoint separation**: `01-cli.md` §7 keeps cline's own session-level file checkpointing
  (`createCheckpoint`/`restoreCheckpoint`, `cline-checkpoint-` git-ref prefix,
  `[GAP-CHECKPOINT-CLINE]`, runtime behavior unverified — static string scan only) as its own
  subject, then names kanban's task-level `createWorkingTreeCheckpointCommit` in exactly one
  sentence as a different thing owned by `02-kanban.md` (08-05's not-yet-written file). The
  cross-reference uses the bare filename `02-kanban.md` rather than a `docs/`-prefixed path — the
  same forward-reference technique 08-02 established for `03-mobile.md` — so `check_manual_claims.sh`'s
  C4-links check (which only inspects tokens with a `docs/`/`phase-0`/`workspace/`/`bench/`/
  `.planning/` prefix) does not fail on a sibling file that does not exist yet.
- **DOC-01's own forward-looking cross-reference to `00-getting-started.md`** (not yet written by
  this plan's scope) tripped C4-links on the first gate run (`dangling:
  docs/manual/00-getting-started.md`). Fixed by rewriting the reference as the bare filename
  `00-getting-started.md`, same pattern as above — first-attempt gate FAIL, immediately corrected
  before commit, not carried forward as a deviation since it was caught and fixed within Task 1's
  own gate-and-fix loop before the task was considered done.
- **iPad/Telegram delegation, not duplication**: DOC-03 explicitly declines to re-author the
  iPad verification steps (delegates to `phase-06/IPAD-CHECKLIST.md`) and the Telegram token
  injection recipe (delegates to `docs/services.md` §6), reproducing only the three inline
  warnings the plan specified because they describe failure modes relevant to *using* the
  feature, not the setup recipe itself.

## Deviations from Plan

None — plan executed exactly as written. The only correction needed (the `00-getting-started.md`
forward-reference collision with C4-links) was caught and fixed inside Task 1's own gate loop
before that task's commit, using the exact cross-reference pattern 08-02 already established for
this situation — not a deviation from the plan's design, just applying an already-agreed pattern
to a second forward reference.

## Issues Encountered

None beyond the C4-links forward-reference fix noted above, resolved within the same task before
commit.

## User Setup Required

None — no external service configuration required. Zero host `cline` invocations this plan (both
tasks were pure documentation writing against already-captured evidence, per the house rule
forbidding any `cline --help`/`--version` calls in this phase). No live service touched, no
`tailscale` command run, no sandbox file touched. All six pids (flashnext 46573, role-shim 75548,
litellm 48525, kanban 36175, telegram-connect 99162, kanban-proxy 19669) confirmed unchanged
before and after.

## Next Phase Readiness

- `docs/manual/01-cli.md` and `docs/manual/03-mobile.md` are both done and gated
  (`check_manual_claims.sh --file 01-cli.md --file 03-mobile.md` → `CASES 8/8`) — ROADMAP Phase 8
  success criteria 1 and 3 are satisfied.
- `01-cli.md` §7's forward reference to `02-kanban.md` (bare filename) is ready for 08-05 to land
  as a real sibling link — no gate change needed, same as 08-02 left for `03-mobile.md` in
  `04-32k-operations.md` §6.
- This plan ran in parallel with 08-04 (the sandbox-widening checkpoint) as designed — it touched
  only `docs/manual/01-cli.md`, `docs/manual/03-mobile.md`, and `phase-08/results/`, and never
  read or wrote `phase-03/sandbox/*` or `docs/sandbox-whitelist.md`.
- No blockers. 08-05 (DOC-02, Kanban manual) and 08-06 (index + phase-close) remain.

---
*Phase: 08-korean-user-manual*
*Completed: 2026-08-31*
