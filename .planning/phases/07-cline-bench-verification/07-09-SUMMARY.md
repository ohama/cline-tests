---
phase: 07-cline-bench-verification
plan: 09
subsystem: testing
tags: [cline-bench, harbor, gap-closure, BCH-01, BCH-03, verify_bench, make_summary]

# Dependency graph
requires:
  - phase: 07-08
    provides: "phase-07/bench/SELECTED_TASKS_GAP (telegram-plugin-refactor, filmarchiver, v-edit-workspace-tests), decision2.md's plus-three interpretation and its unique-task-count-vs-run-instance-count correction"
provides:
  - "bench/runs/20260830T122809Z-phase07-fix/: 3 new evidence bundles (jobs/, meta/, prompts/, server-log/, preassert/) plus a regenerated summary.md carrying the reached-the-model count in its own header"
  - "phase-07/results/20260830T170042Z-gap-batch/: pre-batch drift baselines, per-task ledger, post-batch standing-gate sweep (7 gates), six drift assertions"
  - "make_summary.sh extended (not hand-edited) to compute and print reached-the-model count in every run directory's summary header"
  - "run_task.sh fixed: a trial that never reaches the verifier now gets an explanatory CAPTURE-GAPS.txt line, closing a verify_bench.sh B4 gap this run first exposed"
