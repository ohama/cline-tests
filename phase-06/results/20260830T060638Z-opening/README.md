# 06-04: The Opening — Attempted, Blocked, Rolled Back

**Status: NOT open.** The network was opened for approximately 90 seconds, found to be
functionally broken (kanban itself rejects every request that arrives via the tailnet
hostname), and closed again via the pinned rollback. The live Tailscale config is
byte-identical to the frozen 06-01 baseline as of the end of this plan.

## What happened, in order

1. **Task 1 (committed, `f94f3bd`):** Re-confirmed live posture (all pre-flight checks OK),
   then ran `setup_tailscale_serve.sh --apply`. It applied exactly one command
   (`tailscale serve --bg --https=8444 http://127.0.0.1:3484`), exit 0, and its own Q1-Q5
   post-assertions all passed. Independent verification confirmed: `AllowFunnel` still
   exactly one key (`ohama-2.tail318f12.ts.net:8443`), `Web` exactly 4 handlers (3 frozen
   byte-identical + the new `:8444`), `TCP` exactly 4 keys, diff showed only additions,
   kanban's own bind/pid/port-3000-unbound all unchanged. **The mechanics of opening the
   Serve entry are correct and were proven correct.**

2. **Task 2 (attempted, not committed as a pass — the network went back down instead):**
   Ran `verify_network.sh` against the now-open network. It FAILed at `CASES 13/15`, with
   two checks failing:
   - `tailnet-https-200`: `https://ohama-2.tail318f12.ts.net:8444/` returned **HTTP 403**,
     body `{"error":"Host not allowed."}` — not 200.
   - `tailnet-no-passcode-gate`: failed as a downstream consequence (body did not look like
     the kanban board).

## Root cause (diagnosed, read-only, network still open at the time)

This is **not** a Tailscale problem and **not** a bug in `setup_tailscale_serve.sh` or
`verify_network.sh`. It is a genuine, previously-undiscovered conflict between kanban's own
application-level defense and the reverse-proxy architecture this phase assumed:

- Confirmed by curling `127.0.0.1:3484` directly with `-H 'Host: ohama-2.tail318f12.ts.net:8444'`
  — same 403/`Host not allowed.` — proving the rejection happens **inside kanban itself**,
  not at the Tailscale layer.
- Read (read-only, no files modified) `/opt/homebrew/lib/node_modules/kanban/dist/cli.js`:
  kanban maintains a `getAllowedHostHeaders()` allowlist. When bound loopback
  (`isKanbanRemoteHost()` false, which is exactly what `--host 127.0.0.1` gives us and which
  Phase 5/6 rely on to keep the passcode gate permanently off), the allowlist is hardcoded to
  `{localhost:<port>, 127.0.0.1:<port>}` only — nothing else is ever added, and there is no
  CLI flag or environment variable found in the binary that widens it.
- `tailscale serve --help` (this version) confirms there is no Host-header-rewrite option on
  the proxy side either — `serve` forwards the client-presented Host/SNI hostname verbatim to
  the backend, it does not rewrite it to the target's own host:port.
- Net effect: **any** reverse-proxy front end that preserves the original Host header will be
  rejected by kanban's own defense, for as long as kanban stays loopback-bound. There is no
  flag-only fix available today.

## Why this was rolled back instead of fixed forward

