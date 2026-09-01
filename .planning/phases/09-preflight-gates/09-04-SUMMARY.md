---
phase: 09-preflight-gates
plan: 04
subsystem: infra
tags: [litellm, mlx-server, reasoning_effort, enable_thinking, gate-verification, probe-harness]

# Dependency graph
requires:
  - phase: 09-preflight-gates (09-01)
    provides: fresh PRB-01/PRB-02 reproduction with negative and positive controls
  - phase: 09-preflight-gates (09-02)
    provides: PRB-03-ORACLE.md (six-arm sweep, reach-probe oracle, multi-turn growth measurement)
  - phase: 09-preflight-gates (09-03)
    provides: PRB-04-FINDINGS.md (controlled synthetic + real-xhigh-trace replay, source re-verification)
provides:
  - phase-09/GATE-VERDICT.md -- fresh-vs-research comparison table, disagreement investigation, gate adjudication for PRB-01 (diagnostic) and PRB-04 (gate), the "Phase 10 진행" verdict with falsifiability section, six-item deferral register, end-to-end stack-unchanged proof, and recorded human confirmation
affects: [phase-10 (VRF-04, CFG-12, CFG-16), phase-12 (USE-05)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "reproduced-values-only adjudication: gate decisions cite phase-09/results/... evidence paths exclusively; 09-RESEARCH.md values appear only in the comparison column, never as the basis for a decision"
    - "anti-flake gate rule: only CONFIRMED/CONFIRMED-NEGATIVE verdicts may decide a gate; any INDETERMINATE reading routes the whole gate to UNDECIDED and the document to 판정 보류, never averaged or overridden by majority"
    - "falsifiability section: every verdict names the specific measured facts that would have produced the opposite outcome"

key-files:
  created:
    - phase-09/GATE-VERDICT.md
  modified: []

key-decisions:
  - "PRB-01 demoted from gate to diagnostic on 2026-09-01 (CFG-11 alias redesign made a negative PRB-01 result non-fatal), decided positive anyway on fresh evidence"
  - "PRB-04 decided positive: controlled replay (09-03) governs as decisive evidence; 09-02's multi-turn growth is corroborating only (confounded by reply-length asymmetry); both agree at delta=0 so no conflict arose"
  - "Verdict: Phase 10 진행 -- both PRB-01 and PRB-04 decided and positive, zero INDETERMINATE readings across all 37 verdicts in the three run directories"
  - "Real-Cline-on-the-wire confirmation deferred to Phase 10 as VRF-04; Phase 9 never invoked cline, per hard constraints, so Cline's reasoning-history attachment is source-verified (MEDIUM confidence) only"

patterns-established:
  - "Gate verdict documents end in exactly one of three outcome-neutral verdict headings (Phase 10 진행 / 마일스톤 종료 / 판정 보류 -- 재측정 필요), all equally valid outcomes of correct execution"

# Metrics
duration: 15min
completed: 2026-09-01
---

# Phase 9 Plan 4: Gate Adjudication Summary

**Adjudicated both Phase 9 kill-condition gates on reproduced (not researched) values and issued a human-confirmed "Phase 10 진행" verdict, with PRB-01 demoted to diagnostic and PRB-04 the sole remaining 🔴 gate, both positive.**

## Performance

- **Duration:** 15 min (this continuation session; Tasks 1-2 were completed in a prior session)
- **Completed:** 2026-09-01
- **Tasks:** 3/3
- **Files modified:** 1 (`phase-09/GATE-VERDICT.md`)

## Accomplishments

- Built a 10-row fresh-vs-research comparison table (§2) covering PRB-01, PRB-02, PRB-03, and PRB-04, every row's evidence path resolving on disk and every `agree?` cell populated (`yes` or `n/a`, zero `no` rows — no numeric or directional disagreement found anywhere).
- Investigated and wrote up in the open (§3) the one substantive non-numeric finding: CFG-11's own design premise ("effort alone might not turn thinking on") is refuted by this phase's fresh negative control, not silently resolved in the design's favor.
- Adjudicated PRB-01 as a diagnostic (demoted from gate by the 2026-09-01 CFG-11 redesign, decided positive) and PRB-04 as the milestone's sole remaining 🔴 gate (decided positive: 16/16 controlled replay deltas `CONFIRMED` at 0, real-trace and synthetic-trace results identical, no conflict with multi-turn corroborating evidence).
- Issued the `Phase 10 진행` verdict with a falsifiability section naming the specific facts (empty `reasoning` at medium; non-zero replay delta) that would have flipped it, and a six-item deferral register assigning an owner to every open item from `09-RESEARCH.md` plus two additional facts surfaced this phase.
- Recorded human confirmation (§7): reviewer approved the verdict as written on 2026-09-01, having been shown the `n/a` comparison rows and the VRF-04 deferral explicitly, with the orchestrator's independent spot-checks (raw JSON reasoning lengths, live PIDs, `verify_config.sh` output) cited as already-verified at approval time.

## Task Commits

1. **Task 1+2: Build fresh-vs-research comparison, investigate disagreements, adjudicate both gates, issue verdict** - `41919c0` (feat) — completed and committed in a prior session
2. **Task 3: Append human confirmation (§7) to GATE-VERDICT.md** - completed and committed in this session (see below)

**Plan metadata:** committed in this session alongside Task 3 (docs: complete plan)

## Files Created/Modified

- `phase-09/GATE-VERDICT.md` - §1 provenance, §2 fresh-vs-research comparison, §3 disagreement investigation, §4 gate adjudication (PRB-01 diagnostic, PRB-04 gate), §5 verdict (`Phase 10 진행`) with falsifiability section, §6 deferral/handoff register, §7 human confirmation record. Ends with exactly one verdict heading.

## Decisions Made

- **PRB-01 demotion honored, not re-litigated:** the plan's §5 literal rule requires both PRB-01 and PRB-04 "decided and positive," and the document explicitly notes this creates no tension here only because PRB-01's fresh result happened to be positive — a future reader should not assume `REQUIREMENTS.md`'s demotion and the plan's §5 wording were designed in perfect alignment.
- **Controlled replay evidence governs PRB-04, multi-turn is corroborating only:** stated before being applied, because 09-02's multi-turn ON/OFF comparison is confounded by reply-length asymmetry (ON's replies hit the completion-token budget and came back empty).
- **VRF-04 deferred to Phase 10 rather than attempted via an isolated `--config` route in Phase 9:** the isolated route carries a known `providers.json` normalization risk documented in `09-RESEARCH.md` §Q1; deferring to Phase 10 (once `flashnext-plan` exists) makes the check nearly free.
- **Human approval recorded as approval of the document's claims as written, not as broader endorsement:** explicitly noted in §7 that approval does not itself constitute the VRF-04 wire observation, nor endorsement of Phase 10 design beyond what §5 lists as inherited.

