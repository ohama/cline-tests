---
phase: 11-usage-surface-wrappers
plan: 03
subsystem: cli-wrappers
tags: [bash, cline-cli, mutation-testing, litellm-alias, config-guard, verify-config]

# Dependency graph
requires:
  - phase: 11-01
    provides: "phase-11/cline-plan and phase-11/cline-act (deny-by-default wrappers), phase-11/wrapper.env (single-source alias config), phase-11/testing/stub-cline (zero-cost argv capture), and the pre-wired VERIFY_CONFIG_NO_WRAPPER_CHECK=1 recursion brake in wrapper_common.sh's own pre-/post-run guard calls"
provides:
  - "phase-11/verify_wrappers.sh: static (Group A) + behavioural (Group B) checks that a wrapper set correctly pairs mode with alias and never leaks --thinking/-m to the real binary"
  - "phase-01/config/verify_config.sh extended with a wrapper section (exit 3), pure addition, zero deletions to the pre-existing providers.json guard"
  - "phase-04/run_headless.sh and phase-04/verify_sandbox_via_cline.sh guarded so a wrapper fault (exit 3) aborts with its own message instead of triggering the providers.json healing path"
  - "phase-11/selftest_verify_wrappers.sh: seeded-mutant proof harness, 9 rows (7 CAUGHT defects + 2 PASS controls), run against the real verify_config.sh"
