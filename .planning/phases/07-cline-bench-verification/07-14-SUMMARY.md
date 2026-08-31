---
phase: 07-cline-bench-verification
plan: 14
subsystem: testing
tags: [cline-bench, remediation, compaction, contextWindow, decision-checkpoint, flashnext]

# Dependency graph
requires:
  - phase: 07-cline-bench-verification (07-11, 07-12, 07-13)
    provides: per-task root-cause forensics (context-ceiling arithmetic, token ladder), the
      classifier-audit's confirmed defect list, and the corrected fail-context/fail-oom verdict
      instrument plus the named finding that real-bench `auto_compaction` events did not prune
      messages in either of the 2 stored completed instances
provides:
  - A candidate (A-F) x root-cause (5 mechanisms) matrix with per-task arithmetic, showing no
    reachable candidate (A, B, D, E) closes any of the 3 measured deficits, and naming C
    (`--compaction basic`) as the one genuinely untested, promising lever
  - A determinate (non-indeterminate) recommendation: no change to `settings.contextWindow`,
    with its cost, falsification condition, and an explicit Core Value scope-check for 07-15/07-16
  - A recorded, verbatim user decision (`SELECTION: doc-only`) plus a separately-resolved
    follow-up decision on the `--compaction basic` mismatch (deferred, not exercised) and a
    correction voiding `phase-01/results/exp-basic/` as evidence for that lever
affects: [07-15 (executes doc-only: no config change), 07-16/future gap phases (compaction-basic
  as a named, unstarted follow-up), PROJECT.md Core Value wording (qualification recommended,
  not made here)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Consciously-deferred-lever pattern: when a checkpoint's canonical option set cannot route
      to a candidate the evidence itself flagged as promising, record that mismatch and the
      user's explicit choice to defer it as a distinct, separately-labeled decision inside
      DECISION.md — never let it be silently absorbed into whichever canonical label was picked,
      and never let 07-15's inability to act on it read as an oversight."
    - "Void-evidence correction pattern: when a stored experiment superficially looks like it
      tested a question but used a broken/non-representative config (here: contextWindow nested
      inside models[], so the 128k fallback engaged instead of the real ceiling), record the
      voiding explicitly in the decision record itself, not just in the analysis document, so a
      future reader who finds the old run directory does not mistake it for counter-evidence."

key-files:
  created:
    - phase-07/results/20260831T011037Z-remediation/README.md
    - phase-07/results/20260831T011037Z-remediation/CANDIDATE-MATRIX.md
    - phase-07/results/20260831T011037Z-remediation/RECOMMENDATION.md
    - phase-07/results/20260831T011037Z-remediation/DECISION.md
  modified: []

key-decisions:
  - "SELECTION: doc-only. Matches RECOMMENDATION.md's own recommendation (no contextWindow
    change) — not a coincidence, the user was shown the recommendation before choosing."
  - "The recommendation not to change contextWindow is determinate, not indeterminate: M4
    (agentic-mode compaction completes without pruning, confirmed in 2/2 real events) means a
    lower contextWindow changes WHEN an ineffective operation fires, not WHETHER it helps — this
    is a mechanism-level finding, not an absence of evidence."
  - "--compaction basic (Candidate C) is the one candidate the matrix scores as genuinely
    promising and untested, but none of the plan's four canonical options routes to it because
    07-15's apply mechanism only handles contextWindow. The user, asked separately, chose to
    record it as a follow-up only ('후속 과제로 기록만') rather than widen this phase's scope to
    exercise it live or synthetically now."
  - "phase-01/results/exp-basic/ (an earlier --compaction basic experiment run this session) does
    NOT count as prior testing of that lever and must not be cited toward it: that run's
    contextWindow sat inside models[], not at the settings top level, so the project's own known
    128k-fallback bug engaged instead of the real 29000/32768 ceiling. --compaction basic remains
    untested against a working top-level config. Recorded explicitly in DECISION.md so this is
    never silently contradicted later."
  - "accept-limit was explicitly NOT selected and the recommendation argues against treating this
    as a hardware ceiling: two of the three deficits are narrow (123 and 459 tokens) and the one
    candidate that targets the confirmed defect (compaction strategy) is untested, not disproven."