## Deviations from Plan

None - plan executed exactly as written. Tasks 1 and 2 were completed and committed (`41919c0`) prior to this session; this session's work was limited to Task 3 (append human confirmation), producing this SUMMARY, and committing.

## Issues Encountered

None. The plan's own §4.1 already flags a documentation cross-reference to watch (REQUIREMENTS.md's PRB-01 demotion vs. this plan's §5 combined-decision wording) — that inconsistency was surfaced to the human reviewer at checkpoint time per the task instructions, not treated as a defect requiring a fix in this plan (it is a wording note, not a measurement error, and resolving it belongs to whoever next edits REQUIREMENTS.md or a future plan revision, not this execution).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 10 is unlocked: both gates decided positive on reproduced evidence, zero INDETERMINATE readings, human confirmation recorded. Phase 10 inherits (per `GATE-VERDICT.md` §5 "What Phase 10 inherits" and §6):
- the reach-probe oracle choice from `phase-09/PRB-03-ORACLE.md` (`low`/`xhigh`, not `medium`);
- CFG-12 input from 09-01's `RESULT.md` on whether `enable_thinking: false` is tolerated or applied;
- litellm's lack of hot reload — Phase 10 owns a restart maintenance window;
- `VRF-04` (real-Cline-on-the-wire confirmation, deferred here) and the litellm request-side schema validation re-check (deferred here), both to be executed against the production `flashnext-plan` alias once it exists.

No blockers. Stack confirmed untouched end to end: PIDs unchanged from `pids-before.txt` across all three run directories, config hashes unchanged, `bash phase-01/config/verify_config.sh` exits 0.

---
*Phase: 09-preflight-gates*
*Completed: 2026-09-01*
