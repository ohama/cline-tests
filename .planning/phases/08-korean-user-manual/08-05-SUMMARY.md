---
phase: 08-korean-user-manual
plan: 05
subsystem: docs
tags: [kanban, manual, korean, sandbox-exec, git-worktree, honesty-gate]

# Dependency graph
requires:
  - phase: 08-korean-user-manual
    provides: "08-01's live registration fix (VERDICT: REGISTERED, kanban pid 36175) and 08-04's DECLINED sandbox-widening decision (WORKTREE_STATUS=WORKTREE=UNAVAILABLE)"
provides:
  - "docs/manual/02-kanban.md -- DOC-02, written entirely from live transcripts, not from source reading"
  - "phase-08/results/20260830T194933Z-doc02/ -- the live-evidence directory the document is written from (board/subcommands/card-lifecycle/diff-and-checkpoint/dependency-chain transcripts, both upstream verdicts copied in, gate-02.txt)"
affects: [08-06 (phase-close gate sweep and REQUIREMENTS status for DOC-02, which must record it as partially met)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Branch-on-pointer-file: resolve an upstream plan's verdict via its stable CURRENT_RUN-style pointer file rather than inferring a timestamped path from prose, so a manual's claims are driven by the actual recorded outcome"

key-files:
  created:
    - docs/manual/02-kanban.md
    - phase-08/results/20260830T194933Z-doc02/ (upstream/, board.txt, subcommands.txt, card-lifecycle.txt, diff-and-checkpoint.txt, dependency-chain.txt, worktree-unavailable.txt, kanban-version.txt, server.txt, server-pre.txt, gate-02.txt)
    - phase-08/results/CURRENT_DOC02_RUN
  modified: []

key-decisions:
  - "Both upstream verdicts were resolved strictly from their pointer files (CURRENT_RUN, CURRENT_WIDENING_RUN) and copied into this plan's own run directory before any manual content was written, per the plan's explicit instruction not to infer paths from prose."
  - "DOC-02 is recorded as partially met: registration/cards/diff-surface-check/dependency chain all work and are documented from live transcripts, but git worktree add remains impossible in this deployment (user DECLINED the metadata-only $HOME widening in 08-04), so kanban's per-task worktree flow is documented as unavailable, not softened into 'not yet verified.'"
  - "No CLI subcommand for diff review was found in the full `kanban task --help` scan; the document says so plainly rather than describing a web-UI flow that was never opened and verified."
  - "The CLI has no generic move-to-column command (only `task start` for backlog->in_progress and `task trash` for ->done); the manual documents this gap explicitly in the 카드 section rather than implying arbitrary drag-and-drop-equivalent CLI moves exist."

patterns-established: []

# Metrics
duration: 7min
completed: 2026-08-31
---

# Phase 8 Plan 05: DOC-02 (웹 Kanban 사용법) Summary

**Wrote `docs/manual/02-kanban.md` entirely from live evidence gathered against the now-registered Kanban server, documenting cards/registration/dependency-chain as working and per-task worktree as unavailable with the reproduced cause — DOC-02 is recorded as partially met, not promoted.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-08-30T19:49:33Z
- **Completed:** 2026-08-30T19:55:43Z
- **Tasks:** 2/2
- **Files modified:** 1 manual document + 1 live-evidence directory (14 files) under `phase-08/results/`

## Accomplishments
- Resolved both upstream verdicts strictly via their stable pointer files (`CURRENT_RUN` → `VERDICT: REGISTERED`, `CURRENT_WIDENING_RUN` → `WORKTREE=UNAVAILABLE`), copied both into this plan's own run directory before writing a single line of manual content
- Exercised the full REGISTERED-path evidence live from inside `$SANDBOX_WORKDIR` (`workspace/scratch-repo`): board listing, a full `kanban task --help` subcommand scan (all 8 verbs plus `hooks`), a real create→list→delete card lifecycle, a real link→list→unlink→delete dependency-chain probe, and a `git log`/`git worktree list` check that confirms no per-task checkpoint commit or worktree has ever been created (consistent with worktree being unavailable)
- Wrote `docs/manual/02-kanban.md` (198 lines) covering 접속, 프로젝트 등록 (git-toplevel substitution mechanism + `GIT_CONFIG_GLOBAL`), 카드, diff 리뷰, `[GAP-CHECKPOINT-KANBAN]` (kept distinct from cline's session checkpointing, cross-referenced to `01-cli.md` §7), `[GAP-WORKTREE]` (stated plainly as unsupported, `지원되지 않는다`, with the reproduced cause and the exact declined change), 의존 체인, `[GAP-READONLY]`, and restart/troubleshooting
- Discovered, live, that the CLI exposes no generic column-move command and no diff/review subcommand at all — both written into the manual as honest gaps rather than assumed web-UI behavior
- `bash phase-08/manual/check_manual_claims.sh --file 02-kanban.md` exits 0 (`CASES 4/4`) after one self-inflicted false-positive link-integrity hit was fixed (see Deviations)

## Task Commits

Each task was committed atomically:

1. **Task 1: Collect live Kanban evidence, driven by the two upstream verdicts** - `71f55ac` (feat)
2. **Task 2: Write docs/manual/02-kanban.md (DOC-02)** - `5fe53d4` (docs)

_No separate plan-metadata commit issued yet — this SUMMARY/STATE.md update follows as the final closeout commit per the execute-plan workflow._

## Files Created/Modified
- `docs/manual/02-kanban.md` - DOC-02, Korean, 198 lines, written entirely from `phase-08/results/20260830T194933Z-doc02/`'s transcripts
- `phase-08/results/20260830T194933Z-doc02/upstream/{VERDICT.txt,DECISION.md,WORKTREE_STATUS}` - the two upstream verdicts, copied verbatim before any branching
- `phase-08/results/20260830T194933Z-doc02/{server-pre.txt,server.txt}` - reachability + `verify_services.sh` (15/15 PASS) before writing any evidence
- `phase-08/results/20260830T194933Z-doc02/{board.txt,subcommands.txt,card-lifecycle.txt,diff-and-checkpoint.txt,dependency-chain.txt}` - the REGISTERED-path live evidence the manual's procedure steps are written from
- `phase-08/results/20260830T194933Z-doc02/worktree-unavailable.txt` - the reason and exact would-be fix, taken from 08-04's `DECISION.md`
- `phase-08/results/20260830T194933Z-doc02/kanban-version.txt` - drift guard, confirms `0.1.70`
- `phase-08/results/20260830T194933Z-doc02/gate-02.txt` - `check_manual_claims.sh --file 02-kanban.md` transcript, `MANUAL_CLAIMS_GATE: PASS`
- `phase-08/results/CURRENT_DOC02_RUN` - stable pointer to this run directory

## Decisions Made
- Branched strictly on the two upstream verdict files rather than any assumption about what "should" have happened by this point in the phase — both were REGISTERED / UNAVAILABLE, and the document was written exactly to match.
- DOC-02 is only partially met: kanban's cards, registration, and dependency chain all work and are documented from live transcripts; per-task worktree does not work in this deployment and is documented as such, with a pointer to the exact would-be fix and its measured cost rather than a vague "not yet verified."
- Where the CLI's own surface turned out not to have a capability the plan assumed might exist (diff review, arbitrary column moves), the manual says so plainly instead of describing a web-UI flow that was never opened and confirmed.

## Deviations from Plan

### Auto-fixed Issues (Rule 1 - self-inflicted bug in this plan's own authoring)

**1. False-positive dangling-link hit from a quoted git commit message**
- **Found during:** Task 2, first `check_manual_claims.sh` run
- **Issue:** The manual quoted the live commit message `init scratch repo (phase-08/01)` verbatim inside the diff-review section. The gate's link-integrity check (`C4-links`) extracts any `phase-0`-prefixed token and requires it to resolve to a real repo path; `phase-08/01` (a plan-number reference inside a quoted commit message, not a filesystem path) does not resolve, so the check correctly flagged it as dangling.
- **Fix:** Rewrote the sentence to reference the commit by hash (`3d8ef27`) and message quote ("init scratch repo") separately, without reproducing the `phase-08/01` substring, preserving the same factual content.
- **Files modified:** `docs/manual/02-kanban.md`
- **Verification:** `check_manual_claims.sh --file 02-kanban.md` re-run, `CASES 4/4`, `MANUAL_CLAIMS_GATE: PASS`
- **Committed in:** `5fe53d4` (the fix was made before the first commit of this file, so no separate commit was needed)

No other deviations — Rules 2-4 did not apply. No architectural change, no sandbox change, and no live service mutation was needed or attempted.

## Issues Encountered
None beyond the self-inflicted authoring issue above. The pre-existing `verify_network.sh`/`verify_bench.sh` single-check delta against the frozen phase-06/07 kanban-pid baseline (53894 vs the current 36175) documented in `08-01-SUMMARY.md` remains unchanged by this plan — this plan never ran either of those two gates.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `docs/manual/02-kanban.md` exists, passes its dedicated gate, and is ready for `08-06`'s phase-close full-manual sweep (once `00-getting-started.md` exists, the full five-file gate will also need that file present — out of this plan's scope).
- DOC-02 must be recorded as **partially met** in REQUIREMENTS/ROADMAP tracking by whichever plan closes out Phase 8's requirement checklist — the per-task worktree flow does not work in this deployment, and that fact must not be softened or promoted downstream.
- The six live pids (flashnext 46573, role-shim 75548, litellm 48525, kanban 36175, telegram-connect 99162, kanban-proxy 19669) were unchanged throughout this plan; no service was restarted; `EXTRA_ALLOW_PATHS` was never touched; `phase-03/` was never touched; host `cline` invocation count for this plan: 0.
- If a future plan reopens the worktree-widening decision, `docs/sandbox-whitelist.md` §9 and `phase-08/results/20260830T193634Z-widening/DECISION.md` (referenced, not duplicated, by this plan's manual output) contain everything needed to apply the approved branch without re-diagnosis.

---
*Phase: 08-korean-user-manual*
*Completed: 2026-08-31*
