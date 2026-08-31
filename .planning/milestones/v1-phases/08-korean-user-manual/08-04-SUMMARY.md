---
phase: 08-korean-user-manual
plan: 04
subsystem: infra
tags: [sandbox-exec, macos-seatbelt, git-worktree, kanban, security-boundary]

# Dependency graph
requires:
  - phase: 03-sandbox
    provides: gen_sandbox_profile.py, verify_sandbox.sh, ALLOWED_REPOS.json / sandbox.sb generation
  - phase: 08-korean-user-manual
    provides: "08-01's live kanban registration fix; 08-RESEARCH.md §A6b's reproduced diagnosis of git worktree add failing inside the sandbox"
provides:
  - "A recorded, user-made DECLINE decision on metadata-only $HOME sandbox widening -- phase-03/ is byte-identical to git HEAD"
  - "phase-08/results/<UTC>-widening/DECISION.md: the reproduced no-widening-fix-exists cause, the operation-keyword-specificity SBPL finding, the measured cost, and the full would-be render_profile()/verify_sandbox.sh/test-suite diff, so a future re-decision does not require re-diagnosis"
  - "docs/sandbox-whitelist.md §9: permanent engineering record of the same, in Korean, with literal file-read-data/file-read-metadata/file-write* strings"
  - "phase-08/results/WORKTREE_STATUS = WORKTREE=UNAVAILABLE, the single file 08-05 branches on"
