---
phase: 07-cline-bench-verification
plan: 16
subsystem: testing
tags: [cline-bench, compaction, contextWindow, doc-sync, anti-overclaim, flashnext, gap-closure-2]

# Dependency graph
requires:
  - phase: 07-cline-bench-verification (07-11, 07-12, 07-13, 07-14, 07-15)
    provides: per-task context-ceiling forensics (token ladder + compaction timeline),
      classifier-audit's defect list, the repaired classify_lib.sh + 0-verdicts-changed
      reclassification, the candidate-vs-root-cause matrix + doc-only recommendation, the
      user's verbatim SELECTION:doc-only decision, and the executed no-op apply (contextWindow
      still 29000, providers.json byte-identical)
provides:
  - The three shipped documents (docs/32k-compaction-policy.md,
    docs/manual/04-32k-operations.md, docs/cline-bench.md) now distinguish the synthetic
    compaction proof from the real-agent non-pruning finding, restate the contextWindow=29000
    justification honestly instead of silently preserving it, and record the two distinct
    proximate failure mechanisms and the classifier fix
  - Five planning documents (PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md,
    v1-MILESTONE-AUDIT.md) synchronised with the same facts in one pass; BCH-01/criterion 1
    remain honestly not_met; ROADMAP Phase 7 plan list and progress table now read 16/16
  - A re-run manual claim gate (21/21 PASS) and two verify_bench.sh + one verify_config.sh
    re-runs, all matching what 07-15 already recorded as green
  - phase-07/results/20260831T023128Z-close/anti-overclaim.md: an 8/8 PASS sentence-cited sweep,
    every quote mechanically verified as a verbatim substring of its cited file
