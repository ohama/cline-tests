# 06-04.1 — the Host/Origin-rewriting loopback proxy that unblocks 06-04

**The network stayed CLOSED for the whole of this plan.** Nothing became reachable in this
plan — the network is still closed, and 06-04.2 is what opens it.

## Chain diagram

```
tailscale serve :8444  --(Host+Origin rewrite)-->  kanban-proxy 127.0.0.1:18484  -->  kanban 127.0.0.1:3484
        (closed;                                    (new; loopback only;              (bind unchanged
         06-04.2 opens                                launchd-supervised,              throughout)
         this leg)                                     com.ohama.kanban-proxy)
```

## Why this exists

06-04 opened the single planned Tailscale Serve entry and proved the Serve mechanics were
exactly correct, then hit a real, previously-unknown blocker: kanban's own compiled
`getAllowedHostHeaders()` (`dist/cli.js`) hardcodes the Host allowlist to
`{localhost:<port>, 127.0.0.1:<port>}` while kanban is loopback-bound, with **no CLI flag or
environment variable** to widen it, and this `tailscale serve` version has no Host-rewrite
option of its own. Every request arriving with the tailnet Host header was rejected by kanban
itself with `403 {"error":"Host not allowed."}` before any application code ran.

The user chose `host-rewrite-proxy`: a small loopback-only process between `tailscale serve`
and kanban that rewrites the Host header (and, as this plan discovered was equally load-bearing,
the Origin header) into the loopback pair kanban already accepts.

## Why BOTH Host and Origin had to be rewritten

Direct-to-kanban baseline probes, re-confirmed in this plan (`smoke/baseline-direct/`):

- GET with the tailnet Host, no proxy: `403 {"error":"Host not allowed."}`
- POST with the correct loopback Host but the tailnet Origin, no proxy:
  `403 {"error":"Origin not allowed."}`

Reading `dist/cli.js`'s `evaluateCors()`/`handleHttpRequest()`/`handleSocketUpgrade()` confirms
why: `allowedOrigin` is fixed to `http://127.0.0.1:3484` and any non-null mismatched `Origin` is
rejected on **every** non-`OPTIONS` request and on **every** WebSocket upgrade — the app makes
both constantly. A Host-only proxy would have served the first page load and then silently
403'd every write and every WebSocket handshake. This is why `kanban_host_proxy.js` rewrites
both headers, and why its `gate()` helper checks both Host and Origin on both the plain-request
path and the `upgrade` path.

## The security argument — translated, not removed

kanban rejects a non-loopback Host to stop DNS-rebinding and cross-site attacks against a
localhost server. The proxy keeps exactly that shape: its own small allowlists
(`PROXY_ALLOWED_HOSTS`: 4 entries — the tailnet name with and without the Serve port, plus its
own loopback identity for local probes; `PROXY_ALLOWED_ORIGINS`: 3 entries — the app's own
tailnet origin plus its own loopback identity) reject anything else **itself**, with the
rejection **never forwarded upstream** — `kanban_host_proxy.js`'s `gate()` runs before any
`http.request`/`net.connect` to kanban is ever opened. The only origin it ever launders into the
upstream-allowed value is `https://ohama-2.tail318f12.ts.net:8444`, the app's own origin. It
therefore never becomes a way to reach kanban with an arbitrary Host or Origin. Because it binds
loopback only (`server.listen(PROXY_PORT_NUM, PROXY_HOST, ...)` — the host argument is
mandatory; omitting it binds every interface) it is not a second way into this machine at all —
the only thing that can reach it is `tailscale serve` itself, connecting from loopback on behalf
of an authenticated tailnet peer. Rejection bodies are byte-compatible with kanban's own
`rejectRequest`/`rejectSocket` so a rejection reads identically wherever in the chain it came
from.

## Why NOT sandboxed

