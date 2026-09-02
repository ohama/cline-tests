---
phase: 11-usage-surface-wrappers
plan: 02
subsystem: testing
tags: [grading, ndjson, cline-bench, benchmark-design, python3-stdlib, bash3.2]

# Dependency graph
requires:
  - phase: 09-preflight-gates
    provides: "PRB-03-ORACLE.md (medium's -2 token effect, xhigh's 300-token budget starvation),
      PRB-04-FINDINGS.md (16/16 delta=0 reasoning-replay cost)"
  - phase: 10-alias-injection-reach-proof
    provides: "REACH-PROOF.md Section 3b (shipped-arm -2 delta corroboration),
      VRF-04-OBSERVATION.md (real NDJSON shape captured from a live cline run)"
  - phase: 07-cline-bench-verification
    provides: "bench/runs/20260830T122809Z-phase07-fix/summary.md and the gap-closure
      RECLASSIFICATION.md/CONTEXT-FORENSICS.md this plan quotes directly"
provides:
  - "AB-TASKSET.md: a dated, evidence-quoted decision to set cline-bench aside for USE-03,
    plus the replacement task set's design constraints and pre-registered outcome meanings"
  - "8 bounded-turn, tool-free, objectively gradable tasks with mechanically derived answer keys"
  - "grade_ab.py: a four-state (plus unparseable) NDJSON grader, proven against 9 fixtures"
