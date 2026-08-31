---
phase: 04-headless-cli-wrapper
plan: 02
subsystem: cli
tags: [bash, cline, sandbox, ndjson, headless, wrapper]

# Dependency graph
requires:
  - phase: 04-headless-cli-wrapper
    provides: "04-01's classify_run.py six-outcome classifier, config.env's SANDBOX_WORKDIR derivation, and the five frozen fixtures under phase-04/fixtures/"
  - phase: 03-sandbox-repo-whitelist
    provides: "phase-03/sandbox/run_sandboxed.sh (the sanctioned sandbox entry point) and phase-03/sandbox/verify_sandbox.sh (the standing gate)"
  - phase: 01-headless-config-and-regression
    provides: "phase-01/config/verify_config.sh / apply_provider_config.sh (providers.json drift guard/heal) and phase-01/config/cline-invocation.env (CLINE_BIN/CLINE_COMMON_FLAGS/CLINE_PINNED_VERSION)"
provides:
  - "phase-04/run_headless.sh: the shipped one-shot headless cline wrapper (HLS-01/02/03) — one command, one prompt, NDJSON on stdout only, --auto-approve false hard-coded, cwd-fix applied and asserted, config/sandbox preflights, classify_run.py-based exit code"
  - "phase-04/results/<ts>-<pid>-headless/: real, committed evidence of one live sandboxed cline run (success, run_result present) plus one preserved crashed-harness-bug attempt for the record"
affects: [04-03-criterion3-verification, 04-04-phase-close]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "In-whitelist scratch-file capture for a sandboxed process's stdio, then copy-out-and-delete, whenever the destination results directory is itself outside the sandbox whitelist (reused verbatim from 03-04's validated fix for the same SIGABRT failure mode)"
    - "ORIG_PWD captured before any `cd`, used to resolve caller-relative env-var paths (DRY_FIXTURE) correctly even after the script itself changes its own working directory later"
    - "PID-suffixed results directory names ($(date)-$$-headless) to prevent same-wall-clock-second collisions between back-to-back invocations, while preserving *-headless glob matchability"

key-files:
  created:
    - phase-04/run_headless.sh
    - phase-04/results/20260829T214344Z-90746-headless/ (real live-run evidence, incl. README.md)
    - phase-04/results/20260829T214124Z-89595-headless-CRASHED-stdio-redirect/ (preserved crashed-attempt evidence, not counted toward the invocation budget)
  modified: []

key-decisions:
  - "The wrapper's stdout is reserved for NDJSON only under every mode (dry-run and live); all preflight/diagnostic output is redirected to stderr via tee-to-file-then->&2, never left on the wrapper's real stdout. Under HEADLESS_DRY=1 the fixture is copied straight to ndjson.log and never echoed to stdout at all, since classify_run.py reads the file, not stdout -- this also sidesteps crashed_truncated.ndjson's deliberately-invalid trailing line, which would otherwise have broken a naive 'echo the fixture to stdout' implementation under the plan's own 'every stdout line parses as JSON' check."
  - "A crash whose native stack trace shows only Node's own C++ bootstrap frames (node::InitializeOncePerProcessInternal / node::Start, no cline/Bun frame) does not count toward 'exactly one live cline invocation' -- same precedent 03-04 already established for the identical failure class. The first live attempt in this plan crashed this way and its evidence is preserved but excluded from the budget; the corrected second attempt is the one counted."
  - "Reused 03-04's exact fix for sandboxed-stdio-to-unpunched-path SIGABRT (in-whitelist scratch file capture, then copy-out-and-delete) rather than re-deriving a new mitigation, since the failure signature (exit 134, stack trace showing only node::InitializeOncePerProcessInternal/node::Start, empty ndjson.log) was byte-for-byte the same class already diagnosed in Phase 3."

# Metrics
duration: ~8min (git commit span, 5cf8c75 to 3083227)
completed: 2026-08-30
---

# Phase 4 Plan 2: Headless CLI Wrapper — Shipped Wrapper + Live Smoke Run Summary

**`phase-04/run_headless.sh`, the shipped headless `cline` wrapper (NDJSON-only stdout, `--auto-approve false` hard-coded, sandbox-only invocation path), proven end-to-end offline against all five frozen fixtures and then proven live: one real sandboxed `cline` task run, exit 0, classified `success`, model replied exactly "PONG".**

## Performance

