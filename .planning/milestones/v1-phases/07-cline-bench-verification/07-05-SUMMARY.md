---
phase: 07-cline-bench-verification
plan: 05
subsystem: documentation
tags: [cline-bench, harbor, docs, phase-close, criteria, ROADMAP, BCH-01, BCH-02, BCH-03]

# Dependency graph
requires:
  - phase: 07-01
    provides: harbor/cline-bench install, preflight.sh, measured 12-task live pool
  - phase: 07-02
    provides: contextWindow injection verdict (INJECTABLE, source-derived), run_task.sh/make_summary.sh/verify_bench.sh
  - phase: 07-03
    provides: the one smoke-run bundle, fail-infra root-cause diagnosis, user's stop-at-one decision
  - phase: 07-04
    provides: bench/runs/20260830T093657Z-phase07/summary.md + prompts/INDEX.md, post-batch gate sweep
provides:
  - docs/cline-bench.md, the house-style Phase 7 record (결론/실행 내역/재현/한계/보안 태세/운영/제거/증거/Phase 8 인계)
  - docs/services.md §11, an additive Phase 7 cross-reference
  - phase-07/results/20260830T103307Z-phase-close/criteria.md, mapping all three ROADMAP criteria and BCH-01/02/03 to evidence
  - phase-07/results/20260830T103307Z-phase-close/handoff.md, answering both inherited open questions
  - .planning/ROADMAP.md Phase 7 marked complete (5/5) with criterion 1's not_met qualification inline
affects: [08-korean-manual]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "phase-close criteria.md mirrors ROADMAP wording verbatim, with the not_met/partial qualification written inline next to the criterion rather than only in a linked file, so a reader of ROADMAP.md alone cannot miss the shortfall"
    - "wording-collision avoidance by paraphrase: naming a forbidden-adjacency term (the public-exposure subcommand) without ever placing it on the same line as its counterpart term, rather than omitting the term entirely"

key-files:
  created:
    - docs/cline-bench.md
    - phase-07/results/20260830T103307Z-phase-close/criteria.md
    - phase-07/results/20260830T103307Z-phase-close/handoff.md
    - phase-07/results/20260830T103307Z-phase-close/ (full 8-gate sweep evidence)
  modified:
    - docs/services.md (additive §11 cross-reference)
    - .planning/ROADMAP.md (Phase 7 plans marked [x], criterion 1 qualified not_met, progress row updated)

key-decisions:
  - "ROADMAP criterion 1 (5-8 tasks) recorded as not_met inline in ROADMAP.md itself, not only in criteria.md -- the plan's own instruction was to mirror criteria.md exactly and not show the phase as fully complete without the qualification visible next to the criterion, so the not_met status and the one-line reason were written directly into the Success Criteria list, not left implicit in the progress table's Status cell alone."
  - "docs/cline-bench.md's house-rule-9 discussion of the host-posture escalation flag and the public-exposure subcommand followed this phase's own precedent from network-exposure.md of paraphrasing (\"host-posture 이스케이프 플래그\", \"공용으로 여는 서브커맨드\") rather than naming the literal flag/subcommand string, while still naming the flag directly once elsewhere (\"--auto-approve\") in a sentence where it never touches an equals sign or shares a line with the whitelist variable or the public-exposure term -- satisfying the plan's requirement to discuss it by name without recreating the trap."
  - "criteria.md's BCH-02 status is met for the one task actually attempted, explicitly scoped -- the on-wire system prompt (never captured) does not downgrade the criterion, since the criterion's own text asks for the prompt text sent (on disk as instruction.md + agent-command.txt), not the transcript."

patterns-established:
  - "A phase-close ROADMAP update writes the not-met qualification directly into the Success Criteria prose, not only into the Progress table's Status column, so a reader scanning only the phase's own success-criteria list (not cross-referencing criteria.md) still sees the shortfall."

# Metrics
duration: ~35min
completed: 2026-08-30
---

# Phase 7 Plan 5: docs/cline-bench.md + Phase-Close Summary

**Phase 7 closed honestly: `docs/cline-bench.md` records that 1 of 12 live cline-bench tasks ran (not 5-8), 0 passed, and the one task never reached this stack's model server -- with limits and a removal recipe as their own top-level sections -- while `criteria.md` maps ROADMAP criterion 1 to `not_met` (quoting the user's `stop-at-one` decision verbatim) and criteria 2/3 to `met`, all eight standing gates re-run green, and zero further bench runs or model spend occurred.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-08-30T10:30:00Z (approx.)
- **Completed:** 2026-08-30T10:40:00Z
- **Tasks:** 2/2
- **Files modified:** 2 new docs files + 1 additive doc edit + 1 ROADMAP edit + ~84 gate-sweep evidence files under `phase-07/results/20260830T103307Z-phase-close/`