affects: ["11-03 (verify_config.sh negative tests)", "11-05/11-06 (the actual A/B run and pilot,
  which consume MANIFEST.tsv's ids/categories and grade_ab.py directly)"]

tech-stack:
  added: []
  patterns:
    - "Mechanically-derived answer keys: every .expected value is produced by executing a
      .truth.py file or a python3 -c arithmetic expression, never typed from memory"
    - "Shape-tolerant NDJSON extraction: recursive walk keyed on any dict carrying a
      contentType/type/kind/block_type field equal to 'reasoning', not a hardcoded jq path"
    - "Four-verdict grading with a non-overturning fallback net: no-answer's
      answer-seen-in-reasoning-only qualifier is reported, never used to change the verdict"

key-files:
  created:
    - phase-11/AB-TASKSET.md
    - phase-11/tasks/MANIFEST.tsv
    - phase-11/tasks/01-pipe-rate.{prompt,expected}
    - phase-11/tasks/02-salt-mixture.{prompt,expected}
    - phase-11/tasks/03-reinvested-interest.{prompt,expected}
    - phase-11/tasks/04-loop-sum.{prompt,expected,truth.py}
    - phase-11/tasks/05-list-aliasing.{prompt,expected,truth.py}
    - phase-11/tasks/06-mode-char.{prompt,expected,truth.py}
    - phase-11/tasks/07-index-shift-bug.{prompt,expected,truth.py}
    - phase-11/tasks/08-zero-div-bug.{prompt,expected,truth.py}
    - phase-11/grade_ab.py
    - phase-11/selftest_grade_ab.sh
    - phase-11/fixtures/{f1..f8,fixture-*.expected,selftest.tsv}
  modified: []

key-decisions:
  - "cline-bench is set aside for USE-03 (not re-run): both easy tasks already overflow 32K
    (31,179/36,155 attempted prompt tokens, quoted from primary Phase 07 evidence) against a
    -2-token medium-reasoning effect and a 0-token reasoning-replay cost -- an A/B on that
    pool would measure the compaction-pruning defect, not reasoning effort. Reversal
    condition and declined fallback both recorded in AB-TASKSET.md Section 1."
  - "Every numeric task uses match:numeric, never exact_normalized -- proven necessary by the
    f8 fixture (ANSWER: 84.0 vs expected 84 gives correct under numeric, incorrect under
    exact_normalized)."
  - "Bug-localisation answer keys are derived by catching the runtime exception the defect
    causes and reading its traceback line number, with the .truth.py function body placed at
    file line 1 so physical line numbers match the prompt's displayed numbering exactly."

patterns-established:
  - "Grader verdicts are governed only by the primary (visible-text) extraction path; fallback
    and reasoning-only nets are reported in every output row's counts but never overturn a
    verdict already decided."

# Metrics
duration: ~55min
completed: 2026-09-02
---

# Phase 11 Plan 02: USE-03 Instrument (Task Set + Grader) Summary

**Built the USE-03 measurement instrument from scratch — a dated cline-bench set-aside decision
quoting Phase 07's primary rows, 8 mechanically-derived-answer tasks, and a four-state NDJSON
grader proven against 9 hand-written fixtures — without issuing a single live model request.**

## Performance

- **Duration:** ~55 min
- **Tasks:** 3/3 completed
- **Files created:** 35 (1 decision doc, 8×2-3 task files, 1 manifest, 1 grader, 1 selftest
  script, 12 fixture files)
- **Live model requests:** 0 (flashnext.err line count unchanged: 23359 → 23359)

## Accomplishments

- Set cline-bench aside for USE-03 with a written, dated (2026-09-02), evidence-quoting decision
  — not by omission or by re-running a foregone conclusion.
- Authored 8 tasks (3 word-problem, 3 code-trace, 2 bug-localisation) whose every answer key was
  produced by execution (`python3 -c` arithmetic or a `.truth.py` script), never typed from memory
  — and caught a real bug in the first draft of the bug-localisation truth scripts this way (see
  Issues Encountered).
- Built a shape-tolerant, four-state grader and proved it can return every verdict it claims,
  including a deliberate-break test that showed the self-test itself can fail.

## Task Commits

1. **Task 1: Record the cline-bench set-aside decision and design constraints** - `fb520f6` (docs)
2. **Task 2: Author 8 tasks and derive every answer key mechanically** - `0856098` (feat)
3. **Task 3: The grader, and the fixtures that prove it can return every verdict** - `b4eec84` (feat)

_No plan-metadata commit issued separately; this SUMMARY.md is committed as its own docs(11-02)
commit per the workflow's final-commit step._

## Files Created/Modified

- `phase-11/AB-TASKSET.md` — the set-aside decision (§1), design constraints (§2), answer
  protocol (§3), pre-registered outcome meanings (§4), and the 8-row task table (§5)
- `phase-11/tasks/MANIFEST.tsv` — machine-readable index: id, slug, category, prompt/expected
  paths, prompt_bytes, match_mode, derivation
- `phase-11/tasks/NN-<slug>.prompt` (×8) — bounded-turn prompts, 361–586 bytes each, all ending
  in the identical `ANSWER: <value>` protocol sentence
- `phase-11/tasks/NN-<slug>.expected` (×8) — `key: value` answer keys with derivation recorded
- `phase-11/tasks/{04,05,06,07,08}-*.truth.py` — executable scripts that produce each code-trace
  and bug-localisation answer
- `phase-11/grade_ab.py` — the four-state (+unparseable) NDJSON grader, stdlib-only
- `phase-11/selftest_grade_ab.sh` — fixture-driven proof harness, bash 3.2 compatible
- `phase-11/fixtures/` — 8 hand-written NDJSON fixtures (f1–f8, f8 graded twice), 3
  `fixture-*.expected` files, and the generated `selftest.tsv` proof artifact

## Decisions Made

**The cline-bench set-aside (AB-TASKSET.md §1).** Quoted directly from
`bench/runs/20260830T122809Z-phase07-fix/summary.md`'s own table (grep-verified, not retyped):
both `easy` tasks are `fail-context` (`discord-trivia-approval-keyerror`,
`telegram-plugin-refactor`); the corrected attempted-prompt-token figures from
`phase-07/results/20260831T010013Z-reclassify/RECLASSIFICATION.md` are 31,179 and 36,155 —
5,000–15,000+ tokens past the 32,768-token ceiling. Against that gap, `medium` reasoning's
measured effect on `prompt_tokens` is −2 (`phase-09/PRB-03-ORACLE.md` §2b, corroborated at the
shipped alias in `phase-10/REACH-PROOF.md` §3b), and reasoning-history replay costs 0 additional
tokens even for a 2,497-character real trace (`phase-09/PRB-04-FINDINGS.md`, 16/16 delta=0). An
A/B on the official pool would very likely return 0/N vs 0/N, measuring the project's own
already-accepted compaction-pruning defect, not reasoning effort. The declined fallback (running
the two `fail-context` easy tasks and reporting 0/2-vs-0/2 as a technically valid "no improvement"
answer) is recorded and explicitly rejected — it would spend the shared model queue on a foregone
conclusion and answer a different question than USE-03 asks. The reversal condition: a future fix
to compaction actually pruning (`messagesAfter < messagesBefore`) such that at least one `easy`
task completes under either arm.

**Numeric vs exact_normalized (AB-TASKSET.md §2, fixture f8).** `ANSWER: 84.0` against
`expected: 84` grades `correct` under `match: numeric` but `incorrect` under
`match: exact_normalized` (normalization strips whitespace/trailing-period/thousands-separators
but does not fold `84.0` to `84`). Every numeric task in `MANIFEST.tsv` therefore uses
`match: numeric`.

**Grader verdict precedence.** The primary (visible-text) extraction path alone decides
correct/incorrect/no-answer/no-output. The raw-file fallback scan and the reasoning-only scan are
always computed and reported (as `fallback_hit`/`reasoning_hit` columns and, for `no-answer`
specifically, the `answer-seen-in-reasoning-only` qualifier) but never promote a verdict — this
was a deliberate design choice per the plan's framing: folding a reasoning-only answer into
`correct` would flatter a thinking arm that got truncated before actually answering; folding it
into `incorrect` would libel it.

## Deviations from Plan

**1. [Rule 1 — Bug] Bug-localisation `.truth.py` line numbers did not match the prompt's displayed
numbering on first execution.**
- **Found during:** Task 2, while running the derivation-verification loop.
- **Issue:** The first draft of `07-index-shift-bug.truth.py` and `08-zero-div-bug.truth.py`
  placed `import sys`/`import traceback` before the function definition. The traceback's
  `frame.lineno` therefore reported the function body's *physical file line* (8 and 10), not the
  line number as displayed in the prompt's hand-numbered snippet (which starts numbering at 1 for
  `def`). Running the script and comparing its output against the hand-predicted answer (4 and 6)
  caught the mismatch immediately — exactly the kind of value that would have been silently wrong
  if asserted from memory instead of executed.
