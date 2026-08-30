---
phase: 07-cline-bench-verification
plan: 10
subsystem: testing
tags: [cline-bench, harbor, gap-closure, documentation, anti-overclaim, BCH-01, BCH-02, BCH-03, phase-close]

# Dependency graph
requires:
  - phase: 07-09
    provides: "The three final numbers this plan needed: 4 unique tasks attempted (5 run instances across two run directories), 3 reached the model, 0 passed. bench/runs/20260830T122809Z-phase07-fix/summary.md with the reached-the-model header count; seven standing gates green."
provides:
  - "docs/cline-bench.md corrected in both directions (173 -> 260 lines): the parts that were false in the post-gap-closure era (§4's 'never reached the model' framing, §9's blanket prohibition) rewritten and explicitly scoped to the pre-fix run directory; the parts that remain true (0 passes, 4/12 coverage, H1 non-causal, on-wire system prompt still uncaptured) kept; a new §4 finding added (all 3 model-reaching tasks hit the 32K MAX_KV_SIZE ceiling)"
  - "phase-07/results/20260830T174325Z-phase-close-2/criteria2.md: the three ROADMAP criteria re-mapped to post-gap-closure evidence, with the reached-the-model sub-line criterion 1 needed, plus the host cline 3.0.60 drift recorded as a known unrepaired open item"
  - ".planning/ROADMAP.md Phase 7 block (10/10 plans, all three criteria verdicts inline, progress table row) and .planning/REQUIREMENTS.md BCH checkboxes/status rows synced to the same N=4/M=3/P=0 counts"
  - ".planning/STATE.md Current focus/Current Position corrected in place, with the pre-gap-closure text preserved as '이전' history rather than deleted"
  - "phase-07/results/20260830T174325Z-phase-close-2/anti-overclaim.md (6/6 checks PASS, each cited to a specific sentence) and gates/collateral.md (9/9 items PASS)"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "correct-in-both-directions: a documentation-correction plan must rewrite the parts that became false (in whichever direction the evidence moved) while explicitly preserving the parts that remain true, scoped by run-directory name where the claim differs by era -- neither a blanket rewrite nor a blanket preservation is honest when half the story changed and half didn't"
    - "audit-by-reading-not-by-self-satisfying-grep: an anti-overclaim check is only meaningful if each PASS cites the actual sentence a reader would encounter, decided by reading the document; a grep pattern this same plan's own prose would also satisfy is not evidence of anything"

key-files:
  created:
    - phase-07/results/20260830T174325Z-phase-close-2/criteria2.md
    - phase-07/results/20260830T174325Z-phase-close-2/anti-overclaim.md
    - phase-07/results/20260830T174325Z-phase-close-2/gates/collateral.md
    - phase-07/results/20260830T174325Z-phase-close-2/gates/ (preflight.txt, verify_bench-prefix.txt, verify_bench-postfix.txt, verify_bench-negative.txt, verify_services.txt, verify_no_regression.txt, verify_sandbox.txt, verify_network.txt, verify_config.txt)
  modified:
    - docs/cline-bench.md
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
    - .planning/STATE.md

key-decisions:
  - "docs/cline-bench.md's original bold §9 prohibition (never claim cline-bench verified this stack) was calibrated to M=0 and is now factually backwards for the post-fix era -- rewrote it to forbid the sentence that is now the dangerous one ('passed'/'validated'/'can complete tasks'), and added a short list of what Phase 8 MAY now write with evidence (flashnext is reached; the stack has not completed any task within the 32K budget)."
  - "H1 (host cline version skew, 3.0.60 vs 3.0.53) is recorded everywhere as ruled-out and non-causal, explicitly so it is not revived -- the schema-rejection root cause (H4) is the one and only causal story, and every document states this."
  - "The unique-task-vs-run-instance distinction 07-08 discovered is carried through every document this plan touched (docs/cline-bench.md, criteria2.md, ROADMAP, REQUIREMENTS, STATE): N=4 unique tasks (5 run instances), never blended or rounded toward 5."
  - "The host cline 3.0.60 drift is recorded as a known, pre-existing, unrepaired, out-of-scope item in criteria2.md and STATE.md -- not silently repaired (no npm install -g was run) and not silently dropped from the record."
  - "The anti-overclaim audit's 6 checks were decided by reading the four documents' actual sentences, not by writing grep patterns -- each PASS row in anti-overclaim.md cites the specific sentence a reader would encounter, per the plan's own warning against an audit that only passes on its own prose."

patterns-established:
  - "See tech-stack.patterns above."

# Metrics
duration: ~30min (context-reading and drafting through the Task 3 commit at 2026-08-31T02:51:10+09:00)
completed: 2026-08-31
---

