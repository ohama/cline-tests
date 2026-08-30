# Smoke run analysis -- discord-trivia-approval-keyerror

Run directory: `bench/runs/20260830T093657Z-phase07/`
Task: `01k7a12sd1nk15j08e6x0x7v9e-discord-trivia-approval-keyerror` (easy, memory_mb=2048, timeout_sec=1800)
Wall-clock start (UTC): 2026-08-30T09:36:57Z. `harbor run` invoked via `phase-07/bench/run_task.sh`
under `phase-07/bench/preflight.sh` (11/11 PASS, `phase-07/results/20260830T093515Z-smoke/pre/`).

This section answers all seven questions, each citing the file/line it comes from. The bench
mechanism working end to end (it did) is not the same claim as the task passing (it did not).

## 1. Did it reach flashnext?

**No.** `bench/runs/20260830T093657Z-phase07/server-log/discord-trivia-approval-keyerror.flashnext.err.txt`
is **0 bytes** -- the byte-offset slice of `$FLASHNEXT_ERR_LOG` for this task's entire wall-clock
window contains not one line, meaning flashnext's own server log recorded zero requests during the
232-second run. This is a stronger claim than "no error appeared": it is the absence of any request
at all, positive or negative, in the server's own log.

Instead, the container's cline hit the **real OpenAI API** default endpoint. Evidence, quoted
verbatim from `bench/runs/20260830T093657Z-phase07/jobs/discord-trivia-approval-keyerror/01k7a12sd1nk15j08e6x0x7v9e-disco__s4cVQPf/agent/cline.txt`:

```
{"ts":"2026-08-30T09:40:21.409Z", ... "error":{"name":"Error","message":"Incorrect API key
provided: local ... "}}
{"ts":"2026-08-30T09:40:21.520Z","type":"run_result","finishReason":"error","iterations":1,
"usage":{"inputTokens":0,"outputTokens":0, ...},"durationMs":1294,"text":"Incorrect API key
provided: local-an***alue. You can find your API key at https://platform.openai.com/account/api-keys."}
```