affects: [08-05 (DOC-02's worktree section must be written as unavailable/partially-met, not promoted or softened), any future plan reopening the sandbox-widening question]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Decision-first recording: DECISION.md's first line is written to disk (DECLINED) before any other action in the task, so the record of the answer can never be lost even if execution is interrupted mid-task"
    - "Would-be-change-on-decline: when a user declines a measured, ready-to-apply change, the exact diff and its measured cost are written down in full at decline time, not just the fact of declining -- avoids re-diagnosis if the decision is revisited"

key-files:
  created:
    - phase-08/results/20260830T193634Z-widening/DECISION.md
    - phase-08/results/20260830T193634Z-widening/README.md
    - phase-08/results/20260830T193634Z-widening/no-change-proof.txt
    - phase-08/results/20260830T193634Z-widening/gates-pre/ (six standing gates, negative-control, saved profile, pids)
    - phase-08/results/20260830T193634Z-widening/post-write-verify/ (post-doc-change re-verification)
    - phase-08/results/CURRENT_WIDENING_RUN
    - phase-08/results/WORKTREE_STATUS
  modified:
    - docs/sandbox-whitelist.md (new §9)

key-decisions:
  - "User selected DECLINE at the Task 1 checkpoint: keep the sandbox boundary exactly as Phase 3 shipped it. Zero files under phase-03/ were touched (verified: git diff --stat phase-03/ empty both immediately after the decision and again at final plan-level verification)."
  - "The would-be change (render_profile() diff, verify_sandbox.sh:167 precheck move, four breaking test assertions plus one missing regression-guard test, and the measured cost) was written down in full in both DECISION.md and docs/sandbox-whitelist.md §9, so this does not have to be re-diagnosed if revisited later."
  - "DOC-02 (08-05) is recorded as only partially met, plainly and without softening -- git worktree add stays impossible in this deployment, so Kanban's per-task worktrees do not work."

patterns-established: []

# Metrics
duration: 7min
completed: 2026-08-30
---

# Phase 08 Plan 04: Sandbox-Widening Decision (DECLINED) Summary

**User declined the measured metadata-only `$HOME` sandbox widening; the security boundary stays byte-identical to what Phase 3 shipped, and the full would-be change plus its exact cost is recorded on disk so it never needs re-diagnosis.**

## Performance

- **Duration:** 7 min (this continuation session; Task 1's checkpoint itself was reached in a prior session with nothing executed or committed before it)
- **Started:** 2026-08-30T19:36:34Z
- **Completed:** 2026-08-30T19:43:37Z
- **Tasks:** 2 of 2 remaining tasks completed (Task 1 was the checkpoint itself, already resolved by the user's answer)
- **Files modified:** 1 tracked file (`docs/sandbox-whitelist.md`); 0 files under `phase-03/`

## Accomplishments
- Recorded the user's DECLINE decision to disk first, before anything else, as the immutable first line of `DECISION.md`
- Proved with `git diff --stat phase-03/` (empty, both right after the decision and at final plan-level verification) that the sandbox boundary was not touched
- Wrote the full would-be `render_profile()` diff, the `verify_sandbox.sh:167` precheck move, all four breaking test assertions, and one missing regression-guard test into both `DECISION.md` and `docs/sandbox-whitelist.md` §9, so a future reconsideration does not require re-diagnosing 08-RESEARCH.md §A6b from scratch
- Recorded the measured (not estimated) cost of the declined widening: stat-level metadata under `$HOME` would become readable for already-known paths; content, directory listing, and writes would stay denied
- Wrote `phase-08/results/WORKTREE_STATUS = WORKTREE=UNAVAILABLE` as the single unambiguous file 08-05 branches on

## Task Commits

1. **Task 2: Execute the decision — record it (DECLINED branch)** - `8e8e5f5` (docs)
2. **Task 3: Record the decision in docs/sandbox-whitelist.md and write handoff files** - `dfb3fc5` (docs)
3. **Final plan-level verification sweep** - `ce75f5e` (docs)

_Task 1 (the `checkpoint:decision`) produced no commit of its own — it was resolved by the user's answer, delivered via this continuation's prompt._

## Files Created/Modified
- `phase-08/results/20260830T193634Z-widening/DECISION.md` - first line `DECLINED`, the user's verbatim answer, the reproduced no-widening-fix-exists cause (three call-shape variants, kernel log), the four-way SBPL ordering experiment, the full would-be `render_profile()` diff, the `verify_sandbox.sh:167` precheck move, all four breaking test assertions plus the missing regression guard, and the measured cost
- `phase-08/results/20260830T193634Z-widening/no-change-proof.txt` - `git diff --stat phase-03/` output (empty)
- `phase-08/results/20260830T193634Z-widening/gates-pre/` - all six standing gates, negative-control baseline, saved current profile, and the six live pids, captured before the decision branch executed
- `phase-08/results/20260830T193634Z-widening/post-write-verify/` - re-run of `verify_sandbox.sh`, `verify_network.sh`, `verify_bench.sh` after the docs write, to confirm nothing regressed
- `phase-08/results/20260830T193634Z-widening/README.md` - run-level summary: decision, what changed (nothing), rollback (not applicable), pointers
- `phase-08/results/CURRENT_WIDENING_RUN` - pointer to this run directory, for 08-05
- `phase-08/results/WORKTREE_STATUS` - `WORKTREE=UNAVAILABLE`, the single file 08-05 branches on
- `docs/sandbox-whitelist.md` - new `## 9. worktree 와 $HOME 메타데이터 결정 (2026-08-31, 08-04)` section: the reproduced cause, the corrected SBPL operation-keyword-specificity finding, the measured cost, the DECLINED decision, and the full would-be code change, with the literal strings `file-read-data`, `file-read-metadata`, `file-write*` present so a reader can diff-check against the profile without decoding prose
- Various `phase-0{2,3,5,6}/results/<timestamp>-*/` directories - read-only transcripts generated as a side effect of running the standing-gate scripts (`verify_sandbox.sh`, `verify_no_regression.sh`, `verify_services.sh`, `verify_network.sh`, `verify_bench.sh`) before and after the decision; consistent with the project's existing convention of tracking these generated evidence directories (459 pre-existing tracked artifacts under `phase-03/results/` alone)

## Decisions Made
- The user declined the metadata-only `$HOME` widening at the Task 1 checkpoint, choosing to keep the sandbox boundary exactly as Phase 3 shipped it over enabling `git worktree add` / Kanban's per-task worktrees.
- Because the widening was already fully measured and proven working in isolation (08-RESEARCH.md §A6b-4, on a scratch profile only), the decline branch's obligation was to preserve that evidence in full rather than let it evaporate — done via `DECISION.md` and `docs/sandbox-whitelist.md` §9, both containing the exact diff, the exact precheck line move, the exact test breaks, and the exact measured cost.
- DOC-02 (08-05) is recorded as only partially met, plainly, per the user's explicit instruction not to promote or soften this.

## Deviations from Plan

None — plan executed exactly as written on its DECLINE branch. No Rule 1-4 deviations were needed; the pre-existing `verify_network.sh`/`verify_bench.sh` gate failures (see Issues Encountered) are a known condition from plan 08-01 (explicitly documented in `08-01-SUMMARY.md`'s own key-decisions as intentionally left unpatched), not something this plan introduced or was asked to fix, and fixing them would require editing files (`phase-06/net/`, `phase-07/bench/config.env`) outside this plan's `files_modified` scope and outside the DECLINE branch's explicit "do exactly this and nothing more" instruction.

## Issues Encountered
- `verify_network.sh` (check 15, `live-pids-stable`) and `verify_bench.sh` (check B10) both fail on a stale expected kanban pid (`53894`) baked into `phase-06/results/20260830T051403Z-baseline/inventory.txt` and `phase-07/bench/config.env`'s `LIVE_PIDS_STR`, from before plan 08-01 restarted kanban to its current pid `36175`. This is pre-existing drift, already documented as an accepted, intentionally-unpatched condition in `08-01-SUMMARY.md`'s key-decisions, is outside this plan's scope, and was not touched here. All other four standing gates plus the negative control pass, and `verify_sandbox.sh` itself (the gate that matters for this plan) passes 4/4 both before and after.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- 08-05 can read `phase-08/results/WORKTREE_STATUS` (`WORKTREE=UNAVAILABLE`) unambiguously to write DOC-02's worktree section as unavailable/partially-met.
- The security boundary (Phase 3's guarantee) is intact and unmodified: `~/.gitconfig` content unreadable, `$HOME` unlistable, `bench/` unreachable, `EXTRA_ALLOW_PATHS` empty, `workspace/sandbox.sb` unchanged, no service restarted.
- If a future phase reopens this decision, `phase-08/results/20260830T193634Z-widening/DECISION.md` and `docs/sandbox-whitelist.md` §9 contain everything needed to apply the approved branch without re-running 08-RESEARCH.md §A6b's diagnosis.
- Blocker/concern carried forward (not introduced by this plan): the stale kanban-pid baseline in `phase-06/results/.../inventory.txt` and `phase-07/bench/config.env` still causes `verify_network.sh`/`verify_bench.sh` to report a single check failure each; whichever phase next touches those baselines should refresh them to `36175`.

---
*Phase: 08-korean-user-manual*
*Completed: 2026-08-30*
