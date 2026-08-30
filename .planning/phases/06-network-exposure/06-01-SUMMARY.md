---
phase: 06-network-exposure
plan: 01
subsystem: infra
tags: [tailscale, network, launchd, kanban, config-env]

# Dependency graph
requires:
  - phase: 05-kanban-telegram-services
    provides: "verify_services.sh 15-check standing gate, live kanban/telegram-connect launchd services, phase-05/services/config.env conventions"
provides:
  - "Pre-change baseline evidence for all four standing gates plus a live network inventory (phase-06/results/20260830T051403Z-baseline/)"
  - "phase-06/net/config.env — single source for Phase 6 port/host/LAN/label values, sourcing phase-05's config"
  - "phase-06/net/expected_serve_baseline.json — frozen, machine-generated snapshot of the three pre-existing Tailscale Serve handlers + AllowFunnel key"
affects: [06-02, 06-03, 06-04, 06-05, 06-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "pre-set-RESULTS_ROOT-then-source convention extended one more layer (phase-06/net/config.env sources phase-05/services/config.env)"
    - "frozen JSON baseline for byte-identity comparison instead of eyeballing live CLI output"

key-files:
  created:
    - phase-06/net/config.env
    - phase-06/net/expected_serve_baseline.json
    - phase-06/results/20260830T051403Z-baseline/ (README.md, inventory.txt, serve-status-before.json, four gate transcripts)
  modified: []

key-decisions:
  - "TS_SERVE_PORT pinned to 8444 (confirmed unclaimed via lsof immediately before writing config.env), excluded from 3000/443/8443/10000 with reasons documented inline"
  - "TS_SERVE_ROLLBACK_CMD hardcoded as 'tailscale serve --https=8444 off' rather than derived, because this tailscale version's --help documents no per-port removal syntax and the only removal verb shown (reset) would wipe the three out-of-scope pre-existing handlers"
  - "expected_serve_baseline.json's provenance note uses a top-level _comment key rather than a sibling README file (plan offered either option)"

patterns-established:
  - "phase-06/net/config.env: PROJECT_ROOT from BASH_SOURCE, pre-set RESULTS_ROOT, then source phase-05/services/config.env — never re-derive KANBAN_HOST/KANBAN_PORT/labels/log-dir"

# Metrics
duration: 15min
completed: 2026-08-30
---

# Phase 6 Plan 1: Pre-change Baseline + Phase Constants Summary

**Captured a byte-exact pre-change network/service baseline (four standing gates + live Tailscale Serve/Funnel inventory) and pinned Phase 6's port/rollback constants in a sourceable config.env — zero mutating tailscale commands issued.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-30T05:14:03Z
- **Completed:** 2026-08-30T05:17:40Z
- **Tasks:** 2 completed
- **Files modified:** 34 (32 new evidence files under `phase-06/results/`, plus `phase-06/net/config.env` and `phase-06/net/expected_serve_baseline.json`)

## Accomplishments
- All four standing gates (`verify_services.sh` 15/15, `verify_no_regression.sh` INF03:PASS, `verify_sandbox.sh` 4/4 CRITERION/16/16 CASES/0 CRASHED, `verify_config.sh` exit 0 on first attempt, no heal needed) ran green and their transcripts are on disk, timestamped, before any Phase 6 change exists.
- Live network inventory captured: `tailscale serve status`/`--json`, `tailscale status`, tailnet IPv4, LAN IP (`192.168.75.108`), port 3000 confirmed UNBOUND, port 8444 confirmed UNBOUND, kanban confirmed bound to exactly `127.0.0.1:3484`, five live pids recorded, log line counts recorded.
- `phase-06/net/config.env` written: sources `phase-05/services/config.env` after pre-setting `RESULTS_ROOT` (no re-derivation), pins `TS_SERVE_PORT=8444`, `TS_SERVE_ROLLBACK_CMD`, `TS_SERVE_SCRATCH_PORT=59999`, and every other Phase 6 constant the later plans need, each with a load-bearing comment explaining why.
- `phase-06/net/expected_serve_baseline.json` machine-generated (python3, from the live capture — never hand-typed) holding exactly the three pre-existing Web handlers and the single AllowFunnel key, with an embedded `_comment` stating none belongs to this project.

## Task Commits

1. **Task 1: Pre-change baseline — four standing gates plus a live network inventory** - `eeff204` (chore)
2. **Task 2: Pin Phase 6 constants and freeze the pre-existing Tailscale handlers** - `3cc9f8f` (feat)

_No separate metadata commit was made beyond these two task commits and this SUMMARY/STATE commit — this plan produces no code, only pinned constants and evidence._

## Files Created/Modified
- `phase-06/net/config.env` - Phase 6 constants (TS_SERVE_PORT, rollback command, scratch port, tailnet identity, FORBIDDEN_SERVE_PORTS, EXPECTED_FUNNEL_KEY, etc.), sourcing phase-05's config
- `phase-06/net/expected_serve_baseline.json` - frozen snapshot of the three pre-existing Tailscale Serve handlers + AllowFunnel key
- `phase-06/results/20260830T051403Z-baseline/README.md` - what was captured, gate verdicts, LAN_IP/tailnet hostname/IPv4, port-3000 danger sentence
- `phase-06/results/20260830T051403Z-baseline/inventory.txt` - live network inventory (Tailscale serve/status, port checks, LAN IP, five pids, log line counts)
- `phase-06/results/20260830T051403Z-baseline/serve-status-before.json` - raw `tailscale serve status --json` output alone
- `phase-06/results/20260830T051403Z-baseline/gate-services/`, `gate-no-regression/`, `gate-sandbox/`, `gate-config/` - four standing-gate transcripts

## Decisions Made
- **TS_SERVE_PORT = 8444**: confirmed genuinely unclaimed via `lsof -nP -iTCP:8444` twice (once during Task 1's inventory, again immediately before writing config.env in Task 2). Excluded 3000 (unbound-must-stay reason: live public-exposure entry already forwards there), 443/8443/10000 (already claimed by the three pre-existing handlers; 8443 is the public-exposure port itself).
- **TS_SERVE_ROLLBACK_CMD hardcoded, not derived**: this tailscale version's `serve --help` has no per-port removal syntax; the only removal-shaped verb (`reset`) wipes the entire serve config including the two out-of-scope handlers and the public-exposure key. `serve --https=<port> off` is the correct, confirmed-accepted, undocumented form — pinned once here with the full reasoning as a comment, per plan instruction.
- **expected_serve_baseline.json provenance documented via a top-level `_comment` key** rather than a separate sibling README file — the plan explicitly offered either option; the single-file approach keeps the frozen data and its provenance note atomic.

## Deviations from Plan

None - plan executed exactly as written. One minor self-caught formatting cleanup: an inline `grep -c ... || echo 0` idiom used while building `inventory.txt` (not part of any plan-authored script) produced a duplicate `0` line for the telegram-connect.log count due to `grep -c`'s exit-code-1-on-zero-matches behavior firing the `||` fallback after already emitting `0`. Caught before committing and replaced with `wc -l` in the same evidence-generation step — this is data-collection tooling I wrote inline, not a plan deviation under Rules 1-4 (no plan-authored file or script was touched), so it is noted here for transparency rather than logged as an auto-fixed issue.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

`phase-06/net/config.env` and `phase-06/net/expected_serve_baseline.json` are ready for 06-02 onward to source and diff against. The frozen baseline directory (`phase-06/results/20260830T051403Z-baseline/`) is the reference point every later Phase 6 plan should compare its own `tailscale serve status --json` capture against to prove nothing beyond the intended single new kanban Serve entry ever appeared, and that the three pre-existing handlers plus the single AllowFunnel key stayed byte-identical throughout.

No blockers. Live pids (flashnext 46573, litellm 48525, role-shim 75548, kanban 53894, telegram-connect 56669) unchanged throughout this plan; `EXTRA_ALLOW_PATHS` empty; port 3000 unbound; zero mutating `tailscale` commands issued; `git status` at plan end shows nothing outstanding under `phase-06/` beyond what these two commits already captured.

---
*Phase: 06-network-exposure*
*Completed: 2026-08-30*
