---
phase: 06-network-exposure
plan: 04
subsystem: infra
tags: [tailscale, network, kanban, host-header, blocked]

# Dependency graph
requires:
  - phase: 06-network-exposure
    provides: "06-01's frozen expected_serve_baseline.json + config.env; 06-03's setup_tailscale_serve.sh (--check/--apply) and verify_network.sh (the 15-check standing gate)"
provides:
  - "Live proof that setup_tailscale_serve.sh's apply mechanics are correct: exactly one Serve entry was added, all Q1-Q5 post-assertions and independent re-verification passed, and the pinned rollback (`serve --https=8444 off`) was proven to restore the live config byte-identically under real (not scratch-port) conditions."
  - "A newly-discovered, previously-unknown blocker: kanban's own compiled application code (getAllowedHostHeaders() in dist/cli.js) rejects any Host header other than localhost/127.0.0.1 while loopback-bound, with no CLI flag or env var to widen it, and tailscale serve (this version) has no Host-rewrite option -- so the tailnet hostname is functionally unreachable through this reverse-proxy shape today."
  - "phase-06/results/20260830T060638Z-opening/README.md -- full diagnosis, evidence, and three unresolved architecture options for a human to choose among."
affects: [06-05, 06-06, 07, 08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "diagnose-then-rollback under fire: when a live post-apply gate FAILs, do NOT attempt to fix the open network in place -- run the pinned rollback immediately, confirm byte-identical restoration, THEN diagnose the root cause read-only against the (now closed) system's static artifacts (kanban's own compiled JS, `--help` output) rather than by further live experimentation on an open network"

key-files:
  created:
    - "phase-06/results/20260830T060638Z-opening/ (README.md, apply/, precheck/, gate-services-before/, gate-network/, gate-network-postrollback/, rollback/, gate-services-after-rollback/, gate-no-regression-after-rollback/, gate-sandbox-after-rollback/, serve-before.json, serve-after.json, serve-after.txt, serve-diff.txt)"
  modified: []

key-decisions:
  - "On verify_network.sh's tailnet-https-200 check FAILing (HTTP 403 instead of 200), rolled back immediately per the plan's explicit instruction and the house-rules reminder, rather than attempting any live fix -- the available fixes (a Host-rewriting proxy layer, or changing kanban's --host which would also flip its passcode gate) are architecture decisions, not bugs, and the plan explicitly reserves architecture decisions for a human (deviation Rule 4)."
  - "Diagnosed the root cause by reading kanban's already-installed compiled cli.js and tailscale serve --help output -- both read-only operations against static, already-present artifacts -- rather than by further live experimentation against the open network, to keep the exposure window as short as possible (approximately 90 seconds, apply to rollback)."

# Metrics
duration: 35min
completed: 2026-08-30
---

# Phase 6 Plan 4: The Opening -- Attempted, Blocked by kanban's Own Host-Allowlist, Rolled Back Summary

**Opened the single planned Tailscale Serve entry for ~90 seconds, proved its mechanics are exactly correct, discovered that kanban's own compiled code rejects every request that arrives with a non-loopback Host header (HTTP 403 `Host not allowed.`), and rolled back to the byte-identical closed baseline rather than improvising an architecture fix live.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-08-30T06:06:00Z (approx)
- **Completed:** 2026-08-30T06:13:35Z
- **Tasks:** 1 of 3 completed as planned (Task 1); Task 2 attempted and correctly aborted per plan instructions; Task 3 not reached (contingent on Task 2 passing)
- **Files modified:** 0 source files; 1 new results directory (`phase-06/results/20260830T060638Z-opening/`, ~37 evidence files) + this SUMMARY

## Accomplishments
- **Task 1 fully succeeded and is committed.** Re-confirmed live posture immediately before mutating anything (`setup_tailscale_serve.sh --check` exit 0, ports 3000/8444 unbound, `verify_services.sh` 15/15, live serve-status content-equal to the frozen baseline), then applied exactly one command (`tailscale serve --bg --https=8444 http://127.0.0.1:3484`) via `setup_tailscale_serve.sh --apply`, exit 0. Independently (not relying on the script's own Q1-Q5) re-verified: `AllowFunnel` still exactly the one pre-existing `:8443` key; `Web` exactly 4 handlers (3 frozen byte-identical + the new `:8444` entry); `TCP` exactly 4 keys; a diff of before/after JSON showed only additions for port 8444; kanban's own bind (`127.0.0.1:3484`), pid (53894), and port-3000-unbound status were all confirmed unchanged.
- **Task 2 correctly discovered a real, previously-unknown blocker and responded exactly as the plan required.** `verify_network.sh` against the freshly-opened network FAILed (`CASES 13/15`): `tailnet-https-200` returned HTTP 403 with body `{"error":"Host not allowed."}` instead of 200. Diagnosed (read-only) that this is kanban's own application code, not a Tailscale or script bug: curling `127.0.0.1:3484` directly with the tailnet Host header reproduced the identical 403; reading kanban's compiled `dist/cli.js` showed `getAllowedHostHeaders()` hardcodes `{localhost:<port>, 127.0.0.1:<port>}` whenever kanban is loopback-bound, with no flag or env var to widen it; `tailscale serve --help` (this version) confirmed there is no Host-rewrite option on the proxy side either. Per the plan's explicit "do not iterate on the open network...roll back...report" instruction, ran the pinned rollback (`tailscale serve --https=8444 off`) immediately -- total time the network was open was approximately 90 seconds.
- **Rollback verified byte-identical.** Post-rollback `serve-status --json` is byte-for-byte identical to the pre-apply capture and content-equal to `expected_serve_baseline.json` on `Web`/`TCP`/`AllowFunnel`; port 8444 confirmed unbound again; port 3000 confirmed still unbound throughout; kanban's bind and pid (53894) unchanged. `verify_network.sh` re-run post-rollback reproduces the exact `CASES 13/15` negative-control signature 06-03 Task 3 Step B already established for the closed state -- confirming a return to the known-good closed posture, not some new/different one.
- **Full post-rollback standing-gate sweep, all PASS:** `verify_services.sh` 15/15, `verify_no_regression.sh` INF03:PASS, `verify_sandbox.sh` 16/16 CRASHED 0, `verify_config.sh` exit 0 (no healing needed). All five live pids (flashnext 46573, litellm 48525, role-shim 75548, kanban 53894, telegram-connect 99162) unchanged throughout, including during the brief open window. `git diff --stat phase-01/ phase-02/ phase-03/ phase-04/` empty, `EXTRA_ALLOW_PATHS` empty, `cline` invocations this plan: 0.

## Task Commits

1. **Task 1: Re-confirm the posture, then apply exactly one Serve entry** - `f94f3bd` (feat)
2. **Task 2: opened network, found kanban Host-allowlist blocker, rolled back** - `0885cbb` (fix)

_Task 3 not reached -- it is scoped as a post-open-network sweep, and the network is closed. The equivalent invariant checks (four standing gates, five live pids, git-diff cleanliness) were performed as part of Task 2's rollback-confirmation work instead and are documented above and in the results README._

**Plan metadata:** commit pending (this SUMMARY + STATE.md update)

## Files Created/Modified
- `phase-06/results/20260830T060638Z-opening/README.md` - full narrative: what happened, root-cause diagnosis with evidence, rollback proof, post-rollback gate sweep, and three unresolved architecture options for the human decision
- `phase-06/results/20260830T060638Z-opening/apply/` - the exact single apply command, its output, and exit code
- `phase-06/results/20260830T060638Z-opening/precheck/`, `gate-services-before/` - Step A pre-flight evidence
- `phase-06/results/20260830T060638Z-opening/serve-before.json`, `serve-after.json`, `serve-after.txt`, `serve-diff.txt` - Task 1's independent before/after JSON capture and diff
- `phase-06/results/20260830T060638Z-opening/gate-network/run1/` - the FAILing `verify_network.sh` run against the open network (CASES 13/15)
- `phase-06/results/20260830T060638Z-opening/rollback/` - rollback command output and post-rollback serve-status capture
- `phase-06/results/20260830T060638Z-opening/gate-network-postrollback/` - `verify_network.sh` re-run confirming return to the known-good closed signature
- `phase-06/results/20260830T060638Z-opening/gate-services-after-rollback/`, `gate-no-regression-after-rollback/`, `gate-sandbox-after-rollback/` - full post-rollback standing-gate sweep

## Decisions Made
- **Rolled back immediately on the first FAILing post-apply check rather than attempting any live fix.** The plan's Task 2 instructions and house-rules reminder both explicitly require this response to any post-apply FAIL. The available fixes (inserting a Host-rewriting proxy layer between `tailscale serve` and kanban, or changing kanban's `--host` in a way that would also flip its remote-access passcode gate on) are architecture decisions, not bugs -- squarely deviation Rule 4 territory, reserved for a human.
- **Diagnosed the root cause using only read-only inspection of already-installed static artifacts** (kanban's compiled `dist/cli.js`, `tailscale serve --help`) rather than further live experimentation against the open network, to minimize the exposure window (~90 seconds total, apply to rollback) while still producing an actionable, evidence-backed report.

## Deviations from Plan

This plan does not fit cleanly into "auto-fixed" or "none" -- it hit a genuine Rule 4 (architectural decision needed) blocker mid-Task-2 and stopped, exactly as the plan's own house rules require.

**1. [Rule 4 - Architectural decision needed] kanban rejects the tailnet Host header; no flag-only fix exists**
- **Found during:** Task 2, first `verify_network.sh` run against the newly-opened network
- **Issue:** `https://ohama-2.tail318f12.ts.net:8444/` returns HTTP 403 `{"error":"Host not allowed."}` instead of 200. Root cause: kanban's own compiled `getAllowedHostHeaders()` only allows `localhost:<port>`/`127.0.0.1:<port>` while loopback-bound; `tailscale serve` (this version) has no Host-header-rewrite option, so the client-presented tailnet hostname is forwarded to kanban verbatim and rejected. No CLI flag or environment variable was found in kanban's binary to widen the allowlist.
- **Response:** NOT auto-fixed. Rolled back the network change immediately (`tailscale serve --https=8444 off`), confirmed byte-identical restoration, ran the full standing-gate sweep to confirm nothing else regressed, and stopped to report -- per the plan's explicit instruction and Rule 4 of the deviation classifier (this affects the security architecture of the exposure path itself; multiple viable options exist with different tradeoffs; a human must choose).
- **Files modified:** None (diagnosis was entirely read-only; the only mutating commands run were the planned apply and its planned rollback, both already accounted for in Task 1/2).
- **Evidence:** `phase-06/results/20260830T060638Z-opening/README.md` (full diagnosis with exact curl commands, cli.js line numbers, and three candidate options), `gate-network/run1/verify_network-verdict.txt` (the FAIL), `rollback/` (the fix's rollback proof).

---

**Total deviations:** 1 (Rule 4, correctly escalated rather than auto-fixed) -- 0 auto-fixed.
**Impact on plan:** The network is NOT open. Task 1's mechanics are proven correct and need no rework once a fix is chosen. Tasks 2 and 3 as originally scoped (full gate PASS twice, post-open-network sweep) cannot proceed until a human selects one of the three options in the results README.

## Issues Encountered
See "Deviations from Plan" above -- the kanban Host-allowlist blocker is the only issue encountered, and it is the reason this plan did not complete as scoped.

## User Setup Required
None yet -- this plan did not reach the point where user-facing setup (e.g., the iPad verification checklist) would apply. A decision is needed first; see "Next Phase Readiness" below.

## Next Phase Readiness
**Blocked.** The network is closed, byte-identical to the 06-01 baseline, and all four standing gates pass -- so the project is in a safe, known-good state and nothing downstream (Phase 7/8) is at risk from this attempt. However, 06-04's own success criteria (NET-01 server-side proof, and by extension 06-05/06-06 which likely depend on the network actually being open) cannot be met until a human picks one of the three options recorded in `phase-06/results/20260830T060638Z-opening/README.md`:
1. Insert a small Host-header-rewriting proxy between `tailscale serve :8444` and kanban.
2. Investigate whether a different kanban version exposes an allowlist override (not found in the currently-installed version).
3. Re-evaluate binding kanban non-loopback (rejected by the existing design in `phase-06/net/config.env` -- also does not fully solve the problem on its own, since the allowlist is built from the bound host, not the proxy's hostname).

`phase-06/net/setup_tailscale_serve.sh` and `phase-06/net/verify_network.sh` require no changes for any of these three options -- the fix, whichever is chosen, lives either in a new component between the proxy and kanban, or in kanban's own invocation flags, not in Phase 6's existing scripts.

---
*Phase: 06-network-exposure*
*Completed: 2026-08-30 (blocked, pending human decision)*
