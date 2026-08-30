# PROOF: the fix works — a cline-bench task reached this stack's model server

`OUTCOME: reached-model`

07-06 diagnosed `ROOT_CAUSE: schema-rejected` (`cline-cw-providers.json` failed cline 3.0.53's
persisted-settings schema, so `ProviderSettingsManager.read()` silently fell back to an empty
providers registry). 07-07 Task 1 applied the demonstrated fix (added top-level `version: 1` and
per-provider `updatedAt` to `cline-cw-providers.json`). This document is the live, real-model
proof that the fix works — not a green exit code, not a `pass` verdict, but a non-empty flashnext
server log slice with `model_turns > 0`.

## The two decisive numbers

Quoted directly from the files (`phase-07/results/20260830T122700Z-injection-fix/decisive.txt`):

```
SLICE_BYTES=145133
MODEL_TURNS=38
VERDICT=fail-context
WALL_CLOCK_SEC=1665
```

- `SLICE_BYTES=145133` — from
  `bench/runs/20260830T122809Z-phase07-fix/server-log/discord-trivia-approval-keyerror.flashnext.err.txt`
  (`wc -c`). Compare to the pre-fix run's slice: **0 bytes**
  (`bench/runs/20260830T093657Z-phase07/server-log/discord-trivia-approval-keyerror.flashnext.err.txt`).
- `MODEL_TURNS=38` — from
  `bench/runs/20260830T122809Z-phase07-fix/meta/discord-trivia-approval-keyerror.json`'s
  `model_turns` field (a `grep -c 'Request completed:'` count over the slice above). Compare to
  the pre-fix run's `model_turns`: **0**.
