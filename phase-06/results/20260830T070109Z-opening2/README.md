# 06-04.2: The Opening, Attempt 2 — Pointed at the Proxy, Fully Open, Fully Proven

**Status: OPEN.** The single planned Tailscale Serve entry on `:8444` is live and points at the
Host/Origin-rewriting proxy (`com.ohama.kanban-proxy`, `127.0.0.1:18484`), which forwards to
kanban (`127.0.0.1:3484`). This is the second and final attempt: 06-04 proved the Serve
mechanics and hit kanban's own Host allowlist (403); 06-04.1 built and proved the fix over
loopback with the network still closed; this plan re-applied the same single Serve entry,
this time pointed at the proxy, and it works end to end.

## The exact command that opened the network

```
/opt/homebrew/bin/tailscale serve --bg --https=8444 http://127.0.0.1:18484
```

Run via `phase-06/net/setup_tailscale_serve.sh --apply`, gated by preflight P5b (refuses to
apply unless the proxy is already loopback-bound and already answering 200 for the tailnet
Host) — see `apply/setup-transcript.txt`. Exit 0. Exactly one invocation, exactly one entry.
`tailscale funnel` was never invoked; `tailscale serve reset` was never invoked.

## Before / after Tailscale config diff

Only additions for port 8444 — see `serve-diff.txt`:

```diff
10a11,13
>     },
>     "8444": {
>       "HTTPS": true
33a37,43
>     },
>     "ohama-2.tail318f12.ts.net:8444": {
>       "Handlers": {
>         "/": {
>           "Proxy": "http://127.0.0.1:18484"
>         }
>       }
```

