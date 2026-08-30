# Phase 7 cline-bench run summary

Generated: 2026-08-30T10:04:59Z
Run directory: `/Users/ohama/projs/cline-tests/bench/runs/20260830T093657Z-phase07`

- Live task pool size (measured now, `bench/cline-bench/tasks/`): **12**
- Tasks run in this directory: **1** (8.3% of the live pool)
- cline-bench commit SHA: `d1085569fb0ae3f9613957e6fc2706c6e2f7da9b`
- harbor version: `0.22.0`
- Model spec: `openai-compatible:flashnext`
- CW_INJECTION (contextWindow injection mechanism, see phase-07/bench/config.env and
  07-02 Task 1's FINDING.md): `applied`

## Table

| task | difficulty | verdict | reward | wall_clock_s | model_turns | max_prompt_tokens | note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| discord-trivia-approval-keyerror | easy | fail-infra | 0 | 232 | 0 | 0 | - |
| every-plugin-api-migration | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| police-sync-segfault | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| intercept-axios-error-handling | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| telegram-plugin-refactor | easy | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| terraform-azurerm-deployment-stacks | hard | not-run | - | - | - | - | not-run: excluded (see config.env EXCLUDED_SUFFIXES -- memory_mb exceeds colima's VM) |
| orpc-client-migration | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| v-edit-workspace-tests | hard | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| healthchain-prefetch-removal | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| aenet-pytorch-pbc-neighborlist | hard | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| suave-http-data-bleeding | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |
| filmarchiver | medium | not-run | - | - | - | - | not-run: not yet attempted in this run directory |

## Totals

- pass: 0
- fail-task: 0
- fail-context: 0
- fail-infra: 1
- not-run: 11
- total wall-clock (attempted tasks only): 232s

## 한계 (Limitations)

A `fail-context` row proves the pipeline reached the model and the request was rejected
by this stack's 32K ceiling because the container's Cline instance was unconfigured (see
07-02 Task 1's FINDING.md) -- it is **NOT** evidence that this stack cannot complete agent
tasks. A `pass` row is **NOT** evidence that the whole live task pool would pass; only
the tasks actually attempted in this run directory are represented above, and `not-run`
rows above name every task that was not.
