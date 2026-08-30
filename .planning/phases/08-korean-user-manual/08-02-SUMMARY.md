---
phase: 08-korean-user-manual
plan: 02
subsystem: docs
tags: [manual, gate, bash-3.2, honesty-markers, compaction, cline-bench, korean]

# Dependency graph
requires:
  - phase: 01-cline-config-compaction
    provides: "docs/32k-compaction-policy.md §5·§7 (contextWindow at settings top level, ×0.9 trigger, 29000→26100), docs/cline-max-tokens-findings.md"
  - phase: 04-headless-wrapper
    provides: "docs/headless-wrapper.md §3 (context_overflow_terminal / exit 5 classification)"
  - phase: 05-services
    provides: "phase-05/services/verify_services.sh standing gate"
  - phase: 06-network-exposure
    provides: "phase-06/net/verify_network.sh --baseline gate"
  - phase: 07-cline-bench-verification
    provides: "docs/cline-bench.md §4·§9 (allowed/forbidden claim sentences, 0 passed of 3 reached)"
provides:
  - "phase-08/manual/check_manual_claims.sh — the phase's standing honesty gate (marker + link-integrity based, not forbidden-string based)"
  - "phase-08/manual/fixtures/negative/ — deliberately broken corpus proving the gate is not fail-open"
  - "docs/manual/04-32k-operations.md — DOC-04, gated clean"
affects: [08-03-cli-and-mobile-manual, 08-05-kanban-manual, 08-06-index-and-close]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Required-marker + link-integrity gate instead of forbidden-string grep, to avoid colliding with prose that legitimately names the thing it forbids"
    - "bash 3.2 parallel indexed arrays with explicit ${#arr[@]} guards before every ${arr[@]}/${arr[*]} expansion (macOS bash 3.2 treats an explicitly-empty declared array as unbound under set -u)"
    - "Cross-referencing a sibling manual document not yet written (03-mobile.md) by bare filename rather than a docs/ path, so a forward reference does not trip the link-integrity check before the sibling plan runs"

key-files:
  created:
    - phase-08/manual/check_manual_claims.sh
    - phase-08/manual/fixtures/negative/00-getting-started.md
    - phase-08/manual/fixtures/negative/01-cli.md
    - phase-08/manual/fixtures/negative/02-kanban.md
    - phase-08/manual/fixtures/negative/03-mobile.md
    - docs/manual/04-32k-operations.md
    - phase-08/results/CURRENT_MANUAL_GATE_RUN
    - phase-08/results/20260830T192004Z-manual-gate/negative-control.txt
    - phase-08/results/20260830T192004Z-manual-gate/bare-preflight.txt
    - phase-08/results/20260830T192004Z-manual-gate/gate-04.txt
  modified: []

key-decisions:
  - "Cross-referenced docs/manual/03-mobile.md by bare filename (03-mobile.md) instead of the docs/-prefixed path, because that file is owned by the parallel/later 08-03 plan and doesn't exist yet — a literal docs/ path token would have made C4-links FAIL on a forward reference the gate can't yet resolve."
  - "Named the retired '작업 예산/태스크 쪼개기' advice exactly once, in a heading whose whole point is retiring it, then never repeated it as live guidance — matching the pattern docs/32k-compaction-policy.md itself already uses for its own retracted §9 conclusion."

patterns-established:
  - "Manual honesty gate is reusable via --file <name> scoping by every later 08-0x plan, and via a bare no-arg call as the phase-close sweep."

# Metrics
duration: 15min
completed: 2026-08-30
---

# Phase 8 Plan 02: Manual Honesty Gate + DOC-04 Summary

**Built a required-marker + link-integrity honesty gate for docs/manual/ (not a forbidden-string grep, to avoid the collision defect class this project hit repeatedly), proved it rejects a deliberately broken corpus, then wrote DOC-04 (32K 운용 주의) in Korean and passed it through that gate clean.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-30T19:10Z (approx, first file read)
- **Completed:** 2026-08-30T19:24Z
- **Tasks:** 2/2
- **Files modified:** 10 created (gate script, 4 fixtures, DOC-04, 4 result/transcript files)

## Accomplishments

- `phase-08/manual/check_manual_claims.sh`: read-only, re-runnable, bash-3.2-compatible standing gate with five checks (C1-exists, C2-evidence-pointer, C3-markers, C4-links, C5-index), `--file` scoping, and a `--negative-control` mode that inverts the pass/fail expectation against a deliberately broken fixture corpus.
- Proved the gate is not fail-open twice, saved as transcripts: `--negative-control` exits 0 (each of C1-C4 individually demonstrated failing on its intended fixture), and a bare run over the five real (not-yet-written) manual filenames exits 1, naming all five as missing under C1-exists.
- `docs/manual/04-32k-operations.md` (126 lines): the corrected 32K story — compaction works automatically, `contextWindow` belongs at `settings` top level (29000 → trigger 26100, ×0.9 once), the ~64s prefill wait and how to tell it apart from a stall, the retired "작업 예산/태스크 쪼개기" advice named once and retired, the terminal (non-retryable) server-400 failure mapped to the headless wrapper's `context_overflow_terminal`/exit 5, ⌘+click's touch limitation, and the cline-bench §9-compliant honesty paragraph (0 of 3 model-reaching tasks ever passed).
- `bash phase-08/manual/check_manual_claims.sh --file 04-32k-operations.md` exits 0 — all four applicable checks (C1-C4) PASS, no dangling links.