Independently re-verified (not relying on the script's own Q1-Q5), against `serve-after.json`:
- `AllowFunnel` — exactly ONE key, `ohama-2.tail318f12.ts.net:8443` — unchanged.
- `Web` — exactly FOUR handlers: the three frozen ones byte-identical to
  `expected_serve_baseline.json`, plus the new
  `ohama-2.tail318f12.ts.net:8444 -> {"/": {"Proxy": "http://127.0.0.1:18484"}}`.
- `TCP` — exactly FOUR keys: `443`, `8443`, `10000`, `8444`.
- `tailscale serve status` text output confirms `:8443` is still `(Funnel on)` (the pre-existing
  public-exposure key, untouched) and `:8444` is `(tailnet only)` (the new entry, never Funnel).

## Rollback

```
tailscale serve --https=8444 off
```

This is `$TS_SERVE_ROLLBACK_CMD` from `phase-06/net/config.env`, validated against scratch port
59999 in 06-03 and exercised for real in 06-04. **`tailscale serve reset` is FORBIDDEN as a
rollback** — it wipes the ENTIRE serve config, including the three pre-existing handlers
(`:443`, `:10000`, and the public-exposure `:8443`) that this project must only ever record and
never touch. Not needed this run — every check passed, so no rollback was executed.

## The chain

```
tailscale serve :8444 (tailnet only, HTTPS terminated by Tailscale)
        |
        v
proxy 127.0.0.1:18484   -- rewrites Host -> 127.0.0.1:3484, Origin -> http://127.0.0.1:3484
        |                  before forwarding; rejects (403, itself, without ever forwarding)
        |                  any Host/Origin not on its own small allowlist
        v
kanban 127.0.0.1:3484   -- unaware anything changed; its own bind, pid, and Host allowlist
                            are exactly as they've always been
```

Each hop: Tailscale terminates TLS for the tailnet MagicDNS name and forwards plaintext to the
proxy over loopback; the proxy translates the client-presented tailnet identity into the
loopback identity kanban already trusts, enforcing its own narrow allowlist on the way in; kanban
never sees a non-loopback Host and so never turns on its remote-access passcode gate.

## Gate transcripts (both full PASS)

`verify_network.sh` run twice back to back against the open network:
- Run 1: `gate-network/run1/verify_network-verdict.txt` — `CASES 24/24`, `CRASHED 0`, exit 0.
- Run 2: `gate-network/run2/verify_network-verdict.txt` — `CASES 24/24`, `CRASHED 0`, exit 0.
- `diff` of the two `CHECK:` line sets is empty — a standing gate that is not stable across
  consecutive runs is not a gate.
- All three checks that were the closed-state negative control now PASS:
  `kanban-serve-entry-present`, `tailnet-https-200`, `tailnet-websocket-101`.

### NET-01 (server-side half)

- `tailnet-https-200`: `curl -s -m 15 -o /dev/null -w '%{http_code}' https://ohama-2.tail318f12.ts.net:8444/`
  returned **200** (`manual/tailnet-https-200-code.txt`). No TLS override needed — Tailscale
  issues a trusted cert for the MagicDNS name.
- Body (`manual/tailnet-https-200-body-head.txt`) is real board markup:
  ```
  <!doctype html>
  <html lang="en">
  ...
  ```
- `tailnet-websocket-101`: `node probe_proxy.js` against
  `https://ohama-2.tail318f12.ts.net:8444/api/runtime/ws` printed `UPGRADE status=101`
  (`manual/tailnet-websocket-101.txt`) — proves the live-update channel survives the WHOLE
  chain (Serve -> proxy -> kanban), not just the first page load.
- The iPad/client-side half of NET-01 is explicitly **not** claimed here and stays
  `human_needed`.

### NET-02 (proven positively, both new and old components)

Curl from this Mac's LAN IP `192.168.75.108` to all three relevant ports — every one refused at
the connection level (`manual/lan-refused-rcs.txt`):

```
port 3484 rc=7
port 8444 rc=7
port 18484 rc=7
```

`kanban-bind-loopback-only`, `lan-refused-kanban-port`, `lan-refused-serve-port`,
`proxy-bind-loopback-only`, `proxy-lan-refused` — all PASS in both gate runs.

### NET-03

`port-3000-unbound` PASS in both gate runs; `lsof -nP -iTCP:3000 | wc -l` == 0, confirmed
independently after Task 1's apply, after Task 2's gate runs, and after Task 3's sweep.

### NET-04

`net04-guard-present` and `net04-guard-refuses` both PASS in both gate runs — re-proven with the
network open, exactly as before it opened.

### Manual out-of-gate probe

A deliberately wrong `Host: evil.invalid` header sent over the real tailnet chain (not
loopback) still gets the proxy's own rejection — nothing was laundered open by the rewrite
(`manual/wrong-host-tailnet.txt`):

```
{"error":"Host not allowed."}
403
```

## Post-change standing-gate sweep (all four, all PASS, network open)

| Gate | Result | Evidence |
|---|---|---|
| `phase-05/services/verify_services.sh` | `CASES 15/15`, exit 0 | `gate-services-after/verify_services-verdict.txt` |
| `phase-02/infra/verify_no_regression.sh` | `INF03: PASS`, exit 0 | `gate-no-regression-after/` |
| `phase-03/sandbox/verify_sandbox.sh` | `CASES 16/16`, `CRASHED 0`, exit 0 | `gate-sandbox-after/` |
| `phase-01/config/verify_config.sh` | exit 0, no healing needed | `gate-config-after/verify_config-transcript.txt` |

## Invariant table

| Invariant | Before | After | Match |
|---|---|---|---|
| flashnext pid | 46573 | 46573 | yes |
| litellm pid | 48525 | 48525 | yes |
| role-shim pid | 75548 | 75548 | yes |
| kanban pid | 53894 | 53894 | yes |
| telegram-connect pid | 99162 | 99162 | yes |
| kanban-proxy pid | 19669 | 19669 | yes |
| `EXTRA_ALLOW_PATHS` value | empty | empty | yes |
| `git diff --stat phase-01/ phase-02/ phase-03/ phase-04/` | empty | empty | yes |
| `kanban.log` line count (vs. 06-01 baseline=16) | 16 | 16 | yes |
| `telegram-connect.log` line count (vs. 06-01 baseline=0) | 0 | 0 | yes |
| `kanban-proxy.log` | n/a (component added by 06-04.1, after the 06-01 baseline) | 15 lines: startup + expected `REJECT` lines from the negative probes only | nothing alarming |
| `pgrep -f 'connect telegram'` | 0 | 0 | still inert |
| public-exposure subcommand under `phase-06/net/` | absent | absent | check 14 PASS both runs |
| port 3000 | unbound | unbound | yes |

See `invariants/` for the raw captures backing this table.

## Reachability, as of the end of this plan

**Tailnet members of `ohama100@` only** can now reach kanban's real board (and its live
WebSocket updates) at `https://ohama-2.tail318f12.ts.net:8444/` — not the LAN, not the public
internet. The pre-existing public-exposure key on `:8443`, forwarding to `127.0.0.1:3000`, is
out of scope for this project — recorded, never touched — which is why port 3000 must stay
unbound forever: it is the only thing standing between that pre-existing Funnel entry and the
open internet.