- **Duration:** ~8 min (commit-to-commit span, `5cf8c75`→`3083227`; excludes upfront research/context reading)
- **Started:** 2026-08-30T06:37:33+09:00 (Task 1 commit)
- **Completed:** 2026-08-30T06:45:07+09:00 (Task 3 commit)
- **Tasks:** 3/3
- **Files modified:** 1 script created (`phase-04/run_headless.sh`, iterated across 4 commits as live testing surfaced real bugs) + 2 evidence directories created under `phase-04/results/`

## Accomplishments
- `phase-04/run_headless.sh`: one command, one prompt, one sandboxed `cline` run. `--auto-approve false` appears as literal adjacent tokens (criterion 2, HLS-02); `--auto-approve true` appears nowhere in the file. The only `$CLINE_BIN` invocation line also contains `run_sandboxed.sh` (HLS-03) — there is no unsandboxed cline call path anywhere in the script.
- The wrapper `cd`'s into `SANDBOX_WORKDIR` and asserts the resulting `$PWD` is a prefix match of `ALLOWED_REPOS.json`'s `repos[]` entry *before* ever invoking cline (04-RESEARCH.md Pitfall 1, THE CWD RULE) — proven live to actually prevent the inherited Phase 3 crash, not just theoretically.
- Header states the safe-but-inert-for-tool-use limitation plainly (`grep -ci inert` >= 1), points to 04-03's deliberately-different `--auto-approve true` TEST-ONLY script without ever naming that literal flag string itself, and states the never-widen-the-sandbox rule.
- All five `phase-04/fixtures/*.ndjson` fixtures replayed offline through the full capture→classify→exit-code pipeline with **zero cline invocations**, each producing its documented contract exit code (2/0/3/5/7), each writing `outcome.json`, and stdout proven empty (hence vacuously NDJSON-only) in every dry run. A dedicated negative control (non-whitelisted `SANDBOX_WORKDIR`) exits 1, names `ALLOWED_REPOS.json`, and never touches `npm install`.
- **One real, live sandboxed `cline` task run completed successfully**: `run_headless.sh --timeout 180 "Reply with exactly the word PONG..."` → wrapper exit 0, classifier outcome `success`, `run_result.finishReason:"completed"`, model text exactly `"PONG"`. This is the first time the actual `cline` binary completed a full task under Phase 3's sandbox — the blocker Phase 3 handed over is resolved live, not just researched. `EXTRA_ALLOW_PATHS` confirmed still empty; `git diff --stat phase-03/` confirmed empty.
- `cline` task invocations spent: **1** (hard cap 2). A first attempt crashed before any cline/Bun code ran (a harness plumbing bug, fixed, and — per 03-04's own established precedent for the identical failure signature — excluded from the invocation count).

## Task Commits

Each task was committed atomically (Task 1 and Task 2's live-testing pass required two follow-up bug-fix commits to `run_headless.sh` before Task 3 could produce a clean live run; Task 2 itself produced no committable artifact per the plan's own "do NOT commit /tmp artifacts" instruction):

1. **Task 1: Write phase-04/run_headless.sh** - `5cf8c75` (feat)
2. **Task 1 fix, found during Task 2's dry-run testing: relative DRY_FIXTURE resolved against the wrong cwd** - `305d8e7` (fix)
3. **Task 1 fix, found during Task 2's dry-run testing: same-second RESULTS_DIR collisions** - `df66610` (fix)
4. **Task 1 fix, found during Task 3's first live attempt: sandboxed stdio redirected to an unpunched path SIGABRT'd Node's bootstrap** - `3c8c115` (fix)
5. **Task 3: One live sandboxed run — criterion 1 evidence** - `3083227` (feat)

**Plan metadata:** (this commit, created after this summary)

## Files Created/Modified
- `phase-04/run_headless.sh` — the shipped wrapper. Header states the exit-code contract, the safe-but-inert limitation, THE CWD RULE, the pointer to 04-03's test-only script, and the never-widen-the-sandbox rule. Steps: source configs → results dir (PID-suffixed) → config guard → sandbox standing gate → cd+assert into SANDBOX_WORKDIR → dry-run-or-live run (stderr captured via an in-whitelist scratch file when live) → post-run config guard → classify_run.py, propagating its exit code.
- `phase-04/results/20260829T214344Z-90746-headless/` — the real live-run evidence: `ndjson.log` (10 lines, one `run_result`), `outcome.json`/`outcome.md` (`success`), `stderr.log` (clean AI-SDK deprecation warnings only, no crash), `config_pre.txt`/`config_post.txt` (the expected post-run heal cycle), `sandbox-gate/` (verify_sandbox.sh 16/16 PASS), `workdir.txt`, `npm_pin.txt`, and `README.md` documenting the exact command, outcome, the Task 2 dry-run summary, and the crashed-first-attempt story.
- `phase-04/results/20260829T214124Z-89595-headless-CRASHED-stdio-redirect/` — the first live attempt's preserved evidence (exit 134, empty `ndjson.log`, `stderr.log` containing only a native `node::InitializeOncePerProcessInternal`/`node::Start` C++ stack trace), kept for the record and explicitly excluded from the invocation budget per 03-04's precedent.

## Decisions Made
- Dry-run mode never echoes the fixture to the wrapper's real stdout — it only copies it to `ndjson.log`, which `classify_run.py` reads from disk. This keeps the "stdout is NDJSON-only" contract vacuously true for every dry run (including `crashed_truncated.ndjson`, whose deliberately truncated trailing line is not valid JSON by design) without needing any special-casing.
- Resolved `DRY_FIXTURE` (a relative path in every one of the plan's own example invocations) against `ORIG_PWD`, captured before the script's own `cd "$SANDBOX_WORKDIR"` — not against `PROJECT_ROOT` and not against the post-cd `$PWD`.
- Inserted `$$` (PID) into the results-directory timestamp (`$(date)-$$-headless`, keeping the `-headless` suffix last so existing `*-headless` glob patterns still match) after observing live, during Task 2's five-fixture loop, that two invocations in the same UTC second silently overwrote each other's evidence directory.
- Captured the live sandboxed process's stderr to a scratch file inside `$SANDBOX_WORKDIR` (already whitelisted) and copied it into `$RESULTS_DIR` afterward, rather than redirecting `2>` directly to a file under `$RESULTS_DIR` (outside the whitelist) — reused 03-04's exact validated fix for this exact SIGABRT failure mode instead of re-deriving one.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Relative `DRY_FIXTURE` path resolved against the wrong working directory**
- **Found during:** Task 2, first attempt at the five-fixture dry-run loop
- **Issue:** The wrapper's step 5 already `cd`'s into `SANDBOX_WORKDIR` before step 6 reads `DRY_FIXTURE`. A relative path (exactly the form every one of the plan's own example commands uses, e.g. `DRY_FIXTURE=phase-04/fixtures/sandbox_denied.ndjson`, run from the repo root) resolved against the post-cd sandbox working directory instead of the invocation cwd, so `cp` failed for every fixture with "No such file or directory" and every dry run aborted with wrapper exit 1 instead of its intended contract exit code.
- **Fix:** Captured `ORIG_PWD="$PWD"` at the very top of the script, before any `cd`, and resolved a non-absolute `DRY_FIXTURE` against it.
- **Files modified:** `phase-04/run_headless.sh`
- **Verification:** All five fixtures then matched their contract exit codes (2/0/3/5/7).
- **Committed in:** `305d8e7`

**2. [Rule 1 - Bug] Same-UTC-second invocations silently clobbered each other's results directory**
- **Found during:** Task 2, five-fixture dry-run loop (all five ran within the same wall-clock second)
- **Issue:** `RESULTS_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-headless"` has only second-level resolution. Back-to-back invocations landing in the same second reused the identical directory name, so only the last fixture's `ndjson.log`/`outcome.json` survived on disk (only 2 of 5 `outcome.json` files were found after the loop, though each run's own exit code was still individually correct since classification happens synchronously within each invocation before the next one starts).
- **Fix:** Inserted `$$` (the wrapper's own PID) into the directory name: `$(date -u +%Y%m%dT%H%M%SZ)-$$-headless` — placed before the `-headless` suffix so `ls phase-04/results/*-headless/...`-style glob patterns (used by this plan's own Task 3 verification) still match.
- **Files modified:** `phase-04/run_headless.sh`
- **Verification:** Re-ran the five-fixture loop; five distinct directories, five `outcome.json` files, all five exit codes still matched their contract values.
- **Committed in:** `df66610`

**3. [Rule 3 - Blocking] The sandboxed `cline` process's inherited stderr fd pointed at an unpunched path, SIGABRT'ing Node's own bootstrap before any cline/Bun code ran**
- **Found during:** Task 3, first live invocation
- **Issue:** `2>"$RESULTS_DIR/stderr.log"` (the plan's own literal step-6 command form) opens a regular file under `phase-04/results/` — outside `SANDBOX_WORKDIR`/`~/.cline`, i.e. an unpunched path — and the sandboxed `cline` process inherits that fd across `exec`. `cline`'s own `#!/usr/bin/env node` launcher's process bootstrap (`node::InitializeOncePerProcessInternal`) SIGABRTs the instant it touches a denied fd, before a single line of cline's/Bun's own code runs. Wrapper's first live attempt: exit 134, `ndjson.log` empty, `stderr.log` containing only a native C++ stack trace. Identical failure signature (and identical root cause) to 03-03's F8 finding and 03-04's own cline-smoke-test crash — a harness plumbing bug, not a sandbox or cline signal.
- **Fix:** Capture stderr to a scratch file inside `$SANDBOX_WORKDIR` (already whitelisted) instead, then `cp` the captured content into `$RESULTS_DIR/stderr.log` and delete the scratch file. stdout was already safe (piped through `tee`, no filesystem path involved for that fd). Reused 03-04's exact validated fix verbatim rather than re-deriving a new one.
- **Files modified:** `phase-04/run_headless.sh`
- **Verification:** The corrected retry produced exit 0, a real 10-line NDJSON stream with one `run_result` event, classifier outcome `success`. The crashed first attempt's evidence is preserved at `phase-04/results/20260829T214124Z-89595-headless-CRASHED-stdio-redirect/` for the record, per 03-04's precedent that a crash showing only Node's own C++ bootstrap frames in its native stack trace does not count toward the invocation budget (no cline/Bun code executed).
- **Committed in:** `3c8c115`

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs found during offline dry-run testing, 1 Rule 3 blocking issue found on the first live attempt — same root-cause class 03-04 already diagnosed and fixed in Phase 3, reused here rather than re-derived)
**Impact on plan:** All three fixes were necessary to get the plan's own literal test commands and live-run instructions to actually work as intended; none touched the sandbox boundary (`EXTRA_ALLOW_PATHS` unchanged, `phase-03/` unmodified throughout). No scope creep — every fix stayed inside `phase-04/run_headless.sh`, this plan's own owned file.

## Issues Encountered
- `phase-01/config/verify_config.sh` failed post-run (`models[] expected length 1, observed None`) after the live cline call, exactly as Phase 1's documented, live-reproduced Pitfall 5 predicts for any real `cline` invocation — healed via `apply_provider_config.sh` and re-verified PASS in the same run, per the plan's own instruction that this is expected, not a failure.
- `cline` was found installed at `3.0.60` (drifted from the pinned `3.0.53`) before this plan's live run began; the reinstall-then-launch chained command (`npm install -g cline@3.0.53 && ...`) restored the pin as designed, with no intervening manual `cline` call.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- `phase-04/run_headless.sh` is the shipped, criterion-1/2/3-relevant wrapper 04-03 and 04-04 can both build on: it never calls `--auto-approve true`, its only cline invocation path goes through `run_sandboxed.sh`, and it now carries three live-discovered, real-world-tested fixes (relative-path resolution, results-dir collision safety, in-whitelist stdio capture) that a from-scratch reimplementation would likely rediscover the hard way.
- The inherited Phase 3 Bun-startup blocker (04-RESEARCH.md Pitfall 1) is now confirmed resolved **live**, not just by research — 04-01 itself made zero cline calls, so this plan is the first actual live confirmation. `EXTRA_ALLOW_PATHS` remains empty; no sandbox artifact was touched.
- `cline` task invocations used by this plan: 1 (the phase's shared budget is 2 total across 04-02/04-03 combined — 04-03 was noted in the plan context as making zero cline calls of its own, so the phase-wide budget is well within bounds).
- Sibling plan 04-03 (`phase-04/verify_sandbox_via_cline.sh`, `phase-04/fixtures/` read-only) ran in parallel with this plan; file ownership boundaries were respected throughout (individual `git add` per commit, no `git add -A`/`.`, `phase-04/fixtures/` untouched — confirmed via `git log -- phase-04/fixtures/` showing only 04-01's commit).
- No blockers for 04-03/04-04.

---
*Phase: 04-headless-cli-wrapper*
*Completed: 2026-08-30*
