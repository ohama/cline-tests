---
phase: 07-cline-bench-verification
plan: 11
subsystem: testing
tags: [cline-bench, context-window, compaction, forensics, flashnext, mlx]

# Dependency graph
requires:
  - phase: 07-cline-bench-verification (07-09, 07-10)
    provides: bench/runs/20260830T122809Z-phase07-fix/ raw evidence (server-log slices,
      per-task meta.json, agent/cline.txt transcripts, .compaction.json session snapshots) and
      phase-07/results/20260830T170042Z-gap-batch/ledger.tsv summarizing the fail-context verdicts
provides:
  - Re-derived true peak prompt-token counts for telegram-plugin-refactor (accepted 21036,
    fatal-attempted 36155) and v-edit-workspace-tests (accepted 30696, fatal-attempted 30843),
    including the requests the server rejected and never logged as queued
  - Per-task compaction timeline (started/completed/skipped) with quantified overshoot against
    the 2,700-3,100 token budget from docs/32k-compaction-policy.md
  - A confirmed, evidence-cited mechanism for each task, distinguishing two different proximate
    failure paths (single oversized tool result vs multi-turn creep after a permanent
    compaction-skip) that the milestone audit's single "fail-context" label had merged
  - A named artifact (max_prompt_tokens undercount) handed forward to 07-12 by name, without
    modifying the classifier
affects: [07-12 (classifier audit), 07-14 (remediation decision), 07-15 (conditional live run)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Forensic-only plan pattern: parse raw evidence into machine-derived TSVs, cross-check
      counts against independent grep/awk one-liners, then write a narrative that cites file+line
      for every claim and explicitly labels confidence (confirmed/probable/indeterminate)."

key-files:
  created:
    - phase-07/results/20260831T003728Z-context-forensics/README.md
    - phase-07/results/20260831T003728Z-context-forensics/token-ladder.tsv
    - phase-07/results/20260831T003728Z-context-forensics/compaction-events.tsv
    - phase-07/results/20260831T003728Z-context-forensics/CONTEXT-FORENSICS.md
  modified: []

key-decisions:
  - "Both tasks' peak_accepted_prompt_tokens matched their meta/*.json max_prompt_tokens field
    exactly (21036 and 30696) - that field is correct for what it measures (accepted requests
    only); the gap is entirely in what it cannot see (rejected requests), so 07-12 should treat
    it as a lower bound, not fix the grep logic itself (out of scope here)."
  - "Answered 'are these the same phenomenon?' as no at the proximate-cause level (one is a
    single ~11.7K-token tool-result jump; the other is a ~3,670-token creep across 4 skipped-
    compaction turns), while naming one plausible shared underlying defect visible in both
    tasks' .compaction.json (messagesBefore==messagesAfter==16 - the one real compaction in each
    run added a summary but pruned nothing) - stated as a hypothesis pending a third example, not
    asserted as proven."
  - "Left the compaction-skip root cause (why iterations 9-12 skip) as indeterminate rather than
    inventing a mechanism - the stored notice metadata has no cause field beyond the subsystem
    name, per the plan's own explicit permission to report indeterminate as a passing outcome."

patterns-established:
  - "When a metric is computed by grepping only the success-path log line, a request the server
    rejects before that line is written is invisible to the metric - always check for a second,
    differently-shaped failure line format before trusting a 'peak' figure derived from one grep."

# Metrics
duration: 15min
completed: 2026-08-31
---

# Phase 07 Plan 11: Context-Ceiling Forensics Summary

**Re-derived the true fatal prompt-token counts for both genuine context-ceiling deaths from raw
server logs (telegram-plugin-refactor: 36,155 attempted vs 21,036 ledger-recorded; v-edit-
workspace-tests: 30,843 vs 30,696), and showed the two tasks died by different mechanisms - one
oversized tool result vs a permanently skipped compaction letting the prompt creep to the wall.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-31T00:37:28Z
- **Completed:** 2026-08-31T00:47:42Z (analysis writing; commits followed immediately after)
- **Tasks:** 3/3
- **Files modified:** 4 created, 0 modified

## Accomplishments

- Parsed both server-log line formats (accepted `Generation queued:` and rejected
  `Request needs ... MAX_KV_SIZE`) for both tasks into `token-ladder.tsv`, cross-checked against
  independent `grep -c` counts and against each task's `meta/*.json` `max_prompt_tokens` field —
  all four cross-checks matched exactly.