affects: [phase-11 (11-04 wrapper-check proof / live alias check, 11-05 USE-03 A/B harness), phase-12 (USE-04 manual, USE-05 design-doc updates)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "two-layer wrapper verification: static content assertions (Group A, catches a wrong literal instantly) plus behavioural argv assertions against a stub binary (Group B, catches wrong behaviour behind a right-looking literal) — deliberately overlapping, not either/or"
    - "distinct exit codes (1 vs 3) to let a caller distinguish a providers.json fault from a wrapper fault without parsing message text"
    - "pure-addition diffs to a standing guard script: new sections inserted only immediately before an existing terminal `exit 0`, or before an `if !`-gated healing branch, so `git diff --numstat` shows zero deletions and the pre-existing behaviour is provably unchanged"
    - "temporary, non-committed instrumentation (a depth counter added and then reverted in the same session) to produce a measured proof of non-recursion, rather than leaving a permanent side-effecting counter in a script that runs before every headless invocation"
    - "mutation testing the standing guard, not just the new unit: seed defects into scratch temp-directory copies of the real wrapper set and assert the REAL verify_config.sh (the thing every caller actually invokes) exits non-zero, not the new sub-checker in isolation"

key-files:
  created:
    - phase-11/verify_wrappers.sh
    - phase-11/selftest_verify_wrappers.sh
    - phase-11/results/20260902T043511Z-wrapcheck/ (recursion-depth-counter.txt, recursion-depth-METHOD.txt, run_headless_smoke.stdout/stderr, wrapper-selftest.tsv, mutants/M1..M9.out, integration-row.txt)
    - phase-11/results/CURRENT_WRAPCHECK_RUN
  modified:
    - phase-01/config/verify_config.sh (+63 lines, 0 deletions)
    - phase-04/run_headless.sh (+8 lines, 0 deletions)
    - phase-04/verify_sandbox_via_cline.sh (+20 lines, 0 deletions)

key-decisions:
  - "The mode/alias mismatch and --thinking leak are properties of an INVOCATION, not of providers.json (Phase 10's own finding: cline -m leaves model at \"flashnext\" regardless of alias used) — so the new check inspects the wrapper SCRIPTS' literal content and their actually-captured argv, never providers.json"
  - "Group A's caller-argument-leak detector looks for a NAMED array [@]/[*] expansion in the construction region (e.g. \"${ORIG_ARGS[@]}\"), not for bare \"$@\" generally, because the real wrapper's legitimate mechanism re-uses bare \"$@\" throughout its own construction chain — a naive \"no $@ at all\" rule would have false-positived on the real, correct wrapper"
  - "Group A's bare-'cline'-invocation and caller-argument-leak checks are scoped to the extracted construction region only (from the first 'set --' through the \"$CMD\" invocation line), not the whole file, after an initial false positive: an unrelated stderr string (\"cline exited $CLINE_RC\") in wrapper_common.sh's post-run warning message matched a whole-file bareword search for 'cline'"
  - "Exit code 3 (wrapper fault) is deliberately distinct from exit 1 (providers.json fault) so phase-04's two call sites can refuse to run their healing/apply_provider_config.sh path on a wrapper fault, which would not fix it and would misreport the cause"
  - "Both Phase 4 call sites needed a PURE-ADDITION guard, not a rewritten conditional, to satisfy the zero-deletions backward-compatibility constraint: run_headless.sh already captured the real exit code via ${PIPESTATUS[0]}, so a single new `if [ \"$A_STATUS\" -eq 3 ]` line sufficed; verify_sandbox_via_cline.sh's `if ! \"$VERIFY_CONFIG\"; then` form inverts $? for its own branching (verified empirically: `if ! (exit 3); then echo $?; fi` prints 0, not 3) and cannot recover the real exit code without modifying that line, so a separate, additional invocation of verify_config.sh was added immediately before it instead"
  - "The recursion depth-counter instrumentation was added to verify_config.sh, run once, its result captured into phase-11/results/, and then reverted in the same session — not shipped — because a permanent counter-file side effect on a guard that runs before every headless invocation was judged worse than a one-time, well-documented measurement"
  - "M4 and M5 (thinking-leak, model-leak) share one seeded mutant directory (a wholesale-replaced wrapper_common.sh doing a naive \"$@\" passthrough) and are recorded as two TSV rows from the same verify_config.sh run, because phase-11/verify_wrappers.sh's Group B already probes both --thinking and -m in every invocation"

patterns-established:
  - "When extending a standing guard script under a strict zero-deletions constraint, prefer running the guarded command an extra time to recover an exit code the existing control-flow already discards (via `if !`), over restructuring the existing line, even though it costs a redundant invocation"
  - "A static leak-detector for 'no caller args reach the construction site' should target the SHAPE a leak necessarily takes (a named array's [@]/[*] expansion) rather than banning the legitimate mechanism's own recurring token (bare \"$@\") wholesale"

# Metrics
duration: ~55min
completed: 2026-09-02
---

# Phase 11 Plan 03: verify_config.sh Wrapper Guard + Mutant Proof Summary

**`verify_config.sh` now catches a mode/alias mismatch and a `--thinking`/`-m` leak by inspecting the wrapper scripts themselves (static content + real captured argv against a stub binary) rather than providers.json — proven by seeding seven real defects into scratch mutant copies and observing the real `verify_config.sh` exit 3 on each, while a clean control and a legitimately-reverted-alias control both still exit 0 in the same session, and both Phase 4 call sites now report the true cause instead of misdiagnosing a wrapper fault as a providers.json drift.**

## Performance

- **Duration:** ~55 min
- **Tasks:** 3/3 completed
- **Files created:** 2 scripts (`verify_wrappers.sh`, `selftest_verify_wrappers.sh`) + one results run directory
- **Files modified:** 3 (`verify_config.sh`, `run_headless.sh`, `verify_sandbox_via_cline.sh`), all pure additions (0 deletions each, confirmed via `git diff --numstat`)
- **Live model requests:** 0 (every wrapper execution went through `phase-11/testing/stub-cline`; the Phase 4 integration check used `HEADLESS_DRY=1`)

## Accomplishments

- `phase-11/verify_wrappers.sh`: Group A (static assertions on `cline-plan`/`cline-act`/`wrapper.env` content — mode-flag pairing, alias source, outcome-neutral alias membership, forbidden codex alias, absolute binary path, no bare `cline` invocation, no named-array caller-argument leak in the construction region) plus Group B (behavioural assertions on argv actually captured via the stub binary, including before/after byte-comparison for the `--thinking`/`-m` refusal cases). Exits 3, distinct from `verify_config.sh`'s own exit 1.
- `phase-01/config/verify_config.sh` extended with a wrapper section, inserted as a pure addition before the file's terminal `exit 0` — `git diff --numstat` shows 63 insertions, 0 deletions. `VERIFY_CONFIG_NO_WRAPPER_CHECK=1` and a non-default `PROVIDERS_JSON` both short-circuit it with a visible `SKIP[WRAPPER]:` line.
- `phase-04/run_headless.sh` (+8 lines) and `phase-04/verify_sandbox_via_cline.sh` (+20 lines) both gained an exit-3 guard at their pre-run and post-run config-guard call sites, each a pure addition (0 deletions), proven offline via `HEADLESS_DRY=1 SKIP_SANDBOX_GATE=1`.
- `phase-11/selftest_verify_wrappers.sh`: seeds M1–M7 (real defects) plus M8/M9 (positive controls) into scratch temp-directory copies of the real wrapper set, runs the real `phase-01/config/verify_config.sh` against each, and records all nine outcomes plus one integration row into `phase-11/results/20260902T043511Z-wrapcheck/wrapper-selftest.tsv`.

## Task Commits

1. **Task 1: phase-11/verify_wrappers.sh — static + behavioural wrapper checks** — `325526e` (feat)
2. **Task 2: Wire verify_wrappers.sh into verify_config.sh; guard Phase 4 call sites** — `41c106d` (feat)
3. **Task 3: selftest_verify_wrappers.sh — seed 9 mutants, observe real verify_config.sh** — `05e6333` (test)

_This document + the STATE.md update are committed together next, per the orchestrator's standard closing commit._

## Files Created/Modified

- `phase-11/verify_wrappers.sh` — the wrapper-pairing and `--thinking`-leak checker (Group A static + Group B behavioural), exit 0/3
- `phase-11/selftest_verify_wrappers.sh` — seeded-mutant proof harness against the real `verify_config.sh`
- `phase-01/config/verify_config.sh` — new wrapper section (pure addition), header doc updated to describe exit codes 1/3 and both new env knobs
- `phase-04/run_headless.sh` — exit-3 guard at both config-guard call sites (pure addition, uses the already-captured `${PIPESTATUS[0]}`)
- `phase-04/verify_sandbox_via_cline.sh` — exit-3 guard at both config-guard call sites (pure addition, via a separate `verify_config.sh` invocation since the existing `if !` form discards the real exit code)
- `phase-11/results/20260902T043511Z-wrapcheck/` — recursion-depth evidence, `run_headless.sh` dry-run smoke evidence, `wrapper-selftest.tsv`, per-mutant output captures, integration row
- `phase-11/results/CURRENT_WRAPCHECK_RUN` — pointer to the above

## Mutant Table (from `phase-11/results/20260902T043511Z-wrapcheck/wrapper-selftest.tsv`)

All nine rows were produced in a single run of `phase-11/selftest_verify_wrappers.sh` against the real `phase-01/config/verify_config.sh`, `WRAPPER_DIR` pointed at a scratch-temp mutant copy per row (never at `phase-11/` itself).

| Mutant | What changed | Exit | Verdict | Message excerpt |
|---|---|---|---|---|
| M1 alias-mismatch | `cline-plan`: `WRAPPER_ALIAS=$WRAPPER_PLAN_ALIAS` → `$WRAPPER_ACT_ALIAS` | 3 | **CAUGHT** | `FAIL[WRAPPER]: cline-plan does not set WRAPPER_ALIAS from $WRAPPER_PLAN_ALIAS — possible mode/alias mismatch (ROADMAP criterion 2)` (also independently caught by Group B's argv assertion, observed `-m flashnext-act` where `-m flashnext-plan` was expected) |
| M2 mode-flag-dropped | `cline-plan`: `WRAPPER_MODE_FLAG="-p"` → `""` | 3 | **CAUGHT** | `FAIL[WRAPPER]: cline-plan does not set WRAPPER_MODE_FLAG="-p" — mode/alias pairing broken (ROADMAP criterion 2)` |
| M3 mode-flag-added | `cline-act`: `WRAPPER_MODE_FLAG=""` → `"-p"` | 3 | **CAUGHT** | `FAIL[WRAPPER]: cline-act does not set WRAPPER_MODE_FLAG="" — mode/alias pairing broken (ROADMAP criterion 2)` |
| M4 thinking-leak | `wrapper_common.sh` wholesale-replaced with a naive `"$@"` passthrough | 3 | **CAUGHT** | `FAIL[WRAPPER]: cline-plan --thinking high 'wrapper-check' should exit non-zero and leave the stub argv file byte-unchanged (USE-02 --thinking leak check) — observed exit=0, byte-unchanged=no` — **also independently caught by Group A's static named-array-leak detector** in the same run (`... expands a named array with [@]/[*] — looks like a caller-argument passthrough leak`) |
| M5 model-leak | same mutant dir as M4, exercised with `-m flashnext` | 3 | **CAUGHT** | `FAIL[WRAPPER]: cline-plan -m flashnext 'wrapper-check' should exit non-zero and leave the stub argv file byte-unchanged (-m override rejection check) — observed exit=0, byte-unchanged=no` |
| M6 wrapper-deleted | `cline-plan` removed entirely | 3 | **CAUGHT** | `FAIL[WRAPPER]: required file missing: <mutant-dir>/cline-plan` (absence gate, not a skip) |
| M7 codex-alias | `wrapper.env`: `WRAPPER_ACT_ALIAS="flashnext-act"` → `"flashnext-codex"` | 3 | **CAUGHT** | `FAIL[WRAPPER]: wrapper.env: WRAPPER_ACT_ALIAS is 'flashnext-codex' — this alias has been measured to kill the model server; forbidden outright regardless of mode` — static check only, no invocation |
| M8 alias-reverted (POSITIVE CONTROL) | `wrapper.env`: `WRAPPER_PLAN_ALIAS="flashnext-plan"` → `"flashnext"` (USE-03's revert state) | 0 | **PASS** | `OK[WRAPPER]: all wrapper assertions passed` |
| M9 clean control | unmutated copy | 0 | **PASS** | `OK[WRAPPER]: all wrapper assertions passed` |

**Zero mutants MISSED.** No blind spot to record for this mechanism at this seeding depth.

**Integration row:** with the M4 mutant directory as `WRAPPER_DIR`, `HEADLESS_DRY=1 SKIP_SANDBOX_GATE=1 bash phase-04/run_headless.sh "smoke"` exited 1 and printed, verbatim:
```
ABORT: wrapper mode/alias check failed (verify_config.sh exit 3) — this is NOT a providers.json drift; healing would not help. See FAIL[WRAPPER] above.
```
with no occurrence of `providers.json still fails` anywhere in its output — confirming the call site reports the true cause.

## Recursion Proof

A temporary instrumentation block (not shipped) was added directly under `set -euo pipefail` in `phase-01/config/verify_config.sh`:
```sh
if [ -n "${VERIFY_DEPTH_COUNTER_FILE:-}" ]; then
  echo "entry pid=$$ $(date -u +%Y%m%dT%H%M%SZ)" >> "$VERIFY_DEPTH_COUNTER_FILE"
fi
```
Run once as `export VERIFY_DEPTH_COUNTER_FILE=<path>; bash phase-01/config/verify_config.sh` (the variable is exported so any descendant process that also executed `verify_config.sh` would inherit it and append its own line). **Observed: exactly one line was appended** (`phase-11/results/20260902T043511Z-wrapcheck/recursion-depth-counter.txt`), for one top-level invocation, completing in under 1 second (well under the 30s budget). The instrumentation was reverted immediately afterward — `phase-11/results/.../recursion-depth-METHOD.txt` records the full methodology and the mechanism: `phase-11/verify_wrappers.sh`'s Group B always invokes `cline-plan`/`cline-act` with `CLINE_WRAPPER_TEST=1`, and `wrapper_common.sh` skips its entire config-guard cycle (both pre- and post-run) whenever that variable is set, regardless of `VERIFY_CONFIG_NO_WRAPPER_CHECK` — so in this design, Group B's stub-backed calls never attempt to re-enter `verify_config.sh` at all. The depth-1 result is not the `VERIFY_CONFIG_NO_WRAPPER_CHECK` brake stopping a real recursion attempt; it is the `CLINE_WRAPPER_TEST=1` test-mode branch never attempting one in the first place. (The `VERIFY_CONFIG_NO_WRAPPER_CHECK` brake would matter only if Group B ever invoked the wrappers without `CLINE_WRAPPER_TEST=1`, which it does not, by design.)

## Backward-Compatibility Evidence

- `bash phase-01/config/verify_config.sh` exits 0; stdout still contains both original lines byte-identical: `OK: providers.json holds flashnext @ localhost:4000/v1, top-level contextWindow=29000, no models[] override, no codex alias` and `trigger = maxInputTokens x 0.9 = 26100 — PROVEN to fire: ...`, plus new `OK[WRAPPER]:` lines.
- `VERIFY_CONFIG_NO_WRAPPER_CHECK=1 bash phase-01/config/verify_config.sh` exits 0, prints `SKIP[WRAPPER]: wrapper check suppressed by VERIFY_CONFIG_NO_WRAPPER_CHECK=1`.
- `PROVIDERS_JSON=<scratch copy> bash phase-01/config/verify_config.sh` exits 0, prints `SKIP[WRAPPER]: wrapper check suppressed — PROVIDERS_JSON is set to a non-default path (...)`.
- `git diff --numstat`: `phase-01/config/verify_config.sh` 63/0, `phase-04/run_headless.sh` 8/0, `phase-04/verify_sandbox_via_cline.sh` 20/0 — zero deletions across all three modified files.
- `HEADLESS_DRY=1 SKIP_SANDBOX_GATE=1 bash phase-04/run_headless.sh "smoke"` exits 0, `RESULT: success`, stdout NDJSON-empty as documented for dry-run — completed normally without aborting at the config guard.

## Exit-Code Contract (added)

| Exit | Meaning |
|---|---|
| `0` | All assertions passed (both providers.json and, unless skipped, the wrapper section) |
| `1` | A providers.json assertion failed (unchanged from before this plan) |
| `3` | The wrapper mode/alias/`--thinking` check failed — distinct from `1` so a caller never misdiagnoses a wrapper fault as a providers.json drift |

## Decisions Made

- The check is about the wrappers, not providers.json — providers.json records neither the mode flag nor which alias a call used (Phase 10's own finding), so there is nothing in it to inspect after the fact for this class of defect.
- Group A's caller-argument-leak detector targets a *named* array `[@]`/`[*]` expansion (e.g. `${ORIG_ARGS[@]}`) rather than banning bare `"$@"` outright, because the real wrapper's legitimate construction chain re-uses bare `"$@"` at every step — a blanket ban would have false-positived on the correct, unmutated wrapper. Verified empirically against both the real construction region (zero matches) and a synthetic leaky snippet (one match) before relying on it.
- Both the bare-`cline`-invocation check and the caller-argument-leak check are scoped to the extracted construction region (from the first `set --` through the `"$CMD"` invocation line) rather than the whole file, after an early false positive: a whole-file search for the bareword `cline` matched an unrelated stderr string (`"WARNING[CONFIG]: cline exited $CLINE_RC..."`) in `wrapper_common.sh`'s own post-run guard message.
- Exit 3 is deliberately distinct from exit 1 so `phase-04/run_headless.sh` and `phase-04/verify_sandbox_via_cline.sh` can refuse their healing (`apply_provider_config.sh`) path on a wrapper fault, which would not fix anything and would misreport the cause.
- Both Phase 4 call-site guards had to be pure additions under the zero-deletions constraint. `run_headless.sh` already captured the real exit code via `${PIPESTATUS[0]}`, so a single new `if [ "$A_STATUS" -eq 3 ]` sufficed. `verify_sandbox_via_cline.sh` uses `if ! "$VERIFY_CONFIG"; then` for its own branching, and `$?` inside that `then` branch is the *negation's* result (0), not the original exit code — confirmed empirically (`if ! (exit 3); then echo $?; fi` prints `0`) — so recovering the real code without modifying that line required one additional, separate invocation of `verify_config.sh` immediately before it.
- The recursion depth-counter was deliberately temporary (added, measured, reverted in the same session) rather than shipped, to avoid leaving a permanent side-effecting counter-file write in a guard script that runs before every headless invocation.
- M4 and M5 share one seeded mutant directory and are reported as two TSV rows derived from the same `verify_config.sh` run, since Group B already probes both `--thinking` and `-m` on every invocation regardless of which one a caller is specifically interested in.

## Deviations from Plan

None that changed scope — all deviations below were within-task refinements made while implementing the plan's own specification, not additions to it.

### Auto-fixed Issues (Rule 1 — bugs found and fixed before they shipped)

**1. Whole-file bareword search for `cline` produced a false positive**
- **Found during:** Task 1, while validating the "no bare `cline` invocation" static check against the real, correct wrapper set before relying on it.
- **Issue:** A regex searching the entire `wrapper_common.sh` file for a standalone `cline` token matched `echo "WARNING[CONFIG]: cline exited $CLINE_RC, but the post-run config guard failed"` — a diagnostic string, not an invocation — which would have made the check FAIL against the real, unmutated wrapper.
- **Fix:** Scoped both the bare-`cline` check and the caller-argument-leak check to the extracted "construction region" (the small block from the first `set --` through the actual `"$CMD"` invocation line) instead of the whole file. Verified empirically: zero matches against the real construction region, one match against a synthetic leaky snippet.
- **Files modified:** `phase-11/verify_wrappers.sh` (part of Task 1's initial implementation, not a later patch — caught during development before the Task 1 commit).
- **Commit:** `325526e`

## User Setup Required

None — no external service configuration required. `WRAPPER_CHECK_ALIAS_LIVE=1` remains available as an opt-in, off-by-default live check against the gateway's own `/v1/models`, reserved for plan 11-04 Task 3 Part A0 to exercise exactly once.

## Next Phase Readiness

- `phase-11/verify_wrappers.sh` and its exit-3 contract are ready for plan 11-04 to exercise live (`WRAPPER_CHECK_ALIAS_LIVE=1`) exactly once, as named in this plan's own Task 1 header comment.
- `phase-01/config/verify_config.sh`'s new wrapper section, and both Phase 4 call sites' exit-3 guards, are in place and proven backward-compatible for any future plan that calls `verify_config.sh` or `run_headless.sh`/`verify_sandbox_via_cline.sh`.
- Stack state verified identical before and after this plan: `com.ohama.flashnext` (pid 46573) and `com.ohama.role-shim` (pid 75548) both still running under their original pids; port 3000 free; `providers.json` `model=flashnext`, `contextWindow=29000` unchanged; `~/llm-system/services/logs/flashnext.err` last modified 2026-09-01 (before this session started), 23359 lines, unchanged across the entire plan — zero live traffic.
- No blockers for 11-04 or 11-05.

---
*Phase: 11-usage-surface-wrappers*
*Completed: 2026-09-02*
