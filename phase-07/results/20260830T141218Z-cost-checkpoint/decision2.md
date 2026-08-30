# Cost decision (round 2): how many more cline-bench tasks to run

**Recorded:** 2026-08-31T00:00:00Z (session date; see `.planning/STATE.md` for exact timestamp)
**Checkpoint:** 07-08 Task 2 (checkpoint:decision, gate="blocking")
**Selected option:** `plus-three`

## Context presented to the user

Full `cost.md` (`phase-07/results/20260830T141218Z-cost-checkpoint/cost.md`) was shown, leading with:

- The 07-03 `stop-at-one` reasoning, quoted verbatim: *"the invocation shape is identical for
  every task, so more runs would very likely reproduce the same structural fail-infra — buying
  repeated evidence of one known limitation rather than more passes."*
- What changed: the injection fix (07-07) is proven working — `model_turns = 38`,
  `max_prompt_tokens = 30463`, a non-empty flashnext server log slice
  (`bench/runs/20260830T122809Z-phase07-fix/meta/discord-trivia-approval-keyerror.json`,
  `phase-07/results/20260830T122700Z-injection-fix/PROOF.md`). `OUTCOME: reached-model`. The
  original `stop-at-one` reasoning no longer holds — additional runs now produce new evidence
  (whether other tasks reach the model, whether any pass) rather than repeating a known infra
  failure. The one measured run still did not pass (`verdict = "fail-context"`, rejected at the
  32K context ceiling on its 38th turn) — reaching the model is proven, passing is not.
- Measured post-fix per-task cost: `agent_execution` 1589.8s (~26.5 min) of a 1663.4s
  (~27.7 min) trial total, against a `1800s` per-task timeout (not hit — the task finished via
  the context-ceiling rejection, not a timeout cutoff).
- Projected ranges for `+3` / `+4` / `+7` (optimistic ~5 min/task structural lower bound;
  pessimistic ~27.75 min/task anchored on the one measurement): `+3` ≈ 15 min to 83 min added,
  `+4` ≈ 20 min to 111 min, `+7` ≈ 35 min to 194 min. Stated explicitly: n=1 cannot support a
  tight projection, and neither bound is a promise.
- ROADMAP criterion 1 (5-8 tasks): reaching the bottom of the band requires 4 more runs beyond the
  two attempted so far (both eras of the same task, 1 unique task); the phase can close honestly
  at any count, including one, because every document records the real number and never rounds it
  up.
- Pool is 12 tasks, 1 excluded for memory (`terraform-azurerm-deployment-stacks`, 8192 MB > colima's
  VM) — honest ceiling 11, 10 not yet attempted.
- The operational side effect: while a batch runs, every model turn queues on the single
  `--max-num-seqs 1` flashnext server, so Kanban and Telegram are sluggish for the batch's
  duration — real time, not a regression.

## User's answer, and how it was interpreted

**The user's literal reply to the checkpoint was "Continue"** — not a named option id from the
five offered (`stop-here`, `plus-three`, `plus-six`, `custom-count`, `accept-terminal`).

**This is recorded here as an orchestrator interpretation of an ambiguous reply, not as a verbatim
user selection.** The orchestrator read "Continue" as `plus-three` on the grounds that the user
had explicitly requested gap closure for Phase 7, whose entire purpose was closing BCH-01 —
running zero additional tasks after fixing the injection specifically to enable running tasks
would mean fixing the mechanism and then not using it, which does not match a phase framed around
gap closure. The orchestrator stated this interpretation plainly to the user at the time and
invited correction; no correction was received before this plan proceeded to completion.

This is **not** the same evidentiary standard as the 07-03 decision (`stop-at-one`), which quoted
the user's own words verbatim. This record does not claim the user said the words "plus-three" or
"run three more tasks" — it claims the orchestrator inferred that choice from an ambiguous
"Continue" and proceeded on that inference, and says so here without softening it.

## Consequence

- `phase-07/bench/SELECTED_TASKS_GAP` is written with 3 task directory suffixes, chosen from the
  10 not-yet-attempted, not-excluded tasks in `phase-07/results/20260830T085301Z-inventory/tasks.tsv`,
  sorted by measured `memory_mb` ascending, then `instruction_lines` ascending (per the resume
  instructions governing this continuation, to keep the run near the optimistic end of the
  projected range — the interpreted reply carries no explicit cost tolerance, so the cheapest
  available three were picked rather than any more expensive alternative):

  | Task | memory_mb | instruction_lines | timeout_sec | difficulty |
  | --- | --- | --- | --- | --- |
  | telegram-plugin-refactor | 2048 | 18 | 1800 | easy |
  | filmarchiver | 2048 | 18 | 1800 | medium |
  | v-edit-workspace-tests | 2048 | 20 | 3600 | hard |

  (`telegram-plugin-refactor` and `filmarchiver` tie at `instruction_lines=18`; the tie was broken
  by `tasks.tsv`'s own row order, which lists `telegram-plugin-refactor` first.)

- If all three run and reach a real verdict, attempted-unique-task count rises from 1 to 4
  (discord-trivia-approval-keyerror + these 3). **This is one short of ROADMAP criterion 1's
  5-8 band, not the bottom of it** — the plan's own framing ("reaches 5 total") counted the
  post-fix rerun of `discord-trivia-approval-keyerror` as a second unit; `cost.md` §4 is explicit
  that it is "the same task, attempted twice, not two different tasks," so the honest unique-task
  count after `+3` is **4**, not 5. This plan does not paper over that arithmetic: see
  `07-08-SUMMARY.md` for the corrected statement of what criterion 1's status will be.
- No `harbor run` was invoked in this plan. `bench/runs/*/meta/*.json` count remains 2
  (unchanged from `meta-count-before.txt`), confirming this plan ran zero bench tasks itself.
- 07-09 (not this plan) will run the three selected tasks and produce the real verdicts.
