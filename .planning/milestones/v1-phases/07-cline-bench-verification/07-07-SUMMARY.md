---
phase: 07-cline-bench-verification
plan: 07
subsystem: testing
tags: [cline, harbor, docker-compose, providers-json, zod-schema, gap-closure, proof, verify_bench]

# Dependency graph
requires:
  - phase: 07-06
    provides: "ROOT_CAUSE: schema-rejected diagnosis, FIX_AVAILABLE: yes, demonstrated-working candidate fix (probe/R3/schema-fix-supplement-result-file.json), injection_probe.sh (R1 compose-merge-replay rung reused here, not copied)"
provides:
  - "cline-cw-providers.json with the schema fix applied (top-level version:1, per-provider updatedAt) -- live proof the fix works"
  - "run_task.sh pre-run assertion (reuses injection_probe.sh --rung R1) that refuses to spend a harbor run if the compose merge cannot resolve the mechanism's mount+env"
  - "verify_bench.sh check B11: reached-the-model (non-empty flashnext log slice AND model_turns>0), opt-in per run directory via config.json's cw_injection field"
  - "bench/runs/20260830T122809Z-phase07-fix/: one real cline-bench task run against the fixed mechanism, OUTCOME: reached-model"
  - "phase-07/results/20260830T122700Z-injection-fix/PROOF.md: the decisive evidence, measured agent_execution cost (1589.8s), and confirmation the stop-at-one premise no longer automatically holds"
