---
phase: 12-documentation-update
plan: 02
subsystem: documentation
tags: [reasoning-history, plan-act, cline-source-audit, correction-precedent, ab-disclosure]

# Dependency graph
requires:
  - phase: 09-plan-act-reasoning-gates
    provides: "phase-09/PRB-04-FINDINGS.md §3 — the corrected source-inspection finding (shouldIncludeReasoningHistory / agentPartToContentBlock DO re-attach reasoning; zero measured token cost)"
  - phase: 11-plan-act-wrappers
    provides: "phase-11/WRAPPER-DESIGN.md (shipped wrapper contract, supersedes the shell-function sketch) and phase-11/AB-RESULTS.md §11 (ratified keep-by-override decision)"
provides:
  - "docs/plan-act-reasoning-implementation.md corrected: reasoning-history architecture claim fixed, token-cost claim kept distinct, superseded wrapper sketch replaced with a pointer, dated correction banner, change table, unresolved section, appendix preserving the original text verbatim"
affects: [12-08-requirements-annotation, any future reader of the plan-act implementation doc]

# Tech tracking
tech-stack:
  added: []
  patterns: ["docs/32k-compaction-policy.md correction shape (banner / change-table / unresolved / collapsed-appendix) applied to a second document"]

key-files:
  created: []
  modified: [docs/plan-act-reasoning-implementation.md]

key-decisions:
  - "Kept the architecture claim ('Cline re-attaches reasoning') and the token-cost claim ('it costs 0 tokens here') explicitly separate throughout, per the plan's own framing of this as the milestone's most consequential self-correction."
  - "Cited all five Phase-9 source paths in `git show cli-v3.0.53:<path>` form rather than bare line numbers, since the cline-src working tree has since moved to cli-v3.0.61 — avoiding the qanda/004 mistake of a future reader grepping the live tree and finding nothing."
  - "Removed the literal appendix marker string from the correction banner and the T5 pointer note (both originally referenced the appendix by quoting its exact heading text), because the grader's live/appendix split triggers on the first occurrence of that literal anywhere in the file — quoting it early would have silently reclassified the entire corrected body as 'appendix' and skipped it from live-body forbidden/citation/disclosure checks."

patterns-established:
  - "When referencing an appendix by name in prose, never quote its exact marker heading literally outside the heading itself in a marker-driven live/appendix splitter."

# Metrics
duration: ~45min
completed: 2026-09-10
---

# Phase 12 Plan 02: Correct plan-act-reasoning-implementation.md Summary

**Corrected the milestone's most consequential false claim — Cline DOES re-attach reasoning history (`shouldIncludeReasoningHistory`, `agentPartToContentBlock`) contrary to the doc's prior claim, while preserving the separate, still-true finding that replayed reasoning costs zero measured tokens on this stack (PRB-04: 16/16 at delta=0) — and superseded the naive shell-function wrapper sketch that Phase 11's MUTANT-LEAKY test proved leaks `--thinking` via bare `"$@"` passthrough.**

## Performance

- **Duration:** ~45 min
- **Tasks:** 2/2 completed
- **Files modified:** 1 (`docs/plan-act-reasoning-implementation.md`)

## Accomplishments

- Replaced the false-negative §T2 source-inspection bullets and transition sentence with `phase-09/PRB-04-FINDINGS.md` §3's actual finding, citing all five real source paths in the mandatory `git show cli-v3.0.53:<path>` form (the `cline-src` checkout has since moved to `cli-v3.0.61`).
- Kept the architecture claim ("Cline re-attaches reasoning") and the token-cost claim ("costs 0 tokens here") explicit and separate — the doc's original defect was conflating the two.
- Replaced the superseded §T5 shell-function sketch (`cline-plan() { ... "$@"; }`) with a labelled `[superseded, 2026-09-10]` pointer to `phase-11/WRAPPER-DESIGN.md` §2·§3·§4 and the shipped `phase-11/cline-plan`/`phase-11/cline-act` scripts, explaining the `"$@"`-passthrough leak Phase 11's `MUTANT-LEAKY` test exists to catch.
- Added a dated `2026-09-10 정정` banner (replacing "계획, 미착수") stating the real outcome: v1.1 shipped; `cline-plan → flashnext-plan` was kept by human override of the pre-registered rule's `revert` output; the override reason was the now-contained `providers.json` side effect, not an A/B accuracy win. Carries the full A/B disclosure quartet (`25/30`, `p=0.563`, `override`, `phase-11/AB-RESULTS.md`).
- Added `## 7. 이 정정이 바꾸는 것` (5-row before/after change table, paraphrased, no verbatim forbidden strings), `## 8. 여전히 미해결` (CFG-05 drift, real-workload compaction non-pruning, untested `--compaction basic`, one-day-old containment, the unexplained VRF-04-vs-Phase-11 contradiction with no invented mechanism), and `## 9. 부록 — 정정 전 기록` — a collapsed `<details>` block preserving the original banner, the three false-negative bullets, the transition sentence, and the shell-function sketch verbatim.
- Left untouched, as instructed: §6's role_shim callout (not present verbatim as quoted in the plan text — the actual §6 in this file is "중단 지점 요약," which was left as-is since Phase 9 §4 recorded no correction needed there), the T7 documentation checklist, and the table/summary rows describing context accumulation as the gate's own criterion (lines that became 229/244 pre-edit, now inside §4/§6 post-edit, unchanged).

