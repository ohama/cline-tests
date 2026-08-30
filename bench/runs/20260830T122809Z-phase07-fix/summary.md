# Phase 7 cline-bench run summary

Generated: 2026-08-30T17:27:02Z
Run directory: `bench/runs/20260830T122809Z-phase07-fix`

- Live task pool size (measured now, `bench/cline-bench/tasks/`): **12**
- Tasks run in this directory: **4** (33.3% of the live pool)
- cline-bench commit SHA: `d1085569fb0ae3f9613957e6fc2706c6e2f7da9b`
- harbor version: `0.22.0`
- Model spec: `openai-compatible:flashnext`
- CW_INJECTION (contextWindow injection mechanism, see phase-07/bench/config.env and
  07-02 Task 1's FINDING.md): `applied-v2`
- **Reached the model (non-empty flashnext server-log slice AND model_turns > 0) in this
  directory: 3 of 4 attempted** -- this is the number
  BCH-01's honesty depends on, distinct from how many tasks merely ran; see verify_bench.sh
  check B11 for the same signal re-verified independently.

## Table

| task | difficulty | verdict | reward | wall_clock_s | model_turns | max_prompt_tokens | note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| discord-trivia-approval-keyerror | easy | fail-context | 0 | 1665 | 38 | 30463 | - |
| filmarchiver | medium | fail-infra | null | 437 | 0 | 0 | - |
| telegram-plugin-refactor | easy | fail-context | 0 | 371 | 6 | 21036 | - |
| v-edit-workspace-tests | hard | fail-context | 0 | 585 | 12 | 30696 | - |
| every-plugin-api-migration | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| police-sync-segfault | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| intercept-axios-error-handling | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| terraform-azurerm-deployment-stacks | hard | not-run | - | - | - | - | not-run: excluded (see config.env EXCLUDED_SUFFIXES -- memory_mb exceeds colima's VM) |
| orpc-client-migration | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| healthchain-prefetch-removal | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| aenet-pytorch-pbc-neighborlist | hard | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| suave-http-data-bleeding | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |

## Totals

- pass: 0
- fail-task: 0
- fail-context: 3
- fail-infra: 1
- not-run: 8
- total wall-clock (attempted tasks only): 3058s

## 한계 (Limitations)

A `fail-context` row proves the pipeline reached the model and the request was rejected
by this stack's 32K ceiling because the container's Cline instance was unconfigured (see
07-02 Task 1's FINDING.md) -- it is **NOT** evidence that this stack cannot complete agent
tasks. A `pass` row is **NOT** evidence that the whole live task pool would pass; only
the tasks actually attempted in this run directory are represented above, and `not-run`
rows above name every task that was not.