affects: [07-08, 07-09, 07-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "opt-in-gate-per-artifact-generation: a verify_bench.sh check (B11) that is conditionally SKIPPED (visible, but excluded from the PASSED/TOTAL denominator) based on a field the artifact itself carries (config.json's cw_injection), so one gate script can honestly judge both a pre-fix and a post-fix era of evidence without either retroactively failing or silently passing the other"
    - "fail-closed-pre-run-assertion-via-reused-probe: run_task.sh calls injection_probe.sh's own R1 rung (not a copy) as a pre-run guard before harbor run, so an infrastructure change that breaks the injection mechanism is caught before ~4 minutes are spent, not after"

key-files:
  created:
    - phase-07/results/20260830T122700Z-injection-fix/PROOF.md
    - phase-07/results/20260830T122700Z-injection-fix/OUTCOME.txt
    - phase-07/results/20260830T122700Z-injection-fix/decisive.txt
    - bench/runs/20260830T122809Z-phase07-fix/
  modified:
    - phase-07/bench/cline-cw-providers.json
    - phase-07/bench/config.env
    - phase-07/bench/run_task.sh
    - phase-07/bench/verify_bench.sh
    - phase-07/bench/CURRENT_RUN

key-decisions:
  - "OUTCOME: reached-model. The schema fix (top-level version:1 + per-provider updatedAt in cline-cw-providers.json) works: the discord-trivia-approval-keyerror smoke task produced a 145133-byte flashnext server log slice with model_turns=38, verified by the new B11 check (CHECK: PASS B11)."
  - "CW_INJECTION: applied -> applied-v2. The old value no longer describes the current file (it now has the schema fix); every run directory created from now on self-describes its mechanism via config.json's injection_mechanism/injection_evidence fields."
  - "The task's own verdict is fail-context, not pass (reward=0) -- it hit the documented 32K MAX_KV_SIZE ceiling at cline's own iteration 38 of 38 (litellm Error code: 400, 'Request needs 33227 context tokens... MAX_KV_SIZE is 32768'), after 38 successful turns. Reaching the model is proven; passing the task is a separate, unresolved question this plan does not claim to answer."
  - "The stop-at-one reasoning from 07-03 (further runs would only reproduce a known fail-infra) no longer automatically applies now that the mechanism reaches the model -- this plan explicitly does not decide what to do next; that is 07-08's checkpoint, seeded with agent_execution=1589.8s and wall_clock=1665s."

patterns-established:
  - "record()-bypass-for-visible-non-counted-checks: verify_bench.sh's SKIP path for B11 prints its own CHECK line directly (not via record()) so it is visible in the transcript without incrementing PASSED/TOTAL -- distinct from B3's 'excused' idiom (which DOES count as a pass with a note); used here because the plan explicitly required the skip to NOT be counted as a pass."

# Metrics
duration: ~85min (includes one uninterrupted ~28min harbor run, the plan's entire model-cost budget)
completed: 2026-08-30
---

# Phase 7 Plan 7: Gap Closure — Apply the Fix and Prove It Summary

**Applied 07-06's demonstrated schema fix (`version`/`updatedAt` in `cline-cw-providers.json`) and proved it live: one `harbor run` produced a 145133-byte flashnext server log slice with `model_turns=38` — `OUTCOME: reached-model`, `verify_bench.sh` reports `CHECK: PASS B11` — reversing 07-03's `fail-infra` finding that the injection mechanism never took effect. `agent_execution=1589.8s` is the first real measured per-task cost of this stack actually running the agent loop.**

`OUTCOME: reached-model`. `agent_execution=1589.8s` (~26.5 min). `wall_clock=1665s` (~27.8 min).

## Performance

- **Duration:** ~85 min (Task 1 ~15 min, Task 2 dominated by one uninterrupted ~28 min `harbor run`, Task 3 ~15 min)
- **Started:** 2026-08-30T12:12:00Z (approx.)
- **Completed:** 2026-08-30T13:35:23Z
- **Tasks:** 3/3
- **Files modified:** 4 bench scripts/config + 1 new run directory + 1 new results directory (plus cross-phase gate-sweep evidence directories under phase-02/03/05/06/07/results/)

## Accomplishments

- **Applied the demonstrated-working fix directly**, no new mechanism: added top-level `"version": 1`
  and a per-provider `"updatedAt"` ISO-8601 datetime to `phase-07/bench/cline-cw-providers.json`,
  reproducing exactly the shape 07-06's R3 probe rung showed cline 3.0.53 retaining in full
  (`baseUrl`/`apiKey`/`model`/`contextWindow` all intact).
- **Added a fail-closed pre-run assertion** to `run_task.sh` that reuses (not copies)
  `injection_probe.sh`'s R1 compose-merge-replay rung: it refuses to invoke `harbor run` unless
  the resolved compose config for the service harbor execs into contains the mechanism's mount
  target and env var with a fully-resolved absolute source path — proven live, standalone, before
  the real run (`CHECK: PASS R1-compose-merge-replay`), and again as the real run's own first
  pre-guard line (`pre-guard: pre-run injection assertion (R1 compose-merge-replay) OK`).
- **Added check B11 to `verify_bench.sh`**: at least one attempted task with BOTH a non-zero-size
  flashnext server log slice AND `model_turns > 0`. Opt-in per run directory via the run's own
  `config.json.cw_injection` field — the pre-fix bundle (`bench/runs/20260830T093657Z-phase07/`)
  gets a visible `CHECK: SKIP B11` line that is NOT counted toward PASSED/TOTAL, so it keeps its
  honest `CASES 10/10` signature unchanged; the new post-fix run directory gets a real
  `CHECK: PASS B11`, `CASES 10/11`.
- **Ran exactly one `harbor run`** (the plan's entire budget) into a new run directory
  (`bench/runs/20260830T122809Z-phase07-fix/`), the same `discord-trivia-approval-keyerror` task
  07-03 used, foreground, to completion (not interrupted): wall-clock 1665s/1666s, `harbor_exit_code=0`.
- **The decisive proof**: `SLICE_BYTES=145133` (vs. the pre-fix run's `0`), `MODEL_TURNS=38` (vs.
  `0`) — the injection mechanism now demonstrably reaches this stack's flashnext server, reversing
  07-03's `fail-infra` finding for the first time in this phase.
- **Traced the task's own outcome to the documented 32K ceiling, not to any harness defect**: the
  38th (last successful) flashnext request completed at `prompt_tokens=30463`; the next request
  (cline's own iteration 38 of 38) needed `33227 context tokens`, exceeding `MAX_KV_SIZE=32768`
  (`docs/32k-compaction-policy.md`'s already-known limit) — litellm rejected it with a genuine
  `Error code: 400` before flashnext ever saw it. `verdict=fail-context`, `reward=0`.
- **Measured the real per-task cost of a task that actually runs the agent loop**:
  `agent_execution=1589.8s` (~26.5 min), from harbor's own `result.json` phase timestamps —
  contrasted against the pre-fix run's `agent_execution=5.3s` (which was never a measurement of
  running the loop at all, just the time to fail against the real OpenAI endpoint before any of
  this stack's own generation cost was incurred).
- **Wrote `PROOF.md`** with the two decisive numbers (with paths), the verbatim first/last flashnext
  log slice lines, the decisive 32K-ceiling rejection line, the fail-context verdict with an
  explicit "reaching the model is not the same as passing the task" statement, the full cost
  breakdown table (post-fix vs. pre-fix), confirmation the run did NOT hit harbor's 1800s per-task
  timeout, and an explicit non-pre-emptive note that the `stop-at-one` premise no longer
  automatically holds — leaving the "what next" decision to 07-08's checkpoint.
- **Re-swept all seven standing gates post-run**: `preflight.sh` 11/11, `verify_bench.sh` on both
  run directories (pre-fix `CASES 10/10` PASS with B11 SKIP; post-fix `CASES 10/11` — B5 fails only
  because `make_summary.sh` was never run against this single-task dir, out of this plan's scope,
  while **B11 PASS**, the decisive check), `verify_services.sh` 15/15, `verify_no_regression.sh`
  INF03 PASS, `verify_sandbox.sh` 16/16 with `CRITERION 4 PASS` asserted **after** the new run
  directory exists under `bench/runs/`, `verify_network.sh --baseline` 24/24, `verify_config.sh`
  exit 0 clean (`check_versions.sh` not run — banned this plan, host `cline` budget stayed 0).

## Task Commits

Each task was committed atomically:

1. **Task 1: Apply the schema fix, add B11** - `81fd055` (feat)
2. **Task 2: Run exactly one task with the fix into a new run directory** - `fd3b863` (feat)
3. **Task 3: PROOF.md, cost breakdown, post-gate sweep** - `7f9bbc0` (docs)

## Files Created/Modified

- `phase-07/bench/cline-cw-providers.json` — added top-level `version:1` + per-provider `updatedAt`
- `phase-07/bench/config.env` — `CW_INJECTION` `applied` -> `applied-v2`; added exported
  `INJECTION_MECHANISM`/`INJECTION_EVIDENCE`
- `phase-07/bench/run_task.sh` — config.json now carries `injection_mechanism`/`injection_evidence`;
  new pre-run assertion (reuses `injection_probe.sh --rung R1`) before `harbor run`
- `phase-07/bench/verify_bench.sh` — new check B11 (reached-the-model), opt-in per run directory
- `phase-07/bench/CURRENT_RUN` — points at the new post-fix run directory
- `bench/runs/20260830T122809Z-phase07-fix/` — the one real run's full evidence bundle
- `phase-07/results/20260830T122700Z-injection-fix/` — `PROOF.md`, `OUTCOME.txt`, `decisive.txt`,
  pre-run preflight capture, post-run gate sweep (`post/`)

## Decisions Made

- **`OUTCOME: reached-model`** — see key-decisions in frontmatter for the full evidentiary chain.
- **`CW_INJECTION: applied -> applied-v2`** — the literal value change makes it impossible to
  mistake a pre-fix run directory for a post-fix one by reading `config.json` alone.
- **The task's `fail-context` verdict (reward=0) is not treated as, or reported as, a passing
  result.** `PROOF.md` states explicitly that reaching the model and passing the task are
  different claims, and that this plan proves only the former.
- **No second `harbor run` was considered**, per the plan's own `stop-at-one`-derived discipline —
  exactly one invocation, whatever its outcome, was this plan's entire model-cost budget.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — bug] Bash parameter-expansion default values cannot contain an unescaped apostrophe, even inside outer double quotes**
- **Found during:** Task 1 (writing `INJECTION_MECHANISM` into `config.env`)
- **Issue:** `X="${X:-...cline 3.0.53's persisted-settings schema...}"` fails `bash -n` with
  `unexpected EOF while looking for matching ''` — an unescaped `'` inside a `${VAR:-word}`
  default is parsed as a quote-open even though the whole assignment is already inside double
  quotes (a documented bash quoting gotcha, not specific to this file). Comments (`# ...`) were
  unaffected; only the literal default-value text of the two new `${VAR:-...}` assignments hit it.
- **Fix:** Reworded the two default strings to avoid contractions/apostrophes (`cline 3.0.53's` ->
  `cline 3.0.53`, `ProviderSettingsManager.read()` -> `ProviderSettingsManager.read`), verified with
  `bash -n` and a live `source` + `echo` of the resulting values.
- **Files modified:** `phase-07/bench/config.env`
- **Committed in:** `81fd055` (Task 1)

**2. [Rule 3 — blocking, tooling] `git diff` computed by the harness's forked shell can lose exported env vars between Bash tool calls**
- **Found during:** Task 3 (first `verify_network.sh --baseline` attempt)
- **Issue:** `bash phase-06/net/verify_network.sh --baseline "$NET_BASELINE"` was invoked in a
  fresh Bash tool call without first re-`source`-ing `config.env` in that same call, so
  `$NET_BASELINE` was empty and the script's own `live-pids-stable` check correctly reported
  `CRASHED: no --baseline <dir> provided`, producing `CASES 23/24 CRASHED 1`.
- **Fix:** Re-ran in a call that `source`d `phase-07/bench/config.env` first, in the same shell
  invocation as the `verify_network.sh` call. Result: `CASES 24/24 CRASHED 0 PASS`. This was an
  operator (this executor's) tooling mistake, not a script or mechanism defect — no file was
  changed, and the first (failed) attempt's transcript was simply superseded, not committed.
- **Files modified:** none (operational only; the correct transcript is what's in
  `phase-07/results/20260830T122700Z-injection-fix/post/verify_network.txt`)
- **Committed in:** `7f9bbc0` (Task 3, correct transcript only)

---

**Total deviations:** 2 auto-fixed (1 Rule-1 bug, 1 Rule-3 operational blocker). Neither touched a
live service, host posture, or the plan's model/harbor budget. No scope creep.

## Issues Encountered

- The `harbor run` took ~28 minutes (1589.8s `agent_execution` + ~74s of setup/verifier overhead),
  well past the ~232s the pre-fix run took (which never reached the model at all) but comfortably
  under harbor's own 1800s per-task timeout. This was expected per the plan's own house rules
  (real generation at `--max-num-seqs 1`, ~64s TTFT-near-ceiling, ~17 tok/s decode) — not a
  regression, and Kanban/Telegram sluggishness during the run (not directly observed by this
  executor, but structurally expected from the shared model server) is the documented cost of that
  choice, not a new finding.
- Harbor's own exception classifier labeled the resulting command failure `ApiRateLimitError`
  (`Classified failed command as ApiRateLimitError (pattern: 'rate.?limit')`) — a generic-pattern
  mislabel; the actual, directly-quoted cause is a 32K context-window rejection, documented plainly
  in `PROOF.md` rather than left as an unexplained exception name.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **07-08** has its checkpoint input ready: `agent_execution=1589.8s`, `wall_clock=1665s`,
  `OUTCOME: reached-model`, and the explicit statement in `PROOF.md` that the `stop-at-one`
  premise no longer automatically applies (without pre-empting what to decide).
- **07-08/07-09/07-10** should NOT re-litigate H1-H5 (07-06, standing) or re-attempt the schema fix
  (this plan, standing, demonstrated live) — both are settled with named evidence paths.
- The new `verify_bench.sh` check B11 is a standing, re-runnable assertion (`CHECK: PASS|SKIP|FAIL
  B11`) — any future run directory's "did this reach the model" question is now machine-checkable
  rather than a prose claim, for both pre-fix and post-fix run directories.
- `bench/runs/20260830T122809Z-phase07-fix/` and `bench/runs/20260830T093657Z-phase07/` now
  coexist as two honestly-distinguished eras (`config.json.cw_injection`: `applied` vs.
  `applied-v2`) — future summaries/docs must cite the correct one for the claim being made
  (pipeline-worked-at-all vs. reached-the-model).
- Six live pids (46573/75548/48525/53894/99162/19669), port 3000 (unbound), `bench/runs/CANARY.txt`,
  `workspace/ALLOWED_REPOS.json`, and `EXTRA_ALLOW_PATHS` (empty) were all unchanged across every
  task and the final gate sweep. Host `cline` invocations: 0 (confirmed via unchanged
  `/opt/homebrew/lib/node_modules/cline/package.json` mtime, pre-existing drift, not touched).
  `harbor run` invocations: exactly 1 (the plan's entire budget).

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-30*