Both the plan's own Task 2 instructions ("If any check FAILs: do not iterate on the open
network. Run the rollback command...and report.") and the plan's house-rules reminder
("If ANY post-assertion fails, run the recorded rollback command immediately...STOP with a
report — do not 'fix forward' on an open network.") require exactly this response. The only
available fixes all change the security architecture of the exposure path itself (e.g.
inserting a Host-header-rewriting proxy between `:8444` and kanban, or changing kanban's
`--host` value in a way that would also flip its passcode gate on) — that is squarely an
architectural decision the plan explicitly reserves for a human, not something to improvise
live against an open network.

## Rollback, proven

```
$ tailscale serve --https=8444 off
Warning: client version ... (benign, pre-existing, ignored per TS_WARN_FILTER)
```

- `serve-after-rollback.json` is byte-for-byte identical to `serve-before.json` (the pre-apply
  capture) — see `rollback/serve-after-rollback.json` vs `serve-before.json`.
- Content-equal to `phase-06/net/expected_serve_baseline.json` on `Web`/`TCP`/`AllowFunnel`.
- Port 8444 confirmed unbound again (`lsof -nP -iTCP:8444` = 0 lines).
- Port 3000 confirmed still unbound throughout (never touched).
- Kanban's bind confirmed unchanged: `127.0.0.1:3484` only, pid `53894` (same pid, never
  restarted).
- `verify_network.sh` re-run post-rollback: `CASES 13/15`, FAIL set exactly
  `{kanban-serve-entry-present, tailnet-https-200}` — the identical negative-control
  signature 06-03 Task 3 Step B already proved for the closed state. The system is back to
  the known-good closed posture, not some new/different state.

## Post-rollback standing-gate sweep (all four, all PASS)

- `phase-05/services/verify_services.sh` — `CASES 15/15`, exit 0.
- `phase-02/infra/verify_no_regression.sh` — `INF03: PASS`, exit 0.
- `phase-03/sandbox/verify_sandbox.sh` — `CASES 16/16`, `CRASHED 0`, exit 0.
- `phase-01/config/verify_config.sh` — exit 0, no healing needed.

## Live pids, unchanged throughout (including during the ~90s the network was briefly open)

| Service | pid | Confirmed |
|---|---|---|
| flashnext | 46573 | unchanged |
| litellm | 48525 | unchanged |
| role-shim | 75548 | unchanged |
| kanban | 53894 | unchanged |
| telegram-connect | 99162 | unchanged, still inert (`pgrep -f 'connect telegram'` = 0) |

## Other invariants confirmed post-rollback

- `git diff --stat phase-01/ phase-02/ phase-03/ phase-04/` — empty.
- `EXTRA_ALLOW_PATHS` — empty; `grep -rn 'EXTRA_ALLOW_PATHS=' phase-06/` — 0 hits.
- `cline` invocations this plan: 0.
- No `tailscale funnel`-shaped command was ever invoked. `reset` was never invoked.

## Reachability, as of the end of this plan

**Nothing is reachable except what was already reachable before this plan started**: tailnet
members via the three pre-existing handlers (`:443`, `:10000`, and public-Funnel `:8443`,
none of which this project owns), and the public internet via that same pre-existing `:8443`
Funnel key forwarding to `127.0.0.1:3000` (still unbound, still inert). Kanban is reachable
from nowhere but this Mac's own loopback interface. Not the LAN, not the tailnet (yet), not
the public internet.

## What a human needs to decide before this can be retried

The Serve-entry mechanics (`setup_tailscale_serve.sh`) are proven correct and need no changes.
What's missing is a way to make kanban accept the tailnet hostname in its Host header while
staying loopback-bound. Options observed during diagnosis (none applied):

1. Insert a small Host-header-rewriting layer between `tailscale serve :8444` and kanban
   (e.g. a minimal local proxy that rewrites `Host:` to `127.0.0.1:3484` before forwarding to
   kanban) — adds a new component to the architecture.
2. Investigate whether a newer/older kanban release exposes an allowlist override (not found
   in the currently-installed version's compiled `cli.js`).
3. Re-evaluate binding kanban non-loopback (rejected by design in `phase-06/net/config.env`
   — this is what keeps the remote-access passcode gate off; changing it also does not
   actually fix the Host check on its own, since the allowlist is built from the *bound*
   host, not the proxy's hostname).

This plan makes no recommendation among these — it is exactly the kind of decision the
project's deviation rules reserve for a human.