"Incorrect API key provided... You can find your API key at platform.openai.com/account/api-keys"
is the OpenAI Node SDK's own server-returned error text for a request that actually reached
`api.openai.com` (not this stack's `host.docker.internal:4000` litellm proxy) -- it is not a
client-side string this project's own stack could produce. The 1294ms round-trip is consistent
with a real network auth-check response, not a local timeout. Neither TTFT (~64s) nor decode rate
(~17 tok/s) is comparable here because no generation ever started -- the request failed at
connection/auth, before the first token.

**Diagnosis (why, not just what):** 07-02's `FINDING.md` (`phase-07/results/20260830T091118Z-ctxwindow/FINDING.md`)
predicted, from static source analysis only, that `--extra-docker-compose` + `CLINE_PROVIDER_SETTINGS_PATH`
would redirect the container's cline to a project-authored `providers.json` supplying
`baseUrl=http://host.docker.internal:4000/v1`. This live run is the first empirical test of that
mechanism, and it did not take effect for the actual invocation shape harbor used
(`cline -P openai-compatible -k $API_KEY -m $MODELID --json --yolo -- <prompt>`, quoted verbatim in
`bench/runs/20260830T093657Z-phase07/prompts/discord-trivia-approval-keyerror/agent-command.txt`,
itself recovered from `trial.log`'s `Running command:` block -- see Q4).

Two lower layers of the mechanism were independently re-verified live, at zero additional
cline/harbor budget, specifically to rule out a merge-order or env-inheritance bug before accepting
this as a cline-level finding:
- `docker compose -f base.yaml -f phase-07/bench/cline-cw-overlay.yaml -f env.json config`, with a
  synthetic empty-`environment:` override file matching harbor's own `write_env_compose_file`
  shape (`~/.local/share/uv/tools/harbor/lib/python3.13/site-packages/harbor/environments/docker/__init__.py`
  line ~20), showed `CLINE_PROVIDER_SETTINGS_PATH` correctly surviving the merge -- an empty
  override map does not erase an earlier map's keys.
- A throwaway `docker run -e CLINE_PROVIDER_SETTINGS_PATH=...` + `docker exec` (no `-e` on the exec
  call) confirmed `docker exec` inherits a container's own environment without needing the variable
  re-passed at exec time.
- `bench/runs/20260830T093657Z-phase07/jobs/.../agent/setup/install-agent-runtime.log` confirms
  cline 3.0.53 (matching the host's pinned version) actually installed and smoke-tested inside the
  container ("3.0.53" / "Cline npm binary smoke test passed").

With compose-merge, exec-env-inheritance, and version-pin all independently confirmed sound, the
remaining explanation is that cline's own runtime resolution for this exact `-P/-k/-m --json`
invocation did not consult the injected settings path before making its first request. This is a
genuine "does not take effect in practice" finding, distinct from a harness bug -- see
`phase-07/bench/run_task.sh` deviations for the two harness bugs that WERE found and fixed
separately (Q6).

## 2. How many model turns happened, and max prompt_tokens

`grep -c 'Request completed:' bench/runs/20260830T093657Z-phase07/server-log/discord-trivia-approval-keyerror.flashnext.err.txt`
= **0** (the file is empty; see Q1). `max_prompt_tokens` = **0** (no `prompt_tokens=` line exists to
extract from). Both recorded in `bench/runs/20260830T093657Z-phase07/meta/discord-trivia-approval-keyerror.json`
(`"model_turns": 0, "max_prompt_tokens": 0`). The usual caveat that this log is shared across every
surface hitting flashnext does not weaken this particular reading -- zero lines in the slice means
zero requests from ANY surface landed in this task's byte-offset window, this task's own included.

## 3. Did the 32K ceiling fire?

**No.** No HTTP 400 anywhere: `meta/discord-trivia-approval-keyerror.json` records
`"http_400_seen": false`, cross-checked directly against both the (empty) flashnext server-log slice
and `agent/cline.txt` (`grep -c 400` on both returns 0 real matches; the one incidental "409" hit in
`cline.txt` is a substring of an unrelated number, not a status code). The observed failure is an
auth/connection error at the client SDK layer (Q1), reported by OpenAI's real API, not a
context-window rejection by this stack. This is exactly the "immediate auth/connection error
unrelated to flashnext" shape the plan's own `<action>` text pre-diagnosed, not the "clean HTTP 400
a few turns in" shape -- per the plan's own instruction, the second shape must never be retried; the
first shape is authorized one retry "with the corrected value." No retry was attempted: the
diagnosis in Q1 does not identify a simple corrected env value (BASE_URL/API_KEY passthrough was
independently confirmed working -- `$API_KEY` resolved correctly to `local-an***alue` inside the
real, failed OpenAI request itself, ruling out an env-passthrough typo) but a deeper mechanism gap,
so retrying with the same configuration would very likely reproduce the identical result at the
cost of another ~4 minutes of container/build time. Per house rule ("if injection turns out not to
work in practice, that is a legitimate finding... do not force it") and the plan's own gate ("if the
run fails in a way that would require repeated model spend to chase, STOP... the user decides"),
this was recorded as the finding rather than blindly repeated.

## 4. Was the prompt captured?

Yes, both halves, though `agent-command.txt` required a fallback this task's own trial exposed.

- `bench/runs/20260830T093657Z-phase07/prompts/discord-trivia-approval-keyerror/instruction.md` --
  1442 bytes, verbatim copy of the task's own `instruction.md`, non-empty.
- `bench/runs/20260830T093657Z-phase07/prompts/discord-trivia-approval-keyerror/agent-command.txt`
  -- 32 lines, non-empty. Harbor did **not** create an `agent/command-*/` directory for this trial
  (a `NonZeroAgentExitCodeError` trial, confirmed absent by direct listing of the copied job
  directory), which is the case `run_task.sh`'s normal capture path assumed always exists. Its
  actual resolved command is instead recoverable from `trial.log`'s own `Running command:` block; a
  fallback extractor was added to `run_task.sh` for exactly this case (see Q6). First lines of the
  recovered `agent-command.txt`:
  ```
  === extracted from .../trial.log (no agent/command-*/ dirs present) ===
  Running command: export NVM_DIR="$HOME/.nvm"; if [ -s "$NVM_DIR/nvm.sh" ]; then . "$NVM_DIR/nvm.sh";
  nvm use 22 >/dev/null 2>&1 || true; fi; set -o pipefail; cline -P openai-compatible -k $API_KEY
  -m $MODELID --json --yolo -- 'The automated trivia approval on startup is not working with the
  following log errors: ...
  ```
  This shows the resolved `-P openai-compatible` provider id and the trailing prompt argument
  (`$API_KEY`/`$MODELID` are the shell variables harbor's adapter substitutes via its own `-e`
  exec-time env dict, per `FINDING.md`'s avenue C read of `harbor/agents/installed/cline/cline.py`).

`SYSTEM_PROMPT_IN_TRANSCRIPT` from the probe (`bench/runs/20260830T093657Z-phase07/prompts/discord-trivia-approval-keyerror/system-prompt-probe.txt`)
is **`no`**. `agent/cline.txt` never got far enough for cline to emit or transcribe a system prompt
(the run errored on its first request, before any tool/system-prompt content was produced) -- this
is a direct, expected consequence of Q1's finding, not a separate capture gap. Per the plan's own
instruction: the on-wire system prompt was not captured this run either way (this stack does not
enable request-body logging on litellm/role-shim -- doing so would require restarting a live
service, out of scope for this phase). `instruction.md` + `agent-command.txt` + the (in this case
empty, itself evidentiary) server-log slice are what BCH-02 is actually met with for this task; no
claim is made on the transcript alone.

## 5. Pass or fail, and which kind?

`verifier/reward.txt` (`bench/runs/20260830T093657Z-phase07/jobs/discord-trivia-approval-keyerror/01k7a12sd1nk15j08e6x0x7v9e-disco__s4cVQPf/verifier/reward.txt`),
quoted verbatim: `0`

`verdict` from the meta record (`bench/runs/20260830T093657Z-phase07/meta/discord-trivia-approval-keyerror.json`):
`"verdict": "fail-infra"` -- per `run_task.sh`'s own auditable verdict rule (comment directly above
the classification code), `fail-infra` is assigned because zero model turns were observed in the
server-log slice, regardless of the verifier having still run and recorded a reward of 0 (the
verifier ran against the unmodified repository, since no code change was ever attempted). This is
correctly NOT `fail-task` (which requires the agent to have visibly worked, i.e. `model_turns > 0`)
and correctly NOT `fail-context` (no 400, no oversized `prompt_tokens`) -- `fail-infra` is the
accurate label: the agent never reached the model at all.

## 6. The cost number

Measured `wall_clock_sec` = **232s** (`meta/discord-trivia-approval-keyerror.json`;
independently cross-checked by the outer wrapper's own `time`-equivalent measurement,
`phase-07/results/20260830T093515Z-smoke/outer_wall_clock_sec.txt` = `232`).

Breakdown from `bench/runs/20260830T093657Z-phase07/jobs/discord-trivia-approval-keyerror/01k7a12sd1nk15j08e6x0x7v9e-disco__s4cVQPf/result.json`'s
own phase timestamps:

| phase | duration |
| --- | --- |
| `environment_setup` (image build/container create) | 141.5s |
| `agent_setup` (nvm/node/npm install cline@3.0.53) | 57.3s |
| `agent_execution` (the actual `cline` invocation) | 5.3s |
| `verifier` | 12.4s |
| trial total (`started_at`->`finished_at`) | 227.8s |

**This particular task's cost breakdown is not representative of a task that actually reaches the
model.** 198.8s of the 232s (~86%) was environment/agent setup that would recur identically for
every task regardless of outcome; only 5.3s was the (immediately-failing) agent call. A task that
DOES reach flashnext would additionally spend real generation time at this stack's own known rate
(~64s TTFT, ~17 tok/s at 32K, per `docs/32k-compaction-policy.md` and this plan's own house-rules
reminder) for however many turns it takes -- a figure this run cannot supply, since it never
generated a token.

**Projection for 4 more / 7 more, explicitly uncertain (n=1, and this one observation reached
neither the model nor a real verdict):**
- If every remaining task reproduces this same `fail-infra` shape (plausible if the injection gap is
  structural and applies to every task uniformly, since none of them changes the invocation shape):
  4 more ~= 4 x ~230s ~= **15 minutes**; 7 more ~= 7 x ~230s ~= **27 minutes**.
- If the injection gap turns out to be task-independent but the mechanism DOES work for some
  provider/model resolution path this task's own shape didn't exercise (unconfirmed), tasks that
  reach the model would each cost setup time (~200s, likely lower on repeat image-layer cache hits)
  PLUS real generation time that could range from a few turns (~1-5 minutes) to the full 1800s/3600s
  agent timeout if the 32K ceiling is hit deep into a long task. Under that scenario, 4 more could be
  anywhere from ~20 minutes to ~2 hours; 7 more from ~35 minutes to ~4+ hours.
- **The honest range given a sample of one is therefore wide: roughly 15 minutes (if the pattern
  repeats) up to several hours (if some tasks reach the model and run long).** This uncertainty,
  not a specific number, is the actual deliverable of this smoke run -- it is why the plan gates
  further spend on a human decision rather than an automatic continuation.

## 7. Was anything else affected?

Kanban and Telegram were **not** observably contended by this specific task, and there is a clean
mechanical reason why: `model_turns = 0` (Q2) means this task issued zero requests to the shared
`--max-num-seqs 1` flashnext server, so it could not have queued behind or ahead of Kanban/Telegram's
own traffic. `verify_services.sh` (`phase-07/results/20260830T093515Z-smoke/post/verify_services.txt`,
`CASES 15/15`) confirms both services healthy immediately after the run. The house-rule expectation
("a long bench run makes Kanban/Telegram sluggish -- that is expected, not a regression") did not
apply to this particular run because it never got far enough to generate load; whether it applies
turns out to depend entirely on whether a task's cline invocation actually reaches the model, which
this run demonstrates is not guaranteed by harbor's own setup succeeding.

---

## Post-run standing gate sweep

All seven gates re-run into `phase-07/results/20260830T093515Z-smoke/post/`:

| gate | result | evidence |
| --- | --- | --- |
| `preflight.sh` | `CASES 11/11`, PASS | `post/preflight-stdout.txt` |
| `phase-05/services/verify_services.sh` | `CASES 15/15`, PASS | `post/verify_services.txt` |
| `phase-02/infra/verify_no_regression.sh` | `INF03: PASS` | `post/verify_no_regression.txt` |
| `phase-06/net/verify_network.sh --baseline ...` | `CASES 24/24`, PASS | `post/verify_network.txt` |
| `phase-03/sandbox/verify_sandbox.sh` | `CASES 16/16`, SBX-04 PASS | `post/verify_sandbox.txt` |
| `phase-01/config/verify_config.sh` | exit 0 | `post/verify_config.txt` |
| `phase-07/bench/verify_bench.sh` | `CASES 10/10`, PASS | `post/verify_bench.txt` |

`cat bench/runs/CANARY.txt` still prints its original single line
(`SBX04-CANARY-MUST-NOT-BE-READABLE-FROM-INSIDE-SANDBOX`). `git diff --stat phase-01 phase-02
phase-04 phase-05 phase-06 workspace` is empty. `phase-03` shows exactly the one intentional fix
described below. Six pids unchanged (46573/75548/48525/53894/99162/19669); port 3000 unbound
(`lsof -nP -iTCP:3000 -sTCP:LISTEN` empty, exit 1).

**First preflight/gate attempt initially FAILED** (`preflight.sh` `CASES 10/11`; `verify_sandbox.sh`
`CRITERION 4 FAIL`) -- see Deviations below for the root cause and fix (a phase-03 test-harness gap
this run's own committed run directory exposed, unrelated to sandbox enforcement itself).

## Deviations from plan (Task 1 + Task 2, combined)

**1. [Rule 1 -- bug] `run_task.sh` JOB_DIR resolution raced harbor's own job-directory creation.**
`-newermt "@$JOBS_MARKER_EPOCH"` (BSD `find`, 1-second resolution) found nothing because harbor
created `bench/cline-bench/jobs/2026-08-30__18-36-57/` at the SAME second `JOBS_MARKER_EPOCH` was
captured, losing the entire `jobs/`, `agent-command.txt`, and `system-prompt-probe.txt` capture for
this task. Fixed by switching to harbor's own lexicographically-sortable job-directory naming
convention with a 30-second sanity buffer instead of strict mtime comparison. `phase-07/bench/run_task.sh`.

**2. [Rule 1 -- bug] `grep -c ... || echo 0` double-printed "0" on zero matches.** `grep -c` already
prints `0` to stdout on zero matches but still exits 1 (no match found), so the `||` fallback
printed a SECOND `0` on its own line, producing a two-line `MODEL_TURN_COUNT` that corrupted the
`meta.json`-writing heredoc (`SyntaxError: invalid syntax. Perhaps you forgot a comma?`, crashing
before the meta record could be written at all). Fixed by dropping the `|| echo 0` in favor of
`${MODEL_TURN_COUNT:-0}`. `phase-07/bench/run_task.sh`.

**3. [Rule 2 -- missing critical functionality] No fallback existed for `agent-command.txt` when
harbor creates no `agent/command-*/` directory.** This task's own `NonZeroAgentExitCodeError` trial
proved this is a real, not merely theoretical, case -- the plan's own success criteria require
"harbor's own resolved command... on disk and non-empty for this task" for ANY task, including
failed ones. Added a `trial.log`-based fallback extractor (the resolved command still appears
verbatim in `trial.log`'s own `Running command:` block). First attempt used `sed`'s `\|` for
alternation, which is a GNU extension BSD/macOS `sed`'s default BRE mode does not support -- it
silently matched neither end pattern, so the extracted block ran past its intended end into the
next unrelated command. Fixed with `sed -E` and POSIX `(a|b)` alternation. `phase-07/bench/run_task.sh`.

All three fixes were applied to `run_task.sh`, then the already-completed run's evidence was
**backfilled from the existing harbor job directory using the corrected logic** -- no second
`harbor run` was invoked. Cline/harbor budget for this task remains exactly one real run.

**4. [Rule 3 -- blocking issue, phase-03-owned file] `verify_sandbox.sh`'s SBX-04 P4 case's own
control run broke once this phase's run directory existed.** `assert_denied.sh`'s P4 case runs `cat
$BENCH_DIR/runs/*` as an UNSANDBOXED control (to prove the command would succeed absent the
sandbox) before testing the sandboxed case. Once `bench/runs/20260830T093657Z-phase07/` (a
directory, per this plan's own required artifact) existed alongside `CANARY.txt`, the glob's
control run legitimately failed with `cat: .../20260830T093657Z-phase07: Is a directory` (rc=1) --
nothing to do with sandbox enforcement, purely `cat`'s ordinary behavior on a directory argument.
`assert_denied.sh` bails out at its own control-run guard on a nonzero control rc, before ever
invoking the sandboxed command, so `P4.txt` was never written and `CRITERION 4` read FAIL. Verified
live (unsandboxed) that this is exactly what happened: `/bin/sh -c "cat bench/runs/*"` -> rc=1,
`cat: bench/runs/<dir>: Is a directory`. Fixed narrowly: P4's command changed from `cat
$BENCH_DIR/runs/*` to `find "$BENCH_DIR/runs" -type f -exec cat {} +`, which asserts the identical
thing (every FILE under `bench/runs/` is unreadable from inside the sandbox) but is robust to
subdirectories -- and is if anything a BROADER assertion (recurses into subdirectories) than the
original, not a weaker one. Verified: unsandboxed control now succeeds (rc=0, 68311 bytes read);
full `verify_sandbox.sh` re-run afterwards shows `CASES 16/16`, `CRITERION 4 PASS`.
`phase-03/sandbox/verify_sandbox.sh`. This is the one file outside `phase-07/` this plan modified;
it does not touch host posture, a live service, or the sandbox's actual security boundary (only a
test harness's own command construction), and was necessary because this phase's own required
artifact (a persistent run directory under `bench/runs/`) permanently changes what P4's glob
matches for the rest of this phase's duration (07-04/07-05 will add more task subdirectories to the
same run directory).

No other deviations. No task in this plan touched a live service, EXTRA_ALLOW_PATHS, `funnel`, or
`tailscale serve`.
