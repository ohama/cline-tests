# 07-11 context forensics — results directory

Created: 2026-08-31T00:37:28Z (UTC), by plan `07-11-PLAN.md` (gap closure, wave 11).

Purpose: root-cause the two genuine context-ceiling deaths (`telegram-plugin-refactor`,
`v-edit-workspace-tests`) purely from evidence already on disk under
`bench/runs/20260830T122809Z-phase07-fix/`. No live bench runs, no model calls were made to
produce this analysis — every number below is parsed or hand-traced from files that already
existed before this plan started.

## Pre-execution safety snapshot (captured before any writes)

Protected pids, checked against the values given in this plan's `<hard_safety_constraints>`:

| pid | expected comm substring | observed at start |
| --- | --- | --- |
| 46573 | qwen38-flash-next-tests/.venv-mlxvlm-new/bin/python3 -m mlx_vlm.server | match |
| 75548 | agent-stack/venv/bin/python .../role_shim.py | match |
| 48525 | agent-stack/venv/bin/litellm | match |

`providers.json` sha256 at start: `534151965f81089b11d96d4af0b8a115b558f38efd42e82a9edd2a76f44fc214`
(matches the value given in the task prompt's hard safety constraints; this is the baseline this
plan must reproduce unchanged at the end — note the OLDER snapshot recorded in
`phase-07/results/20260830T170042Z-gap-batch/pre/providers-hash.txt`,
`fa43d153c0698dd832a2a196f04a5e283ed66690d3191b9dee06484c8de8e708`, is stale/from an earlier
session and is a pre-existing drift this plan did not cause and is not responsible for
reconciling — the plan's own hard constraint gives the authoritative current value.)

`lsof -i :3000`: empty. `colima status`: not running (left stopped, as instructed).

## Files in this directory

- `token-ladder.tsv` — Task 1 output. Per-request `prompt_tokens`/`max_tokens`/outcome ladder for
  both tasks, parsed from `bench/runs/20260830T122809Z-phase07-fix/server-log/*.flashnext.err.txt`.
- `compaction-events.tsv` — Task 2 output. Every `auto_compaction` status record (started/
  completed/skipped) extracted from each task's `agent/cline.txt`.
- `CONTEXT-FORENSICS.md` — Task 3 output. Per-task verdict, narrative, same-phenomenon question,
  measurement-artifact finding, and limits of the analysis.

## Evidence read (read-only, unmodified)

- `bench/runs/20260830T122809Z-phase07-fix/server-log/telegram-plugin-refactor.flashnext.err.txt`
- `bench/runs/20260830T122809Z-phase07-fix/server-log/v-edit-workspace-tests.flashnext.err.txt`
- `bench/runs/20260830T122809Z-phase07-fix/meta/{telegram-plugin-refactor,v-edit-workspace-tests}.json`
- `bench/runs/20260830T122809Z-phase07-fix/jobs/telegram-plugin-refactor/01k6zz0nyj31znwsevx4sn6zb2-teleg__KQTna76/agent/cline.txt`
- `bench/runs/20260830T122809Z-phase07-fix/jobs/telegram-plugin-refactor/01k6zz0nyj31znwsevx4sn6zb2-teleg__KQTna76/agent/sessions/1788109523872_h90ba/1788109523872_h90ba.compaction.json`
- `bench/runs/20260830T122809Z-phase07-fix/jobs/v-edit-workspace-tests/01k8mwgj1z6kr0a7q59r6ek2ar-v-edi__b8ZqnXb/agent/cline.txt`
- `bench/runs/20260830T122809Z-phase07-fix/jobs/v-edit-workspace-tests/01k8mwgj1z6kr0a7q59r6ek2ar-v-edi__b8ZqnXb/agent/sessions/1788110203697_678s2/1788110203697_678s2.compaction.json`
- `docs/32k-compaction-policy.md` (for the 2,700-3,100 token overshoot budget cited in §4)

Both tasks DID have a rejection line present (`outcome=rejected-maxkv`); `v-edit-workspace-tests`
additionally has one `failed-other` line (a METAL/OOM error, unrelated to context sizing) between
its last two accepted requests — see `CONTEXT-FORENSICS.md` for the discussion of that confound.