# Phase 7 Plan 10: Gap-Closure Documentation Correction and Phase Close Summary

**Final counts: N=4 unique cline-bench tasks attempted (5 run instances across two run directories), M=3 reached this stack's model server (flashnext), P=0 passed. ROADMAP criterion 1 (5-8 tasks) remains `not_met`. Corrected `docs/cline-bench.md` in both directions — rewrote the parts that gap-closure made false (the "never reached the model" limitation, the blanket "never claim cline-bench verified this stack" prohibition), kept the parts that remain true (still 0 passes, still only 4/12 of the pool, the H1 version-skew hypothesis stays ruled-out and non-causal), and added the new finding that every task which reached the model hit the 32K `MAX_KV_SIZE` ceiling. Synced ROADMAP/REQUIREMENTS/STATE and swept all seven standing gates green.**

## Performance

- **Duration:** ~30 min
- **Completed:** 2026-08-31T02:51:10+09:00 (Task 3 commit)
- **Tasks:** 3/3
- **Files modified:** `docs/cline-bench.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, plus ~85 new evidence/transcript files under `phase-07/results/20260830T174325Z-phase-close-2/` and cross-phase gate-sweep directories under `phase-02/results/`, `phase-03/results/`

## Accomplishments

- **Corrected `docs/cline-bench.md` in both directions** (173 → 260 lines, all nine numbered sections intact): §1's conclusion now states N=4/M=3/P=0 across both run directories instead of the old N=1/M=0/P=0; §2 adds the post-fix injection mechanism, the container's pinned cline 3.0.53, and the host cline 3.0.60 drift with the H1-ruled-out explanation; §3 adds `injection_probe.sh` and both run directories' `verify_bench.sh` invocations; §4 (the section required to stay most visible) rewrites the "never reached the model" bullet scoped explicitly to the pre-fix run directory by name, adds the reached-the-model proof and its limits, and adds the new 32K-ceiling-is-structural finding while keeping the "ran ≠ passed" bullet verbatim; §6/§7/§8 updated with real operational evidence, the corrected removal recipe (`docker builder prune`, not `docker rmi` — harbor already deletes trial images), and evidence-index rows for every gap-closure artifact; §9's forbidden-sentence list is inverted to forbid the now-dangerous overclaim ("passed"/"validated"/"can complete tasks") while permitting the now-true, evidence-backed statement that requests reach flashnext.
- **Wrote `criteria2.md`**, re-mapping all three ROADMAP criteria to post-gap-closure evidence: criterion 1 `not_met` (4 unique, 5-8 required) with the new reached-the-model sub-line (3/4) BCH-01's honesty depends on; criteria 2/3 `met` for all 4 unique tasks/5 instances across both run directories; a BCH mapping table; and the host cline 3.0.60 drift recorded as known/unrepaired/out-of-scope.
- **Synced ROADMAP, REQUIREMENTS, and STATE** to the same N=4/M=3/P=0 counts: ROADMAP Phase 7's three criteria verdicts written inline, `**Plans**: 10 plans`, all ten plan checkboxes `[x]`, progress table row updated to `10/10 ◆ 완료`; REQUIREMENTS BCH-02/03 ticked (`met`), BCH-01 left unticked with a dated correction footnote; STATE's Current focus/Current Position rewritten with the corrected picture, the pre-gap-closure text preserved verbatim as `이전(Phase 7 최초 완료, gap-closure 이전)` history rather than deleted.
- **Swept all seven standing gates green**: `preflight.sh` 11/11; `verify_bench.sh` 10/10 on the pre-fix directory (B11 correctly SKIP) and 11/11 on the post-fix directory (B11 PASS); the `--run-dir /nonexistent` negative control correctly still FAILs (4/10, B1 catches the missing directory); `verify_services.sh` 15/15; `verify_no_regression.sh` INF03 PASS; `verify_sandbox.sh` 16/16 with `CRITERION 4 PASS`; `verify_network.sh --baseline` 24/24; `verify_config.sh` exit 0 clean (`check_versions.sh` not run, banned this plan).
- **Wrote `anti-overclaim.md`**: 6/6 checks PASS, each row citing the actual sentence in `docs/cline-bench.md`, `criteria2.md`, `ROADMAP.md`, or `STATE.md` that was read to decide the verdict — not a self-satisfying grep pattern. Confirmed the counts N=4/M=3/P=0 are identical across all four documents.
- **Wrote `gates/collateral.md`**: 9/9 collateral-damage items PASS — six live pids unchanged, port 3000 unbound, `EXTRA_ALLOW_PATHS` unset in every plist, `workspace/ALLOWED_REPOS.json` unchanged (still excludes `bench/` and the repo root), the SBX-04 canary unchanged with `CRITERION 4 PASS`, host `providers.json` hash byte-identical, host `cline` version recorded as 3.0.60 (unchanged, not repaired), no lingering bench/harbor containers, no new `tailscale serve` entries beyond Phase 6's documented baseline.

## Task Commits

Each task was committed atomically:

1. **Task 1: Correct docs/cline-bench.md to match reality** - `5458259` (docs)
2. **Task 2: Re-map the criteria and sync ROADMAP, REQUIREMENTS and STATE** - `b6edfac` (docs)
3. **Task 3: Final gate sweep and anti-overclaim audit** - `21a4dac` (docs)

## Files Created/Modified

- `docs/cline-bench.md` — corrected in both directions, all nine sections, 173 → 260 lines
- `phase-07/results/20260830T174325Z-phase-close-2/criteria2.md` — the three criteria re-mapped to post-gap-closure evidence, host cline drift recorded
- `phase-07/results/20260830T174325Z-phase-close-2/anti-overclaim.md` — 6/6 checks PASS, cited sentences
- `phase-07/results/20260830T174325Z-phase-close-2/gates/` — per-gate transcripts (9 files) plus `collateral.md`
- `.planning/ROADMAP.md` — Phase 7 block (three criteria verdicts inline, 10/10 plans, plan checkboxes) and progress-table row
- `.planning/REQUIREMENTS.md` — BCH-01/02/03 checkboxes and status-table rows
- `.planning/STATE.md` — Current focus/Current Position corrected in place; pre-gap-closure text preserved as history
- `phase-02/results/20260830T174829Z-inf03/`, `phase-03/results/20260830T174839Z-sbx/`, `phase-07/results/20260830T174637Z-preflight/`, `phase-07/results/20260830T174746Z-gate/`, `phase-07/results/20260830T174841Z-net-gate/` — standing-gate sweep transcripts from the cross-phase gates Task 3 re-ran (each script's own default output convention, same pattern as prior plans)

## Decisions Made

See `key-decisions` in frontmatter. In brief: rewrote the two now-false halves of `docs/cline-bench.md` (the pre-fix "never reached the model" framing, scoped explicitly to the pre-fix run directory; the blanket §9 prohibition, inverted to forbid the now-dangerous overclaim) while keeping every part that remains true; carried forward the unique-task-vs-run-instance distinction without blending it; recorded the host cline 3.0.60 drift as known/unrepaired everywhere required; decided the anti-overclaim audit by reading sentences, not by grep.

## Deviations from Plan

None (Rule 1-4 sense) — no bugs, missing functionality, blocking issues, or architectural changes were required. This plan executed as written: correct the documentation in the direction the evidence supports, sync the tracking documents, sweep the gates, audit for overclaim, and close the phase.

## Issues Encountered

None. Every evidence path cited in `criteria2.md` and `anti-overclaim.md` was confirmed to exist on disk before being cited. Both run bundles (`bench/runs/20260830T093657Z-phase07/`, `bench/runs/20260830T122809Z-phase07-fix/`) were confirmed untouched (`git status --short` empty for both) throughout this plan — no writes into either evidence bundle occurred.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **Phase 7 is closed at the count it actually reached: 4 unique tasks attempted, 3 reached the model, 0 passed.** ROADMAP criterion 1 is `not_met`; criteria 2 and 3 are `met`.
- **Phase 8 (한글 사용 매뉴얼)** can now write, with evidence, that cline-bench requests reach this stack's flashnext/litellm chain — but must not write that cline-bench "passed," that the suite was "validated," or that this stack "can complete" cline-bench tasks (`docs/cline-bench.md` §9's rewritten forbidden/permitted lists are the authoritative boundary).
- **The 32K context ceiling is now a corroborated (n=3), not merely suspected (n=1), limitation of this stack for cline-bench-shaped agent loops** — every task that ever reached the model was rejected at `MAX_KV_SIZE=32768`. Phase 8's 32K-operations documentation (DOC-04) should treat this as reinforcing evidence, not new information, consistent with `docs/32k-compaction-policy.md`'s already-documented host-side ceiling.
- **The host `cline` 3.0.60 drift remains open and unrepaired** — recorded in `criteria2.md` and `.planning/STATE.md` as a known item requiring an explicit future decision (`npm install -g cline@3.0.53`, only after confirming no `cline`/kanban process is running). Not this plan's scope; not silently fixed.
- Zero `harbor run` invocations, zero host `cline` invocations, zero model spend in this plan. Six live pids, port 3000, `EXTRA_ALLOW_PATHS`, and the SBX-04 canary all confirmed unchanged at the end of Task 3.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-31*
