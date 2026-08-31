---
phase: 03-sandbox-repo-whitelist
plan: 01
subsystem: infra
tags: [sandbox-exec, seatbelt, sbpl, macos, whitelist, python, bash]

# Dependency graph
requires:
  - phase: 02-infra-hardening
    provides: "config.env house style (VAR=\"${VAR:-default}\" with heavy override-point comments), reused as the model for phase-03/sandbox/config.env"
provides:
  - "workspace/ALLOWED_REPOS.json — SBX-01 single source of truth for which repos the sandboxed agent may touch"
  - "phase-03/sandbox/gen_sandbox_profile.py — ALLOWED_REPOS.json -> sandbox.sb SBPL compiler with realpath canonicalization, existence validation, nesting rejection, and 11 passing unit tests"
  - "phase-03/sandbox/run_sandboxed.sh — the single public entry point Phase 4 will call: regenerate-then-exec sandbox-exec wrapper, fail-closed, exit code/stderr pass through unchanged"
  - "bench/runs/CANARY.txt — SBX-04 target string, deliberately outside the whitelist, already observed unreadable from inside the sandbox"
affects: [03-03-verify (wave 2, builds verify_sandbox.sh against this generator/wrapper), 04-headless-wrapper (calls run_sandboxed.sh directly)]

# Tech tracking
tech-stack:
  added: [sandbox-exec (macOS Seatbelt, OS-provided, no install), SBPL (version 1 dialect)]
  patterns:
    - "(allow default) + deny-root(subpath $HOME) + allow-punch-through(subpath <realpath>) SBPL profile shape — (deny default) was tried in research and rejected as SIGABRT-crash-prone"
    - "config.env sourced from every script, PROJECT_ROOT derived from the sourcing script's own location so it works from any cwd"
    - "regenerate-then-exec: no cached-profile code path anywhere, profile regenerated unconditionally on every invocation"
    - "fail closed: if profile generation fails, abort before running the wrapped command at all"

key-files:
  created:
    - phase-03/sandbox/config.env
    - phase-03/sandbox/gen_sandbox_profile.py
    - phase-03/sandbox/run_sandboxed.sh
    - phase-03/tests/test_gen_sandbox_profile.py
    - workspace/ALLOWED_REPOS.json
    - workspace/scratch-repo/README.md
    - bench/runs/CANARY.txt
  modified:
    - .gitignore

key-decisions:
  - "gen_sandbox_profile.py always punches through a built-in default Cline data dir (~/.cline, realpath'd) even when no --extra-allow is given, in addition to accepting explicit --extra-allow paths for callers (run_sandboxed.sh) that want to pass CLINE_DATA_DIR/EXTRA_ALLOW_PATHS explicitly — deduplicated by insertion order so passing the same path both ways is harmless"
  - "workspace/scratch-repo/ is gitignored (disposable sandbox working dir), but its README.md is still created on disk per the plan's files_modified list — it is not force-added to git, consistent with sandbox.sb and phase-03/fixtures/ also being generated/disposable and gitignored"

patterns-established:
  - "Pattern 1 from 03-RESEARCH.md (allow-default + deny-root + punch-through) is now a working, tested implementation, not just a research recommendation"
  - "Every path written into an SBPL profile must be realpath()'d before it reaches render_profile() — enforced by load_allowed_repos() and the CLI's --protected-root/--extra-allow handling, regression-guarded by TestCanonicalization"

# Metrics
duration: ~10min
completed: 2026-08-30
---

# Phase 3 Plan 01: Sandbox Whitelist Generator + Wrapper Summary

**Built and live-verified the ALLOWED_REPOS.json -> sandbox.sb SBPL compiler and the run_sandboxed.sh regenerate-then-exec wrapper, using the `(allow default)` + deny-`$HOME` + punch-through profile shape proven in 03-RESEARCH.md — bench/runs/CANARY.txt is already observably unreadable from inside the sandbox.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-08-30T04:58Z (approx, first task commit df088e2)
- **Completed:** 2026-08-30T05:02:41+09:00 (last task commit 925e9f9)
- **Tasks:** 3/3
- **Files modified:** 8 (7 created, 1 modified: .gitignore)

