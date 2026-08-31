---
phase: 07-cline-bench-verification
plan: 12
subsystem: testing
tags: [cline-bench, harbor, flashnext, classifier-audit, verdict-forensics, mlx_vlm]

# Dependency graph
requires:
  - phase: 07-cline-bench-verification (07-07, 07-09)
    provides: the post-fix bench run (bench/runs/20260830T122809Z-phase07-fix/) whose four
      meta/*.json verdicts this plan audits, and the pre-fix run
      (bench/runs/20260830T093657Z-phase07/) needed to resolve the fail-infra/fail-context
      naming conflict
provides:
  - A byte-level trust verdict on the fail-context label used by the v1 milestone audit's
    headline claim
  - A numbered, evidence-backed defect list in HTTP_400_SEEN's two grep targets, ready for 07-13
  - Resolution of the apparent discord-trivia-approval-keyerror fail-infra/fail-context
    contradiction as two correct statements about two different run directories
affects: [07-13 (classifier fix), any future cline-bench run whose fail-context labels get cited]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Forensic audit pattern: re-run the exact grep/classification logic by hand against stored
      bytes rather than trusting recorded meta.json fields, to distinguish a correct label from a
      coincidentally-correct one."

key-files:
  created:
    - phase-07/results/20260831T004024Z-classifier-audit/README.md
    - phase-07/results/20260831T004024Z-classifier-audit/failure-composition.tsv
    - phase-07/results/20260831T004024Z-classifier-audit/match-provenance.md
    - phase-07/results/20260831T004024Z-classifier-audit/CLASSIFIER-AUDIT.md
  modified: []

key-decisions:
  - "The classifier (phase-07/bench/run_task.sh's HTTP_400_SEEN + MAX_PROMPT_TOKENS OR rule) is
    judged UNSOUND, not sound and not indeterminate: it has a demonstrated false-negative (the
    real MAX_KV_SIZE line never contains a bare 400) and a demonstrated false-positive (the
    benchmark task's own repository source code, echoed into agent/cline.txt, contains real
    HTTP-400 literals unrelated to any rejection)."
  - "All four post-fix labels are nonetheless judged 'correct', not 'coincidentally-correct' --
    each fail-context task has an independent true-signal match (litellm's relayed
    'Error code: 400' quoting the exact MAX_KV_SIZE numbers) alongside the noise, and
    fail-infra/filmarchiver has zero evidence of any kind to dispute it."
  - "The discord-trivia-approval-keyerror fail-infra (smoke ANALYSIS.md) vs fail-context
    (milestone audit) conflict is not a contradiction: fail-infra describes the pre-fix run
    bench/runs/20260830T093657Z-phase07/ (injection not yet working, hit real OpenAI API,
    0 server-log bytes) and fail-context describes the post-fix run
    bench/runs/20260830T122809Z-phase07-fix/ (injection working, 38 turns, genuine MAX_KV
    rejection) -- two different run directories, both correct for their own run."
  - "The milestone claim '3/3 reached-the-model tasks died at the 32K ceiling' survives intact --
    independently reconfirmed by matching the raw server-log rejection numbers against the
    relayed transcript numbers for all three tasks -- but should be qualified with the caveat
    that the instrument producing these labels is not reliable in general, only that it happened
    to be right in these three cases."
  - "This plan does not modify phase-07/bench/*.sh -- diagnosis only. The fix (making
    HTTP_400_SEEN match only the actual MAX_KV_SIZE/rejection phrase, and/or capturing which
    substring matched) is 07-13's job."

patterns-established:
  - "When grep -q -based classifiers are audited, always re-run the underlying grep with -o and
    surrounding context (grep -oE '.{N}<pattern>.{N}') rather than trusting the boolean result --
    -q's short-circuit and lack of match-reporting is itself part of what makes such classifiers
    hard to trust."

# Metrics
duration: 25min
completed: 2026-08-31
---

# Phase 7 Plan 12: Classifier Audit (fail-context trustworthiness) Summary

**The `fail-context` classifier is unsound (server-log false-negative + false-positive on
transcript-embedded repo source), but by coincidence got all four post-fix labels right; the
milestone's "3/3 died at the 32K ceiling" claim survives, independently reconfirmed byte-for-byte,
and the discord-trivia-approval-keyerror fail-infra/fail-context "conflict" is resolved as two
correct statements about two different run directories, not a contradiction.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-31T00:40:24Z
- **Completed:** 2026-08-31T00:45:12Z (last task commit)
- **Tasks:** 3/3 completed
- **Files modified:** 4 created, 0 modified

## Accomplishments

- Quantified `discord-trivia-approval-keyerror`'s failure composition byte-for-byte: 6 distinct
  METAL/GPU out-of-memory events (not 24 — that number, obtained by naively `grep -c`'ing the raw
  OOM string, over-counts 4x because each event logs the same string on 4 separate lines) versus
  1 `MAX_KV_SIZE` rejection — but the task recovered from every OOM and only stopped for good at
  the single terminal context rejection, so "died of memory exhaustion" and "died of the context
  ceiling" are both partially true depending on which question is asked, and this summary answers
  both explicitly rather than picking one.
- Replayed both `HTTP_400_SEEN` grep targets by hand for all four post-fix tasks and named every
  matched substring: found a real, demonstrated false-positive vector in the benchmark task's own
  repository source (`telegram-plugin-refactor`'s `case 400:` / `new ApiError(...,400,...)`) and a
  real, demonstrated false-negative in the server-log target (the authoritative `MAX_KV_SIZE`
  rejection line never contains a bare `400` in any of the 3 tasks that hit it).
- Resolved the `discord-trivia-approval-keyerror` fail-infra/fail-context question definitively by
  quoting both sources' own meta records and naming both run directories
  (`bench/runs/20260830T093657Z-phase07/` pre-fix vs `bench/runs/20260830T122809Z-phase07-fix/`
  post-fix) — not a contradiction.
- Delivered a numbered, evidence-cited defect list for 07-13 (5 defects) without modifying
  `phase-07/bench/*.sh`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Quantify the failure composition of every post-fix task** - `e53ed5e` (feat)
2. **Task 2: Trace exactly which bytes set each verdict** - `a58abab` (feat)
3. **Task 3: Write CLASSIFIER-AUDIT.md and resolve the fail-infra/fail-context conflict** - `f074348` (docs)

**Plan metadata:** (this commit, see below)

## Files Created/Modified

- `phase-07/results/20260831T004024Z-classifier-audit/README.md` - directory index
- `phase-07/results/20260831T004024Z-classifier-audit/failure-composition.tsv` - per-task,
  per-event-class counts and first/last timestamps for `maxkv-rejection` / `metal-oom` /
  `other-request-failed` / `completed`, independently re-derivable with `grep -c`
- `phase-07/results/20260831T004024Z-classifier-audit/match-provenance.md` - every literal
  substring that set `HTTP_400_SEEN` for all four tasks, quoted with context, labeled true-signal
  or false-positive; the false-negative test on the authoritative `MAX_KV_SIZE` line; findings on
  `make_summary.sh` (transcribes only) and `verify_bench.sh` B2 (vocabulary check only)
- `phase-07/results/20260831T004024Z-classifier-audit/CLASSIFIER-AUDIT.md` - the verdict document:
  label-vs-evidence table, run-conflict resolution, classifier correctness verdict (unsound, 5
  numbered defects), milestone-claim impact assessment, limits

## Decisions Made

See `key-decisions` in frontmatter. In short: classifier unsound; all four current labels
correct anyway; the two run directories resolve the naming conflict; the milestone headline
survives; no code changed here.

## Deviations from Plan

None — plan executed exactly as written. One incidental, non-required finding surfaced during
Task 2 and is recorded in `match-provenance.md` §3 rather than acted on: `MAX_PROMPT_TOKENS` is
extracted only from successful `Request completed:`/`Generation queued:`/`Prefill ...:` lines and
can therefore never reach 32768 for a request that was itself rejected (the rejection line spells
the prompt count out in prose instead of `prompt_tokens=`). This is not a required deliverable of
this plan but is directly relevant to 07-13's scope, so it is documented rather than silently
dropped. No file was modified to address it (would violate this plan's read-only constraint on
`phase-07/bench/*.sh`).

**Total deviations:** 0 auto-fixed (0 required; one additional finding documented for 07-13's
benefit, no code touched).
**Impact on plan:** None — fully in scope, no scope creep.

## Issues Encountered

None. The one methodological pitfall handled carefully: raw `grep -c` on
`kIOGPUCommandBufferCallbackErrorOutOfMemory` returns 24 for `discord-trivia-approval-keyerror`,
but each real OOM event logs that string on 4 separate lines (two `RuntimeError:` traceback lines,
one `WARNING - Request failed:`, one `ERROR - Chat completion stream generation failed:`), so the
true event count is 6, not 24. `failure-composition.tsv` uses "Request failed:"-anchored counts
(1 event = 1 "Request failed:" line) to avoid this over-count, and the audit text calls out the
4x inflation explicitly so a future reader doesn't repeat the naive count.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

07-13 (the classifier fix, next in the gap-closure sequence) has everything it needs: a concrete,
numbered defect list in `CLASSIFIER-AUDIT.md` §3, each defect backed by quoted evidence in
`match-provenance.md`. No blockers. One thing 07-13 should decide explicitly: whether to also
narrow `MAX_PROMPT_TOKENS`'s extraction to include the rejected-request's prompt count (currently
structurally incapable of reaching 32768), since that field is currently dead weight in the OR
condition — every real `fail-context` verdict in this dataset was carried by `HTTP_400_SEEN`
alone.

Safety verification at plan end (all confirmed, see commits' surrounding shell output in this
session): `bench/runs/` and `phase-07/bench/` both byte-unchanged (`git status --short` empty for
both); pids 46573/75548/48525 unchanged; `providers.json` sha256
`534151965f81089b11d96d4af0b8a115b558f38efd42e82a9edd2a76f44fc214` unchanged; colima still stopped
(`colima status` → "colima is not running"); `lsof -i :3000` empty; no `harbor` process running;
zero live bench runs; zero model calls.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-31*
