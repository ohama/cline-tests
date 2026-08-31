---
phase: 07-cline-bench-verification
plan: 03
subsystem: testing
tags: [harbor, cline-bench, docker, fail-infra, cost-checkpoint, evidence-capture]

# Dependency graph
requires:
  - phase: 07-02
    provides: contextWindow-injection mechanism (verdict INJECTABLE, source-derived, never live-tested), run_task.sh/make_summary.sh/verify_bench.sh
provides:
  - "One official cline-bench task (discord-trivia-approval-keyerror) executed end to end under harbor run --env docker, in the foreground, with a complete evidence bundle"
  - "Live proof that 07-02's INJECTABLE contextWindow/BASE_URL injection mechanism does not take effect for harbor's real -P/-k/-m --json --yolo invocation shape"
  - "phase-07/bench/SELECTED_TASKS, written empty at the user's explicit stop-at-one decision"
  - "phase-07/results/20260830T093515Z-smoke/decision.md, the verbatim checkpoint answer"
  - "A one-file (phase-03/sandbox/verify_sandbox.sh) fix for a self-inflicted SBX-04 control-run regression"
affects: [07-04, 07-05, 08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "verify-in-isolation-before-blaming-the-target: before accepting a live failure as a cline-level finding, the docker-compose merge and docker exec env-inheritance layers underneath it were each independently re-tested in isolation, at zero cline/harbor budget, to rule out a harness-level explanation first"

key-files:
  created:
    - phase-07/results/20260830T093515Z-smoke/decision.md
    - phase-07/bench/SELECTED_TASKS
  modified: []

key-decisions:
  - "User selected stop-at-one at the blocking cost-decision checkpoint: zero further bench tasks, zero additional model spend. Reasoning recorded verbatim: the invocation shape is identical for every task in the pool, so more runs would very likely reproduce the same structural fail-infra rather than buying new passes -- repeated evidence of one known limitation, not more information."
  - "ROADMAP Phase 7 criterion 1 ('harbor run --env docker 로 cline-bench 공식 과제 5~8개가 로컬 Docker 에서 실행') is recorded as NOT MET -- one task ran, not five to eight -- explicitly, at the user's direction, with no rounding up and no reframing of one task as satisfying a 5-8 range."
  - "07-02's contextWindow/BASE_URL injection mechanism (verdict INJECTABLE, sourced from static reads of the installed harbor adapter and installed cline binary, never live-tested) does NOT take effect for harbor's actual invocation shape in practice. The container's cline hit the real OpenAI API default endpoint instead of this stack's flashnext, and failed on 'Incorrect API key provided... platform.openai.com/account/api-keys'. This is a genuine cline-level 'does not take effect' finding, not a harness bug -- the docker-compose merge and docker exec env-inheritance layers underneath it were each independently re-verified live and confirmed sound."

patterns-established:
  - "cost-decision checkpoints must present the measured single-observation number plus an explicitly-labeled uncertainty range for extrapolation, never a false-precision projection"

# Metrics
duration: ~7min (Task 3 only -- checkpoint answer already provided; Tasks 1-2 ~35min prior)
completed: 2026-08-30
---

# Phase 7 Plan 3: Smoke Task + Cost Checkpoint Summary

**One cline-bench task ran end to end under `harbor run --env docker` in 232s and never reached this stack's model server (verdict `fail-infra`) -- proving 07-02's source-derived contextWindow/BASE_URL injection mechanism does not take effect for harbor's real invocation shape -- and the user chose `stop-at-one`, leaving `phase-07/bench/SELECTED_TASKS` empty and ROADMAP criterion 1 (5-8 tasks) recorded as explicitly NOT MET.**

## Performance

- **Duration:** Task 1-2 ~35 min (prior agent); Task 3 (this continuation) ~7 min
- **Completed:** 2026-08-30T10:12:00Z (approx.)
- **Tasks:** 3/3 (2 `auto`, 1 `checkpoint:decision` -- blocking, answered `stop-at-one`)
- **Files modified:** 2 new files this task (`decision.md`, `SELECTED_TASKS`); ~80 evidence files across Tasks 1-2

## Accomplishments

- Ran `discord-trivia-approval-keyerror` (easy, `memory_mb=2048`) via `harbor run --env docker` in the foreground under `preflight.sh` (`CASES 11/11`), measured wall-clock **232s**, and captured a complete evidence bundle (`instruction.md`, `agent-command.txt`, `system-prompt-probe.txt`, server-log byte-offset slice, `meta.json`) even though the run itself failed before reaching the model.
- Diagnosed the failure with citations, not inference: the server-log slice is 0 bytes (zero requests reached flashnext); the container's cline instead hit the real `api.openai.com` and failed with the OpenAI SDK's own "Incorrect API key provided" text. This directly falsifies 07-02's `VERDICT: INJECTABLE` in live practice -- the mechanism was source-derived and never live-tested until this run.
- Ruled out a harness-level explanation before accepting the cline-level finding: independently re-verified live, at zero additional cline/harbor budget, that (a) the docker-compose overlay merge preserves `CLINE_PROVIDER_SETTINGS_PATH` and (b) `docker exec` inherits container env without re-passing `-e`. Both layers underneath the injection mechanism work correctly in isolation -- the gap is specifically in cline's own runtime resolution for harbor's exact `-P/-k/-m --json --yolo` invocation shape.
- Measured and broke down the 232s wall-clock: `environment_setup` 141.5s, `agent_setup` 57.3s, `agent_execution` 5.3s, `verifier` 12.4s -- roughly 86% is per-task setup that would recur identically for every task regardless of outcome, only 5.3s was the (immediately-failing) agent call.
- Re-ran and passed all seven standing gates post-run (`preflight.sh` 11/11, `verify_services.sh` 15/15, `verify_no_regression.sh` INF03:PASS, `verify_network.sh` 24/24, `verify_sandbox.sh` 16/16 SBX-04 PASS, `verify_config.sh` exit 0, `verify_bench.sh` 10/10), after finding and fixing a self-inflicted `verify_sandbox.sh` SBX-04 control-run regression (this phase's own required run directory broke an unsandboxed `cat` control via `Is a directory`, unrelated to sandbox enforcement).
- Presented the measured cost, the `fail-infra` verdict and its cause, and an explicitly-uncertain projection range for 4/7 more tasks (roughly 15 minutes if the pattern repeats, up to several hours if some tasks reach the model) at the blocking cost-decision checkpoint. The user selected **`stop-at-one`**.
- Recorded the user's answer verbatim in `phase-07/results/20260830T093515Z-smoke/decision.md` with a UTC timestamp, and wrote `phase-07/bench/SELECTED_TASKS` empty (comment line naming the chosen option id only), per the plan's own `<after>` instruction for the `stop-at-one` branch.

## Task Commits

Each task was committed atomically:

1. **Task 1: Run the smoke task, foreground, timed** - `380e951` (feat)
2. **Task 2: Analyse the smoke result and re-run every standing gate** - `c784e11` (docs)
3. **Task 3 (checkpoint:decision): record `stop-at-one`, `SELECTED_TASKS` empty** - `9bcd62f` (docs)

## Files Created/Modified

- `phase-07/results/20260830T093515Z-smoke/console.txt`, `outer_wall_clock_sec.txt`, `exit_code.txt`, `pre/` — Task 1's foreground run capture and preflight evidence
- `bench/runs/20260830T093657Z-phase07/` — the phase's single run directory (`prompts/`, `jobs/`, `server-log/`, `meta/`, `logs/`, `config.json`, `summary.md`), seeded with the smoke task; 07-04 will append into this same directory if ever run
- `phase-07/results/20260830T093515Z-smoke/ANALYSIS.md` (279 lines) — the seven-question analysis, each citing file/line
- `phase-07/results/20260830T093515Z-smoke/post/` — full post-run gate sweep evidence (all seven gates)
- `phase-03/sandbox/verify_sandbox.sh` — one-line-scope fix: SBX-04 P4's unsandboxed control changed from `cat $BENCH_DIR/runs/*` to `find "$BENCH_DIR/runs" -type f -exec cat {} +`, robust to subdirectories, broader not weaker
- `phase-07/results/20260830T093515Z-smoke/decision.md` — the checkpoint's verbatim answer, with context and consequence
- `phase-07/bench/SELECTED_TASKS` — written empty (comment naming `stop-at-one` only); 07-04 must treat this as its documented not-a-failure path
- `phase-07/bench/run_task.sh` — three bug fixes found while capturing this task's evidence (JOB_DIR race, `grep -c` double-print, `agent-command.txt` `trial.log` fallback)

## Decisions Made

- **`stop-at-one` selected at the blocking checkpoint.** Verbatim reasoning: the invocation shape (harbor's resolved command, provider-settings path, container env passthrough) is identical for every task in the live pool, so more runs would very likely reproduce the same structural `fail-infra` outcome rather than produce new passes or new information -- extra hours would buy repeated evidence of one known limitation, not more coverage. Full verbatim record: `phase-07/results/20260830T093515Z-smoke/decision.md`.
- **ROADMAP criterion 1 (5-8 tasks) is recorded as NOT MET**, exactly as the plan's own `stop-at-one` option cons text anticipated ("would be recorded as NOT met, with the reason and the user's decision quoted"). One task was run. This is not rounded up, not reframed, and not described as satisfying a 5-8 range anywhere in this summary or in `decision.md`.
- **The contextWindow/BASE_URL injection mechanism (07-02's `VERDICT: INJECTABLE`) does not take effect in harbor's real invocation shape.** It was source-derived only and never live-tested prior to this run. This live run is the first and only empirical test, and it falsified the mechanism taking effect for the exact `-P openai-compatible -k $API_KEY -m $MODELID --json --yolo` shape harbor's adapter uses. This is a durable, cross-phase finding: **Phase 8's manual must not describe cline-bench as having exercised this stack's model server** -- the one task that ran never reached flashnext.
- **No retry was attempted.** The diagnosis (Q3/Q1 in `ANALYSIS.md`) did not identify a simple corrected env value -- `$API_KEY`/`$MODELID` passthrough was independently confirmed working -- but a deeper mechanism gap, so a retry would very likely reproduce the identical result at the cost of another ~4 minutes. Per house rule ("if injection turns out not to work in practice, that is a legitimate finding... do not force it"), this was recorded as the finding rather than blindly repeated.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 -- bug] `run_task.sh` JOB_DIR resolution raced harbor's own job-directory creation**
- **Found during:** Task 1 (evidence capture for the smoke run)
- **Issue:** `-newermt` (BSD `find`, 1-second resolution) found nothing because harbor created its job directory in the same second `JOBS_MARKER_EPOCH` was captured, silently losing the whole `jobs/` copy.
- **Fix:** Switched to harbor's own lexicographically-sortable job-directory naming convention with a 30-second sanity buffer.
- **Files modified:** `phase-07/bench/run_task.sh`
- **Committed in:** `380e951` (Task 1)

**2. [Rule 1 -- bug] `grep -c ... || echo 0` double-printed "0" on zero matches**
- **Found during:** Task 1
- **Issue:** `grep -c` prints `0` but still exits 1 with no matches, so the `||` fallback printed a second `0`, producing a two-line `MODEL_TURN_COUNT` that corrupted the `meta.json` heredoc.
- **Fix:** Dropped `|| echo 0` in favor of `${VAR:-0}`.
- **Files modified:** `phase-07/bench/run_task.sh`
- **Committed in:** `380e951` (Task 1)

**3. [Rule 2 -- missing critical functionality] No fallback existed for `agent-command.txt` when harbor creates no `agent/command-*/` directory**
- **Found during:** Task 1 (this task's own `NonZeroAgentExitCodeError` trial proved the case is real, not theoretical)
- **Issue:** The plan's own success criteria require harbor's resolved command on disk and non-empty for any task, including failed ones.
- **Fix:** Added a `trial.log`-based fallback extractor (`sed -E` with POSIX alternation, after a first attempt using GNU-only `\|` alternation silently over-ran into the next command block on BSD `sed`).
- **Files modified:** `phase-07/bench/run_task.sh`
- **Committed in:** `380e951` (Task 1)

**4. [Rule 3 -- blocking issue, phase-03-owned file] `verify_sandbox.sh`'s SBX-04 P4 control run broke once this phase's run directory existed**
- **Found during:** Task 2 (post-run gate sweep)
- **Issue:** P4's unsandboxed control (`cat $BENCH_DIR/runs/*`) legitimately failed (`Is a directory`) once `bench/runs/20260830T093657Z-phase07/` (this plan's own required artifact) existed alongside `CANARY.txt` -- purely `cat`'s ordinary behavior on a directory argument, unrelated to sandbox enforcement, but it made `assert_denied.sh` bail before writing P4's evidence.
- **Fix:** P4's command changed to `find "$BENCH_DIR/runs" -type f -exec cat {} +`, asserting the identical claim ("every file under bench/runs/ is unreadable from inside the sandbox") but robust to subdirectories -- broader, not weaker.
- **Files modified:** `phase-03/sandbox/verify_sandbox.sh` (the one file outside `phase-07/` this plan touches)
- **Verification:** Re-verified live: `CASES 16/16`, `CRITERION 4 PASS`.
- **Committed in:** `c784e11` (Task 2)

---

**Total deviations:** 4 auto-fixed (2 Rule-1 bugs, 1 Rule-2 gap-fill, 1 Rule-3 blocking fix)
**Impact on plan:** All four were necessary for correctness or to unblock the standing-gate sweep; none touched a live service, host posture, or spent additional model/cline/harbor budget. No scope creep.

## Issues Encountered

- The smoke task's own evidence-capture path exposed three latent `run_task.sh` bugs (above) that would have blocked evidence capture for ANY `fail-infra`/zero-turn task, not just this one -- fixed and the already-completed run's evidence backfilled from the existing harbor job directory using the corrected logic, without a second `harbor run`.
- The injection mechanism 07-02 judged `INJECTABLE` from static source analysis alone did not take effect live. This was explicitly anticipated as a possible outcome by 07-02's own summary ("either outcome leaves 07-03's own contingency intact") and by this plan's own `<action>` text (pre-diagnosing the two failure shapes) -- it required careful, cited diagnosis rather than a fix, since fixing it live would require re-architecting how harbor's adapter resolves provider settings for this invocation shape, out of scope for a smoke-run analysis plan.

## User Setup Required

None -- no external service configuration required.

## Next Phase Readiness

- **07-04** must read `phase-07/bench/SELECTED_TASKS` and find it empty, and treat that as its documented `stop-at-one` / "not a failure of this plan" path (already anticipated in 07-04-PLAN.md's own `<action>` text) -- no further `harbor run` invocations, zero additional model spend.
- **07-05** (phase-close) must record ROADMAP criterion 1 as `NOT MET` (or the project's equivalent status label), quoting this decision, alongside whatever status criteria 2/3 receive once assessed against the one task that did run.
- **Phase 8's manual** must not describe cline-bench as exercising this stack's model server -- the one task that ran never reached flashnext. It may describe the pipeline mechanics (harbor invocation, evidence capture, verdict classification) as proven, but not that a real cline-bench task was observed running against this stack's own flashnext/litellm chain.
- Six live pids (46573/75548/48525/53894/99162/19669) and port 3000 (unbound) unchanged across Task 3 and the prior sweep. `EXTRA_ALLOW_PATHS` still empty. `bench/runs/CANARY.txt` still unreadable from inside the sandbox and unchanged in content. Zero further bench runs occurred in this task; zero model spend.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-30*