- Confirmed the hypothesis in the plan's `<why_this_matters>` block was correct for
  `telegram-plugin-refactor` (rejection line present, real prompt 36,155 vs ledger's 21,036) but
  found the `v-edit-workspace-tests` undercount is far smaller (147 tokens, not a large hidden
  jump) — a materially different shape of the "same" measurement artifact.
- Traced the compaction event for `telegram-plugin-refactor` (iteration 6, trigger 26100) to its
  own server-log entry (a 330-token-in/319-token-out summarization call) via tight timestamp
  correlation, and showed via the persisted `.compaction.json` that `messagesBefore==
  messagesAfter==16` — compaction reported "completed" but pruned nothing.
- Found the identical non-pruning pattern in `v-edit-workspace-tests`'s one real compaction
  (iteration 8), then traced four subsequent `auto-compaction-skipped` events (iterations 9-12,
  matching the plan's hint) firing within 0-1ms of their own `started` notice with no cause field
  recorded, while the prompt crept from 27,173 to the fatal 30,843 over those same four turns.
- Identified and documented a confound in `v-edit-workspace-tests`: a transient METAL/OOM server
  error and an automatic same-content retry sitting between the last two accepted requests,
  unrelated to context sizing but entangled in the same run's `fail-context` verdict.
- Wrote `CONTEXT-FORENSICS.md` with all five required sections, explicit `confirmed`/
  `indeterminate` labels per claim, and five named gaps (with the specific capture that would
  settle each) in the "Limits of this analysis" section.

## Task Commits

Each task was committed atomically:

1. **Task 1: Re-derive the true token ladder, including the rejected requests** - `1fb36f5` (feat)
2. **Task 2: Reconstruct the compaction timeline and quantify overshoot per task** - `f9d9d67` (feat)
3. **Task 3: Write CONTEXT-FORENSICS.md with a per-task verdict** - `7c55fac` (docs)

**Plan metadata:** commit created below (docs: complete plan)

## Files Created/Modified

- `phase-07/results/20260831T003728Z-context-forensics/README.md` - results-dir manifest, pre-
  execution safety snapshot (pids, providers.json hash, port 3000, colima state)
- `phase-07/results/20260831T003728Z-context-forensics/token-ladder.tsv` - per-request
  `task, seq, timestamp, line, request_id, prompt_tokens, max_tokens, sum, outcome, detail` for
  both tasks (23 rows incl. header)
- `phase-07/results/20260831T003728Z-context-forensics/compaction-events.tsv` - per-
  `auto_compaction` event `task, iteration, phase, ts, triggerTokens, maxInputTokens,
  targetTokens, messageTargetTokens, tokensBefore, tokensAfter, messagesBefore, messagesAfter,
  overshoot, raw_json` (12 rows incl. header)
- `phase-07/results/20260831T003728Z-context-forensics/CONTEXT-FORENSICS.md` - 298-line analysis:
  verdict table, per-task narrative with file+line citations, same-phenomenon verdict (no, with a
  named shared-hypothesis caveat), measurement-artifact handoff to 07-12, five named analysis
  limits

## Decisions Made

- Reported the `messagesBefore==messagesAfter` non-pruning pattern as a shared *hypothesis*
  across both tasks (not a proven shared root cause), since the plan requires a shared cause only
  be asserted "if the evidence forces it" — two data points is suggestive, not forcing.
- Did not attempt to reconcile the three disagreeing "before" token figures found for the
  telegram compaction (38626 in the notice, 45507 in the compaction_summary message metadata,
  ~33920/36155 from directly summing/observing the real payload) into a single number; reported
  all three and named what capture would settle the discrepancy, per the plan's explicit
  permission for "indeterminate, here is what we lacked" outcomes.
- Did not touch the classifier, the ledger, or `meta/*.json` — the `max_prompt_tokens` undercount
  finding is handed to 07-12 by name only, exactly as scoped.

## Deviations from Plan

None — plan executed exactly as written. All three tasks' `<verify>` and `<done>` criteria were
met using only evidence already on disk; no live bench run, no model call, and no write outside
the new `phase-07/results/20260831T003728Z-context-forensics/` directory was needed.

## Issues Encountered

None. The rejection line format, the compaction notice format, and the `.compaction.json` schema
all matched what the plan's `<why_this_matters>` and `<key_links>` sections predicted, and the
one open question they flagged (whether the two tasks are the same phenomenon) resolved cleanly
against the evidence: no at the proximate-cause level, yes-as-hypothesis at one underlying-defect
level.

## User Setup Required

None - no external service configuration required. This plan is read-only with respect to all
live services and configuration.

## Next Phase Readiness

- 07-12 (classifier audit) has a named, quantified handoff: `max_prompt_tokens` in `meta/*.json`
  is a lower bound on the true fatal request, undercounting by 15,119 tokens for
  `telegram-plugin-refactor` and by 147 tokens for `v-edit-workspace-tests`.
- 07-14 (remediation decision) has arithmetic-only per-task headroom figures (telegram needed
  5,435 more tokens than the hard wall allowed / 7,155 more than the 29,000 safe ceiling; v-edit
  needed only 123 more than the hard wall) without this plan prescribing a config value.
- 07-15's conditional live run (if it proceeds) would be the first opportunity to capture a third
  `fail-context` example, which is the specific gap this plan named as blocking a firm verdict on
  whether the non-pruning compaction pattern is systemic.
- No blockers. All hard safety constraints held throughout: `bench/runs/` byte-unchanged (`git
  status --short bench/runs/` empty), pids 46573/75548/48525 unchanged, `providers.json` sha256
  unchanged (`534151965f81089b...`), port 3000 unbound, colima left stopped, zero `cline`/
  `harbor` processes invoked by this plan.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-31*
