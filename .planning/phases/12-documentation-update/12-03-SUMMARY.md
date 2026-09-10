---
phase: 12-documentation-update
plan: 03
subsystem: docs
tags: [plan-act, reasoning_effort, litellm, hosted_vllm, gate-verdict, ab-test, documentation-correction]

# Dependency graph
requires:
  - phase: 09-preflight-gates
    provides: "phase-09/GATE-VERDICT.md's Gate ① adjudication (zero-cost reasoning reattachment) and PRB-04-FINDINGS.md §3's source correction"
  - phase: 10-alias-and-reach
    provides: "the shipped hosted_vllm/ aliases (flashnext-plan/-act/-reach-xhigh) and PHASE-10-FINDINGS.md's weak-margin/reach disclosures"
  - phase: 11-wrapper-and-ab
    provides: "WRAPPER-DESIGN.md's deny-by-default contract, OPEN-ITEMS.md's per-prefix 400/500/exit-1 measurement, AB-RESULTS.md §11's override-to-keep decision"
  - phase: 12-documentation-update
    plan: 01
    provides: "phase-12/verify_docs.sh (the grader) and phase-12/SCOPE-DECISIONS.md (resolved citations, TAG_CITATION/AB_DISCLOSURE mechanics)"
provides:
  - "docs/plan-act-reasoning-design.md corrected: adopted status, both §5 gate verdicts with reasons, per-alias-prefix --thinking failure modes, superseded §L3 sketch replaced with a pointer, correction table, unresolved section, preserved original appendix"
  - "docs/plan-act-reasoning-diagrams.md corrected: implemented status, corrected Gate ① source-reading callout, annotated (not redrawn) mermaid K2/K6 disposition, web-mirror staleness caveat, correction table, preserved original appendix"
affects: [12-08-audit]

# Tech tracking
tech-stack:
  added: []
  patterns: ["dated correction banner + '이 정정이 바꾸는 것' table + '미해결' section + collapsed '부록 — 정정 전 기록' appendix, per docs/32k-compaction-policy.md's precedent"]

key-files:
  created: []
  modified:
    - docs/plan-act-reasoning-design.md
    - docs/plan-act-reasoning-diagrams.md

key-decisions:
  - "Corrected the --thinking/400 claim to be per-alias-prefix (openai/ -> litellm 400, hosted_vllm/ -> model-server 500, raw cline bypassing the wrapper -> exit 1) rather than a single figure, per phase-12/SCOPE-DECISIONS.md item 8 and phase-11/OPEN-ITEMS.md Open Item 1."
  - "Stated the A/B outcome as no-measurable-improvement-plus-human-override, never as an improvement, every place the A/B is mentioned in the live body (25/30, p=0.563, override, phase-11/AB-RESULTS.md) — matches the grader's AB_DISCLOSURE class and this plan's own hard warning not to let a reader conclude the A/B favoured flashnext-plan."
  - "Correction-table 'previous' cells paraphrase rather than quote the forbidden literal verbatim — caught by the grader on first pass (diagrams.md quoted '소스 조사는 \"누적되지 않는다\" 쪽을 가리킨다' verbatim in the table), fixed by paraphrasing per docs/32k-compaction-policy.md §7's own convention."
  - "Left §7 item 1 (design.md) and the mermaid diagram itself (diagrams.md §6) untouched, annotating rather than redrawing/rewording, per phase-09/PRB-04-FINDINGS.md §4's explicit 'no correction needed' finding for those spots."

patterns-established: []

# Metrics
duration: 35min
completed: 2026-09-10
---

# Phase 12 Plan 03: Correct plan-act-reasoning design.md and diagrams.md Summary

**Replaced both documents' stale "제안/계획, 미착수" badges with an adopted/implemented status carrying both §5 gate verdicts (Gate ① zero-cost, not omission; Gate ② no accuracy benefit, kept via human override), qualified the `--thinking` 400 claim per alias prefix (400 for `openai/`, 500 for `hosted_vllm/`, exit 1 for a raw bypassing `cline`), and moved the superseded `cline-plan(){ ... "$@"; }` sketch into a preserved appendix behind a pointer to the shipped `phase-11/cline-plan`/`cline-act` wrappers.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 2 (Task 1: design.md, Task 2: diagrams.md)
- **Files modified:** 2

## Accomplishments

