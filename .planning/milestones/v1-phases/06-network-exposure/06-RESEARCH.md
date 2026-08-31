# Phase 6: 네트워크 노출 - Research

**Researched:** 2026-08-30
**Domain:** Tailscale Serve/Funnel, kanban's built-in remote-access passcode, cline's Telegram connector CLI gating, launchd service network exposure
**Confidence:** HIGH (all findings below are from live commands on this Mac, `--help` output, live `strings`/grep against the installed `kanban` and `cline` binaries, and the standing `verify_services.sh` gate — no theorizing)

## Summary

This Mac already has a live Tailscale Serve/Funnel configuration that predates this project: three proxy entries exist (`443→127.0.0.1:8787`, `10000→127.0.0.1:8788`, `8443→127.0.0.1:3000` **with Funnel ON**). None of these were created by this project and none should be touched by it, but the `8443→:3000` entry is the literal, currently-live embodiment of the danger NET-03 exists to avoid: port 3000 is free right now, so that Funnel rule forwards to nothing — but the instant **any** process (this project's or not) binds `127.0.0.1:3000`, it becomes reachable from the **public internet**, no Tailscale login required, because Funnel is already armed on that port. NET-03 is not a hypothetical; it is a live trap already set on this machine.

The correct shape for Phase 6, confirmed by reading `kanban`'s and `cline`'s actual `--help` output and by disassembling the installed `kanban` CLI's remote-access logic: **do not rebind kanban's `--host` at all.** Leave it on its default `127.0.0.1:3484`. Front it with `tailscale serve` (never `tailscale funnel`) on a **new, unused port** (not 3000, not 443, not 8443, not 10000 — those are already spoken for), proxying to `http://127.0.0.1:3484`. Because `tailscale serve` connects to the backend over loopback, kanban never sees a non-loopback bind and its own remote-access passcode gate (`isKanbanRemoteHost()`) stays permanently off for anyone arriving via that route — this **is** "Tailscale 무인증": no additional credential beyond already being an authenticated member of the tailnet. Kanban's own passcode/`--host` flags cannot cleanly deliver "Tailscale-unauthenticated AND LAN-token-gated" from a *single* process, because the passcode gate is a single global on/off switch tied to the `--host` value at startup, not evaluated per-connection-source — so turning it on to gate LAN also gates Tailscale-Serve-proxied traffic, defeating "무인증." The clean, evidence-provable answer for NET-02 is therefore the stronger claim: kanban is **never bound to any LAN-reachable interface at all**, so a same-LAN device cannot reach it, period — which trivially and honestly satisfies "LAN 기기는 토큰 없이 접근하지 못한다" (there is no way in, tokened or not). This is spelled out as an explicit interpretation choice below, not smuggled in.

NET-04 cannot be satisfied by `cline connect telegram --allowed-user-id` alone — this was re-confirmed live: `cline connect telegram -k <fake-token> --no-tools` (no `--allowed-user-id`) proceeded straight to calling Telegram's `getMe` API and only failed because the token was garbage, not because the flag was missing. `--allowed-user-id` is accepted but never validated as present. The honest fix is a **wrapper-level pre-flight** inside `phase-05/services/run_telegram_service.sh` that refuses to exec `cline connect telegram` at all when `TELEGRAM_ALLOWED_USER_ID` is unset/empty — "커넥터가 기동하지 않는다" can only be truthfully claimed about *our* launchd-supervised invocation path, not about the `cline` binary itself, and the RESEARCH.md says so plainly rather than papering over it.

NET-05 is where the static evidence gets genuinely uncomfortable: `kanban`'s CLI proves a card-side "in_progress" column exists and is agent-verifiable (`kanban task list --column in_progress`), giving an honest, provable answer for the Kanban half. For Telegram, disassembling the compiled `cline` binary found exactly **one** call site for the Telegram typing indicator (`sendChatAction` action `"typing"`), fired once when a message is received, with no periodic refresh loop anywhere in the 88MB binary. Telegram's own protocol lets a typing indicator decay after ~5 seconds. There is no placeholder "thinking…" message and no evidence of a resend loop. This means the *structural* guarantee for "Telegram 대화에서 작업 중 상태가 시각적으로 확인된다" during a 64-second prefill or a compaction-triggered summary call is weak by default — this is flagged as an Open Question requiring a live, real-token test (the first one this project will ever run), not asserted as either pass or fail.

**Primary recommendation:** Keep kanban on `127.0.0.1:3484` unchanged; add exactly one `tailscale serve --bg --https=<new-port> localhost:3484` entry (never touch the existing 443/8443/10000 entries, never call `tailscale funnel`); add a wrapper pre-flight in `run_telegram_service.sh` that hard-fails startup when `TELEGRAM_ALLOWED_USER_ID` is empty; treat NET-02 as satisfied by "no LAN bind exists" rather than by a hand-rolled token layer; and treat NET-05's Telegram half as an open, empirically-untested risk that the plan must probe with a real token before claiming success.

## Standard Stack

### Core
| Tool | Version (this Mac) | Purpose | Why Standard |
|------|---------------------|---------|---------------|
| `tailscale serve` | tailscale 1.96.4 client / 1.96.5 daemon (macOS App Store "macsys" variant, not Homebrew's `tailscaled`) | Reverse-proxies a tailnet HTTPS endpoint to a local loopback port, TLS terminated by Tailscale using an auto-issued cert for the MagicDNS name | Official mechanism for exposing a local service to tailnet peers only, without the service itself ever binding a non-loopback interface |
| kanban's built-in passcode (`src/security/passcode-manager.ts`, compiled into `dist/cli.js`) | kanban CLI installed at `/opt/homebrew/lib/node_modules/kanban` | Auto-generated 8-char passcode gate, active only when kanban's `--host` is a non-localhost value | Already exists in the shipped binary — no need to hand-roll a token layer if a genuinely LAN-bound path is ever wanted |
| `cline connect telegram --allowed-user-id` | cline 3.0.53 (pinned) | CLI flag that *should* restrict the bot to one Telegram user ID | Present in `--help`, but confirmed live to be non-enforcing — see Pitfalls |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `phase-02/infra/restart_service.sh` | Sole sanctioned bootout→bootstrap→poll restart path for both launchd services | Any time a plist or wrapper script changes |
| `phase-05/services/verify_services.sh` | 15-check standing gate (0/1/2 exit contract) | Before and after any Phase 6 change — ran it live during this research: **15/15 PASS**, fresh baseline captured at `phase-05/results/20260830T043509Z-gate` |
| `lsof -i :3000` | The literal NET-03 acceptance check | Must show nothing after every service start/restart in Phase 6 |
| `kanban task list --column in_progress` | Agent-verifiable proof of Kanban-side "작업 중" status | Use during the NET-05 evidence-gathering task |

### Alternatives Considered
| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| `tailscale serve` fronting loopback-only kanban | `kanban --host 0.0.0.0` directly on the tailnet interface | Rejected: binds a real interface, drags in kanban's own passcode gate for *everyone* including Tailscale peers (see below), and is exactly the class of accidental-wide-bind mistake NET-03 exists to prevent generally |
| `tailscale serve` on a fresh port | Reusing port 443 or 8443 with a path prefix under the existing entries | Rejected: 8443 already has **Funnel** on (public internet); 443 and 10000 already proxy to unrelated pre-existing services (ports 8787/8788, origin unknown, not this project's) — touching either risks breaking something outside this project's scope |
| Wrapper-level `--allowed-user-id` pre-flight | Waiting for a future cline version to enforce it itself | Rejected: cline 3.0.53 is pinned per Phase 1; cannot depend on unreleased behavior |

**No install needed** — `tailscale`, `kanban`, and `cline` are all already present and pinned from prior phases.

## Architecture Patterns

### Pattern 1: Tailscale Serve as a pure loopback-fronting reverse proxy (NET-01, indirectly NET-03)
**What:** `tailscale serve --bg --https=<PORT> localhost:3484` registers a tailnet-only HTTPS listener on `https://ohama-2.tail318f12.ts.net:<PORT>` that reverse-proxies to `http://127.0.0.1:3484`. Kanban's own bind never changes.
**When to use:** Whenever a service should be reachable by tailnet peers but must never itself listen on a non-loopback interface.
**Evidence (live, this Mac):**
```
$ tailscale serve status
# Funnel on:
#     - https://ohama-2.tail318f12.ts.net:8443

https://ohama-2.tail318f12.ts.net:10000 (tailnet only)
|-- / proxy http://127.0.0.1:8788

https://ohama-2.tail318f12.ts.net (tailnet only)
|-- / proxy http://127.0.0.1:8787

https://ohama-2.tail318f12.ts.net:8443 (Funnel on)
|-- / proxy http://127.0.0.1:3000
```
```
$ tailscale serve status --json
{
  "TCP": {"10000":{"HTTPS":true},"443":{"HTTPS":true},"8443":{"HTTPS":true}},
  "Web": {
    "ohama-2.tail318f12.ts.net:10000": {"Handlers":{"/":{"Proxy":"http://127.0.0.1:8788"}}},
    "ohama-2.tail318f12.ts.net:443":   {"Handlers":{"/":{"Proxy":"http://127.0.0.1:8787"}}},
    "ohama-2.tail318f12.ts.net:8443":  {"Handlers":{"/":{"Proxy":"http://127.0.0.1:3000"}}}
  },
  "AllowFunnel": {"ohama-2.tail318f12.ts.net:8443": true}
}
```
Three independent port entries coexist already, confirming each `tailscale serve --https=<port> …` call adds/updates only its own port without disturbing the others — safe to add a fourth for kanban on a **new** port number.

**`tailscale serve --help` (verbatim, this version):**
```
USAGE
  tailscale serve <target>
  tailscale serve status [--json]
  tailscale serve reset
...
  - Expose an HTTP server running at 127.0.0.1:3000 in the background:
    $ tailscale serve --bg 3000
FLAGS
  --bg, --bg=false   Run as background process (default false; --bg required for persistence)
  --https value      Expose an HTTPS server at the specified port (default mode)
  ...
```
`--bg` is required — without it, `tailscale serve <target>` runs in the **foreground** and drops the config when the invoking process/terminal exits (this explains why the three pre-existing entries persist without a visible attached foreground process: they were set up with `--bg`, or via the newer `--service`/config-file path).

### Pattern 2: Funnel vs Serve — the exact mechanism and why port 3000 is dangerous
**What:** `tailscale serve` exposes to tailnet members only (identity-gated by Tailscale's own auth — this is what makes it honestly "무인증" from the app's point of view, since the network layer already authenticated the client). `tailscale funnel` does everything `serve` does **plus** makes the same endpoint reachable from the raw public internet with **no Tailscale login required by the visitor** — from `tailscale funnel --help`: *"Funnel enables you to share a local server on the internet using Tailscale... To share only within your tailnet, use `tailscale serve`."*
**Why port 3000 specifically:** it is not a rule about the number "3000" in the abstract — it is a rule about **this Mac's pre-existing, currently-live configuration**: `tailscale serve status` shows `8443 (Funnel on) → proxy http://127.0.0.1:3000` was already configured by something outside this project **before** this research ran. That rule is 100% live right now — verified via `tailscale serve status --json`, `AllowFunnel: {"ohama-2.tail318f12.ts.net:8443": true}`. Port 3000 is free (`lsof -i :3000` → empty). The moment **anything** binds `127.0.0.1:3000` — this project's kanban, a stray `npm start` default dev server, anything — it becomes live on `https://ohama-2.tail318f12.ts.net:8443/` to the entire internet, un-authenticated, with zero code in this project touching Tailscale at all.
**Relationship to 443/8443/10000:** Tailscale Funnel is documented to support HTTPS only on ports **443, 8443, 10000** (a hard platform limitation, not a local choice) — consistent with all three pre-existing entries using exactly those three numbers. `tailscale serve` (tailnet-only, no Funnel) is **not** restricted to that set; arbitrary ports work for serve-only entries. **Consequence for the plan: the new kanban Serve entry must use a port that is (a) not 3000, (b) not 443/8443/10000 (already claimed, and 8443 is the live Funnel port), and (c) genuinely free.** A concrete safe suggestion: `8444` (adjacent to but distinct from 8443, clearly not itself a Funnel port unless a plan task explicitly runs `tailscale funnel` against it — which this project must never do).
**Anti-pattern to avoid:** Never run `tailscale funnel` for anything in this project. Never let kanban's `--port`/`KANBAN_RUNTIME_PORT`/the `--port auto` retry logic land on 3000 — pin `--port 3484` explicitly (already done in the installed plist) and treat any drift toward 3000 as a hard failure in `verify_services.sh`-style checks (the existing `port-hygiene-no-3000` check already covers this and passed 15/15 at the fresh baseline taken during this research).

### Pattern 3: kanban's built-in remote-access passcode is a single global switch, not per-connection
**What:** Disassembled from the installed `dist/cli.js` (`/opt/homebrew/lib/node_modules/kanban/dist/cli.js`):
```js
// src/core/runtime-endpoint.ts (compiled)
DEFAULT_KANBAN_RUNTIME_HOST = "127.0.0.1";
LOCALHOST_HOSTS = new Set(["127.0.0.1", "::1", "localhost"]);
runtimeHost = process.env.KANBAN_RUNTIME_HOST?.trim() || options.host || DEFAULT_KANBAN_RUNTIME_HOST;
function isKanbanRemoteHost() {
  return !LOCALHOST_HOSTS.has(runtimeHost);   // <-- decided ONCE at process startup, from the --host flag
}
// src/cli entrypoint:
if (isKanbanRemoteHost()) {
  if (options.noPasscode) {
    disablePasscode();
    console.log("Passcode authentication disabled (--no-passcode). Ensure you have your own auth layer.");
  } else {
    const passcode = generatePasscode();       // fresh 8-char random passcode, regenerated EVERY startup, never persisted
    generateInternalToken();
    console.log(`\n🔐 Remote access passcode: ${passcode}\n\nShare this with users who need access.\n`);
  }
}
```
`isKanbanRemoteHost()` is a pure function of the `--host` CLI flag / `KANBAN_RUNTIME_HOST` env var chosen at process launch — **it is not evaluated per incoming connection or per source IP.** This means: if kanban is ever launched with `--host 0.0.0.0` (to make it LAN-reachable), the passcode gate turns on **globally**, applying equally to a LAN device *and* to a request that `tailscale serve` proxies in over loopback — there is no way, with a single kanban process, to be simultaneously "unauthenticated via Tailscale" and "passcode-gated via LAN." Whichever `--host` value is chosen applies to every path in.
**Consequence:** the only architecture that cleanly delivers both halves of the phase title ("Tailscale 무인증 + LAN 토큰 게이팅") from *this* CLI's actual behavior is: keep `--host 127.0.0.1` (default, unchanged) so the passcode gate never turns on, and let "LAN 토큰 게이팅" be satisfied by the fact that LAN has **no path in at all** (see NET-02 discussion below) rather than by an actual live passcode prompt on a LAN-bound socket.
**Also confirmed live:** `kanban --help` shows `--no-passcode` exists ("Disable auto-generated passcode for remote access (for advanced users behind a reverse proxy)") — this flag is irrelevant to the recommended architecture since `--host` never leaves `127.0.0.1`, but it is documented here because it is exactly the flag a *future* genuinely-LAN-bound kanban instance would need to actively *avoid* passing (leaving the passcode ON) if the user later wants real LAN+passcode access as a separate, explicit decision.

### Pattern 4: wrapper-level `--allowed-user-id` enforcement (NET-04)
**What:** `cline connect telegram --help` (verbatim, live):
```
Usage: telegram -k <TELEGRAM_BOT_TOKEN> [options]
  -k, --bot-token <token>    Telegram bot token
  --allowed-user-id <id>     Only allow this Telegram user ID to use the bot
  --no-tools                 Disable tools for Telegram sessions
  ...
```
Live-tested: `timeout 5 cline connect telegram -k "000000:FAKE_TOKEN_FOR_FLAG_TEST" --no-tools` (deliberately **no** `--allowed-user-id`) did **not** refuse to start. It proceeded straight into `Telegram getMe failed (401 Unauthorized): Unauthorized: invalid token specified` — i.e. it got as far as calling Telegram's live API and only failed because the fake token was rejected by Telegram itself, not because the flag was absent. This directly reconfirms Phase 5's research note: cline 3.0.53 accepts starting without `--allowed-user-id`.
**What "기동 실패" can truthfully mean:** Not "cline itself refuses." The honest, provable claim is: **our launchd-supervised invocation path (`phase-05/services/run_telegram_service.sh`) refuses to exec `cline connect telegram` at all** when `TELEGRAM_ALLOWED_USER_ID` (a new env var, parallel to the existing `TELEGRAM_BOT_TOKEN` slot already in the plist) is unset or empty. This is a wrapper-level pre-flight `exit 1` before the `exec`, verifiable by: (a) reading the wrapper script and seeing the guard, (b) running the wrapper directly with the env var unset and observing immediate non-zero exit + a clear log line, (c) `launchctl print` showing the launchd job settle into a fast-fail/backoff state rather than a running cline process, and (d) confirming via `ps`/`lsof` that no `cline connect telegram` process ever exists in that state. **The plan must state this distinction explicitly rather than imply the flag itself now blocks bare invocation** — a plan or verification doc that says "`--allowed-user-id` 없이 기동 실패한다" without naming the wrapper as the actual enforcement point would overclaim.

### Recommended file/process structure for Phase 6
```
phase-06/
├── net/
│   ├── config.env                     # new port for tailscale serve, TELEGRAM_ALLOWED_USER_ID slot name, etc. (reuse phase-05/services/config.env pattern, do not fork it)
│   ├── setup_tailscale_serve.sh       # idempotent: adds/updates ONE serve entry (never funnel), verifies the other 3 entries are untouched before/after
│   └── verify_network.sh              # NET-02/03/04 server-side checks: lsof :3000 empty, curl LAN IP:PORT fails, curl tailnet URL succeeds from the Mac itself, wrapper pre-flight rejects empty allowed-user-id
├── plists/
│   └── (telegram plist patch to add TELEGRAM_ALLOWED_USER_ID key, mirroring the existing empty TELEGRAM_BOT_TOKEN key pattern)
└── results/
    └── (evidence captures: tailscale serve status before/after, verify_services.sh before/after, NET-05 real-token trial transcript)
```
This mirrors Phase 5's `config.env` + idempotent setup script + standing verify script shape exactly — do not invent a new structure.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Reverse-proxying kanban to the tailnet | A custom nginx/Caddy TLS proxy | `tailscale serve` | Already installed, already terminates TLS with an auto-issued cert for the MagicDNS name, already has 3 working precedents on this exact Mac |
| A LAN access token, if genuinely wanted later | A bespoke shared-secret header/query-param scheme | kanban's built-in `--host <LAN_IP>` + auto-generated passcode (`src/security/passcode-manager.ts`) | It already exists in the shipped binary, is rate-limited (`RATE_LIMIT_MAX_ATTEMPTS`/`RATE_LIMIT_LOCKOUT_MS` constants confirmed present), and session-cookie-backed (`SESSION_TTL_MS` constant confirmed present) — reinventing this would be strictly worse |
| Telegram user allowlisting | Parsing/patching cline's compiled binary to add real enforcement | A wrapper pre-flight guard in `run_telegram_service.sh` | cline is pinned at 3.0.53 (Phase 1 decision) — cannot be patched; the wrapper is this project's own code and is the sanctioned place for such guards (same pattern as the existing CWD-rule assertion in the same file) |

**Key insight:** every "gate" this phase needs (TLS+identity for Tailscale, a passcode for LAN, refusing to start without an ID) already exists as a real, tested feature in either `tailscale` or `kanban`. The only genuinely custom code this phase should add is the thin wrapper pre-flight for `--allowed-user-id`, because that specific gap is real and confirmed live — everything else is wiring, not building.

## Common Pitfalls

### Pitfall 1: Reusing an existing Tailscale Serve/Funnel port
**What goes wrong:** Registering kanban's Serve entry on port 443, 8443, or 10000 either silently overwrites (or fails on) an existing, unrelated proxy target (8787/8788, origin unknown, not this project's), or — worst case, if landed on 8443 — instantly places kanban on the **public internet** via the already-armed Funnel rule.
**Why it happens:** Those three port numbers look like "the obvious ones" (they're literally the only ones Tailscale documents for HTTPS/Funnel), so a plan that doesn't first run `tailscale serve status` will reach for one of them.
**How to avoid:** Always run `tailscale serve status --json` immediately before adding any entry; assert the three existing entries are still present and byte-identical afterward; pick a port outside `{443, 8443, 10000, 3000}` (e.g. 8444) for kanban's entry.
**Warning signs:** `tailscale serve status` showing a fourth handler under an existing port, or `AllowFunnel` gaining a new `true` key you didn't explicitly intend.

### Pitfall 2: Binding kanban's `--host` to satisfy "LAN 토큰 게이팅" literally
**What goes wrong:** Setting `--host 0.0.0.0` (or the LAN IP) to give LAN devices a passcode-gated path also flips `isKanbanRemoteHost()` to `true` **globally**, which means Tailscale-Serve-proxied traffic (arriving over loopback from the Serve process) now also hits the passcode wall, breaking NET-01's "무인증" property. It also opens a brand-new socket directly on the LAN and Tailscale interfaces, which is exactly the "accidental wide bind" class of mistake the whole project has been defending against since Phase 2/3.
**Why it happens:** The roadmap phrase "LAN 토큰 게이팅" reads as "LAN should be reachable, just gated" — but kanban's actual implementation makes that incompatible with "Tailscale 무인증" from one process.
**How to avoid:** Default to the "no LAN bind at all" interpretation (see NET-02 discussion) unless CONTEXT.md/a human decision explicitly asks for a genuinely LAN-reachable, passcode-gated third path, in which case scope it as a clearly-separate, explicitly-approved addition, not an implicit side effect of opening Tailscale access.
**Warning signs:** `lsof -i :3484` showing a LISTEN on anything other than `127.0.0.1`; `kanban.log` printing a "🔐 Remote access passcode" banner when no one asked for LAN access.

### Pitfall 3: Treating `--allowed-user-id` as self-enforcing
**What goes wrong:** A plan or verification doc claims NET-04 is satisfied because `--allowed-user-id` is passed in the plist, without adding a pre-flight guard — but a future config drift (env var accidentally unset, a manual `restart_service.sh` invocation with a stale plist) would silently start an unrestricted bot, and nothing in cline itself would catch it.
**Why it happens:** The flag's name and description ("Only allow this Telegram user ID") strongly imply enforcement; the live test proving otherwise is non-obvious unless someone actually runs it with a fake token and watches how far it gets.
**How to avoid:** Add the wrapper-level `exit 1` pre-flight and make it the thing `verify_network.sh` actually checks (e.g., temporarily unset the env var, run the wrapper standalone, assert non-zero exit and no `cline` process spawned) — never assert NET-04 from "the plist contains the flag" alone.
**Warning signs:** A verification doc that cites the plist's `ProgramArguments` array as evidence, rather than an actual failed-startup transcript.

### Pitfall 4: Assuming the Telegram typing indicator covers a 64-second wait
**What goes wrong:** A plan assumes NET-05's Telegram half is satisfied because "cline shows typing," without checking that Telegram's typing indicator decays after ~5 seconds and that the compiled `cline` binary contains exactly one, non-repeating call site for it (`startTypingForPrivateMessage`, fired once on message receipt). During the ~64s prefill wait or a compaction-triggered summary call — both of which happen *before* any streamable token exists — there is no evidence of a resend loop or a placeholder "thinking…" message.
**Why it happens:** "Typing…" is such a standard bot UX pattern that it's easy to assume it's kept alive automatically; Telegram bot frameworks in other ecosystems often do implement a refresh loop, but this static analysis of the actual installed binary found none.
**How to avoid:** Do not assert NET-05's Telegram half from static reasoning. Run one real, token-backed `cline connect telegram` session (the first one this project will ever execute against a real token — flagged as unproven territory since Phase 5) during a genuinely long prefill/compaction window and directly observe what the Telegram client shows at t=10s, t=30s, t=64s. If the indicator has visibly decayed, this is a real gap the plan must either accept-and-document (mirroring how Phase 5 handled the reboot-persistence proxy-evidence gap) or address with a small enhancement (e.g., the wrapper or a hook periodically re-invoking a typing ping) — decide only after seeing the real behavior, not before.
**Warning signs:** A plan task that marks NET-05 "done" based only on server logs showing an RPC session is active, without an actual client-side observation (screen capture, screenshot, or an explicit human checklist item) of what the Telegram app displays over time.

### Pitfall 5: `tailscale` client/daemon version mismatch noise
**What goes wrong:** Every single `tailscale` CLI invocation on this Mac currently prints `Warning: client version "1.96.4-t41cb72f27" != tailscaled server version "1.96.5-t4ee448d3a-g74ffbefc2"` to stderr. A verification script that does naive `set -e` / treats any stderr output as failure will false-positive on every single tailscale command.
**Why it happens:** This Mac runs Tailscale via the macOS App Store "macsys" system-extension build (`/Applications/Tailscale.app`, network extension running as root PID under `io.tailscale.ipn.macsys.network-extension`), not Homebrew's `tailscaled` — the CLI binary at `/opt/homebrew/bin/tailscale` is a slightly different point release than the background daemon it's talking to. This is a pre-existing condition, not something Phase 6 caused or can easily fix without touching the user's Tailscale app installation (out of scope).
**How to avoid:** Any verify/setup script that shells out to `tailscale` must filter this exact warning line out of stderr before treating output as an error signal, and must not gate success/failure on stderr being empty.
**Warning signs:** A "clean run" requirement in a verify script failing purely because of this benign warning.

### Pitfall 6: Reboot-persistence of Tailscale Serve config is not directly observed
**What goes wrong:** Assuming `tailscale serve --bg` survives a reboot without ever having tested a reboot.
**What's actually known:** The Tailscale network extension (`io.tailscale.ipn.macsys.network-extension`) is a macOS **System Extension** running as root (PID 499 at research time, started "Thu 11AM" — days of uptime), which is a different and generally more robust persistence mechanism than a user LaunchAgent (system extensions activate at boot, independent of user login, once approved). Homebrew's `tailscale` CLI at `/opt/homebrew/bin/tailscale` is only a thin client talking to this daemon over a local socket — it is not itself what needs to survive reboot. Tailscale's documented behavior is that Serve/Funnel configuration is held in the daemon's own state and re-applied when the daemon starts. This Mac's Phase 5 precedent explicitly treated reboot persistence as "PROXY-evidenced, not observed" (RunAtLoad flags inspected, not a real reboot performed) — Phase 6 should do the same: cite the System Extension mechanism and RunAtLoad-equivalent activation as proxy evidence, and say plainly that an actual reboot was not performed to confirm.
**How to avoid overclaiming:** State this exactly as the confidence level it deserves (MEDIUM — mechanism understood and documented, not empirically verified by an actual reboot) rather than asserting persistence as a fact.

## Code Examples

### Verified: NET-03 port-3000 hygiene check (already exists, already passing)
```bash
# phase-05/services/verify_services.sh, "port hygiene" section — reran live during this research:
CHECK: PASS port-hygiene-no-3000
```
```
$ lsof -i :3000
# (empty output — nothing bound)
```

### Verified: kanban's runtime host/port flags (`kanban --help`, live)
```
Options:
  --host <ip>              Host IP to bind the server to (default: 127.0.0.1).
  --port <number|auto>     Runtime port (1-65535) or auto.
  --https                  Enable HTTPS. Requires both --cert and --key.
  --cert <path>            Path to a TLS certificate PEM file (implies HTTPS).
  --key <path>             Path to a TLS private key PEM file (implies HTTPS).
  --no-passcode            Disable auto-generated passcode for remote access
                           (for advanced users behind a reverse proxy).
Runtime URL: http://127.0.0.1:3484
```
(`--https`/`--cert`/`--key` are irrelevant to the recommended architecture — Tailscale Serve terminates TLS itself; kanban should keep speaking plain HTTP on loopback, exactly as it does today.)

### Verified: cline's Telegram connector flags (`cline connect telegram --help`, live)
```
Usage: telegram -k <TELEGRAM_BOT_TOKEN> [options]
  -m, --bot-username <name>  Telegram bot username; fetched from token if omitted
  -k, --bot-token <token>    Telegram bot token
  --provider <id>            Provider override
  --model <id>                Model override
  --cwd <path>                Workspace / cwd for runtime
  --mode <act|plan>           Agent mode (default: "act")
  -i, --interactive           Keep connector in foreground
  --no-tools                  Disable tools for Telegram sessions
  --allowed-user-id <id>      Only allow this Telegram user ID to use the bot
  --rpc-address <host:port>   RPC address (default: "127.0.0.1:25463")
```
(Confirms the wrapper's existing long-form-flag usage pattern from Phase 5 is still correct on this cline version; `-P`/`-m` ambiguity note from Phase 5 stands — `-m` is `--bot-username`, not a model shorthand.)

### Verified: kanban's task-status column enum (NET-05 Kanban-side evidence)
```
$ kanban task list --help
  --column <column>      Filter column: backlog | in_progress | review | done. trash is also accepted.
$ kanban task start --help
Start a task session and move task to in_progress.
```
`kanban task list --column in_progress` during a live long-running turn is the concrete, agent-verifiable proof for the Kanban half of NET-05.

### Verified: cline's Telegram typing-indicator implementation (disassembled from compiled binary)
```js
// found once, single call site, inside the Telegram provider class:
async startTyping($) {
  let J = this.resolveThreadId($);
  await this.telegramFetch("sendChatAction", {
    chat_id: J.chatId,
    message_thread_id: J.messageThreadId,
    action: "typing"
  });
}
// only invocation site, fired on incoming private message, fire-and-forget:
startTypingForPrivateMessage($, J, Y) {
  if ($.chat.type !== "private" || $.from?.is_bot) return;
  let X = this.startTyping(J).catch((Z) => {
    this.logger.warn("Failed to send Telegram typing action", {...});
  });
  Y?.waitUntil?.(X);
}
```
No `setInterval`/refresh loop calling `startTyping` was found anywhere else in the 88MB compiled binary (a full `strings` + targeted grep pass across the whole file was run). A separate `stream()` method exists that incrementally edits a Telegram message via `sendRichMessageDraft` as tokens arrive — but this only fires once actual output tokens exist to stream, which is *after* the prefill/compaction wait NET-05 is actually asking about, so it does not help for the two specific waits named in the requirement.

## State of the Art

| Old assumption (from context handed into this research) | Current finding | Impact |
|-----------|------------------|--------|
| "`--allowed-user-id` is optional" (Phase 5) | Reconfirmed live with a fresh test: not just optional, actively bypassed all the way to a real Telegram API call | Confirms wrapper-level enforcement is the only honest fix; no ambiguity left |
| Reboot persistence "proxy-evidenced, not observed" (Phase 5, re: launchd) | Same posture now applies to Tailscale Serve config, but the underlying mechanism (macOS System Extension, root-owned, days of uptime) is structurally more boot-independent than a user LaunchAgent | Slightly higher confidence than Phase 5's launchd case, but still not empirically reboot-tested — say so |
| contextWindow correction (compaction works, 26.1k trigger) | NET-05's "①/②" wording already reflects this correction in REQUIREMENTS.md (2026-08-30 addendum: "압축이 정상 작동하므로 '죽은 작업' 상태가 아니라 '압축 중' 상태가 필요하다") | The card/chat status during a long wait must read as "actively compacting," not "stalled" — kanban's generic `in_progress` column satisfies this at the granularity asked (it doesn't distinguish sub-states, and the requirement doesn't ask it to) |

**Deprecated/outdated:** none — this is a fast-moving live-system check, not a library-version question. Re-verify `tailscale serve status` immediately before executing any Phase 6 plan task, since it is genuinely live, mutable state on this Mac that could change between research and execution.

## Open Questions

1. **Does the Telegram typing indicator (or any other visible signal) actually survive a real 64-second prefill wait, or a compaction-triggered summary call?**
   - What we know: exactly one, non-repeating `sendChatAction`/typing call exists in the compiled binary; Telegram's own protocol decays typing after ~5s; no placeholder message; the rich-draft streaming path only fires once tokens exist, which is after the wait in question.
   - What's unclear: whether some other layer (the RPC session/hub, not the per-provider connector code grepped here) independently re-pings typing, or whether Telegram's client-side behavior in practice holds the "typing…" state visible longer than the protocol's nominal 5s in some client versions.
   - Recommendation: the plan MUST include a live, real-token trial (first one this project runs) that watches an actual Telegram client through a genuine long wait and records what is/isn't visible at various timestamps, before NET-05's Telegram half is marked done. Do not fabricate this evidence — it is explicitly named `human_needed` per the locked decisions, but the *server-side* half (does cline attempt to send anything at all, checkable via `telegram-connect.log`) should still be captured by the agent as supporting evidence.

2. **Exactly which port should the new `tailscale serve` entry for kanban use?**
   - What we know: must avoid 3000, 443, 8443, 10000 (all claimed); arbitrary ports are permitted for tailnet-only Serve (not Funnel).
   - What's unclear: whether there's a project convention/preference for the specific number (nothing in prior phases suggests one).
   - Recommendation: 8444 is a reasonable, clearly-non-Funnel-adjacent default; the plan should pin whatever it picks into `phase-06/net/config.env` the same way Phase 5 pinned `--port 3484`.

3. **Does the LAN-token-gating goal, as literally phrased in the roadmap ("LAN 토큰 게이팅"), actually want a genuinely-reachable, passcode-gated LAN path, or is "LAN cannot get in at all" an acceptable/preferred reading?**
   - What we know: kanban's own passcode mechanism cannot deliver both "Tailscale unauthenticated" and "LAN passcode-gated" from one process (Pattern 3 above); "no LAN bind" is the only architecture that cleanly satisfies both NET-01 and NET-02 as literally worded, and it's the interpretation the research brief's own framing pointed toward.
   - What's unclear: whether the user actually wants a genuine LAN-fallback path (e.g., for a device that can't run Tailscale) as a deliberate, separate, explicitly-scoped addition.
   - Recommendation: default to "no LAN bind" for this phase (satisfies both criteria with the strongest, most defensible evidence and zero new attack surface); if the user later wants real LAN+passcode access, that is a new, explicit decision — not something to slip in as a side effect of opening Tailscale.

## iPad Verification Checklist (for the user — human_needed, NET-01 & NET-05)

Both tailnet iPad peers are currently offline (`ipad-mini-6th-gen-wifi`, 29d; `ipad165`, 4d) — they will likely need Tailscale re-login after being offline this long. Concrete steps to leave in the plan/verification doc:

1. On the iPad: open the Tailscale app, confirm it shows **Connected** and the same tailnet (`ohama100@`). If not connected, log in again (Tailscale login sessions can expire after extended offline periods).
2. In iPad Safari, open `https://ohama-2.tail318f12.ts.net:<the new Serve port, e.g. 8444>/` (exact URL to be pinned once the plan picks the port). Expect: the Kanban board loads directly, **no passcode prompt**, no certificate warning (Tailscale auto-issues a trusted cert for the MagicDNS name).
3. Confirm the card list is visible and at least one diff can be opened and reviewed (scrolling/tap targets work at iPad width — this is the actual NET-01 success criterion, not just "page loads").
4. Turn off Wi-Fi / disconnect Tailscale on the iPad (or use a second, non-Tailscale device on the same LAN) and try `https://192.168.75.108:3484/` (the Mac's LAN IP + kanban's own port) or the LAN address directly. Expect: connection fails outright (no route/refused) — this is NET-02's iPad-side confirmation, complementing the agent's own LAN-refusal proof.
5. During a real, long request (near the 32K/64s prefill window or a compaction event), watch **both** the Kanban card (expect it to sit in the "In Progress" column, not appear stalled/red/errored) and the Telegram conversation with the bot (expect... to be determined by the live trial in Open Question 1 above — the checklist should tell the user exactly what to look for once that trial's actual result is known, not before).

## Sources

### Primary (HIGH confidence — live commands run on this Mac during this research)
- `tailscale status`, `tailscale serve status`, `tailscale serve status --json`, `tailscale serve --help`, `tailscale funnel --help`, `tailscale version` — run live, 2026-08-30
- `kanban --help`, `kanban task --help`, `kanban task list --help`, `kanban task update --help`, `kanban task start --help`, `kanban hooks --help` — run live
- `cline connect telegram --help` — run live
- `strings`/grep against `/opt/homebrew/lib/node_modules/kanban/dist/cli.js` (passcode-manager, runtime-endpoint modules) — direct disassembly of shipped code
- `strings`/grep against `/opt/homebrew/lib/node_modules/cline/bin/.cline` (compiled Bun binary, 88MB) — direct disassembly of shipped code, Telegram connector class
- Live negative test: `cline connect telegram -k <fake> --no-tools` (no `--allowed-user-id`) → proceeded to real Telegram API call, confirming non-enforcement
- `lsof -i :3000`, `ifconfig`, `ps aux | grep tailscale`, `sfltool dumpbtm` (attempted; hung on a permission prompt, killed) — live system state
- `bash phase-05/services/verify_services.sh` — run live, fresh baseline: **15/15 PASS**, results at `phase-05/results/20260830T043509Z-gate`
- `.planning/REQUIREMENTS.md` (NET-01..05 exact wording, including the 2026-08-30 compaction-status addendum on NET-05)
- `~/Library/LaunchAgents/com.ohama.kanban.plist`, `~/Library/LaunchAgents/com.ohama.telegram-connect.plist`, `phase-02/infra/restart_service.sh`, `phase-05/services/verify_services.sh` — read directly

### Secondary (MEDIUM confidence)
- Tailscale Funnel's documented 443/8443/10000-only restriction — well-established, widely-documented Tailscale platform limitation; not independently re-derived from source here but consistent with the three live entries observed
- Reboot persistence of the Tailscale System Extension and of `tailscale serve` config — mechanism understood (root-owned System Extension, daemon-side state) but not confirmed via an actual reboot in this research session

### Tertiary (LOW confidence)
- None — every claim above traces to a live command or direct binary inspection performed during this research session.

## Metadata

**Confidence breakdown:**
- Standard stack (Tailscale Serve/Funnel mechanics, kanban flags, cline flags): HIGH — all verified live against this exact Mac and these exact pinned versions
- Architecture (loopback-fronted Serve, passcode-gate-is-global finding, wrapper pre-flight for NET-04): HIGH — derived directly from disassembling the actual shipped code, not from documentation guesses
- Pitfalls: HIGH for 1-3 and 5 (directly observed/tested); MEDIUM for 4 and 6 (strong static evidence / documented mechanism, but genuinely require a live trial or a reboot respectively to close out)

**Research date:** 2026-08-30
**Valid until:** This is unusually perishable — the pre-existing Tailscale Serve/Funnel configuration (§Pattern 1/2) is live, mutable state on this Mac that could change at any time for reasons outside this project. **Re-run `tailscale serve status --json` immediately before executing any Phase 6 plan task**, do not trust this document's captured snapshot as still-current without that re-check. The `kanban`/`cline` binary findings are valid as long as the pinned versions (kanban per Phase 1, cline 3.0.53) don't change.