## Task Commits

1. **Task 1 + Task 2 (combined in one commit per the plan's single-file, two-task structure)** - `06558bd` (docs)

_Both tasks touch the same file with tightly coupled edits (Task 2's appendix depends on exactly the text Task 1 removes); they were completed together and verified together before the single commit, per the plan's own instruction to commit per-task but with both tasks scoped to one file's shape change._

## Files Created/Modified

- `docs/plan-act-reasoning-implementation.md` - Corrected reasoning-history finding, superseded wrapper sketch replaced with a pointer, dated correction banner, change table, unresolved section, appendix preserving the original text verbatim.

## Decisions Made

- Kept the architecture claim and token-cost claim distinct throughout (this is the plan's central instruction — the risk is a reader collapsing "reasoning IS re-attached" and "it costs 0 tokens" into a single flattened, potentially wrong takeaway).
- Cited every Phase-9 source path via `git show cli-v3.0.53:<path>` rather than bare line numbers against the current working tree, since that tree is now at `cli-v3.0.61`.
- Fixed a self-inflicted grader hazard mid-execution: the first draft of the correction banner and the T5 pointer quoted the literal appendix heading text (`부록 — 정정 전 기록`) as a cross-reference. Because `phase-12/verify_docs.sh`'s live/appendix split triggers on the *first* occurrence of that literal string anywhere in the file, quoting it in the banner (near the top) would have caused the splitter to classify almost the entire corrected document as "appendix" rather than "live body" — silently exempting it from the FORBIDDEN, CITED_PATHS_EXIST, TAG_CITATION, and AB_DISCLOSURE checks that only scan the live body. Caught by noticing `TAG_CITATION` reported "does not cite cli-v3.0.53 (check not triggered)" despite the corrected text visibly citing it many times. Fixed by rephrasing both cross-references to avoid the literal marker substring (e.g. "§9(정정 전 원문을 보존하는 부록)" instead of quoting the heading), leaving the literal marker present exactly once, at the actual `## 9.` heading.

## Deviations from Plan

None beyond the self-caught grader-interaction issue described above, which was fixed before commit (not a deviation from the plan's intent — the plan's own text and structure were followed; only my initial phrasing of two cross-references needed correcting to avoid an unintended interaction with the grader's marker-based split).

## Issues Encountered

- Initial full run of `phase-12/verify_docs.sh` showed all checks passing for this file but with `TAG_CITATION` reporting "check not triggered" — a false-positive-looking pass that on inspection meant the live/appendix split point had moved to line 13 of the file instead of line 336. Diagnosed via `grep -n '부록 — 정정 전 기록'` finding 3 occurrences instead of the expected 1, then fixed by rewording the two premature occurrences. Re-ran the grader after the fix; `TAG_CITATION` then correctly reported the required-form citation present, and all other checks continued to pass on the correctly-scoped live body.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `docs/plan-act-reasoning-implementation.md` is corrected and ready as a reconciliation target for any future edits to `docs/plan-act-reasoning-design.md`/`-diagrams.md` (owned by concurrent plan 12-03).
- `phase-12/verify_docs.sh` reports zero `FAIL[DOCS]` lines naming this file, both in isolation and in the full-sweep run alongside the other five wave-2 plans' files (9 unrelated failures remain, all in `docs/32k-compaction-policy.md` and `docs/cline-max-tokens-findings.md`, owned by other wave-2 plans).
- No blockers. Stack state confirmed unchanged throughout: `com.ohama.flashnext` (46573) and `com.ohama.role-shim` (75548) never restarted, cumulative `Prefill started` count held at 1054, `bash phase-01/config/verify_config.sh` exits 0, `providers.json` untouched, no port-3000 listener, `flashnext-codex` never invoked.

---
*Phase: 12-documentation-update*
*Completed: 2026-09-10*
