---
phase: 06-network-exposure
plan: 03
subsystem: infra
tags: [tailscale, network, json-assertion, rollback-proof, standing-gate]

# Dependency graph
requires:
  - phase: 06-network-exposure
    provides: "06-01's phase-06/net/config.env (TS_SERVE_PORT, TS_SERVE_ROLLBACK_CMD, TS_SERVE_SCRATCH_PORT) and expected_serve_baseline.json; 06-02's NET-04 guard in run_telegram_service.sh"
provides:
  - "phase-06/net/setup_tailscale_serve.sh -- fail-closed, idempotent writer for kanban's single tailnet-only Serve entry (--check/--apply), with the rollback pinned in its header and printed on every failure path"
  - "phase-06/net/verify_network.sh -- read-only, re-runnable 15-check standing gate covering NET-01 through NET-04, inherited by Phase 7/8"
  - "phase-06/results/20260830T055744Z-authoring/ -- offline self-validation evidence: check-mode no-op proof, gate negative control, two forced-failure probes, and rollback-syntax proof against the scratch port"
affects: [06-04, 06-05, 06-06, 07, 08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "single python3 -c JSON-comparator idiom (subset check on Web/TCP, exact check on AllowFunnel) duplicated deliberately across setup_tailscale_serve.sh's P4/Q2 and verify_network.sh's check 3, rather than factored into a shared file, to stay within the plan's declared two-file scope"
    - "needle-from-two-variables idiom for a self-policing repo grep (check 14), so the check's own source text never contains the adjacency it searches for"

key-files:
  created:
    - phase-06/net/setup_tailscale_serve.sh
    - phase-06/net/verify_network.sh
    - phase-06/results/20260830T055744Z-authoring/ (README.md, setup-check/, gate-closed/, forced-failure/c1-funnel-key/, forced-failure/c2-baseline/, rollback/)
  modified: []

key-decisions:
  - "setup_tailscale_serve.sh's pre-flight P4 and post-assertion Q2 use the SAME subset-match logic (baseline's three Web/TCP keys must be present and byte-identical; extra keys tolerated) but an EXACT match on AllowFunnel (zero tolerance, even before the kanban entry exists) -- this lets P6's idempotency check and Q3's baseline+1 count check each own their narrower slice without P4/Q2 rejecting a valid re-run"
  - "verify_network.sh check 10 (tailnet-no-passcode-gate) treats 'not yet reachable' as a PASS (reachability is check 9's job), so the log-banner assertion can run meaningfully both before and after 06-04 without becoming a third pre-entry FAIL and breaking Task 3 Step B's exact two-FAIL contract"
  - "check 12 (net04-guard-refuses) invokes run_telegram_service.sh directly, hard-bounded via `timeout 15`, mirroring 06-02's standalone negative-control invocation verbatim -- never through launchd, so the standing gate never risks disturbing the live telegram-connect service"

# Metrics
duration: 20min
completed: 2026-08-30
---

# Phase 6 Plan 3: Live-Action Scripts, Authored and Proven Offline Summary

**Wrote and offline-proved the two scripts that will open (`setup_tailscale_serve.sh`) and then police (`verify_network.sh`) kanban's Tailscale Serve exposure -- including a live scratch-port proof that the pinned, undocumented `serve --https=<port> off` rollback syntax is genuinely accepted by this tailscale version -- while changing zero real network state.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-08-30T05:40:00Z (approx, first context read)
- **Completed:** 2026-08-30T06:00:22Z
- **Tasks:** 3 completed
- **Files modified:** 2 new scripts + 15 evidence files under `phase-06/results/20260830T055744Z-authoring/`

## Accomplishments
- `phase-06/net/setup_tailscale_serve.sh` (355 lines): defaults to `--check` (prints the exact single command `--apply` would run, mutates nothing); `--apply` runs six pre-flight assertions (P1 tailscale reachable, P2 port not forbidden, P3 port 3000 unbound, P4 the fail-closed heart -- live config matches the frozen baseline exactly for the three pre-existing entries, P5 kanban loopback-bound and healthy, P6 idempotency short-circuit), then exactly one mutating command (`tailscale serve --bg --https=8444 http://127.0.0.1:3484`), then five post-assertions (Q1 no new public-exposure key -- "the single most important assertion in Phase 6", Q2 the three pre-existing handlers still byte-identical, Q3 the new handler present and the ONLY addition, Q4 port 3000 still unbound, Q5 kanban's bind unchanged). Any post-assertion failure exits 2 (inconclusive, never a pass) and prints the pinned rollback loudly.
- `phase-06/net/verify_network.sh` (472 lines): read-only, re-runnable, house-style `CHECK: PASS|FAIL` + 0/1/2 exit contract, 15 checks covering NET-01 (kanban-serve-entry-present, tailnet-https-200), NET-02 (kanban-bind-loopback-only, lan-refused-kanban-port, lan-refused-serve-port), NET-03 (port-3000-unbound), NET-04 (net04-guard-present static + net04-guard-refuses behavioural, run standalone never through launchd), the phase's overriding safety property (no-new-public-exposure), byte-identity of the three pre-existing handlers, repo-wide wildcard-bind and public-exposure-subcommand sweeps, and live-pid stability for the four upstream processes via an optional `--baseline <dir>`.
- Task 1's self-check caught a real latent bug before it ever reached the offline-proof stage: a `set +e ... set -e` toggle borrowed from house style silently re-enabled `errexit` for the rest of the script (the top-level `set -uo pipefail` never had `-e` to begin with), so the very next bare pipeline (`lsof | wc -l` on the expected-empty port 3000) aborted the script silently under `pipefail`. Fixed by removing every `set +e`/`set -e` pair and capturing `$?` directly, matching the "-e never active" baseline the file actually runs under.
- Task 3 formally proved, with evidence captured to `phase-06/results/20260830T055744Z-authoring/`: (A) `setup_tailscale_serve.sh --check` is a genuine no-op (serve-status before/after byte-identical); (B) `verify_network.sh` against the closed posture exits 1 with `CASES 13/15` and the FAIL-id set is EXACTLY `{kanban-serve-entry-present, tailnet-https-200}` -- proving the gate is a non-vacuous negative control; (C) both safety-critical checks (`no-new-public-exposure`, `preexisting-serve-entries-untouched`) genuinely FAIL when fed a bogus expectation via scoped env override / temp baseline copy, with the real config/baseline files confirmed untouched afterward; (D) the pinned rollback form, run for real against the confirmed-unclaimed scratch port 59999, was ACCEPTED as valid syntax and failed only with `"failed to remove web serve: handler does not exist"` (the success signal, not a parse error) -- `serve-before.json`/`serve-after.json` byte-identical, proving the three pre-existing handlers survived.

## Task Commits

1. **Task 1: Write setup_tailscale_serve.sh -- fail-closed, idempotent, one entry only** - `36fdb61` (feat)
2. **Task 2: Write verify_network.sh -- the standing Phase 6 gate** - `776f4b2` (feat)
3. **Task 3: Offline self-validation against the still-CLOSED posture** - `2ffbc20` (test)

_No separate metadata commit beyond these three task commits and this SUMMARY/STATE commit._

## Files Created/Modified
- `phase-06/net/setup_tailscale_serve.sh` - the ONE script that will ever add kanban's Serve entry; --check/--apply, six pre-flight assertions, one mutating command, five post-assertions, rollback pinned and printed on every failure path
- `phase-06/net/verify_network.sh` - Phase 6's standing 15-check network gate, inherited by Phase 7/8
- `phase-06/results/20260830T055744Z-authoring/README.md` - narrative tying all four self-validation steps together
- `phase-06/results/20260830T055744Z-authoring/setup-check/` - Step A: check-mode no-op proof (before/after serve-status.json, transcript)
- `phase-06/results/20260830T055744Z-authoring/gate-closed/` - Step B: the negative-control gate run against the closed posture
- `phase-06/results/20260830T055744Z-authoring/forced-failure/c1-funnel-key/`, `c2-baseline/` - Step C: the two forced-failure probes
- `phase-06/results/20260830T055744Z-authoring/rollback/` - Step D: scratch-port rollback-syntax proof (before/after JSON, stdout/stderr/exit code)

## Decisions Made
- **P4/Q2 subset-match vs. AllowFunnel exact-match, deliberately asymmetric**: the three pre-existing Web/TCP entries are checked as a subset (an already-applied kanban entry is tolerated, since P6/Q3 own that narrower question), but `AllowFunnel` is checked for EXACT equality even in P4 (pre-apply) -- no new public-exposure key is ever tolerated at any point, not even transiently.
- **verify_network.sh check 10's reachability-agnostic design**: rather than hard-failing when `$TS_SERVE_URL` is unreachable (which would make Task 3 Step B's negative control show THREE failing checks instead of exactly two), check 10 treats "no passcode banner in the log" as sufficient for a PASS when the URL isn't reachable yet, and additionally validates the response body once it is. This keeps the check genuinely meaningful (it still catches a real passcode-banner regression) without duplicating check 9's reachability assertion.
- **check 12 mirrors 06-02's standalone probe verbatim** (`timeout 15 env -u TELEGRAM_ALLOWED_USER_ID TELEGRAM_BOT_TOKEN="$NET04_PROBE_TOKEN" bash run_telegram_service.sh`), run directly rather than through launchd, so the standing gate can be re-run by Phase 7/8 indefinitely without ever touching the live telegram-connect service's supervision state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `set -e` silently re-enabled after the first `set +e`/`set -e` toggle in setup_tailscale_serve.sh**
- **Found during:** Task 1, first offline `--check` execution (the P3 pre-flight step vanished from the transcript with no error message and rc=1)
- **Issue:** The script's top-level `set -uo pipefail` never included `-e`. A `set +e; ...; set -e` toggle around the P1 `tailscale status` check (borrowed from `verify_services.sh`'s style) turned `errexit` ON for the rest of the script -- something `verify_services.sh` gets away with only because every subsequent risky command there happens to also be individually wrapped in its own `set +e`/`set -e` pair. My P3 check (`lsof -nP -iTCP:3000 | wc -l | tr -d ' '`) was NOT wrapped, so when `lsof` legitimately returned a non-zero exit (finding nothing bound -- the expected/good outcome) `pipefail` propagated that non-zero status into the now-active `errexit`, silently killing the script mid-pipeline before any abort message could print.
- **Fix:** Removed all eight `set +e`/`set -e` pairs from the script and captured `$?` directly after each fallible command instead, matching the "`-e` never active" baseline the file's own `set -uo pipefail` actually establishes. Bisected the failure with `bash -x`, a truncated-copy test, and explicit stderr markers before finding the root cause.
- **Files modified:** `phase-06/net/setup_tailscale_serve.sh`
- **Verification:** Default no-arg run and `--check` both now complete all six pre-flight assertions and exit 0; forced P2 (forbidden port) and P4 (corrupted baseline) failures both abort correctly with rc=1 and print the rollback; `bash -n` passes; live `tailscale serve status --json` confirmed byte-identical before/after every test run.
- **Committed in:** `36fdb61` (Task 1 commit -- caught and fixed before that commit was made; `verify_network.sh`, written afterward in Task 2, was authored without the toggle pattern from the start)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary for the script to function at all past its second pre-flight step. No scope creep -- fix was confined to removing a stylistic idiom that turned out to be unsafe without full-file bracketing discipline; no check's logic, ordering, or the plan's specified assertions changed.