## Accomplishments
- `workspace/ALLOWED_REPOS.json` exists as the SBX-01 single source of truth (one entry: `workspace/scratch-repo`, repo root never listed)
- `gen_sandbox_profile.py` built test-first: 11 unit tests written and confirmed RED (module missing) before implementation, then GREEN after — covering exact profile text/ordering, wildcard-only forms, symlink canonicalization (the reproduced research bypass), validation failures (missing/file-not-dir/nested entries), prefix-boundary sanity, and the empty-repos-list fail-open guard
- `run_sandboxed.sh` built and live-verified against all 5 plan verify cases: `--dry-run` prints the exact command, unconditional regeneration confirmed by deleting and re-running, `bench/runs/CANARY.txt` denied with `Operation not permitted`, missing `ALLOWED_REPOS_JSON` fails closed with no output from the wrapped command, no `[ -f ... ]` cached-profile guard exists
- The generated profile was accepted by the real kernel (`sandbox-exec -f ... /bin/echo ok` → `ok`, exit 0), not just by the unit tests

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold the whitelist, the workspace, the bench tree, and the single config point** - `df088e2` (feat)
2. **Task 2: Test-first build of the ALLOWED_REPOS.json -> sandbox.sb generator** - `7092a0a` (feat, includes the test-first RED/GREEN cycle as one task-level commit since the task was not marked `tdd="true"`)
3. **Task 3: run_sandboxed.sh — the regenerate-then-exec wrapper Phase 4 will call** - `925e9f9` (feat)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified
- `phase-03/sandbox/config.env` - single override point for every phase-03 path; states the `$HOME`-only scope limitation verbatim in its header
- `workspace/ALLOWED_REPOS.json` - SBX-01 single source of truth, one entry, repo root never listed
- `workspace/scratch-repo/README.md` - default sandboxed working dir for Phase 4, intentionally empty/disposable (gitignored, not `git init`'d)
- `bench/runs/CANARY.txt` - SBX-04 target string, tracked (not gitignored) as a reproducible fixture
- `.gitignore` - added `workspace/sandbox.sb`, `workspace/scratch-repo/`, `phase-03/fixtures/`
- `phase-03/tests/test_gen_sandbox_profile.py` - 11 pytest/unittest cases, written before the implementation existed
- `phase-03/sandbox/gen_sandbox_profile.py` - `load_allowed_repos()` (realpath + validate + reject nesting), `render_profile()` (pure, deterministic), CLI with `--allowed-repos`/`--protected-root`/`--extra-allow`/`--out`/`--print-only`
- `phase-03/sandbox/run_sandboxed.sh` - regenerate-then-exec wrapper; header documents the Phase 4 interface, the scope limitation, and the `EXTRA_ALLOW_PATHS` widening point; `--dry-run` flag; fail-closed on generation failure

## Decisions Made
- Cline's own data dir (`~/.cline`, realpath'd) is punched through by the generator's CLI unconditionally (a built-in default), on top of accepting explicit `--extra-allow` entries — this satisfies both Task 2's verify command (no `--extra-allow` flag, `.cline` line still expected in output) and Task 3's wrapper (which additionally passes `--extra-allow "$CLINE_DATA_DIR"` explicitly so an overridden `CLINE_DATA_DIR` in config.env is still honored). Duplicate paths are deduplicated by insertion order before rendering, so passing the same path both ways produces no duplicate SBPL rules.
- `workspace/scratch-repo/README.md` is created on disk (per the plan's `files_modified` list) but not committed to git, since `workspace/scratch-repo/` is gitignored by design (disposable sandbox working directory, same treatment as the generated `sandbox.sb`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] gen_sandbox_profile.py crashed with an unhandled traceback instead of failing cleanly when ALLOWED_REPOS.json itself is missing/unparseable**
- **Found during:** Task 3, exercising `run_sandboxed.sh`'s fail-closed verify case (`ALLOWED_REPOS_JSON=/nonexistent.json run_sandboxed.sh -- /bin/echo should-not-run`)
- **Issue:** `load_allowed_repos()` only handled invalid *entries* inside a valid JSON file (missing dir, file-not-dir, nesting) with a clean `SystemExit`. It did not handle the JSON file itself being missing or malformed — that path raised an unhandled `FileNotFoundError`/`JSONDecodeError`, printing a Python traceback to stderr instead of a clean message. `run_sandboxed.sh` still aborted correctly either way (fail-closed behavior itself was not broken — the wrapped command was never run and no output leaked), but the diagnostic was noisy and inconsistent with every other validation path in the same function.
- **Fix:** Wrapped the `open()`/`json.load()` call in `load_allowed_repos()` in a try/except, converting `FileNotFoundError` and `json.JSONDecodeError` into the same clean `sys.exit(<message naming the path>)` pattern used elsewhere in the function.
- **Files modified:** `phase-03/sandbox/gen_sandbox_profile.py`
- **Verification:** All 11 unit tests still pass; re-ran the fail-closed live check — now prints `ALLOWED_REPOS.json not found at '/nonexistent.json' -- refusing to emit a profile` followed by the wrapper's own `aborting (fail closed, command NOT run)` message, exit 1, no `should-not-run` output.
- **Committed in:** `925e9f9` (Task 3 commit, since it was found while verifying Task 3's test case; documented in that commit message)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Pure robustness/diagnostics fix; fail-closed behavior was already correct before the fix, only the error message quality changed. No scope creep.

## Issues Encountered
- macOS `/bin/bash` 3.2's `set -u` treats `"${ARR[@]}"` on a genuinely empty indexed array as an unbound-variable error (unlike bash 4+). Hit this immediately on the first `--dry-run` test of `run_sandboxed.sh` with an empty `EXTRA_ALLOW_ARGS` array. Fixed by using the `"${EXTRA_ALLOW_ARGS[@]+"${EXTRA_ALLOW_ARGS[@]}"}"` parameter-expansion idiom, which is bash-3.2-safe (this is a portability fix within Task 3's own first-attempt implementation, not a deviation from the plan — the plan already flagged bash 3.2 as a constraint to design around).
- `sandbox-exec`'s own arg parsing (not documented in its man page, which shows no `--` separator) was empirically confirmed to honor `--` as an options-terminator via a live test before relying on it in `run_sandboxed.sh` — `sandbox-exec -f <profile> -- /bin/echo hello` behaves identically to the form without `--`, confirmed with an argument-printing script that showed no stray `--` reaching the wrapped command's argv.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 03-02 (parallel, fixtures/probe/assert-denied) and this plan's deliverables are both in place; wave 2 (plan 03-03, `verify_sandbox.sh`) can now compile a real profile via `gen_sandbox_profile.py` and exercise `run_sandboxed.sh` against 03-02's fixtures.
- Phase 4's headless wrapper can call `phase-03/sandbox/run_sandboxed.sh -- <command> [args...]` directly today — the interface is documented in the script's own header and is stable.
- No blockers. One open item carried forward (not a blocker for this plan): the real `cline` binary itself has not yet been smoke-tested under this sandbox — 03-RESEARCH.md Open Question 1 explicitly defers that one-time check to a later plan (budgeted, not skipped), consistent with this plan's instruction not to invoke `cline` at all.

---
*Phase: 03-sandbox-repo-whitelist*
*Completed: 2026-08-30*
