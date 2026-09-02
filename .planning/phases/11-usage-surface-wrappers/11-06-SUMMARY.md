---
phase: 11-usage-surface-wrappers
plan: 06
subsystem: cli-wrappers
tags: [bash, cline-cli, litellm, ab-testing, ab-results, providers-json, use-03]

# Dependency graph
requires:
  - phase: 11-05
    provides: "phase-11/AB-PROTOCOL.md (pre-registered arms/fairness/sizing/decision rule), phase-11/run_ab.sh (resumable budget-capped runner), the human-authorised main-run size (8 tasks x N=5, cap 88, threshold >=7 of 40 cells)"
provides:
  - "phase-11/AB-RESULTS.md: full per-cell table (66 rows), four-category per-arm aggregates, latency+completion-length reported together, void-condition walk (none triggered), a descriptive permutation test, and the pre-registered decision rule applied mechanically -- RULE OUTPUT: revert"
  - "phase-11/results/20260902T062649Z-ab-main/: the main run directory -- ab.tsv, 66 raw NDJSON streams, budget.tsv, manifest.txt, preflight/postflight.txt, regrade-check.txt (0 verdict differences), providers-drift.tsv (31 rows, 31 repaired), interruptions.txt"
  - "phase-11/run_ab.sh: an orchestrator-directed per-invocation providers.json check+repair (check_and_repair_providers), since -m flashnext-plan now drifts providers.json's model field at 100% frequency (31/31 this run) -- probe_lib11.sh's own hard-halt-no-repair guard is unmodified, this repair lives entirely in run_ab.sh"
  - "A measured, 100%-frequency confirmation that phase-11/cline-plan's underlying invocation shape (-m flashnext-plan) mutates the shared providers.json entry every single time at cline 3.0.61 -- upgraded from the prior two single-occurrence observations (11-04, the 11-05 pilot)"
affects: ["11-07 (ratifies keep/revert with a human; must weigh both this document's RULE OUTPUT and the now-100%-frequency providers.json mutation hazard, neither of which this plan resolves alone)"]

tech-stack:
  added: []
  patterns:
    - "A safety-envelope guard designed for a probe (hard-halt-no-repair on a rare drift) does not automatically remain correct at 40x the invocation volume a full A/B makes -- when a orchestrator overrides that guard's behaviour for one run, the override is implemented in the caller (run_ab.sh) rather than by weakening the shared library (probe_lib11.sh), so every OTHER script that sources the library keeps the stricter behaviour"
    - "When a pre-registered request cap is sized on an assumption the pilot could not have tested (here: 1 request per invocation), report the cap-triggered early stop as a first-class, non-void outcome with a full three-way budget cross-check, rather than treating a smaller-than-authorised N as a defect to paper over"
    - "When a raw-count decision-rule gap is produced by unequal N plus a single shared floor case rather than by any actual accuracy divergence, say so explicitly in the same section that reports the rule's mechanical output, so a reader cannot mistake 'the rule says revert' for 'arm C measurably underperformed'"

key-files:
  created:
    - phase-11/AB-RESULTS.md
    - phase-11/results/20260902T062649Z-ab-main/ (ab.tsv, budget.tsv, manifest.txt, preflight.txt, postflight.txt, regrade-check.txt, providers-drift.tsv, interruptions.txt, streams/ [66 NDJSON+stderr pairs])
    - phase-11/results/CURRENT_AB_MAIN_RUN
  modified:
    - phase-11/run_ab.sh