The proxy is deliberately **not** run through `run_sandboxed.sh`. Its own source,
`phase-06/net/kanban_host_proxy.js`, lives under `$HOME`, which `workspace/sandbox.sb` denies
except for two punched subpaths (`workspace/scratch-repo`, `~/.cline`) — a sandboxed node could
not even read its own entry point without widening `EXTRA_ALLOW_PATHS`, which stays EMPTY for
this entire plan (confirmed: `EXTRA_ALLOW_PATHS` empty at both start and end). The sandbox
exists to confine agent-driven code execution (cline, kanban's own task runner); this process
executes no user-supplied or agent-supplied code — it forwards bytes between two loopback
sockets and touches no filesystem path at runtime beyond the log fds launchd itself opens before
exec.

## WebSocket finding

kanban's UI builds `/api/runtime/ws`, `/api/terminal/io` and `/api/terminal/control` as
WebSockets from `window.location.host` (confirmed by reading the shipped bundle
`dist/web-ui/assets/index-*.js`). `kanban_host_proxy.js`'s `server.on('upgrade', ...)` handler
runs the same `gate()`, rewrites the same two headers, opens a raw `net.connect` to kanban,
replays the handshake, and pipes both directions. `probe_proxy.js` performs a real raw WebSocket
handshake (random `Sec-WebSocket-Key`, `Sec-WebSocket-Version: 13`) and was proven against:

- the scratch port (18485, hand-run, Task 1): `UPGRADE status=101`
- the real service port (18484, through launchd, Task 2): `UPGRADE status=101`
- the closed tailnet URL (`verify_network.sh` check 24, Task 3): `ERROR connect ECONNREFUSED`
  — **expected while the network is closed**; this is the negative-control half of the proof
  that the WHOLE chain (Serve -> proxy -> kanban), not just the loopback half, will work once
  06-04.2 opens the entry.

## sync.sh (SVC-05 mirror) diff

`sync.sh.diff` — additions only, one line changed:

```diff
-        com.ohama.kanban com.ohama.telegram-connect)
+        com.ohama.kanban com.ohama.telegram-connect com.ohama.kanban-proxy)
```

`sync.sh` itself was **not executed** in this session — 06-02 already established that this
environment's command classifier blocks running it directly (denied twice, including with the
sandbox override). The sanctioned substitute, recorded in `sync-mirror-cp.txt`, is the same
single-file `cp -p` step `sync.sh` performs for this one path, followed by `cmp` proving
byte-identity:

```
cp -p ~/Library/LaunchAgents/com.ohama.kanban-proxy.plist ~/local-llm-settings/launchagents/com.ohama.kanban-proxy.plist
cmp ~/Library/LaunchAgents/com.ohama.kanban-proxy.plist ~/local-llm-settings/launchagents/com.ohama.kanban-proxy.plist   # rc=0
```

## Take-down/restore transcript (`takedown/`)

- `takedown/00-before.txt` — pid before bootout: `19310`
- `takedown/01-bootout.txt` — `launchctl bootout gui/$UID/com.ohama.kanban-proxy`
- `takedown/02-teardown-confirmed.txt` — self-polled (bootout is async): label unregistered
  (`launchctl print` rc=113) and port 18484 freed (lsof count 0) before `restart_service.sh` was
  ever called again
- `takedown/03-restore.txt` — `phase-02/infra/restart_service.sh com.ohama.kanban-proxy 18484`
  → `RESTART OK ... pid=19669`
- `takedown/04-new-pid.txt` / `05-restore-stability.txt` — the restored pid (19669) sampled
  stable across a second >=10s window; all five pre-existing live pids
  (flashnext 46573, litellm 48525, role-shim 75548, kanban 53894, telegram-connect 99162)
  unchanged throughout the whole take-down/restore cycle

## The new `CASES 21/24` closed-state signature

Prior summaries' `CASES 13/15` closed-state signature is **historical**: the gate has grown
from 15 checks to 24 (nine new proxy checks, 16-24). `CASES 21/24` is the new closed-state
signature 06-04.2 will be measured against.

`bash phase-06/net/verify_network.sh` was run **twice back to back**
(`gate-network-closed/run1/`, `gate-network-closed/run2/`) with an identical `CHECK:` line set
both times (`diff` of the sorted `CHECK:` lines is empty). Both runs:

```
CASES 21/24
CRASHED 0
VERIFY_NETWORK: FAIL
```