## Issues Encountered
None beyond the deviation above, resolved within Task 1 before that task's commit.

## User Setup Required
None - no external service configuration required. Both scripts are authored and offline-proved only; the live `--apply` execution (the single riskiest action in this project) is 06-04's job, not this plan's.

## Next Phase Readiness

`phase-06/net/setup_tailscale_serve.sh` and `phase-06/net/verify_network.sh` are ready for 06-04 to run for real. The rollback form pinned in `phase-06/net/config.env` as `TS_SERVE_ROLLBACK_CMD` is now proven (not just documented) accepted by this tailscale version (1.96.4) -- 06-04 can trust it without re-deriving or re-testing it. `verify_network.sh` is ready for 06-04 to run before and after the live `--apply`, and for Phase 7/8 to inherit as their standing network gate (pass `--baseline phase-06/results/20260830T051403Z-baseline` for check 15 to be conclusive rather than INCONCLUSIVE).

No blockers. Zero Tailscale mutations against the real config occurred anywhere in this plan (the only live-mutating command run was Step D's single scratch-port probe against the confirmed-unclaimed port 59999, proven byte-for-byte to have changed nothing). Live pids (flashnext 46573, litellm 48525, kanban 53894, role-shim 75548, telegram-connect 99162) unchanged throughout; `pgrep -f 'connect telegram'` = 0; `verify_services.sh` re-confirmed 15/15 at plan end; port 3000 and 8444 both still unbound; `EXTRA_ALLOW_PATHS` empty; `cline` invocations this plan: 0; `git diff --stat phase-05/ phase-03/ phase-02/ phase-01/` empty.

---
*Phase: 06-network-exposure*
*Completed: 2026-08-30*
