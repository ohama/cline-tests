# Phase 6 Pre-change Baseline

Captured: 2026-08-30T05:14:03Z (UTC, this directory's own timestamp prefix)

## What was captured

This directory is the frozen, pre-change record of this machine's service health and
network posture, taken immediately before any Phase 6 task opens anything. Nothing was
changed to produce this evidence — every command below is read-only.

- `gate-services/` — `phase-05/services/verify_services.sh` transcript
- `gate-no-regression/` — `phase-02/infra/verify_no_regression.sh` transcript
- `gate-sandbox/` — `phase-03/sandbox/verify_sandbox.sh` transcript
- `gate-config/` — `phase-01/config/verify_config.sh` transcript
- `inventory.txt` — live network inventory (Tailscale serve status, tailscale status,
  tailnet IPv4, port checks, LAN IP, five live pids, log line counts)
- `serve-status-before.json` — raw `tailscale serve status --json` output, saved alone

## Standing gate verdicts (all four, pre-change)

| Gate | Verdict | Detail |
|------|---------|--------|
| `verify_services.sh` | PASS | exit 0, 15/15 `CHECK: PASS`, `VERIFY_SERVICES: PASS` |
| `verify_no_regression.sh` | PASS | exit 0, `INF03: PASS` |
| `verify_sandbox.sh` | PASS | exit 0, 4/4 CRITERION, 16/16 CASES, 0 CRASHED |
| `verify_config.sh` | PASS | exit 0 on first attempt — no heal needed |

## Confirmed values

- `LAN_IP` = `192.168.75.108`
- Tailnet hostname = `ohama-2.tail318f12.ts.net`
- Tailnet IPv4 = `100.118.140.2`

## Port 3000

**Port 3000 is UNBOUND and must stay that way because a pre-existing public Tailscale
entry on :8443 already forwards to it.**

## Pre-existing Tailscale Serve/Funnel state (out of scope, record only)

Three handlers exist, all pre-dating this project — none of these belong to this project
and Phase 6 must never modify them:

- `https://ohama-2.tail318f12.ts.net:8443` (public-exposure mode ON) -> `http://127.0.0.1:3000`
- `https://ohama-2.tail318f12.ts.net:10000` (tailnet only) -> `http://127.0.0.1:8788`
- `https://ohama-2.tail318f12.ts.net` (tailnet only, port 443) -> `http://127.0.0.1:8787`

`AllowFunnel` currently has exactly one key: `ohama-2.tail318f12.ts.net:8443` = true.

## Live pids (unchanged by this plan)

46573 (flashnext), 48525 (litellm), 53894 (kanban), 56669 (telegram-connect), 75548 (role-shim)

**RECONCILED (2026-08-31, 08-06 phase-close):** kanban's pid above (53894) is this directory's
original 06-01 capture and is left as-is — plan 08-01 (2026-08-31) sanctioned a live restart of
`com.ohama.kanban` (`phase-02/infra/restart_service.sh` only) that changed it to **36175**.
`inventory.txt` now carries a reconciled expectation line ahead of the original transcript so
`phase-06/net/verify_network.sh --baseline` (check 15, `live-pids-stable`) reads the current
pid rather than staying permanently red against a value this project itself made stale. See
`docs/services.md` §5a and `phase-08/results/20260830T191320Z-kanban-fix/`.

## Nothing was changed

This plan mutates nothing. `git status` at the end of this plan shows only new files under
`phase-06/`.