key-decisions:
  - "Reset the persistent budget-watermark file (phase-11/results/.budget-watermark-11-04) immediately before this run, so its own request accounting measured only THIS run's spend against the cap of 88, not cumulatively with plan 11-04's and the 11-05 pilot's prior 9 requests against the same shared counter file -- verified the reset watermark's line count matched the orchestrator's independently-captured 911 Prefill-started baseline exactly"
  - "Implemented the orchestrator-directed providers.json check-and-repair entirely inside run_ab.sh (a new check_and_repair_providers function, called after every cline invocation including retries), rather than editing probe_lib11.sh's shared postflight11 guard -- this keeps every OTHER script in the phase that sources probe_lib11.sh on the stricter, no-self-repair behaviour, and confines the repair-instead-of-halt behaviour to exactly the one run authorised to need it"
  - "Split the authorised 88-invocation run into two run_ab.sh invocations (arms A,C at reps=5 in one call, arm B at reps=1 in a second --resume call), per run_ab.sh's own documented convention for honouring arm B's reduced-replication design -- invocation 2 never started because invocation 1 exited non-zero on the request cap"
  - "When the run hit the pre-registered request cap after only 66 of 88 invocations (an emergent tool-calling behaviour on tasks 05-07 consumed more than 1 request per invocation, which the pilot's all-single-turn 6-cell dataset never exercised), did not raise the cap to finish the sweep, per this plan's own hard constraint 5 -- reported the actual 66-cell, cap-limited dataset as the outcome, with a full three-way independent cross-check confirming exactly 88 requests were spent (never exceeded)"
  - "Manually re-ran postflight11 against the run directory within seconds of the cap-triggered abort, because probe_lib11.sh's assert_budget calls exit 1 directly on hitting the cap -- a real, minor defect in run_ab.sh's cap-abort path that skips its own postflight11/manifest-close block, unlike every other abort path in the script. Documented as a finding, not fixed mid-run (the run's own data was already collected; editing the shared safety-envelope file to fix this was judged riskier than manually reproducing its one-time output)"
  - "Applied AB-PROTOCOL.md's section5 decision rule exactly as pre-registered (raw correct-count gap, threshold read off the >=7-of-40-cells row without recomputing for the smaller achieved N) even though the achieved dataset (31 vs 35 cells) is smaller and less balanced than the 40-vs-40 the threshold was computed for -- gap = 26-30 = -4, well short of and opposite in sign from +7, so RULE OUTPUT: revert. Explicitly documented in the same section that this gap is produced by N imbalance plus a single shared floor task (both arms tied 0/5 on task 06), not by any measured accuracy difference -- on every task both arms could be compared on equal footing, both are 100% correct"
  - "Did not attempt to recover arm B's or task 08's missing data via --resume or any other means once the cap was reached -- per hard constraint 6 (no retry for content) and hard constraint 5 (cap not raised to finish the sweep), reported their absence plainly in section1a, section5, and section9 rather than substituting a smaller ad hoc B/task-08 run outside the authorised budget"

# Metrics
duration: ~44min (2026-09-02T06:19:32Z orchestrator baseline through 2026-09-02T07:03Z, including the ~26-minute live run itself)
completed: 2026-09-02
---

# Phase 11 Plan 06: USE-03 Main A/B Run and Results Summary

**Ran the authorised 88-invocation A/B; it stopped at the pre-registered 88-request cap after only 66 invocations because tasks 05-07 triggered unplanned tool-calling, leaving task 08 and the arm-B prefix control entirely untested — on the data collected, the pre-registered rule mechanically outputs `revert` (gap -4 vs threshold +7), but that gap is an artifact of unequal N and a single shared floor task, not a measured accuracy difference: on every task both arms could be compared, both hit 100%.**

## Performance

- **Duration:** ~44 min end-to-end (orchestrator baseline 2026-09-02T06:19:32Z → this summary
  2026-09-02T07:03Z); the live A/B itself ran ~26 minutes (2026-09-02T06:27:13Z → 06:53:32Z).
