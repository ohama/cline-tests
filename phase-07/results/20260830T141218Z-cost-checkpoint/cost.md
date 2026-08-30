# Cost picture: what a cline-bench task actually costs on this stack, now that it reaches the model

`OUTCOME: reached-model` (`phase-07/results/20260830T122700Z-injection-fix/OUTCOME.txt`).

Every number below is quoted from a file on disk, with its path. No projection is presented as a
measurement, and every genuine estimate is labelled as one.

## 1. Phase breakdown: post-fix vs. pre-fix

Source: harbor's own `result.json` phase timestamps.

| Phase | Post-fix (this run) | Pre-fix (07-03 smoke run) |
| --- | --- | --- |
| `environment_setup` | 6.2s | 141.5s |
| `agent_setup` | 49.5s | 57.3s |
| **`agent_execution`** | **1589.8s** | 5.3s |
| `verifier` | 6.4s | 12.4s |
| trial total (`finished_at` minus `started_at`) | 1663.4s | 216.5s |
| outer wall-clock (`run_task.sh`'s own measurement) | 1665s / 1666s | 232s |

- Post-fix source: `bench/runs/20260830T122809Z-phase07-fix/jobs/discord-trivia-approval-keyerror/01k7a12sd1nk15j08e6x0x7v9e-disco__mp6a7pB/result.json`,
  cross-cited in `phase-07/results/20260830T122700Z-injection-fix/PROOF.md`.
- Pre-fix source: `bench/runs/20260830T093657Z-phase07/jobs/discord-trivia-approval-keyerror/01k7a12sd1nk15j08e6x0x7v9e-disco__s4cVQPf/result.json`.

**The delta is the agent loop, and only the agent loop.** `agent_execution` goes from 5.3s (the
pre-fix run never reached the model — it failed against the real OpenAI default endpoint before
any of this stack's own generation cost was incurred) to 1589.8s (~26.5 min): 38 real generation
turns against flashnext, most of them well into the accumulated context, each slower than the last
as the prompt grows (`--max-num-seqs 1`, ~64s TTFT-near-ceiling, ~17 tok/s decode — established in
`docs/32k-compaction-policy.md`).

## 2. model_turns, max_prompt_tokens, verdict, timeout

Source: `bench/runs/20260830T122809Z-phase07-fix/meta/discord-trivia-approval-keyerror.json`.

- `model_turns = 38` (pre-fix: `0` — `bench/runs/20260830T093657Z-phase07/meta/discord-trivia-approval-keyerror.json`)
- `max_prompt_tokens = 30463` (pre-fix: `0`)
- `verdict = "fail-context"` — **not a pass.** `reward = 0`. The task reached its own 38th agent
  iteration successfully, then its 38th (last) request needed 33,227 context tokens against a
  32,768 `MAX_KV_SIZE` ceiling and was rejected by litellm with a genuine HTTP 400
  (`phase-07/results/20260830T122700Z-injection-fix/PROOF.md`, "The server's own record of the
  request" section, quoting `bench/runs/20260830T122809Z-phase07-fix/server-log/discord-trivia-approval-keyerror.flashnext.err.txt`
  verbatim). **Reaching the model is proven. Passing a task is not — this run is not evidence
  either way that any task in this pool can pass on this stack.**
- **Did it hit harbor's per-task timeout?** No. `task.toml`'s `timeout_sec = 1800` (30 min)
  (`bench/cline-bench/tasks/01k7a12sd1nk15j08e6x0x7v9e-discord-trivia-approval-keyerror/task.toml`);
  the trial finished in 1663.4s (~27.7 min) on its own, via the 32K rejection above, not via a
  timeout cutoff. This means **1663.4s ≈ 27.7 min is close to a worst-case single-task cost for a
  task that runs its full iteration budget without passing or timing out** — it is not itself the
  timeout ceiling, but it is close to it (the ceiling is 30 min for this task; some tasks in the
  pool have `timeout_sec = 3600`, a 60 min ceiling — see the pool table below).

## 3. Image-layer caching: measured for one task, not established across tasks

`environment_setup` fell from 141.5s (pre-fix, cold) to 6.2s (post-fix, same task rerun) —
**this is a caching artifact of re-running the identical task's Docker image in the same session,
not a consequence of the fix itself** (`PROOF.md`, "Measured per-task cost breakdown" section,
final paragraph). This is measured, but only for one task run twice.

**ESTIMATE, not measured:** whether this saving transfers to the *other* 11 tasks in the pool is
unknown — `phase-07/bench/cline-cw-overlay.yaml`'s target aside, **each of the remaining tasks has
its own Dockerfile** (`bench/cline-bench/tasks/<dir>/`), so cache layers are not guaranteed to be
shared across different tasks. The honest assumption for a *first* run of a task not yet attempted
is the pre-fix `environment_setup` figure (141.5s, cold-pull order of magnitude) as an upper bound,
and the post-fix figure (6.2s) as a lower bound only for tasks that happen to share base layers
already pulled in this session.

## 4. The remaining pool

Source: `phase-07/results/20260830T085301Z-inventory/tasks.tsv` (the measured, live inventory —
12 tasks). Attempted-task cross-reference: `ls bench/runs/*/meta/*.json` (2 files, both
`discord-trivia-approval-keyerror` — one pre-fix, one post-fix; the same task, attempted twice, not
two different tasks).

| Task | Difficulty | memory_mb | timeout_sec | Status |
| --- | --- | --- | --- | --- |
| discord-trivia-approval-keyerror | easy | 2048 | 1800 | **attempted (both eras)** — post-fix `reached-model`/`fail-context` |
| telegram-plugin-refactor | easy | 2048 | 1800 | not attempted |
| filmarchiver | medium | 2048 | 1800 | not attempted |
| v-edit-workspace-tests | hard | 2048 | 3600 | not attempted |
| police-sync-segfault | medium | 2048 | 1800 | not attempted |
| orpc-client-migration | medium | 2048 | 3600 | not attempted |
| intercept-axios-error-handling | medium | 2048 | 1800 | not attempted |
| every-plugin-api-migration | medium | 2048 | 1800 | not attempted |
| suave-http-data-bleeding | medium | 4096 | 1800 | not attempted |
| healthchain-prefetch-removal | medium | 4096 | 1800 | not attempted |
| aenet-pytorch-pbc-neighborlist | hard | 4096 | 3600 | not attempted |
| terraform-azurerm-deployment-stacks | hard | 8192 | 3600 | **excluded** — `memory_mb=8192` exceeds colima's VM (`EXCLUDED_SUFFIXES`, `phase-07/bench/config.env`) |

- Pool size: 12. Excluded (memory): 1. **Honest ceiling: 11 tasks this stack can run at all.**
- Attempted so far (either era): 1 unique task (`discord-trivia-approval-keyerror`).
- **Tasks actually available to run and not yet attempted: 10.**

## 5. Projected totals — ranges, with assumptions stated

**n = 1 cannot support a tight projection.** The only real `agent_execution` measurement is
1589.8s, for one `easy`-difficulty task that ran to its full 38-iteration budget without passing.
Two bounding assumptions:

- **Best case per task** (assumption, not measured): a task finishes — passes or fails — well
  before the iteration/context ceiling, and its Docker layers are already warm. Approximated here
  as `environment_setup` ~6-20s (warm-cache order) + `agent_setup` ~50-60s + a *shorter*
  `agent_execution` than the one measurement + `verifier` ~6-15s. There is no measured example of
  a short `agent_execution` on this stack to anchor this on — it is a structural lower bound, not
  an extrapolation from data.
- **Worst case per task** (assumption, grounded in the one measurement): the task runs its full
  iteration budget like this one did, `agent_execution` ≈ the measured 1589.8s (for a 1800s-timeout
  task) or scales toward the 3600s ceiling for the four `hard`/`3600s`-timeout tasks in the
  remaining pool (v-edit-workspace-tests, orpc-client-migration, aenet-pytorch-pbc-neighborlist —
  orpc is `medium` but still 3600s). Total trial time approaches, but per this one data point does
  not exceed, the task's own `timeout_sec`.

Using the one measured worst-case anchor (~1665s ≈ 27.75 min per task, all 1800s-timeout tasks) as
the pessimistic bound, and a deliberately loose optimistic bound (~5 min per task: warm setup +
a short agent loop that finishes well short of the ceiling — **unverified, structural estimate
only**):

| Option | Tasks added | Optimistic total (added) | Pessimistic total (added) |
| --- | --- | --- | --- |
| `+3` | 3 | ~15 min | ~83 min (~1.4 hr) |
| `+4` | 4 | ~20 min | ~111 min (~1.85 hr) |
| `+7` | 7 | ~35 min | ~194 min (~3.2 hr) |

These are **wall-clock ranges for the added tasks only**, run one at a time (see §6 — tasks are
strictly sequential on this stack, they cannot run in parallel against a single `--max-num-seqs 1`
flashnext server). The pessimistic bound assumes every added task looks like the one measured task
(reaches the model, runs to its iteration ceiling, does not pass); the optimistic bound assumes
none of them do. **Neither bound is a promise.** Whether `fail-context` at iteration 38 is typical
of this pool or specific to this one task is unknown at n=1 — that is itself something more runs
would tell you that nothing observed so far does.

## 6. Operational side effect

While any batch of additional tasks runs, every model turn queues on the same
`--max-num-seqs 1` flashnext server (`bench/runs/20260830T122809Z-phase07-fix/config.json`'s
`model_spec`, `phase-07/bench/config.env`'s `HARBOR_MODEL_SPEC`) — Kanban and Telegram (both live
services sharing this model server) will be sluggish for the full duration of the batch. This is
expected, not a regression, but it is real degraded time for the user's other tools, and it scales
directly with however many tasks are chosen: one task took ~27.8 min end-to-end; a batch of `N`
tasks run sequentially takes roughly `N` times that, not less.

## What this does not tell you

- It does not tell you whether any task in this pool can pass on this stack. The one task run
  reached the model and still failed, at the documented 32K ceiling.
- It does not tell you whether `fail-context` at iteration 38 is typical of this pool (many tasks
  have far fewer `instruction_lines` than this one's 30 — see `tasks.tsv` — which may or may not
  correlate with fewer turns) or an artifact of this specific task's shape. That is unknown from
  n=1.
- It presents no recommendation. The next task asks the question.