FAIL set, exactly the three checks that cannot pass until 06-04.2 opens the Serve entry:

- `kanban-serve-entry-present` — no Web handler for the tailnet Host yet (expected; Serve
  is closed)
- `tailnet-https-200` — `curl_rc=7`, connection refused (expected; port 8444 unbound)
- `tailnet-websocket-101` — `ECONNREFUSED` (expected; same reason, WebSocket half)

All other 21 checks PASS, including all eight proxy-prefixed checks (16-23) and check 24's
sibling proof at the loopback layer (checks 18-21, all PASS). `gate-network-closed/
verify_network-verdict.txt` is a copy of run2's verdict file, used for the byte-count
assertions below.

## Full standing-gate sweep (all PASS, all pre-existing signatures unchanged)

| Gate | Result | Evidence |
|---|---|---|
| `verify_services.sh` (Phase 5, deliberately NOT extended) | `CASES 15/15`, exit 0 | `gate-services/` |
| `verify_no_regression.sh` (Phase 2) | `INF03: PASS`, exit 0 | `gate-no-regression/` |
| `verify_sandbox.sh` (Phase 3) | `CASES 16/16`, CRASHED 0, exit 0 | `gate-sandbox/` |
| `verify_config.sh` (Phase 1) | exit 0 | `gate-verify-config.txt` |

Additional invariants, all confirmed:

- The five pre-existing live pids (flashnext 46573, litellm 48525, role-shim 75548,
  kanban 53894, telegram-connect 99162) — unchanged across this entire plan, including during
  the proxy's own take-down/restore cycle (`gate-pids-invariant.txt`). The proxy's own new pid
  (19669 at plan end) is the one expected addition.
- `EXTRA_ALLOW_PATHS` empty at both `[ -z ... ]` checks.
  **Note:** `grep -rn 'EXTRA_ALLOW_PATHS=' phase-06/` reports 1 hit, but it is a pre-existing,
  historical self-reference inside `phase-06/results/20260830T060638Z-opening/README.md` (06-04's
  own evidence, written before this plan started, describing the grep command itself in prose —
  the same "prose collides with its own grep" trap this plan's house rules warn about). Nothing
  written by 06-04.1 contains that literal; re-scoping the grep to exclude prior `results/`
  directories (as `verify_network.sh` check 13 already does, by construction, since it only
  scans `*.sh`/`*.env`/`*.plist`/`*.js`) confirms zero hits in any file this plan could affect.
  Not auto-fixed: editing a prior, already-closed plan's evidence file to satisfy a grep in a
  later plan's informal sweep step felt like rewriting history rather than fixing a bug; the
  actual guarantee (`EXTRA_ALLOW_PATHS` itself is empty) holds, and this note documents the
  finding rather than silently papering over it.
- `git diff --stat phase-01/ phase-02/ phase-03/ phase-04/` — empty (`git-diff-frozen-phases.txt`).
- `lsof -nP -iTCP:3000 | wc -l` == 0, `lsof -nP -iTCP:8444 | wc -l` == 0.
- `tailscale serve status --json` — content-equal to `expected_serve_baseline.json` on
  `Web`/`TCP`/`AllowFunnel`; `AllowFunnel` still exactly the one pre-existing
  `ohama-2.tail318f12.ts.net:8443` key; zero `8444` matches anywhere in the live capture
  (`final-serve-status.json`, `final-baseline-check.txt`).
- `cline` invocations this plan: 0.

## Nothing became reachable in this plan

The network is still closed exactly as it was at the start: no Serve entry was added, port 8444
is unbound, `AllowFunnel` is unchanged, and `tailnet-https-200`/`tailnet-websocket-101` both
FAIL for the expected reason (connection refused — nothing is listening on 8444 at all). Every
proof in this plan — the 200 with real board markup, the two self-issued 403s, the 101 upgrade —
was made entirely over loopback, against `127.0.0.1:18484` directly, through the proxy but never
through Tailscale. **06-04.2 is what opens the network; this plan only proves, over loopback,
exactly what will answer once it does.**