- **Fix:** Moved the function definition to file line 1 in both `.truth.py` files (imports and the
  execution harness moved after the function, inside a `_main()` helper), so the traceback's
  physical line number equals the prompt's displayed line number by construction.
- **Files modified:** `phase-11/tasks/07-index-shift-bug.truth.py`,
  `phase-11/tasks/08-zero-div-bug.truth.py`
- **Verification:** Re-ran both scripts; output (4, 6) now matches the recorded `.expected`
  values and the prompt's own line numbering.
- **Committed in:** `0856098` (part of Task 2's commit, before the mismatch was ever recorded as
  a fact anywhere)

**Total deviations:** 1 auto-fixed (Rule 1 — bug, caught by execution before it became a
recorded/asserted value).
**Impact on plan:** None on scope; this is exactly the failure mode the plan's Task 2 instructions
were designed to prevent ("an answer key that was typed from memory would make every downstream
accuracy number unfalsifiable"), and it worked as intended.

## Issues Encountered

**Concurrent-commit cross-contamination (informational, not a defect in this plan's own output).**
Plan 11-01 is running in parallel in the same repository (wave 1). Task 3's commit (`b4eec84`) was
made with `git commit -m "..."` after staging only this plan's own files
(`git add phase-11/grade_ab.py phase-11/selftest_grade_ab.sh phase-11/fixtures/`) — but
`.planning/phases/11-usage-surface-wrappers/11-01-SUMMARY.md` appeared in that same commit's diff.
Investigation confirmed the file did not exist at `HEAD~1` and `git status` was clean immediately
after the commit — the only explanation is that 11-01's own process had staged that file (via its
own `git add`) between this plan's Task 2 and Task 3 commits, and a bare `git commit -m` (no
pathspec) commits the *entire index*, not just what this plan's own `git add` call touched. No
content belonging to this plan was affected, and 11-01's file content itself is presumably correct
(it is 11-01's own output) — but the commit's authorship/attribution for that one file is now
this plan's commit rather than 11-01's own. This plan did not attempt to rewrite history to fix it
(rewriting shared history mid-execution while another agent may be reading it would be more
dangerous than the cosmetic attribution issue itself). **Recommendation for future parallel
execution:** always commit with an explicit pathspec (`git commit -m "..." -- <files>`) rather
than a bare `git commit -m "..."`, so a concurrently-staged file from a sibling plan can never be
swept into the wrong commit.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `phase-11/tasks/MANIFEST.tsv` is ready for plan 11-05's pilot: ids are unique, sequential
  (01–08), and the category column holds exactly 3 word-problem / 3 code-trace / 2
  bug-localisation rows, matching the counts 11-05's "lowest-id task of category X" /
  "highest-id non-piloted sibling" rules expect.
- `phase-11/grade_ab.py` and `phase-11/selftest_grade_ab.sh` are ready to grade real NDJSON output
  once 11-05/11-06 fire live requests; no code changes anticipated, since the extraction logic was
  validated against the actual NDJSON shape phase-10 captured from a live `cline` run
  (`event.contentType == "reasoning"`), not an assumed one.
- **Concern carried forward:** the `max_tokens=2048` figure and NDJSON shape assumptions are
  3.0.53-sourced and only partially re-verified at the drifted 3.0.60 binary (per
  `phase-10/VRF-04-OBSERVATION.md`) — plan 11-04 owns re-verifying this before the live A/B runs
  in 11-05/11-06.
- No blockers. Zero live model requests were made; the three `com.ohama.*` service pids
  (litellm 68670, flashnext 46573, role-shim 75548) were unchanged throughout, and
  `phase-01/config/verify_config.sh` exits 0 with an empty `git diff --stat`.

---
*Phase: 11-usage-surface-wrappers*
*Plan: 02*
*Completed: 2026-09-02*
