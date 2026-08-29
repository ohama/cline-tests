---
phase: 03-sandbox-repo-whitelist
plan: 03
subsystem: testing
tags: [sandbox-exec, seatbelt, macos, security-testing, node, bash, python, standing-gate]

# Dependency graph
requires:
  - phase: 03-sandbox-repo-whitelist (plan 03-01, wave 1)
    provides: "workspace/ALLOWED_REPOS.json, gen_sandbox_profile.py, run_sandboxed.sh"
  - phase: 03-sandbox-repo-whitelist (plan 03-02, wave 1)
    provides: "make_fixtures.sh, assert_denied.sh, probe_fs.js"
provides:
  - "phase-03/sandbox/verify_sandbox.sh — the standing Phase 3 gate, re-runnable, read-only, 0/1/2 exit contract, one PASS/FAIL line per ROADMAP criterion"
  - "gen_sandbox_profile.py --no-canonicalize — test-only debug flag proving the canonicalization step is load-bearing and its removal is caught"
  - "Two independent real evidence runs against workspace/ALLOWED_REPOS.json (phase-03/results/20260829T202043Z-sbx/, .../20260829T202048Z-sbx/) plus a negative-control run proving the gate itself can fail (phase-03/results/20260829T201927Z-negative-control/)"
affects: [03-04 (cline smoke test + docs/sandbox-whitelist.md + phase-close revalidation should call verify_sandbox.sh), 04-headless-wrapper, 05-kanban-telegram, 06-network-exposure, 07-cline-bench (all should call verify_sandbox.sh before trusting run_sandboxed.sh)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "verify_sandbox.sh mirrors phase-02/infra/verify_no_regression.sh's house style: read-only, re-runnable, timestamped results dir, PASS/FAIL verdict file, 0/1/2 exit contract"
    - "Profile sanity pre-check (fail-open guard) runs on BOTH generated profiles before ANY case, aborting the whole run rather than letting a lost deny-root rule make every allow case pass for the wrong reason"
    - "Every allow/deny judgement routes through assert_denied.sh (13 direct invocations) or, for the one multi-assertion probe case (F8), through probe_fs.js's own DENIED/ERROR/SUCCEEDED text — never a bare exit code"
    - "Criterion-1 ancestor check direction is load-bearing: realpath(BENCH_DIR) must not equal or start-with realpath(entry)+os.sep for any whitelist entry (catches 'whitelisted the repo root', not the harmless reverse case)"
    - "Negative-control mode is a structurally separate code path (early exit before Group P), with its own inverted PASS/FAIL semantics, never sharing state with the normal run"
---

# Phase 3 Plan 03: verify_sandbox.sh Standing Gate Summary

**Wired 03-01's generator/wrapper to 03-02's assert_denied.sh/probe_fs.js into `phase-03/sandbox/verify_sandbox.sh`, a re-runnable gate that proved all four ROADMAP Phase 3 criteria PASS twice in a row against the real `workspace/ALLOWED_REPOS.json`, then proved itself falsifiable via three separate negative controls (deny-less profile, precheck-bypassed deny-less profile, and a `--no-canonicalize` symlink-bypass regression) — all before any `cline` invocation or launchd mutation.**

## Performance

- **Duration:** ~16 min
- **Started:** 2026-08-30T05:06Z (approx, wave 1 completion)
- **Completed:** 2026-08-30T05:22:04+09:00 (last commit `4d64f09`)
- **Tasks:** 3/3
- **Files modified:** 3 code files (1 created, 2 modified) + 61 evidence files across 3 results directories

## Accomplishments
- `verify_sandbox.sh` runs end-to-end against both a fixture profile (Group F, 8 cases) and the real production profile (Group P, 6 cases), delegating every allow/deny judgement to `assert_denied.sh` (13 direct calls) or `probe_fs.js`'s own text output (case F8) — confirmed by `grep -c 'assert_denied.sh'` = 20 and an empty result from the plan's bare-exit-code anti-pattern grep
- Profile sanity pre-check (fail-open guard) implemented and exercised on both profiles before any case runs
- Criterion 1's ancestor check implemented in the corrected direction (catches "whitelisted the repo root", not the harmless reverse) and live-verified PASS against the real `ALLOWED_REPOS.json`
- F6 (the canonicalization regression fixture) and F5 (the prefix-trap sibling) are asserted on every run, not just once, matching the plan's must-have
- Two full, independent, back-to-back real runs against `workspace/ALLOWED_REPOS.json`: both exit 0, both print identical four `CRITERION ... PASS` lines, 16/16 cases, 0 CRASHED, and a canary-content grep sweep confirmed the string `SBX04-CANARY-MUST-NOT-BE-READABLE-FROM-INSIDE-SANDBOX` appears in no captured sandboxed stdout in either run
- `launchctl print gui/$UID/com.ohama.flashnext` checked before and after the whole plan: same pid (46573) throughout — no service restart, no `cline` invocation anywhere in this plan
- Three negative controls archived, each showing the verifier genuinely failing as designed: profile pre-check rejects a deny-less profile; with the pre-check bypassed, every Group F deny case individually reports `FAIL not-denied`; and `F6` fails when `gen_sandbox_profile.py --no-canonicalize` reproduces the exact symlink-spelling bypass 03-RESEARCH.md found

## Task Commits

Each task was committed atomically:

1. **Task 1: verify_sandbox.sh — the standing gate covering criteria 1-4** - `029b809` (feat)
2. **Task 2: Negative control — prove the verifier can detect a fail-open sandbox** - `13cf27d` (feat)
3. **Task 3: Run the gate for real and record the phase evidence** - `4d64f09` (docs)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified
- `phase-03/sandbox/verify_sandbox.sh` - the standing Phase 3 gate: profile generation + sanity pre-check, Group F (8 cases against a fixture profile) + Group P (6 cases against the real production profile), F8's `probe_fs.js` run, criterion-1 Python check, verdict output, `--negative-control`/`--negative-control-skip-precheck` modes
- `phase-03/sandbox/gen_sandbox_profile.py` - added `--no-canonicalize` (TEST-ONLY debug flag, documented in its own header and `--help`); `load_allowed_repos()`/`_validate_extra_allow()` now accept a `resolve=` callable defaulting to `os.path.realpath` so existing callers/tests are unaffected
- `phase-03/results/20260829T202043Z-sbx/` - primary real evidence run: verdict, both `.sb` profiles, 13 per-case `assert_denied.sh` transcripts, `probe-sandboxed.txt`, fixture manifest, and a `README.md` mapping each ROADMAP criterion to its proving case IDs with quoted real kernel denial messages
- `phase-03/results/20260829T202048Z-sbx/` - the second, independent re-run (re-runnability confirmation), same full evidence set
- `phase-03/results/20260829T201927Z-negative-control/` - three archived controls (`control-1-precheck.txt`, `control-2-skip-precheck.txt`, `control-3-canonicalization.txt`) plus per-run evidence subdirectories and a `README.md` explaining why a Phase 3 verification without these controls would be unfalsifiable

## Decisions Made
- Chose direct `assert_denied.sh` invocations at each of the 13 call sites over a shared `run_case()` wrapper function, specifically so the literal string `assert_denied.sh` appears once per case in the script — this was a deliberate correction after an initial wrapper-function draft passed the *intent* of "every judgement delegated to assert_denied.sh" but only produced 5 literal matches against the plan's own `grep -c assert_denied.sh >= 12` verification command. Case bookkeeping (`record_case`) stays a tiny shared helper since it does no allow/deny judging itself.
- F8's `probe_fs.js` invocation required two live-reproduced workarounds, neither of which weakens the DENIED/ERROR/SUCCEEDED discrimination itself (see Deviations below for the full root-cause writeup): (a) capture via command-substitution pipe instead of redirecting to a file under an unpunched path, and (b) copy `probe_fs.js` into the fixture's already-punched-through `$FX/allowed/` for the duration of the case, plus `--preserve-symlinks-main`, so Node can load and run at all under a profile that (correctly) does not punch through `phase-03/sandbox/`.
- Negative-control mode is a structurally separate branch that exits before ever reaching Group P or the production profile — kept this way so a negative-control run can never accidentally contaminate or be confused with a real evidence run's `sbx-verdict.txt`.
- `--no-canonicalize` resolves via a `resolve=` parameter threaded through `load_allowed_repos()`/`_validate_extra_allow()` rather than a module-global flag, keeping `render_profile()` (the pure, exactly-tested function) completely untouched.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] F8's live sandboxed Node invocation crashed with SIGABRT / MODULE_NOT_FOUND as literally specified in the plan**
- **Found during:** Task 1, first live run of `verify_sandbox.sh`
- **Issue:** Two distinct, live-reproduced environmental blockers prevented the plan's literal F8 command (`sandbox-exec -f fixture.sb ... node phase-03/sandbox/probe_fs.js > "$OUT_DIR/probe-sandboxed.txt"`) from ever completing: (a) redirecting the sandboxed process's stdout/stderr directly to a file under `$OUT_DIR` (which lives under `$HOME/.../phase-03/results/`, not punched through by the fixture profile) crashed Node with `SIGABRT` during its own native startup (`node::InitializeOncePerProcessInternal`), confirmed reproducible 100% of the time and confirmed to disappear the instant the same command captured output via a pipe/command-substitution instead of a named file path; (b) even with the crash fixed, plain `node <path>` could not read its own entry script at all (`phase-03/sandbox/` is correctly NOT in the fixture profile's punch-through list — it was never supposed to be), and Node's default module-resolution `realpath()` walk additionally `lstat()`s every ancestor directory up to `/`, including `$HOME` itself, which is denied metadata access outside the specific punched-through subpaths (`EPERM lstat '/Users/ohama'`).
- **Fix:** (a) Capture F8's output via `"$(...)"` command substitution (no named filesystem path touched by the child process) and write the captured text to `$PROBE_OUT` afterward, from the unsandboxed parent. (b) Copy `probe_fs.js` into the fixture's already-punched-through `$FX/allowed/` for the duration of the case (removed immediately after), and pass `node --preserve-symlinks-main` so Node skips the ancestor-lstat'ing realpath resolution of the main script. Neither fix touches the DENIED/ERROR/SUCCEEDED classification logic in `probe_fs.js` itself or weakens what F8 proves (SBX-02/SBX-03 collapse) — both are pure plumbing so Node can start at all under a correctly-scoped profile.
- **Files modified:** `phase-03/sandbox/verify_sandbox.sh`
- **Verification:** F8 now passes reliably (7/7 checks correct) across all runs in this plan, including both real production runs and the initial self-check; the fix is documented inline in the script's own F8 section comment for future readers.
- **Committed in:** `029b809` (Task 1 commit — found and fixed before the commit was made)

---

**Total deviations:** 1 auto-fixed (1 blocking issue, two related root causes)
**Impact on plan:** Required to make the plan's own F8 case runnable at all in this environment; no weakening of any assertion, no scope creep. All other 12 cases plus both negative-control runs behaved exactly as the plan specified with no changes needed.

## Issues Encountered
- The plan's Task 1 verify command (`grep -n 'assert_denied.sh' ... | wc -l` >= 12) revealed, during self-testing, that a first-draft `run_case()` wrapper function — while satisfying the *intent* of "every judgement delegated to assert_denied.sh" — only produced 5 literal string matches. Refactored to 13 direct `"$SCRIPT_DIR/assert_denied.sh"` invocations (one per case) before the Task 1 commit; this is reflected in the script as written, not a deviation requiring separate documentation since it was caught and fixed pre-commit during normal verify-step execution.
- Investigated the F8 crash with five successive isolated repros (relative vs. absolute profile path, redirect-to-`/tmp` vs. redirect-to-repo-under-`$HOME`, with/without `--preserve-symlinks-main`, with/without a punched-through script copy) before landing on the combined fix — documented above as the one auto-fixed deviation.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `phase-03/sandbox/verify_sandbox.sh` is complete and is the standing Phase 3 gate: Phases 4, 5, 6, and 7 should call it (with no arguments, landing in a fresh timestamped `phase-03/results/` directory) before trusting `run_sandboxed.sh`, exactly as `phase-02/infra/verify_no_regression.sh` is called by later phases for INF-03.
- Plan 03-04 (the single budgeted `cline` smoke test + `docs/sandbox-whitelist.md` + phase-close revalidation) can now run `verify_sandbox.sh` as its own pre-flight check before spending the one live `cline` invocation this phase's plans have deliberately deferred throughout.
- `gen_sandbox_profile.py --no-canonicalize` exists only as a test-only debug flag exercised by `verify_sandbox.sh`'s negative control; `run_sandboxed.sh` (03-01's artifact) was not touched and never passes it.
- No blockers. All four ROADMAP Phase 3 success criteria (SBX-01..04) are proven true simultaneously by two independent real runs, and the standing gate itself has been proven capable of failing (not just of passing) via three separate negative controls — satisfying 03-RESEARCH.md Pitfall 5's requirement that a fail-open sandbox not be an invisible failure mode.

---
*Phase: 03-sandbox-repo-whitelist*
*Completed: 2026-08-30*