- `verify_bench.sh --run-dir bench/runs/20260830T122809Z-phase07-fix` reports `CHECK: PASS B11`
  (the new reached-the-model gate, opt-in for this post-fix run directory via its own
  `config.json`'s `cw_injection: "applied-v2"`).

## The server's own record of the request (verbatim)

First 6 lines of the flashnext log slice:

```
2026-08-30 21:29:35,041 - INFO - Request started: endpoint=/chat/completions model=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4 stream=True in_flight=1
2026-08-30 21:29:35,067 - INFO - Generation queued: request=82ebe32030 prompt_tokens=3021 max_tokens=23788 images=0 audio=0 videos=0
2026-08-30 21:29:35,110 - INFO - Prefill started: request=82ebe32030 backend=continuous_batching prompt_tokens=3021 images=0 audio=0 videos=0
2026-08-30 21:29:39,278 - INFO - Prefill progress: request=82ebe32030 tokens=2048/3021 (67.8%)
2026-08-30 21:29:41,174 - INFO - Prefill completed: request=82ebe32030 prompt_tokens=3021 cached_tokens=0 elapsed=6.020s rate=501.8 tok/s
2026-08-30 21:29:41,175 - INFO - Decode started: request=82ebe32030 time_to_first_token=6.117s
```

Last 6 lines of the flashnext log slice (verbatim — includes an unrelated flashnext-internal
`BatchGenerator.__del__` cleanup traceback that fires after the decisive rejection line below;
not edited out):

```
       ^^^^^^^^^^^^^^^^
  File "/Users/ohama/.local/share/uv/python/cpython-3.12.13-macos-aarch64-none/lib/python3.12/contextlib.py", line 144, in __exit__
    next(self.gen)
  File "/Users/ohama/projs/qwen38-flash-next-tests/.venv-mlxvlm-new/lib/python3.12/site-packages/mlx_vlm/generate/common.py", line 214, in wired_limit
    mx.synchronize(stream)
RuntimeError: There is no Stream(gpu, 1) in current thread.
```

The decisive rejection line (immediately before the traceback above, still verbatim):

```
2026-08-30 21:56:00,599 - INFO - Request completed: endpoint=/chat/completions model=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4 stream=True backend=continuous_batching prompt_tokens=30463 generated_tokens=408 elapsed=84.360s prefill=512.4 tok/s decode=16.5 tok/s finish_reason=tool_calls in_flight=0
2026-08-30 21:56:00,722 - INFO - Request started: endpoint=/chat/completions model=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4 stream=True in_flight=1
2026-08-30 21:56:00,762 - WARNING - Request failed: endpoint=/chat/completions model=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4 stream=True error=Request needs 33227 context tokens (31179 prompt + 2048 max generation), but MAX_KV_SIZE is 32768. in_flight=0
```

## Verdict, and why reaching the model is not the same as passing the task

**Verdict: `fail-context`** (`bench/runs/20260830T122809Z-phase07-fix/meta/discord-trivia-approval-keyerror.json`).
`fail-context` under `run_task.sh`'s own verdict rule means an HTTP 400 / context-window rejection
was seen (or `max_prompt_tokens >= 32768`) — it does **not** mean the model was never reached; it
means the opposite: **the request reached the model repeatedly (38 successful turns) and was
finally rejected at the 32K ceiling.**

- The 38th (and last successful) flashnext request completed with `prompt_tokens=30463`
  (`finish_reason=tool_calls`, meaning cline was mid-tool-use, still working the task).
- The very next request (cline's own agent iteration **38**, per
  `agent/cline.txt` line 777-779: `"iteration":38`, `"iterations":38`,
  `"finishReason":"error"`) needed `33227 context tokens (31179 prompt + 2048 max generation)`,
  which exceeds `MAX_KV_SIZE=32768` (`docs/32k-compaction-policy.md`'s already-documented ceiling)
  — litellm rejected it with a genuine `Error code: 400` before flashnext ever saw it, hence the
  server-log slice's 38 (not 39) completed requests but 38 iterations in cline's own agent log.
- Harbor's own exception classifier labeled the resulting command failure `ApiRateLimitError`
  (`Classified failed command as ApiRateLimitError (pattern: 'rate.?limit')`,
  `bench/runs/20260830T122809Z-phase07-fix/jobs/discord-trivia-approval-keyerror/*/trial.log`) —
  this is a harbor-side generic-pattern mislabel, not a real rate limit; the actual cause,
  confirmed above, is the 32K context ceiling.
- `reward=0` (`verifier/reward.txt` under the same trial dir) — the task was not completed. A
  `fail-context` (or even a `pass`) verdict on ONE task is evidence this stack's model-serving path
  works end-to-end; it is **not** evidence the task suite passes, and it is not evidence the 32K
  ceiling itself is a defect in this stack (that ceiling and its consequences are the subject of
  `docs/32k-compaction-policy.md`, not this plan).

**Reaching the model is not the same as passing the task.** This run demonstrates the former
conclusively; it says nothing new about the latter (reward remains 0, matching the pre-fix run's
0/1 pass rate, for an unrelated reason — the pre-fix run never reached the model at all).

## Measured per-task cost breakdown (harbor's own `result.json` phase timestamps)

Source: `bench/runs/20260830T122809Z-phase07-fix/jobs/discord-trivia-approval-keyerror/01k7a12sd1nk15j08e6x0x7v9e-disco__mp6a7pB/result.json`.

| Phase | Post-fix (this run) | Pre-fix (07-03 smoke run) |
| --- | --- | --- |
| `environment_setup` | 6.2s | 141.5s |
| `agent_setup` | 49.5s | 57.3s |
| **`agent_execution`** | **1589.8s** | 5.3s |
| `verifier` | 6.4s | 12.4s |
| trial total (`finished_at` minus `started_at`) | 1663.4s | 216.5s (sum of the four phases above) |
| outer wall-clock (`run_task.sh`'s own measurement) | 1665s / 1666s (outer wrapper) | 232s |

**`agent_execution` = 1589.8s (~26.5 minutes) is the number 07-08's checkpoint needs.** It is the
real per-task cost of a task that actually runs the agent loop against this stack, at
`--max-num-seqs 1` with this GPU's measured ~64s TTFT-near-ceiling / ~17 tok/s decode rate: 38
real generation turns, most of them well into the accumulated context, each one slower than the
last as the prompt grows. Contrast with the pre-fix run's `agent_execution` of 5.3s — that number
was never a measurement of running the agent loop at all; it was the time cline took to fail
immediately against the real OpenAI default endpoint with an auth error, before any of this
stack's own generation cost was ever incurred. The pre-fix `environment_setup` (141.5s) and this
run's (6.2s) differ because the discord-trivia task's Docker image was already cached/pulled in
this session; that difference is a caching artifact, not a fix-related change.

**Did the task hit harbor's per-task timeout?** No. `task.toml`'s `timeout_sec=1800` (30 minutes);
this trial finished in 1663.4s (~27.7 minutes), ending on its own via the exception described
above, not via a timeout cutoff.

## What this changes

The `stop-at-one` reasoning the user applied at 07-03 (`phase-07/results/20260830T093515Z-smoke/decision.md`)
was sound while every task produced a structural `fail-infra` — running more tasks would only
reproduce the same known limitation, buying no new information. **That premise no longer holds**:
this run demonstrates the mechanism now works, so a `fail-infra` outcome is no longer the expected
result of running additional tasks. This document does not pre-empt what to do next (run more
tasks vs. accept the current single-task evidence vs. something else) — 07-08's checkpoint asks
that question, with these two numbers (`agent_execution=1589.8s`, wall-clock=1665s) as its input.

## Cost ledger for this plan

- `harbor run` invocations: **1** (exactly the budget this plan set).
- Host `cline` invocations: **0**.
- Model requests reaching this stack: 38 completed (flashnext's own count) + 1 rejected at the 32K
  ceiling (litellm, before reaching flashnext) = 39 attempted, all real, all against this stack's
  own flashnext/litellm, none against any external API.
