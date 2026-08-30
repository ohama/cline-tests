# Cost decision: how many more cline-bench tasks to run

**Recorded:** 2026-08-30T10:11:48Z
**Checkpoint:** 07-03 Task 3 (checkpoint:decision, gate="blocking")
**Selected option:** `stop-at-one`

## Context presented to the user

- Measured wall-clock for the smoke task: **232s** total, split into
  environment_setup 141.5s, agent_setup 57.3s, agent_execution 5.3s, verifier 12.4s
  (~86% of the run is per-task setup, not agent turns).
- Verdict: **fail-infra**. The task never reached this stack's model server —
  flashnext's byte-offset-bounded log slice is 0 bytes. The container's cline hit the
  real OpenAI default endpoint and failed with
  "Incorrect API key provided... platform.openai.com/account/api-keys", proving 07-02's
  `CLINE_PROVIDER_SETTINGS_PATH` injection (verdict INJECTABLE, source-derived, never
  live-tested) does not take effect for harbor's actual invocation shape.
- Because the invocation shape (harbor's resolved command, provider-settings path,
  container env passthrough) is identical for every task in the pool, running more
  tasks would very likely reproduce this same structural fail-infra outcome rather than
  produce new passes or new information. The projected totals for 4 more / 7 more were
  presented as ranges built on top of the 232s single observation, with the explicit
  caveat that a sample of one cannot support that projection meaningfully, and that all
  of those additional runs would most plausibly repeat the identical infra failure.

## User's answer, verbatim

> The user selected `stop-at-one`.
>
> - Run NO further bench tasks. Zero additional model spend.
> - `SELECTED_TASKS` stays empty — 07-04 must treat that as its documented "not a
>   failure of this plan" path.
> - ROADMAP criterion 1 (5-8 tasks) is NOT met, and must be recorded honestly as such,
>   with the reason and the user's decision quoted. Do NOT promote it, do not round it
>   up, do not describe one task as satisfying a 5-8 range.
> - The user's reasoning, for the record: the invocation shape is identical for every
>   task, so more runs would very likely reproduce the same structural fail-infra —
>   buying repeated evidence of one known limitation rather than more passes.

## Consequence

- `phase-07/bench/SELECTED_TASKS` is written empty (comment line only, naming the
  chosen option id `stop-at-one`).
- No further `harbor run` invocations occur in this phase. Zero additional model spend.
- ROADMAP criterion 1 ("5-8 tasks run") is recorded as **NOT MET** — one task was run,
  not five to eight — for the reason above, at the user's explicit direction. This is
  not an oversight and is not to be rounded up or reframed in any downstream document.