## Accomplishments

- Wrote `docs/cline-bench.md` (173 lines) in the house style of `docs/network-exposure.md`/`docs/services.md`: 9 numbered top-level sections, with 한계 (limits, §4) and 제거 방법 (removal, §7) each standing alone as their own top-level heading rather than nested.
- Every number in the document (12-task pool, 1 task run, 0 passes, 232s wall-clock, the 141.5/57.3/5.3/12.4s phase breakdown) was cross-checked against `bench/runs/20260830T093657Z-phase07/summary.md` and matches exactly.
- §4 states plainly, in its own bullets: the pool is 12 not ~89, one task ran not 5-8 (with the user's `stop-at-one` reasoning quoted verbatim), the one task never reached flashnext (0-byte server-log slice, real OpenAI API error text quoted), the 07-02 `INJECTABLE` injection verdict does not take effect for harbor's real invocation shape (with the two independently-reverified lower layers named), `docs/32k-compaction-policy.md` describes host configuration only and does not apply inside harbor's containers, the on-wire system prompt was never captured, and a `pass`/`fail-infra` row says nothing about untested tasks.
- §9 (Phase 8 인계) lists, as an explicit "must not write" list, every overclaiming sentence shape named in this plan's own house-rules reminder -- most prominently that cline-bench did NOT verify this stack, since the one task run never touched flashnext.
- Ran this plan's own house-rule-9 greps against the finished document before committing: `funnel` and `Tailscale`/`tailscale` never share a line, `EXTRA_ALLOW_PATHS=` never appears (the variable is discussed without an adjacent equals sign), and every `통과` (passed) sentence is either the explicit "0 passes" statement or a "ran ≠ passed" distinction sentence -- none claims a pass beyond `summary.md`'s own count of 0.
- Appended an additive-only cross-reference to `docs/services.md` (§11, `git diff` shows insertions only) noting Phase 7 drove real load through the shared model server without restarting either live service, and that the one task run never actually reached flashnext so the queuing contention was not empirically observed this run.
- Re-ran all eight required standing gates fresh into `phase-07/results/20260830T103307Z-phase-close/`, all exit 0: `preflight.sh` `CASES 11/11`, `verify_bench.sh` `CASES 10/10`, `verify_services.sh` `CASES 15/15`, `verify_no_regression.sh` `INF03:PASS`, `verify_network.sh` `CASES 24/24`, `verify_sandbox.sh` `CASES 16/16` SBX-04 PASS, `verify_config.sh` exit 0 (clean, so `check_versions.sh` was correctly SKIPPED per its own conditional trigger, matching 07-04's precedent), and `python3 -m pytest phase-03 phase-04` `24 passed`.
- Wrote `criteria.md` mapping all three ROADMAP Phase 7 criteria (criterion 1 `not_met`, quoting the user's decision verbatim and citing the run directory; criteria 2/3 `met`, scoped explicitly to the one task attempted) and the three BCH requirements the same way, plus an explicit note that a `fail-infra` row is not evidence the stack works and does not by itself satisfy or fail BCH-02/BCH-03 (which ask only for artifacts-on-disk, not a `pass` verdict).
- Wrote `handoff.md` answering both inherited questions in writing: the host-posture `--auto-approve` escalation question is not applicable to this phase (harbor's containerized cline never routes through the host sandbox or the host `cline` binary at all), and the kanban `~/.gitconfig` sandbox blocker did not recur (this phase never invoked kanban) and remains open, unchanged, for Phase 3/8.
- Updated `.planning/ROADMAP.md`: all five Phase 7 plans marked `[x]`, `criteria.md`'s statuses written inline next to each Success Criteria bullet (not only in the progress table), and the Progress table row changed from "0/TBD Not started" to "5/5 ◆ 완료" with the criterion 1 `not_met` qualification visible in the same cell.
- Confirmed, at the end of both tasks, zero further bench runs occurred: `bench/runs/` still contains exactly the one pre-existing run directory plus `CANARY.txt`; the six live pids (46573/75548/48525/53894/99162/19669) are unchanged; port 3000 is unbound; the SBX-04 canary is unchanged and still unreadable from inside the sandbox (re-confirmed by `verify_sandbox.sh` CRITERION 4 PASS this sweep); `EXTRA_ALLOW_PATHS` remains unset/empty.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write docs/cline-bench.md** - `46e6423` (docs)
2. **Task 2: Phase-close gate sweep, criteria.md, ROADMAP update** - `339efbe` (docs)

## Files Created/Modified

- `docs/cline-bench.md` - the full Phase 7 record: 결론(한 줄), 무엇을 실행했나, 어떻게 재현하나, ⚠️ 한계, 보안·태세(건드리지 않은 것), 운영 부작용, 제거 방법, 증거 인덱스, Phase 8 인계
- `docs/services.md` - additive §11 cross-reference to Phase 7 (no deletions)
- `phase-07/results/20260830T103307Z-phase-close/criteria.md` - three ROADMAP criteria + three BCH requirements, each mapped to a status literal and an evidence path
- `phase-07/results/20260830T103307Z-phase-close/handoff.md` - the two inherited-question answers + standing-gate command + removal-recipe pointer
- `phase-07/results/20260830T103307Z-phase-close/{preflight,verify,p-network,p-no-regression,p-sandbox,p-services}/` and top-level `.txt` files - fresh evidence for all eight gates
- `.planning/ROADMAP.md` - Phase 7 plans marked complete, criterion 1 qualified `not_met` inline, progress table row updated

## Decisions Made

- **Criterion 1's `not_met` status was written into ROADMAP.md's Success Criteria prose itself**, not left only in the linked `criteria.md` or the progress-table Status cell -- so a reader who only opens `ROADMAP.md` still sees the shortfall and the one-line reason without following a link.
- **The house-rule-9 wording-collision requirement (discuss the host-posture flag and public-exposure mode by name) was satisfied by following this phase's own established Phase 6 precedent**: paraphrase where the literal term would sit adjacent to its trap partner (e.g. "host-posture 이스케이프 플래그", "공용으로 여는 서브커맨드"), while still naming `--auto-approve` directly in one place where no equals sign or adjacent trap term follows it. This discusses the flag by name (satisfying the plan's instruction) without recreating the wording collision the grep-based verify checks for.
- **BCH-02's `met` status in criteria.md is explicitly scoped to the one task attempted** and explicitly notes the on-wire system prompt was not captured without treating that as a downgrade -- the criterion's own text asks for the prompt text sent (on disk as `instruction.md` + `agent-command.txt`), which is present, not the transcript Cline itself would have produced had the request succeeded.
- **No retry, no additional `harbor run`, and no new bench task were run anywhere in this plan** -- both tasks operated entirely on artifacts already on disk from 07-01 through 07-04. `cline`/`harbor` budget consumed this plan: 0.

## Deviations from Plan

None -- plan executed exactly as written. Both tasks' own `<verify>` blocks were satisfied on the first attempt: `docs/cline-bench.md` is 173 lines (>=120) with 한계/제거 방법 as top-level headings and every number matching `summary.md`; `docs/services.md`'s diff shows additions only; all eight gates in `criteria.md`'s sweep exited 0 on the first run, with no pre-existing host-state mismatch of the kind 07-04 encountered (`docker ps -q` was not asserted by this plan's own `<verify>` text, so no analogous reportable mismatch arose here).

## Issues Encountered

None. All referenced upstream artifacts (07-01 through 07-04 SUMMARY.md files, `decision.md`, `ANALYSIS.md`, `summary.md`, `prompts/INDEX.md`, `config.json`) were present, internally consistent, and matched the numbers this plan needed to cite.

## User Setup Required

None - no external service configuration required. This plan is documentation-only plus read-only gate re-runs.

## Next Phase Readiness

- **Phase 8's manual writer has an unmissable, explicit standing gate**: `docs/cline-bench.md` §9 lists the exact sentence shapes the manual must not contain, most importantly that cline-bench did NOT verify this stack's model server (the one task run never reached flashnext).
- `phase-07/bench/verify_bench.sh --run-dir bench/runs/20260830T093657Z-phase07` remains the re-runnable standing gate over the committed run directory (`CASES 10/10` as of this sweep) -- Phase 8 or any future phase can re-verify without spending any model budget.
- Both inherited open questions (host-posture `--auto-approve` escalation, kanban `~/.gitconfig` sandbox blocker) are answered in writing in `handoff.md` rather than silently dropped -- neither was decided or fixed by this phase, both remain exactly as their originating phases left them.
- The complete, literal removal recipe (`uv tool uninstall harbor`, `rm -rf bench/cline-bench`, `docker image prune`) is in the shipped `docs/cline-bench.md`, not only in a results directory -- `bench/runs/` is explicitly excluded from that recipe as this phase's evidence.
- Six live pids (46573/75548/48525/53894/99162/19669), port 3000 (unbound), the sandbox whitelist, and the SBX-04 canary are all confirmed unchanged at the end of this plan and this phase. Zero bench runs occurred in this plan; zero model spend.
- Phase 7 is now closed (5/5 plans, ROADMAP updated) and ready for Phase 8 to begin, which per the ROADMAP depends on all of Phases 1-7 being complete.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-30*
