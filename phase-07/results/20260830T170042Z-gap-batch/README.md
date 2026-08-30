# Gap-closure batch: running the 07-08 `plus-three` selection

**Started:** 2026-08-30T17:01:09Z

`phase-07/bench/SELECTED_TASKS_GAP` resolves to **3** non-comment, non-blank
task suffixes (verbatim, in file order):

```
telegram-plugin-refactor
filmarchiver
v-edit-workspace-tests
```

This is the plus-three selection recorded in
`phase-07/results/20260830T141218Z-cost-checkpoint/decision2.md` (07-08 Task 2) — itself an
orchestrator interpretation of an ambiguous "Continue" reply, not a verbatim user selection; see
that file for the full caveat. Not a no-op path: this batch runs all three tasks, sequentially,
into the existing post-fix run directory (`bench/runs/20260830T122809Z-phase07-fix`, already
pointed at by `phase-07/bench/CURRENT_RUN`).

Expected cost, per `cost.md`'s projected `+3` range: ~15 min (optimistic) to ~83 min (~1.4 hr,
pessimistic), for the three added tasks. Stop threshold for this plan: roughly double the
pessimistic worst case quoted in `cost.md` (~1.4 hr x2 ≈ 2.8 hr cumulative) — if crossed, this
plan stops after the current task and records why here, rather than continuing open-ended.

Pre-batch baselines captured in `pre/`: `providers-hash.txt`, `host-cline.txt`,
`allowed-repos.txt`, `pids.txt`, `images.txt`.

## Result

**Completed:** 2026-08-30T17:24:53Z (batch driver's own "BATCH COMPLETE" line).

All three tasks ran, once each, into `bench/runs/20260830T122809Z-phase07-fix`. None were retried.
Total wall-clock across the three: **1396s (~23.3 min)** — well inside the optimistic-to-pessimistic
`+3` range from `cost.md` (~15 min to ~83 min); the stop threshold (~2.8 hr cumulative) was never
approached.

| Task | Verdict | Wall clock | model_turns | slice_bytes | max_prompt_tokens |
| --- | --- | --- | --- | --- | --- |
| telegram-plugin-refactor | fail-context | 372s | 6 | 21895 | 21036 |
| filmarchiver | fail-infra | 438s | 0 | 0 | 0 |
| v-edit-workspace-tests | fail-context | 586s | 12 | 42450 | 30696 |

- **telegram-plugin-refactor** and **v-edit-workspace-tests** both reached this stack's model
  server (non-empty flashnext log slice, `model_turns > 0`) and were both rejected at the 32K
  `MAX_KV_SIZE` ceiling (`fail-context`) — the same failure mode `PROOF.md` documented for
  `discord-trivia-approval-keyerror`, now observed on two more, structurally different tasks. This
  is new evidence the ceiling is a recurring constraint of this stack's context ceiling rather than
  a one-task artifact, not evidence that any task in this pool can pass.
- **filmarchiver** did **not** reach the model (`model_turns=0`, 0-byte slice) — a genuine
  `fail-infra`, unrelated to the injection mechanism: the container's own environment-setup step
  (`bun install`) segfaulted (`panic(main thread): Segmentation fault at address 0x2D8`, `oh no:
  Bun has crashed`), preceded by Bun's own runtime warning `CPU lacks AVX support. Please consider
  upgrading to a newer CPU` — this task's own Docker image runs an x86_64 Bun binary that expects
  AVX under colima's emulated/virtualized environment, and crashed before cline was ever invoked.
  Per house rule ("do not retry a failed task"), this was recorded once and not re-run — re-running
  it would reproduce the identical segfault at the identical cost, not buy new information. Source:
  `bench/runs/20260830T122809Z-phase07-fix/jobs/filmarchiver/*/trial.log`.
- Resumability proven: re-running `run_gap_batch.sh` against the same `RESULTS` dir afterward
  produced three `SKIP (already has meta record)` lines and zero new `harbor run` invocations.
- Post-batch: `lsof -nP -iTCP:3000 -sTCP:LISTEN` empty; all six live pids present; meta record count
  in the post-fix run directory is 4 (1 pre-existing `discord-trivia-approval-keyerror` + these 3).