## Task Commits

1. **Task 1: Author the manual claim gate and prove it is not fail-open** - `4ce7bbc` (feat)
2. **Task 2: Write docs/manual/04-32k-operations.md (DOC-04)** - `42433af` (feat)

## Files Created/Modified

- `phase-08/manual/check_manual_claims.sh` - Standing honesty gate: existence/min-lines, evidence pointer, marker registry (17 [GAP-*] pairs across the five manual filenames), link integrity, index cross-reference; `--file`/`--negative-control`/`--out` interface; 0/1/2 exit contract.
- `phase-08/manual/fixtures/negative/{00-getting-started,01-cli,02-kanban,03-mobile}.md` - Deliberately broken copies, each isolating exactly one of C1-C4's failure modes.
- `docs/manual/04-32k-operations.md` - DOC-04, Korean, user-facing 32K operations guidance.
- `phase-08/results/CURRENT_MANUAL_GATE_RUN` - Points later tasks/plans at the shared gate-run directory.
- `phase-08/results/20260830T192004Z-manual-gate/{negative-control,bare-preflight,gate-04}.txt` - Proof transcripts.

## Decisions Made

- **03-mobile.md cross-reference format**: DOC-04's §6 needed to point at the mobile manual, but `docs/manual/03-mobile.md` is 08-03's output and doesn't exist during this parallel plan's execution. Referencing it by bare filename (`03-mobile.md`, no `docs/` prefix) keeps the cross-reference readable while staying outside C4-links' path-extraction prefixes (`docs/`, `phase-0`, `workspace/`, `bench/`, `.planning/`), so the gate doesn't fail on a forward reference it has no way to resolve yet.
- **Retired-advice wording**: Task 2's action explicitly requires naming and retiring "작업 예산/태스크 쪼개기" in the document (§4's own heading), while the higher-level success criteria describe this as advice that must "not appear." Resolved by writing it exactly once, inside the sentence whose entire purpose is retiring it, and never repeating it as live guidance elsewhere — the same pattern `docs/32k-compaction-policy.md` itself uses to preserve its own retracted §9 conclusion without re-endorsing it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixture-authoring self-collision: explanatory comments accidentally satisfied the checks they were describing**
- **Found during:** Task 1, first `--negative-control` dry run
- **Issue:** `01-cli.md`'s top-of-file HTML comment spelled out the literal phrase `근거 문서:` while explaining that the file omits it, and `02-kanban.md`'s comment spelled out the literal `[GAP-READONLY]` bracket token while explaining that the file omits it. Both accidentally made C2/C3 PASS instead of FAIL on their respective fixture — the exact "forbidden literal collides with prose that legitimately names the thing it describes" defect class this gate exists to avoid, self-inflicted in the gate's own test fixtures.
- **Fix:** Rewrote both comments to describe the omission without repeating the literal marker/phrase text (e.g., "the read-only-limitation one" instead of the bracket token).
- **Files modified:** `phase-08/manual/fixtures/negative/01-cli.md`, `phase-08/manual/fixtures/negative/02-kanban.md`
- **Verification:** Re-ran `--negative-control`; C2-evidence-pointer now correctly FAILs on `01-cli.md` and C3-markers correctly FAILs on `02-kanban.md` (missing `[GAP-READONLY]`), each of C1-C4 individually demonstrated exactly once across the four fixture files, overall negative-control exit 0.
- **Committed in:** `4ce7bbc` (part of Task 1 commit — caught before the first commit, not a follow-up fix)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug caught and fixed before commit, during the gate's own self-test)
**Impact on plan:** Strengthened the negative control's evidentiary value; no scope change, no live mutation, no code outside the two planned files.

## Issues Encountered

None beyond the deviation above.

## User Setup Required

None - no external service configuration required. Zero host `cline` invocations this plan.

## Next Phase Readiness

- `phase-08/manual/check_manual_claims.sh` is available to 08-03, 08-05, and 08-06 both `--file`-scoped (as each writes its own document) and as a bare phase-close sweep once all five exist.
- `docs/manual/04-32k-operations.md` is done and gated; ROADMAP Phase 8 success criterion 4 is satisfied (64s wait, automatic compaction + its delay, `contextWindow` at `settings` top level, ⌘+click touch limitation, Phase 1 VER conclusion — all present; the 2026-08-31-retired token-budget/task-split clause is named once, then not reissued).
- 08-03 must write `docs/manual/03-mobile.md`; once it exists, 04's bare-filename cross-reference in §6 will read naturally as a real sibling link (no gate change needed — C4-links only inspects `docs/`-prefixed tokens, and 04 never used one for this reference).
- No blockers. `phase-08/results/CURRENT_MANUAL_GATE_RUN` names `phase-08/results/20260830T192004Z-manual-gate` for any later plan that wants to append further gate transcripts to the same run directory rather than minting a new timestamp.

---
*Phase: 08-korean-user-manual*
*Completed: 2026-08-30*