affects: [07-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "reached-the-model-in-the-header: BCH-01's honesty depends on a number distinct from 'how many tasks ran' -- make_summary.sh now computes it the same way verify_bench.sh's B11 does (non-empty server-log slice AND model_turns>0) and prints it in every run directory's own summary.md header, not only in a results directory a reader might not open"
    - "reward.txt-can-legitimately-not-exist: a trial can crash during environment_setup before the verifier stage ever runs, meaning verifier/reward.txt never gets created -- this is a genuine fail-infra, not a harness bug, and the evidence-capture script now records why explicitly (CAPTURE-GAPS.txt) rather than leaving the standing gate to find an unexplained hole"

key-files:
  created:
    - bench/runs/20260830T122809Z-phase07-fix/summary.md
    - phase-07/results/20260830T170042Z-gap-batch/README.md
    - phase-07/results/20260830T170042Z-gap-batch/ledger.tsv
    - phase-07/results/20260830T170042Z-gap-batch/post/drift.txt
    - phase-07/results/run_gap_batch.sh
  modified:
    - phase-07/bench/make_summary.sh
    - phase-07/bench/run_task.sh
    - bench/runs/20260830T122809Z-phase07-fix/prompts/filmarchiver/CAPTURE-GAPS.txt

key-decisions:
  - "Ran all three SELECTED_TASKS_GAP tasks in file order, no retries, no substitutions, no early stop -- total batch wall-clock (1396s, ~23.3 min) never approached the 2x-pessimistic stop threshold"
  - "filmarchiver's fail-infra (bun install segfault, CPU lacks AVX under colima's virtualization) was recorded once and not retried -- re-running would reproduce the identical crash at identical cost, buying no new information, per house rule"
  - "Auto-fixed (Rule 3, blocking issue) a verify_bench.sh B4 gap: run_task.sh had no <action> that ever wrote an explanation to CAPTURE-GAPS.txt when a trial legitimately never reaches the verifier stage. Fixed the script for future runs and backfilled the one already-produced file (filmarchiver's) without re-running the task, since the explanation is truthful post-hoc (the trial genuinely never reached the verifier) rather than a retroactive rationalization of a different outcome."
  - "Extended make_summary.sh (not hand-edited the generated file) to add the reached-the-model count to every run directory's own summary.md header -- required by this plan's own must_haves and previously absent from the script entirely (Rule 2, missing critical functionality the plan explicitly required)."
  - "Unique-task count after this batch is 4 (discord-trivia-approval-keyerror + these 3), not 5 -- BCH-01's 5-8 floor is still not reached. Stated in every relevant document as 4 unique tasks / 5 run instances across two run directories, never blended into a single ambiguous 'ran 5 times' framing (carrying forward 07-08's own correction of the plan's original wording)."

patterns-established:
  - "See tech-stack.patterns above."

# Metrics
duration: ~31min (2026-08-30T17:01Z start of pre-batch baseline capture through the Task 2 commit at 17:31:52Z; the bench batch itself was 23.3 min of that)
completed: 2026-08-31
---

# Phase 7 Plan 9: Gap-Closure Batch Run + BCH-03 Regeneration Summary

**Ran the three `plus-three` tasks (telegram-plugin-refactor, filmarchiver, v-edit-workspace-tests) sequentially into the post-fix run directory: two more reached the model and were rejected at the 32K context ceiling (fail-context), one never reached it (fail-infra, an unrelated Bun/AVX segfault). Regenerated `summary.md` with a reached-the-model count in its own header (3 of 4 attempted, post-fix), and swept seven standing gates green.**

**The three numbers 07-10 needs:** across both run directories, **4 unique tasks attempted** (5 run instances -- `discord-trivia-approval-keyerror` was attempted once pre-fix and once post-fix, the same task, not two different tasks), **3 reached the model** (non-empty flashnext server-log slice AND `model_turns > 0`: `discord-trivia-approval-keyerror`'s post-fix rerun, `telegram-plugin-refactor`, `v-edit-workspace-tests` -- its pre-fix attempt and `filmarchiver` did not), **0 passed**. BCH-01's 5-8-task floor is still not reached; this plan does not promote it.

## Performance

- **Duration:** ~31 min total (pre-batch baselines through Task 2's commit); the bench batch itself ran 23.3 min (1396s) of that, well inside `cost.md`'s `+3` projected range (~15-83 min)
- **Started:** 2026-08-30T17:01:09Z
- **Completed:** 2026-08-30T17:31:52Z
- **Tasks:** 2/2
- **Files modified:** 2 scripts fixed (`make_summary.sh`, `run_task.sh`), 1 evidence file backfilled (`filmarchiver/CAPTURE-GAPS.txt`); ~190 files created (evidence bundles + gate-sweep transcripts)

## Accomplishments

- Ran `telegram-plugin-refactor`, `filmarchiver`, `v-edit-workspace-tests` into `bench/runs/20260830T122809Z-phase07-fix`, once each, resumably (proven: a second driver invocation produced zero new `harbor run` calls)
- `telegram-plugin-refactor`: fail-context, 372s, `model_turns=6`, 21895-byte slice, `max_prompt_tokens=21036` -- reached the model
- `v-edit-workspace-tests`: fail-context, 586s, `model_turns=12`, 42450-byte slice, `max_prompt_tokens=30696` -- reached the model
- `filmarchiver`: fail-infra, 438s, `model_turns=0`, 0-byte slice -- did not reach the model; its container's `bun install` segfaulted (`CPU lacks AVX support`, `panic(main thread): Segmentation fault`) before cline was ever invoked, an environment-setup crash unrelated to the injection mechanism
- Extended `make_summary.sh` to compute and print the reached-the-model count in every run directory's own `summary.md` header -- this plan's `must_haves` required it and no prior version of the script produced it
- Fixed a real gap in `run_task.sh`'s evidence capture: a trial can legitimately crash before the verifier stage and never produce `verifier/reward.txt` (first observed on `filmarchiver`), and no `<action>` anywhere previously wrote an explanation for that into `CAPTURE-GAPS.txt` -- `verify_bench.sh` check B4 has an escape valve for exactly this case, but nothing populated it. Fixed for future runs and backfilled `filmarchiver`'s already-captured file (not a re-run) so this run's own evidence bundle is internally consistent with the fixed script's output.
- Swept seven standing gates, all green: `verify_bench.sh` (11/11 post-fix, B11 PASS; 10/10 pre-fix, B11 correctly SKIPped; `/nonexistent` negative control still FAILs 4/10), `preflight.sh` (11/11), `verify_services.sh` (15/15, 0 crashed), `verify_no_regression.sh` (INF03 PASS), `verify_sandbox.sh` (16/16, CRITERION 4 PASS), `verify_network.sh --baseline` (24/24), `verify_config.sh` (exit 0)
- Recorded six drift assertions in `post/drift.txt`: canary unchanged, `ALLOWED_REPOS.json` still excludes `bench/`+repo-root, `EXTRA_ALLOW_PATHS` empty in every plist, `providers.json` hash byte-identical pre/post, host `cline` pin (3.0.60) named as pre-existing drift not repaired here, no bench container running and `docker images` byte-identical to the pre-batch capture (harbor removes each task's built image after its own trial -- the reclaimable weight lives in Docker's build cache, 6.858GB, not in named images; 07-10's removal recipe should target `docker builder prune`, not `docker rmi`)

## Task Commits

1. **Task 1: Run the selected tasks sequentially, resumably** - `74e1691` (feat)
2. **Task 2: Regenerate the BCH-03 table and sweep every standing gate** - `8eacab7` (docs)

## Files Created/Modified

- `bench/runs/20260830T122809Z-phase07-fix/meta/{telegram-plugin-refactor,filmarchiver,v-edit-workspace-tests}.json` - per-task verdict/turns/tokens records
- `bench/runs/20260830T122809Z-phase07-fix/server-log/*.flashnext.err.txt` - byte-offset server-log slices, the decisive reached-the-model evidence
- `bench/runs/20260830T122809Z-phase07-fix/summary.md` - regenerated BCH-03 table, 4 attempted + 8 not-run rows, reached-the-model count in the header
- `bench/runs/20260830T122809Z-phase07-fix/prompts/filmarchiver/CAPTURE-GAPS.txt` - backfilled with the missing-reward.txt explanation
- `phase-07/bench/make_summary.sh` - added the reached-the-model header computation
- `phase-07/bench/run_task.sh` - added the CAPTURE-GAPS.txt line for a trial that never reaches the verifier
- `phase-07/results/20260830T170042Z-gap-batch/` - pre-batch baselines (`pre/`), per-task ledger, driver logs, post-batch gate-sweep transcripts and drift assertions (`post/`)
- `phase-07/results/run_gap_batch.sh` - the batch driver: per-task pre-guards, resumability, ledger writer (not itself part of the standing `phase-07/bench/` toolset -- a one-shot orchestration script for this plan's Task 1)
- `phase-02/results/20260830T172957Z-inf03/`, `phase-03/results/20260830T173004Z-sbx/`, `phase-05/results/20260830T172912Z-gate/`, `phase-06/results/20260830T173009Z-net-gate/` - standing-gate sweep transcripts from the cross-phase gates Task 2 re-ran

## Decisions Made

See `key-decisions` in frontmatter. In brief: no retries on the `filmarchiver` fail-infra; two script fixes applied automatically as blocking/missing-functionality deviations (both required by this plan's own success criteria, neither a structural or host-posture change); the unique-task-count-vs-run-instance-count distinction from 07-08 is carried forward, not repeated as an error.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `verify_bench.sh` B4 failed: `filmarchiver` had no `verifier/reward.txt` and no explained gap**
- **Found during:** Task 2, first `verify_bench.sh` run against the post-fix directory (10/11, B4 FAIL)
- **Issue:** `run_task.sh` only ever wrote a `CAPTURE-GAPS.txt` explanation for a missing `prompts/<task>/agent-command.txt`; it never wrote one for a missing `verifier/reward.txt`, even though a trial can legitimately crash before the verifier stage (as `filmarchiver` did -- `bun install` segfaulted during environment setup). `verify_bench.sh`'s own B4 check has an escape valve for exactly this case (a `CAPTURE-GAPS.txt` line mentioning "reward"), but nothing ever populated it -- the defect class this project has flagged repeatedly: a `<verify>`/gate requiring something no `<action>` produces.
- **Fix:** Added an `else` branch in `run_task.sh` (step 9, reward computation) that appends `MISSING verifier/reward.txt (... the trial never reached the verifier stage)` to `CAPTURE-GAPS.txt` whenever `$TRIAL_DIR/verifier/reward.txt` does not exist. Backfilled the identical line into `filmarchiver`'s already-committed `CAPTURE-GAPS.txt` by hand (confirmed the file genuinely does not exist under that trial dir first) rather than re-running the task, since re-running would cost real model time to reproduce an already-known, already-evidenced crash.
- **Files modified:** `phase-07/bench/run_task.sh`, `bench/runs/20260830T122809Z-phase07-fix/prompts/filmarchiver/CAPTURE-GAPS.txt`
- **Verification:** `verify_bench.sh --run-dir bench/runs/20260830T122809Z-phase07-fix` went from 10/11 (B4 FAIL) to 11/11 (all PASS)
- **Committed in:** `8eacab7` (Task 2 commit)

**2. [Rule 2 - Missing Critical] `make_summary.sh` never computed the reached-the-model count this plan's `must_haves` required**
- **Found during:** Task 2, before the first `make_summary.sh` run -- reading the plan's `<action>` text against the script's actual output
- **Issue:** The plan requires "the count of attempted tasks whose server-log slice is non-empty with `model_turns > 0`... must appear in the table's own header, not only in a results directory," and explicitly says to do this "via `make_summary.sh`, not by hand-editing the generated file." No version of `make_summary.sh` computed this number anywhere.
- **Fix:** Added a pre-pass loop in `make_summary.sh` that walks the same `meta/*.json` + `server-log/<task>.flashnext.err.txt` pair `verify_bench.sh`'s B11 check already uses (same signal, computed independently -- never re-derives verdict from a transcript), and prints the resulting count in the header before the table.
- **Files modified:** `phase-07/bench/make_summary.sh`
- **Verification:** Regenerated `summary.md` shows "Reached the model ... in this directory: 3 of 4 attempted" in its header, matching `verify_bench.sh` B11's independent PASS
- **Committed in:** `8eacab7` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 missing critical)
**Impact on plan:** Both fixes were required for this plan's own `<verify>` blocks to pass (B4 for Task 2's `verify_bench.sh` gate, the header number for Task 2's own summary requirement) and both are standing-toolset corrections that benefit every future run, not one-off patches. No scope creep, no structural changes, no host-posture changes.

## Issues Encountered

None beyond the two deviations above. The batch itself ran faster than the pessimistic estimate (23.3 min actual vs. up to 83 min projected for `+3`), so the stop-threshold logic in Task 1's `<action>` was never exercised.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 07-10 has exactly the three numbers it needs, stated plainly in this document's second paragraph: 4 unique tasks attempted (5 run instances across two run directories), 3 reached the model, 0 passed.
- BCH-01 (5-8 tasks) remains `not_met` -- this batch does not close it, and no document produced by this plan claims otherwise.
- BCH-03 (the pass/fail/duration/model_turns table) is up to date: `bench/runs/20260830T122809Z-phase07-fix/summary.md` covers all 4 attempted tasks in that directory with real causes, plus 8 honestly-labeled `not-run` rows.
- Two new pieces of evidence that `fail-context` (32K ceiling rejection) is a recurring, structural property of this stack rather than a one-task artifact: it now appears on 3 of 3 tasks that ever reached the model, spanning `easy` and `hard` difficulty. `docs/32k-compaction-policy.md` and 07-10's own writing should treat this as strengthened, not new, evidence.
- `filmarchiver`'s Bun/AVX segfault is a real, unretried finding: this specific task cannot currently run to completion on this stack's colima/Docker configuration, independent of the injection mechanism. 07-10 should record it as a known per-task limitation, not attempt a fix (out of this plan's scope, and no host/colima resize is permitted per house rules).
- Docker's build-cache weight (6.858GB reclaimable) is now the accurate target for any cleanup recipe 07-10 writes, not a list of bench-tagged images -- there are none left, by harbor's own design.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-31*