patterns-established: []

# Metrics
duration: 55min
completed: 2026-08-31
---

# Phase 07 Plan 14: Remediation Decision Summary

**Candidate-versus-root-cause matrix ruled out every reachable remediation lever
(contextWindow, tool-output cap, max_tokens floor, memory contention) on arithmetic or confirmed-
defect grounds, the user selected `doc-only` (no config change, matching the plan's own
recommendation), and the one untested-but-promising lever (`--compaction basic`) was recorded as
a consciously deferred follow-up rather than an oversight.**

## Performance

- **Duration:** ~55 min
- **Started:** 2026-08-31T01:10:37Z (results directory timestamp / safety snapshot)
- **Completed:** 2026-08-31T02:05:35Z (Task 3 commit)
- **Tasks:** 3/3 completed (Task 3 spanned a blocking checkpoint across two agent sessions)
- **Files modified:** 4 created, 0 modified

## Accomplishments

- Built a candidate (A-F) x root-cause (5 mechanisms) matrix with per-task arithmetic
  (`CANDIDATE-MATRIX.md`), tracing every required-headroom figure to `07-11`'s `token-ladder.tsv`
  and scoring three explicit trial `contextWindow` values against the measured (not synthetic)
  overshoot.
- Determined that candidates B (tool-output cap) and D (lower `max_tokens` floor) are not
  reachable through any configuration surface this project has found — scored `not applicable`
  rather than `promising`, per the plan's explicit rule that an unavailable remedy scores zero.
- Determined candidate A (lower `contextWindow`) does not close either forensically-detailed
  deficit, for a confirmed mechanistic reason (M4: real completed `auto_compaction` events add to,
  rather than prune, the tracked token count in 2/2 observed instances) rather than mere
  insufficient headroom — a determinate negative finding, not an indeterminate one.
- Wrote `RECOMMENDATION.md` with all six required sections: no change to `contextWindow`; the cost
  (BCH-01 stays not_met, next similar task likely dies the same way); a concrete falsification
  condition (`messagesAfter < messagesBefore` and `tokensAfter < tokensBefore` on any fresh real
  completed compaction event); an explicit statement that zero tasks have passed and this analysis
  does not claim otherwise; and a Core Value scope-check recommending PROJECT.md's "달성됨" wording
  be qualified as synthetic-workload-only, without editing PROJECT.md itself.
- At the Task 3 checkpoint, presented the four canonical options, their costs, and the 🔴 live-
  effect risk on running `com.ohama.kanban`/`com.ohama.kanban-proxy` to the user; separately
  surfaced the mismatch between the matrix's one promising-but-untested candidate
  (`--compaction basic`) and the four options' inability to route to it (07-15's apply mechanism
  only writes `contextWindow`).
- Recorded the user's verbatim decision in `DECISION.md`: `SELECTION: doc-only` for the main
  checkpoint, and "후속 과제로 기록만" (record as follow-up only) for the compaction-basic
  mismatch — with the mismatch itself, the reason it can't route through 07-15, and the user's
  choice to defer rather than expand scope, all written out so a future reader sees a conscious
  deferral, not an oversight.