- **Started:** 2026-09-02T06:19:32Z (baseline capture, per the orchestrator's prompt)
- **Completed:** 2026-09-02T07:03Z
- **Tasks:** 2/2 (both `type="auto"`, no checkpoints in this plan)
- **Files modified:** 1 (`phase-11/run_ab.sh`); 2 created at the top level (`phase-11/AB-RESULTS.md`,
  `phase-11/results/CURRENT_AB_MAIN_RUN`) plus one full run directory (66 cells' worth of raw
  evidence, ~180 files)

## Accomplishments

- Executed the authorised main A/B (`phase-11/run_ab.sh`, 8 tasks × N=5 for arms A/C, N=1 for arm
  B, cap 88 requests) at `phase-11/results/20260902T062649Z-ab-main/`. The run stopped at the
  **request cap, exactly (88 of 88), not exceeded** — cross-checked three independent ways
  (`budget.tsv`'s own running total; an independent recount of new `Generation queued` lines since
  a freshly-reset watermark; the cumulative `Prefill started` delta against the orchestrator's
  911-line baseline) — after **66 of the 88 authorised invocations**, because tasks 05–07 triggered
  the model spontaneously invoking the `run_commands` tool (2–3 model turns per invocation instead
  of the pilot's uniform 1), a behaviour the pilot's 6-cell, all-single-turn dataset never
  exercised. Task 08 (both bug-localisation tasks) and arm B (the prefix control) were never
  reached.
- Re-graded all 66 retained streams fresh against `grade_ab.py`: **zero verdict differences**
  (`regrade-check.txt`) — the aggregate is proven reproducible from the raw evidence alone.
  Confirmed via `git log`/`git diff` that neither the task set nor the grader was touched before,
  during, or after the run.
- Implemented, per explicit orchestrator instruction, a per-invocation `providers.json`
  check-and-repair inside `run_ab.sh` (not in the shared `probe_lib11.sh`), since a bare
  `-m flashnext-plan` invocation reproducibly rewrites `providers.json`'s `model` field. Measured
  result: **31 of 31 arm-C invocations (100%) drifted; all 31 repaired before the next cell; 0
  halts; `contextWindow` never drifted.** This raises the finding from "reproducible" (two prior
  single-occurrence observations, plan 11-04 and the 11-05 pilot) to **"happens every time,"** now
  handed to plan 11-07 as a hazard it must weigh alongside this document's answer-quality finding.
- Wrote `phase-11/AB-RESULTS.md`: full per-cell table, four-category per-arm aggregates (0
  `no-answer`/`no-output`/`unparseable` in either arm — `finish_reason=stop` on every one of 66
  cells), latency printed beside completion length per the confound requirement (arm C's
  completions run ~68% longer, so its ~18% higher median latency is explicitly **not** read as pure
  "thinking cost"), an explicit walk of all four pre-registered void conditions (**none
  triggered**), a descriptive permutation test (p=0.563, explicitly not the decision criterion),
  and the pre-registered §5 decision rule applied mechanically: correct_C=26, correct_A=30, gap=-4,
  threshold ≥+7 → **`RULE OUTPUT: revert`**. Does not declare the keep/revert decision — that
  remains plan 11-07's, with a human.
- Root-caused the run's only source of incorrect verdicts: **all 10 incorrect cells, in both arms,
  are task 06 (mode-char)** — both arms answered `ANSWER: 'a'` (Python-quoted) against an expected
  bare `a`, a format-compliance miss under `exact_normalized` matching, not a grader defect (the
  prompt explicitly instructs the bare form; `grade_ab.py`'s `normalize_exact` is behaving exactly
  as pre-registered by not stripping quote characters). Excluding task 06, **both arms are 100%
  correct on every task actually attempted by both.**

## Task Commits

1. **Task 1: Execute the authorised main run** - `dbdad9e` (feat)
2. **Task 2: AB-RESULTS.md — the table, the four categories, and the rule's mechanical output** - `bec6104` (docs)

**Plan metadata:** this summary is the closing record; no separate metadata commit was made beyond
the two task commits above (per this plan's explicit instruction not to touch STATE.md, ROADMAP.md,
or REQUIREMENTS.md).

## Files Created/Modified

- `phase-11/AB-RESULTS.md` — the full results document (§1–§10; RULE OUTPUT: revert)
- `phase-11/run_ab.sh` — added `check_and_repair_providers()`, called after every `cline`
  invocation (including retries), plus a resume-safe `providers-drift.tsv` log and manifest/
  final-echo lines reporting the per-invocation drift count
- `phase-11/results/20260902T062649Z-ab-main/` — the main run directory: `ab.tsv` (66 data rows),
  `streams/` (66 NDJSON+stderr pairs), `budget.tsv`, `manifest.txt`, `preflight.txt`,
  `postflight.txt` (run manually after the cap-abort — see Deviations), `regrade-check.txt` (0
  differences), `providers-drift.tsv` (31 rows, all `repaired`), `interruptions.txt` (the full
  account of the cap-triggered stop), 31 `providers-repair-*.log` files
- `phase-11/results/CURRENT_AB_MAIN_RUN` — pointer to the run directory

## Decisions Made

See `key-decisions` in the frontmatter for the full, precise record. In brief: the budget watermark
was reset before this run to isolate its own spend; the providers.json repair was implemented in
`run_ab.sh` rather than the shared `probe_lib11.sh` so other scripts keep the stricter guard; the
authorised 88-invocation run was split into two `run_ab.sh` invocations (A/C, then B) per the
script's own documented convention; the cap was not raised when it was reached (hard constraint 5);
`postflight11` was run manually once, immediately, after the cap-triggered abort; the pre-registered
decision rule was applied exactly as written to the smaller achieved dataset, with the reason for
the negative gap (N imbalance + one shared floor task, not accuracy divergence) stated explicitly
alongside the rule's mechanical output; no attempt was made to backfill arm B or task 08 outside the
authorised budget.

## Deviations from Plan

### Auto-fixed / orchestrator-directed changes

**1. [Orchestrator-directed change to how this plan runs] Per-invocation `providers.json`
check-and-repair, replacing the plan-as-written's implicit reliance on `probe_lib11.sh`'s
hard-halt-no-repair guard**
- **Why:** `cline -m flashnext-plan` had already been reproduced twice (plan 11-04's Open Item 3;
  the 11-05 pilot's own last cell) rewriting `providers.json`'s `model` field, both at cline 3.0.61.
  `probe_lib11.sh`'s `postflight11` treats any such drift as a hard, no-self-repair failure — correct
  for a probe issuing a handful of requests, but this run makes 31 real `flashnext-plan` invocations
  (arm C), so unmodified it would have halted the entire main run at the very first C-arm cell.
- **Instruction source:** the orchestrator that spawned this execution, given explicitly in this
  plan's own prompt (not present in `11-06-PLAN.md`'s text) — "repair after every invocation, do not
  halt on it," with `contextWindow` drift kept as a hard stop since it has never been observed.
- **Fix:** added `check_and_repair_providers()` to `phase-11/run_ab.sh`, called after every real
  `cline` invocation (including operational retries). Reads `providers.json`'s `model`/
  `contextWindow`; if `contextWindow` moved, halts the whole run immediately (never observed this
  run); if `model` moved, calls `phase-01/config/apply_provider_config.sh` (the same pre-existing
  tool the orchestrator used out-of-band after the 11-05 pilot), re-checks, and halts only if the
  repair itself failed. Every occurrence logged to `providers-drift.tsv` (cell, arm, alias, observed
  value, restore outcome).
- **Files modified:** `phase-11/run_ab.sh`
- **Verification:** 31 of 31 arm-C invocations drifted and were repaired (`providers-drift.tsv`, 31
  rows, all `restore_outcome=repaired`); 0 halts; `contextWindow` held at 29000 on every check
  including all 31 drift events; the manual `postflight11` re-check after the run's end confirms the
  live file ended compliant (`model=flashnext`, `contextWindow=29000`, `verify_config.sh` exit 0).
- **Committed in:** `dbdad9e` (Task 1 commit)

**2. [Rule 3 - Blocking issue] Persistent budget-watermark file reset before the run**
- **Found during:** pre-run investigation, before Task 1's `run_ab.sh` invocation
- **Issue:** `phase-11/results/.budget-watermark-11-04` (untracked, a leftover from the 11-05
  pilot's own run) already held a running total of 6 requests spent by the pilot. Left unreset,
  passing `--cap 88` to this run would have measured this run's own spend cumulatively with the
  pilot's prior 6, effectively leaving only 82 requests for this run's own 88-invocation budget —
  contradicting `AB-PROTOCOL.md` §4's own text that 88 is the cap for **plan 11-06's own run**.
- **Fix:** deleted the watermark file immediately before this run's preflight, so
  `probe_lib11.sh`'s idempotent `init_budget_watermark11` recreated it fresh at the current log line
  count. Verified the fresh watermark's line count matched the orchestrator's independently-captured
  911 `Prefill started` baseline exactly (i.e., zero new requests had occurred between the
  orchestrator's baseline capture and this reset).
- **Files modified:** none (a runtime state file, not a plan artifact; left untracked per the
  orchestrator's own "your call" note)
- **Verification:** the three independent budget-accounting methods in §1 of `AB-RESULTS.md` all
  agree at exactly 88 — had the watermark not been reset, they would have disagreed by 6.

### The cap-triggered early stop (reported, not "fixed")

The run stopping at 66 of 88 invocations is **not** treated as a defect to work around — per hard
constraint 5, "the cap is not raised to finish the sweep." It is reported in full in
`phase-11/results/20260902T062649Z-ab-main/interruptions.txt` and in `AB-RESULTS.md` §1a. One real,
minor code defect this exposed (documented, not fixed mid-run): `probe_lib11.sh`'s `assert_budget`
calls `exit 1` directly on hitting the cap, which exits `run_ab.sh` immediately without running its
own `postflight11` call or manifest-closing block — unlike every OTHER abort path in `run_ab.sh`
(idle-timeout, the per-cell runaway guard, the new provider-repair-failure hook), which set
`ABORTED=1` and `break` out gracefully, letting `postflight11` still run. Worked around by manually
invoking the same `postflight11` function against the run directory within seconds of the abort
(exit 0: pids unchanged, `providers.json` compliant, `verify_config.sh` exit 0, `cline --version`
stable) — recorded as a finding for whoever next touches `run_ab.sh`'s cap-abort path, not corrected
in this plan (the run's data was already collected; editing the shared safety-envelope file
mid-evidentiary-run was judged riskier than manually reproducing its one-time output).

**Total deviations:** 1 orchestrator-directed change (providers.json repair, tracked as evidence per
the orchestrator's own instruction), 1 auto-fixed blocking issue (watermark reset), 1 documented
(not fixed) minor code defect (postflight-skipping cap-abort path).
**Impact on plan:** the providers.json repair was necessary for the run to produce any A/C data past
the first C-arm cell at all. The watermark reset was necessary for the budget accounting required by
Task 1's own verification to be correct. Neither changed the task set, the grader, or any measured
verdict.

## Authentication Gates

None — no authentication was required for this plan's work.

## Issues Encountered

- **The run did not reach its authorised size.** 66 of 88 invocations completed; task 08 (both
  bug-localisation tasks) and arm B (the prefix control) were never attempted. Root cause: tasks
  05–07 triggered spontaneous tool-calling (2–3 model turns per invocation) that the pilot's
  all-single-turn 6-cell dataset never exercised, consuming the 88-request budget faster than the
  1-request-per-invocation assumption `AB-PROTOCOL.md` §4's sizing arithmetic implicitly made. Not a
  void condition (see `AB-RESULTS.md` §7 — none of the four pre-registered void conditions
  triggered); governed instead by the separate, pre-registered hard request cap (hard constraint 5).
- **`providers.json`'s drift frequency is now measured at 100%** (31/31 arm-C invocations), a
  materially stronger finding than the prior two single-occurrence observations. Handed to plan
  11-07 as a hazard it must weigh directly, per `AB-PROTOCOL.md` §4's own prior framing that this
  cannot be resolved by an answer-quality decision rule alone.
- **The decision rule's raw-count gap (-4) is potentially misleading if read in isolation** — it is
  produced by arm A having 4 more total cells than arm C and both arms tying at 0/5 on a single
  shared floor task (06), not by any measured accuracy divergence. `AB-RESULTS.md` §8 states this
  explicitly in the same breath as the rule's mechanical output, per the outcome-neutrality
  requirement to report what the numbers actually show rather than let a mechanically-correct
  output be misread.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `phase-11/AB-RESULTS.md` carries the full evidence trail and the pre-registered rule's mechanical
  output (`revert`) for plan 11-07 to act on, with a human. Plan 11-07 also needs to weigh the
  now-100%-frequency `providers.json` mutation hazard (§1c) — a `providers-drift.tsv` with 31/31
  repaired occurrences is direct, quantified evidence for that discussion, not something plan 11-07
  has to re-derive.
- **Two gaps plan 11-07 should be aware it is deciding without:** arm B (the prefix control) has
  zero data from this run — the `hosted_vllm/`-vs-`openai/` confound `AB-PROTOCOL.md` introduced arm
  B to separate is not addressed by anything measured here; and task 08 (bug-localisation) has zero
  data from either arm — one of the two categories the 11-05 checkpoint most wanted broader evidence
  on before authorising the full run remains completely untested.
- The live stack is left compliant: three `com.ohama.*` pids unchanged throughout, `providers.json`
  holds `model=flashnext`/`contextWindow=29000`, `verify_config.sh` exits 0, `cline --version`
  stable at 3.0.61 before and after the entire run (confirmed via the manual post-abort re-check).
- Per this plan's explicit instruction, `.planning/STATE.md`, `ROADMAP.md`, and `REQUIREMENTS.md`
  were not touched by this execution.

---
*Phase: 11-usage-surface-wrappers*
*Completed: 2026-09-02*