affects: [any future phase or session that reads PROJECT.md's Core Value, docs/cline-bench.md,
  or docs/32k-compaction-policy.md; this is the final plan of the v1 milestone's gap-closure 2]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sentence-cited anti-overclaim sweep with mechanical verification: rather than trusting
      a human-written quote, extract every '> \"...\" -- `file:line`' block and grep/substring-
      check it against the actual file content before treating the check as PASS. Caught three
      real citation errors (a fabricated quote, a dropped particle, a misplaced ellipsis) that
      manual proofreading alone had missed."
    - "Narrowing-not-reversing correction pattern (second instance in this project after
      2026-08-30's models[]-vs-settings correction): when new evidence contradicts a prior
      claim's implicit scope but not its literal content, add a dated qualifier that keeps the
      original evidence citation intact and states the new boundary, rather than rewriting or
      deleting the original sentence."

key-files:
  created:
    - phase-07/results/20260831T023128Z-close/README.md
    - phase-07/results/20260831T023128Z-close/anti-overclaim.md
    - phase-07/results/20260831T023128Z-close/gates/check_manual_claims.txt
    - phase-07/results/20260831T023128Z-close/gates/verify_bench-phase07-fix.txt
    - phase-07/results/20260831T023128Z-close/gates/verify_bench-phase07.txt
    - phase-07/results/20260831T023128Z-close/gates/verify_config.txt
  modified:
    - docs/32k-compaction-policy.md
    - docs/manual/04-32k-operations.md
    - docs/cline-bench.md
    - .planning/PROJECT.md
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/STATE.md
    - .planning/v1-MILESTONE-AUDIT.md

key-decisions:
  - "docs/32k-compaction-policy.md's contextWindow=29000 value is NOT changed -- per
    DECISION.md's SELECTION: doc-only -- but its justification is restated: the synthetic
    overshoot (2,700-3,100) and the real-agent overshoot (telegram 12,526; v-edit
    1,909-then-skip-creep) are now shown side by side, and the underlying assumption the
    original formula rested on (compaction actually prunes when it fires) is stated as
    confirmed-violated in 2/2 real captures, so the value is honestly labeled 'validated for
    the synthetic regime' rather than silently re-justified for real workloads."
  - "The retired DOC-04 'task budget / split your task' advice is explicitly NOT revived. Every
    place this plan could have plausibly reintroduced it (32k-compaction-policy.md #5 item 2,
    the manual's #4 section) instead adds a sentence stating the retirement stands despite the
    new non-pruning finding, because the user's doc-only selection means no new operational
    advice ships."
  - "The two proximate mechanisms (telegram: single oversized post-compaction tool result,
    deficit 5,435; v-edit: compaction permanently skipped then crept, deficit 123) are kept
    distinct everywhere, never merged into one narrative -- discord-trivia's mechanism (deficit
    459) is marked indeterminate rather than assigned to either bucket, since 07-11 never
    forensically characterized it."
  - "BCH-01 and ROADMAP criterion 1 are updated with dated footnotes recording the root-cause
    investigation's conclusion, but neither is ticked or upgraded -- the investigation changed
    zero task-count arithmetic and zero classifier verdicts, so 'not_met' is restated, not
    softened."
  - "The anti-overclaim sweep is verified mechanically, not just written: a small Python check
    extracted every quoted block and grep-matched it (whitespace/markdown-bold normalized)
    against the actual cited file before the sweep was considered final. This caught one
    fabricated quote (docs/cline-bench.md check 6) and two near-miss transcription errors
    (a dropped particle in ROADMAP.md's citation, an ellipsis standing in for real intervening
    text in 32k-compaction-policy.md's check 7 citation) before commit."

patterns-established:
  - "Mechanical quote verification for anti-overclaim/citation-heavy documents: regex-extract
    '> \"...\"  -- `file:line`' blocks and substring-match the quote (whitespace/bold-marker
    normalized) against the live file content, rather than trusting a written citation at face
    value."

# Metrics
duration: ~35min
completed: 2026-08-31
---

# Phase 07 Plan 16: Land the Gap-Closure-2 Findings in Documents Summary

**Narrowed the unqualified "compaction works" claim in the three shipped docs and five planning
records to "works on the synthetic regression; on 2/2 captured real-agent completions it pruned
zero messages and grew tokens," restated the contextWindow=29000 justification honestly instead
of silently preserving it, and closed Phase 7's gap-closure 2 with an 8/8 PASS anti-overclaim
sweep whose every citation was mechanically verified against the live file text.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-08-31T02:03:00Z (approx.; STATE.md/context loading)
- **Completed:** 2026-08-31T02:37:54Z (Task 3 commit + verification)
- **Tasks:** 3/3 completed
- **Files modified:** 8 modified (3 docs, 5 planning records), 6 created (all under
  `phase-07/results/20260831T023128Z-close/`)

## Accomplishments

- `docs/32k-compaction-policy.md`: §1's unqualified "자동 압축은 정상 작동한다" narrowed to the
  synthetic filler regression with a dated correction block; new §4a puts the synthetic
  overshoot (2,700-3,100) and the two real-agent overshoots (telegram 12,526; v-edit
  1,909-then-4-turn-skip-creep) in one table, states that the `contextWindow=29000` formula's
  own premise (compaction prunes when it fires) is confirmed-violated in 2/2 real captures, and
  records that compaction can be fully skipped for multiple turns, not just late by one turn.
  §5/§8 updated to match without reviving the retired task-budget advice.
- `docs/manual/04-32k-operations.md`: §2/§7 tell the reader what real agent load actually
  showed (2/2 real completions pruned zero messages and grew tokens; the two distinct proximate
  mechanisms behind the three `fail-context` deaths) without adding new operational advice,
  matching the doc-only decision; §4's retirement note gets one sentence confirming it still
  stands.
- `docs/cline-bench.md` §4: corrected the `max_prompt_tokens` undercount (accepted-only vs the
  true fatal-request size: telegram 15,119/v-edit 147/discord-trivia 716 tokens undercounted)
  with the per-task deficit breakdown (5,435/123/459) and the classifier-defect-then-fix note
  (0/5 verdicts changed on reclassification); §9 Phase 8 handoff prohibitions left byte-for-byte
  untouched.
- Five planning documents (`PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`,
  `v1-MILESTONE-AUDIT.md`) synchronised in one pass: Core Value block and the "32K 압축" section
  in `PROJECT.md` both gained a 2026-08-31 scope-narrowing qualifier that preserves the synthetic
  citation; `REQUIREMENTS.md`'s BCH-01 gained a dated footnote (checkbox stays unticked);
  `ROADMAP.md`'s 07-11..07-16 checkboxes flipped to `[x]`, progress table moved to 16/16, and
  criterion 1 still reads `not_met`; `v1-MILESTONE-AUDIT.md`'s §1b, open item 6, and the phase-07
  `tech_debt` frontmatter entry all replaced the "outran the overshoot budget" framing with the
  confirmed non-pruning mechanism and the two-cause breakdown.
- Re-ran all required gates: `check_manual_claims.sh` (21/21 PASS across all five manual docs,
  and 4/4 on `04-32k-operations.md` alone before committing that doc), `verify_bench.sh` against
  both `bench/runs/20260830T122809Z-phase07-fix/` (11/11) and `bench/runs/20260830T093657Z-phase07/`
  (10/10, expected B11 SKIP), and `verify_config.sh` (`contextWindow=29000` confirmed unchanged)
  — all four outputs match what 07-15's `APPLIED.md` already recorded as green.
- Wrote `anti-overclaim.md`: 8/8 PASS, each check citing a quoted sentence and file. Every
  quote block was then mechanically re-verified with a small Python script that extracted the
  `> "..." — \`file:line\`` pattern and substring-matched it (whitespace/bold-marker normalized)
  against the live file — this caught and fixed one fabricated quote and two transcription
  errors (a dropped particle, an ellipsis standing in for real text) before the file was
  finalized.

## Task Commits

Each task was committed atomically:

1. **Task 1: Update the three shipped documents** - `83cde88` (docs)
2. **Task 2: Synchronise the planning records and PROJECT.md** - `8144f5b` (docs)
3. **Task 3: Re-run the claim gates and write the anti-overclaim sweep** - `dfb12d8` (docs)

**Plan metadata:** commit created below (docs: complete plan)

## Files Created/Modified

- `docs/32k-compaction-policy.md` - §1 narrowed to synthetic scope with a dated correction
  block; new §4a (synthetic-vs-real overshoot table, honest 29000-value restatement, skip-not-
  just-late finding); §5/§8 updated to match without reviving retired advice
- `docs/manual/04-32k-operations.md` - §2/§4/§7 gain dated corrections narrating the real-agent
  finding and the two-mechanism breakdown without adding new operational advice
- `docs/cline-bench.md` - §4 gains the `max_prompt_tokens_attempted` per-task breakdown and the
  classifier-fix note; §9 untouched
- `.planning/PROJECT.md` - Core Value block + "32K 압축" section heading both scope-qualified
- `.planning/REQUIREMENTS.md` - BCH-01 dated footnote + traceability row update
- `.planning/ROADMAP.md` - 07-11..07-16 checked off, progress table 16/16, criterion 1 text
  updated
- `.planning/STATE.md` - 07-16 log entry appended (three-task narrative + safety confirmation)
- `.planning/v1-MILESTONE-AUDIT.md` - §1b correction block, open item 6, tech_debt frontmatter
  entry all updated
- `phase-07/results/20260831T023128Z-close/README.md` - directory index + pre-execution safety
  snapshot
- `phase-07/results/20260831T023128Z-close/anti-overclaim.md` - 8/8 PASS sentence-cited sweep
- `phase-07/results/20260831T023128Z-close/gates/*.txt` - four re-run gate transcripts

## Decisions Made

See `key-decisions` in frontmatter. In short: `contextWindow=29000` stays unchanged with its
justification honestly restated (not silently preserved); the retired task-budget advice stays
retired; the two proximate mechanisms stay distinct and discord-trivia's stays indeterminate;
BCH-01/criterion 1 stay `not_met`; and the anti-overclaim sweep was mechanically verified, not
just hand-written.

## Deviations from Plan

None — plan executed exactly as written. One self-correction during Task 3, not a deviation
from the plan's own instructions but worth recording: while drafting `anti-overclaim.md` this
plan wrote three citations that did not exactly match the live document text (one quote that
paraphrased rather than quoted `docs/cline-bench.md`'s indeterminate-mechanism sentence, one
citation missing a copula, and one citation eliding real intervening text with "..."). These
were caught by mechanically re-verifying every quote block against the actual file content
before finalizing the sweep, and fixed prior to any commit — no incorrect citation was ever
committed. This is exactly the kind of error the plan's own emphasis on "sentence-cited" made
worth guarding against, so the extra verification step is recorded as good practice rather than
a deviation requiring its own Rule classification.

## Issues Encountered

None blocking. The only friction was self-inflicted (see above) and resolved before commit.

## User Setup Required

None - no external service configuration required. This plan is entirely documentation and
read-only verification; zero configuration changes, zero live bench runs, zero model calls.

## Next Phase Readiness

- This is the final plan of Phase 7's gap-closure 2 and, per `STATE.md`'s prior entries, the
  final plan of the v1 milestone. Phase 7 now reads 16/16 plans complete; `BCH-01`/ROADMAP
  criterion 1 remain honestly `not_met`; `P=0` unchanged.
- The one open, consciously-deferred follow-up (`--compaction basic`, untested against a
  working top-level `contextWindow` config; `phase-01/results/exp-basic/` voided as evidence for
  it) is now recorded in `docs/32k-compaction-policy.md` §8, `.planning/v1-MILESTONE-AUDIT.md`
  open item 6, and `.planning/REQUIREMENTS.md`'s BCH-01 footnote — any future session that wants
  to pick it up has three independent pointers to `DECISION.md` and does not need to
  rediscover the `exp-basic` voiding from scratch.
- No blockers. All hard safety constraints held throughout: `providers.json` sha256
  `534151965f81089b11d96d4af0b8a115b558f38efd42e82a9edd2a76f44fc214` unchanged (checked before
  Task 1, before Task 2, and after Task 3); all six live service pids
  (46573/75548/48525/36175/19669/99162) unchanged; `colima status` → "colima is not running"
  (checked repeatedly); `lsof -i :3000` empty; no `harbor`/`cline`/`kanban` command was invoked
  by this plan (pre-existing, longer-running `cline` host processes observed at the final safety
  check predate this plan's session and were not started by it); `git status --short bench/runs/
  phase-07/bench/ phase-01/config/` empty throughout; `git diff --stat` across all three commits
  touches only `docs/`, `.planning/`, and `phase-07/results/20260831T023128Z-close/`.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-31*