- Recorded a correction voiding `phase-01/results/exp-basic/` as evidence for `--compaction basic`
  (that run's `contextWindow` sat inside `models[]`, so the 128k fallback applied instead of this
  stack's real ceiling), so this project's record never silently treats that run as prior testing
  of the lever.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build the candidate-versus-root-cause matrix with per-task arithmetic** - `fe92a3c` (docs)
2. **Task 2: Write RECOMMENDATION.md with cost and falsification condition** - `793cc26` (docs)
3. **Task 3: User decides what, if anything, ships** - `f735d1a` (docs) — checkpoint, resumed by
   continuation agent after user answered

**Plan metadata:** commit created below (docs: complete plan)

## Files Created/Modified

- `phase-07/results/20260831T011037Z-remediation/README.md` - directory index and pre-plan safety
  snapshot (six pids, providers.json hash, colima/port-3000 state, clean git status)
- `phase-07/results/20260831T011037Z-remediation/CANDIDATE-MATRIX.md` - per-task required-headroom
  arithmetic, 5 root-cause mechanisms, and A-F candidate scoring against each, with no empty cells
- `phase-07/results/20260831T011037Z-remediation/RECOMMENDATION.md` - the six-section
  recommendation: answer, recommended action (no change), cost, falsification condition, explicit
  non-claims (zero tasks passed), and Core Value scope check
- `phase-07/results/20260831T011037Z-remediation/DECISION.md` - the options as presented, the
  user's verbatim `doc-only` reply and its canonical `SELECTION: doc-only` label, the separately-
  resolved `--compaction basic` follow-up decision, the `exp-basic` evidence-voiding correction,
  and a post-write safety verification block

## Decisions Made

See `key-decisions` in frontmatter. In short: `doc-only` was selected because it is what the
evidence itself recommends (a lower `contextWindow` targets the wrong mechanism); the one
genuinely open lever (`--compaction basic`) is recorded as a named, deliberately deferred follow-up
rather than silently dropped or silently folded into `doc-only`; and an earlier same-session
experiment that superficially looks like a test of that lever is explicitly voided as evidence
because its configuration engaged the project's own known 128k-fallback bug instead of the real
ceiling.

## Deviations from Plan

None - plan executed exactly as written. The plan's own Task 3 anticipated an off-menu or
supplementary reply needing resolution before `DECISION.md` is written ("an off-menu or ambiguous
reply must be resolved to exactly one of the four labels... proposing the closest label back...
and getting your confirmation"); here the main reply was on-menu (`doc-only`) with no resolution
needed, and the supplementary `--compaction basic` question was a second, separate question the
checkpoint's own context section invited ("if it cannot be mapped... ask again") applied to a
lever outside the four-option menu entirely, handled by recording it as its own labeled decision
rather than forcing it into one of the four canonical labels it does not belong to.

## Issues Encountered

None. Continuation-agent handoff was clean: both prior commits (`fe92a3c`, `793cc26`) verified
present in `git log` before proceeding, and all three artifact files were read in full before
writing `DECISION.md`.

## User Setup Required

None - no external service configuration required. This plan and its completion touch only
`phase-07/results/` and `.planning/`; no shipped configuration was changed.

## Next Phase Readiness

- 07-15 has a single, unambiguous input: `SELECTION: doc-only` in
  `phase-07/results/20260831T011037Z-remediation/DECISION.md`. It should document the findings
  (including the recommended Core Value wording qualification from `RECOMMENDATION.md` §6) and
  make no change to `~/.cline/data/settings/providers.json` or any other shipped configuration.
  No live bench run is authorized.
- A named, unstarted follow-up exists for whoever picks it up next: `--compaction basic` is the
  one candidate the matrix scores as directly targeting the confirmed non-pruning defect (M4), but
  it has never been tested against a working top-level `contextWindow` config on this stack (the
  session's own `phase-01/results/exp-basic/` used a `models[]`-nested config and is voided as
  evidence). Exercising it would require its own live-run authorization and a correctly
  top-level-configured provider file — neither exists yet.
- No blockers. All hard safety constraints held throughout both sessions: `providers.json` sha256
  `534151965f81089b11d96d4af0b8a115b558f38efd42e82a9edd2a76f44fc214` unchanged (verified at plan
  start and again immediately before writing `DECISION.md`); all six live service pids
  (46573/75548/48525/36175/99162/19669) unchanged; `colima status` -> "colima is not running"
  both times checked; `lsof -i :3000` empty; no `cline`/`kanban`/`harbor` process invoked; zero
  live bench runs; zero model calls; `git status --short` shows changes only under
  `phase-07/results/` for the task commits.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-31*