- `docs/plan-act-reasoning-design.md`: dated 2026-09-10 correction banner states adopted (v1.1) status and both gate verdicts with their real *reasons* (Gate ① passed because replayed reasoning costs 0 tokens, not because it isn't reattached; Gate ② found no accuracy benefit and `keep` is a human override of the pre-registered rule's `revert` output). The §1-3 `--thinking`/400 sentence is now qualified per alias prefix, with the wrapper's parsing-stage refusal stated as the fact that supersedes the whole problem. The §L3 shell-function sketch is replaced in the live body by a labelled-superseded pointer to `phase-11/cline-plan`/`cline-act`; the original snippet is preserved verbatim in a new §11 appendix. New §9 "이 정정이 바꾸는 것" table and §10 "미해결" section (CFG-05, real-workload compaction non-pruning, `--compaction basic` untested, containment less than a day old) added.
- `docs/plan-act-reasoning-diagrams.md`: same banner treatment (구현됨, both gates summarized). The §6 Gate ① callout no longer claims source inspection ruled out reasoning accumulation — it now states the opposite (accumulation is real, architecturally) with the zero-token-cost reason for why the gate still passed. The mermaid flowchart itself is unchanged; a new note beneath it records that K2 and K6 did not fire, and why (zero cost vs. human override), without redrawing the diagram. Web-mirror row now carries a staleness caveat. New §7 table and §9 appendix (preserving the original status line and Gate ① callout verbatim) added.
- Both files' `cli-v3.0.53` citations now carry the literal `git show cli-v3.0.53:` form (`phase-12/SCOPE-DECISIONS.md` item 6), verified resolvable against the real `cline-src` checkout.
- `bash phase-12/verify_docs.sh` reports zero `FAIL[DOCS]` lines naming either file (13 remaining failures across the full sweep all belong to other wave-2 plans' files: `docs/32k-compaction-policy.md`, `docs/cline-max-tokens-findings.md`, `qanda/003-how-the-wrappers-work.md`).

## Task Commits

1. **Task 1 + Task 2 (combined, single commit — both files declared by this plan, no partial-task state existed between them):** `70985a5` — `docs(12-03): correct design.md/diagrams.md status, gates, thinking-400 per-prefix, L3 sketch`

No separate plan-metadata commit was made beyond this one, per `COMMIT_PLANNING_DOCS` staging rules — this SUMMARY and the STATE.md update are committed by the orchestrator's normal phase-close flow, not by this plan, to avoid a second commit racing wave-2's other five concurrently-running plans' own final commits.

## Files Created/Modified

- `docs/plan-act-reasoning-design.md` — status banner, per-prefix `--thinking` correction, §L3 sketch superseded-and-pointed, §9/§10/§11 (table/unresolved/appendix) added
- `docs/plan-act-reasoning-diagrams.md` — status banner, Gate ① callout corrected, mermaid K2/K6 annotated, web-mirror caveat, §7/§9 (table/appendix) added

## Decisions Made

- Qualified the `--thinking` failure mode by alias prefix rather than leaving a single "400" figure, per `phase-12/SCOPE-DECISIONS.md` item 8 and `phase-11/OPEN-ITEMS.md` Open Item 1 (case 1a/1b/1c) — a document that says only "400" is wrong for four of the five live aliases.
- Every A/B mention in both live bodies carries `25/30`, `p=0.563`, `override`, and `phase-11/AB-RESULTS.md` — matching the grader's `AB_DISCLOSURE` mechanical check and the plan's explicit instruction not to let a reader conclude the A/B favoured `flashnext-plan`.
- Correction-table "이전" cells paraphrase rather than quote the forbidden literal verbatim (caught on first `verify_docs.sh` run for diagrams.md's table — see Deviations below).
- Left `design.md` §7 item 1 and `diagrams.md`'s mermaid diagram body itself untouched (annotate, don't redraw/reword), per `phase-09/PRB-04-FINDINGS.md` §4's explicit "no correction needed" findings for those exact spots.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Correction table quoted a forbidden literal verbatim instead of paraphrasing**
- **Found during:** Task 2 verification (first `bash phase-12/verify_docs.sh` run against `diagrams.md`)
- **Issue:** The new §7 "이 정정이 바꾸는 것" table's "이전" column for the Gate ① row quoted `소스 조사는 "누적되지 않는다" 쪽을 가리킨다` verbatim — the exact forbidden literal `phase-12/verify_docs.sh` checks for in the live body. This directly violates the plan's own constraint ("Correction tables paraphrase, they do not quote") and would have failed the grader's `FORBIDDEN` check.
- **Fix:** Replaced the quoted sentence with a short paraphrase ("소스 판독이 재첨부 없음을 시사한다는 취지의 서술(범위를 잘못 짚은 함수 인용)"), matching `docs/32k-compaction-policy.md` §7's own paraphrase convention.
- **Files modified:** `docs/plan-act-reasoning-diagrams.md`
- **Verification:** Re-ran `bash phase-12/verify_docs.sh` — the `FORBIDDEN` check for that literal now reports `OK[DOCS]: ... absent from live body`.
- **Committed in:** `70985a5` (part of the single task commit; the fix was made before committing, so no separate commit exists for it)

---

**Total deviations:** 1 auto-fixed (1 bug, self-caught during verification before commit)
**Impact on plan:** No scope creep — pure correction of the plan's own paraphrase-not-quote constraint before it reached a commit.

## Issues Encountered

None beyond the deviation above. Reading `phase-11/AB-RESULTS.md` §11, `phase-11/OPEN-ITEMS.md`, and `phase-11/PHASE-11-FINDINGS.md` confirmed Phase 11 is closed (no re-derivation needed beyond what `12-RESEARCH.md` and `phase-12/SCOPE-DECISIONS.md` already carried forward).

## User Setup Required

None — documentation only, no external service configuration.

## Next Phase Readiness

- Both files pass every `phase-12/verify_docs.sh` assertion registered for them (FORBIDDEN, REQUIRED, REQUIRED_ANY, APPENDIX_INTEGRITY, TAG_CITATION, AB_DISCLOSURE).
- `plan-12-08`'s human-read audit still has residual work: `AB_DISCLOSURE`'s trigger is a literal-string match (`'A/B'`/`'AB-RESULTS'`) and cannot mechanically detect a pure-Korean-paraphrase discussion of the A/B that uses neither literal — none exists in either of this plan's two files (checked by inspection), but 12-08 should not rely solely on the grader for this class of gap.
- No blockers for other wave-2 plans: this plan touched only its two declared files; `git diff --name-only HEAD~1 HEAD` on the commit lists exactly `docs/plan-act-reasoning-design.md` and `docs/plan-act-reasoning-diagrams.md`, no index race with concurrently-running 12-02/12-04/12-05/12-06/12-07.
- Zero model requests issued: `grep -c "Prefill started" ~/llm-system/services/logs/flashnext.err` remained at `1054` throughout; `com.ohama.flashnext` (46573), `com.ohama.role-shim` (75548) PIDs unchanged; `bash phase-01/config/verify_config.sh` still exits 0.

---
*Phase: 12-documentation-update*
*Completed: 2026-09-10*
