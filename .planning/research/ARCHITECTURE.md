# Architecture Research: Cline Persistent Server on macOS

**Domain:** Local-first agentic coding server (Cline) layered on an existing, validated local-LLM inference stack
**Researched:** 2026-08-29
**Confidence:** HIGH for topology/ports/access-control mechanics (verified against live system + Cline docs); MEDIUM for exact token-counting implementation details inside role_shim.py (implementation-level, not yet built); MEDIUM for launchd boot-ordering guidance (launchd has no native dependency graph, so guidance is "design for tolerance," not a verified timing number)

---

## 1. Target Topology

### Existing (validated, do not modify behavior)

```text
  client → litellm(:4000) → role-shim(:8011) → mlx_vlm.server(:8000)
                                                Qwen3.8-Flash-Next-MLX-oQ4 + MTP drafter
                                                --max-kv-size 32768
```

### Target — with the three new surfaces + guard

```text
                                    TAILSCALE (100.64.0.0/10)              LAN (192.168.75.0/24)
                                    unauthenticated                        token required
                                            │                                      │
                                            │ http://100.118.140.2:3484           │ http://192.168.75.x:3484
                                            ▼                                      ▼
                              ┌───────────────────────────────────────────────────────┐
                              │        com.ohama.cline-kanban-gateway  (NEW, :3484)     │
                              │  binds 0.0.0.0:3484 · inspects source IP                │
                              │  src ∈ 100.64.0.0/10 or 127.0.0.1 → pass through        │
                              │  else → require Bearer token, else 401                  │
                              └───────────────────────┬──────────────────────────────┘
                                                        │ proxies to loopback
                                                        ▼
                              ┌───────────────────────────────────────────────────────┐
                              │        com.ohama.cline-kanban  (NEW, 127.0.0.1:33484)   │
                              │  Kanban web UI · per-card git worktrees                 │
                              │  workspace root = ~/projs/cline-tests/workspace/        │
                              └───────────────────────┬──────────────────────────────┘
                                                        │
  Telegram (outbound long-poll,          ┌─────────────┤
  no inbound port)                       │             │
        ▲                                │             │
        │                                ▼             ▼
  ┌─────────────────────┐      ┌──────────────────────────────┐
  │ com.ohama.cline-     │      │  headless CLI wrapper (NEW)   │
  │ telegram  (NEW)      │      │  script only — NOT a service   │
  │ --allowed-user-id    │      │  (project scope: no service)   │
  │ --hook-command        │      └───────────────┬──────────────┘
  └──────────┬───────────┘                        │
             │                                    │
             └──────────────┬─────────────────────┘
                              │  all three surfaces share ONE Cline agent core,
                              │  configured with provider = openai-compatible,
                              │  base_url = http://localhost:4000/v1, model = flashnext,
                              │  contextWindow forced to 32768 (overrides 128k fallback)
                              ▼
              ┌───────────────────────────────────────────────────────┐
              │   litellm (:4000)   — UNCHANGED, existing validated    │
              └───────────────────────┬──────────────────────────────┘
                                       ▼
              ┌───────────────────────────────────────────────────────┐
              │   role-shim (:8011) — role normalization UNCHANGED     │
              │   + ADDITIVE: 32K guard (NEW logic, same process)      │
              │     count tokens in incoming messages before forward  │
              │     > 32768 → reject 413, do NOT forward, do NOT trunc │
              └───────────────────────┬──────────────────────────────┘
                                       ▼
              ┌───────────────────────────────────────────────────────┐
              │   mlx_vlm.server (:8000) — UNCHANGED, --max-kv-size    │
              │   32768, Qwen3.8-Flash-Next-MLX-oQ4 + MTP drafter      │
              └───────────────────────────────────────────────────────┘
```

### New components at a glance

| Component | Port | New/Modified | Binds to |
|---|---|---|---|
| `cline-kanban-gateway` | 3484 (external, documented) | NEW process | `0.0.0.0:3484` |
| `cline-kanban` (Kanban itself) | 33484 (internal, arbitrary) | NEW process | `127.0.0.1:33484` only |
| `cline-telegram` | none (outbound long-poll to Telegram API) | NEW process | n/a |
| headless CLI wrapper | none | NEW script, not a service | n/a |
| 32K guard | inside :8011 | ADDITIVE code in `role_shim.py` | n/a (logic, not a port) |
| litellm, role-shim (existing), mlx_vlm.server | 4000, 8011, 8000 | UNCHANGED behavior | 127.0.0.1 (loopback, per existing config) |

**Why Kanban itself moves off 3484 internally:** Kanban has zero built-in authentication (verified — see §3). The only way to enforce "Tailscale unauthenticated, LAN token-gated" without trusting Kanban's own code is to put something in front of it that owns the externally-visible port. Kanban keeps its documented default (bind to loopback) and never becomes reachable except through the gateway.

---

## 2. Component Boundaries

| Component | Responsibility | Talks to |
|---|---|---|
| `cline-kanban-gateway` (NEW) | Single point of network exposure for the web surface. Source-IP classification (tailnet vs LAN), token check, reverse-proxy to Kanban | Kanban (127.0.0.1:33484) upstream; iPads/laptops downstream |
| `cline-kanban` (NEW) | Kanban board UI, per-card git worktrees, task orchestration against the Cline agent core | Cline agent core (in-process or CLI subprocess) → litellm :4000 |
| `cline-telegram` (NEW) | Telegram bot connector: long-polls Telegram's servers, maps chat → Cline agent session, `--allowed-user-id` + optional `--hook-command` gate incoming messages | Telegram Bot API (outbound only) → Cline agent core → litellm :4000 |
| headless CLI wrapper (NEW) | Thin script wrapping `cline` invocation with fixed flags (model, context window, sandbox args); no listening port | Cline agent core → litellm :4000 |
| Cline agent core (shared) | Task loop, tool execution, `.clineignore`/command-permission enforcement | litellm :4000 as its only model backend |
| litellm :4000 (existing) | OpenAI-compatible endpoint, alias routing (`flashnext`) | role-shim :8011 |
| role-shim :8011 (existing + additive guard) | Role normalization (unchanged) + NEW: reject requests whose message tokens exceed 32768 | mlx_vlm.server :8000 |
| mlx_vlm.server :8000 (existing) | Model inference, hard `--max-kv-size 32768` | — |

---

## 3. Where the 32K Guard Belongs

### Options evaluated

| Option | What it catches | What it misses / risks |
|---|---|---|
| **(a) Inside `role_shim.py` (:8011)** | Every request that reaches the model, from **any** current or future consumer of the shared pipeline (Cline, and the dormant claude-proxy/hermes/openjarvis aliases that also route through :8011) — structurally guaranteed, because litellm's `flashnext`/`flashnext-codex` aliases hard-code `api_base: http://localhost:8011/v1`. Catches the "Cline believes it has 128k" case directly: regardless of what context window Cline *thinks* it has, the actual message array it sends is what role-shim inspects. | Needs its own token counter (mlx_vlm.server's tokenizer isn't exposed to role-shim as a library call — must load the Qwen tokenizer separately, e.g. via `transformers.AutoTokenizer.from_pretrained()` on the on-disk model path). A bug here has blast radius across every consumer of :8011, not just Cline — mitigated by keeping the guard as a small, isolated, well-tested addition, and by fail-closed semantics (see below). |
| **(b) litellm config (:4000)** | Same requests, if implemented as a per-model callback/guardrail scoped to the `flashnext` aliases. | litellm's guardrail/callback system is heavier machinery for this need, and `litellm-config.yaml` is a *shared, synced, validated* file (`sync.sh` tracks it) consumed by other downstream projects (claude-proxy, hermes, openjarvis) even though they're currently inactive. Editing it conflates "Cline-specific safety" with "shared infra config," and callbacks are less trivially unit-testable than a single Python function in role-shim. |
| **(c) A new proxy in front of litellm** | Only requests where Cline's `base_url` is correctly pointed at the new proxy instead of at `:4000` directly. | This is the fatal flaw: the guard's effectiveness now depends on a *client-side config value being right*. If Cline (or a future surface, or a manual `curl` test) is ever pointed at `:4000` directly — which is exactly how the existing validated pipeline is documented to be used — the guard is silently bypassed. This reintroduces a silent-failure mode instead of eliminating one. Also adds a new port/service for no structural gain over (a). |
| **(d) Cline-side config only** | Nothing structurally — this is "pinning Cline's own context window to 32768," which is a **separate, already-required** item in PROJECT.md, not a substitute for a gateway guard. It reduces how *often* the guard is hit but cannot be the guard itself, because it lives entirely inside the untrusted client and is exactly the layer with the known #12520/#13457 128k-fallback bug. | Does not protect the shared model resource from any other future caller, and does not protect against the very bug this project exists to defend against. |

### Recommendation: (a) — additive guard inside `role_shim.py`

**Rationale, tied to structure, not just preference:**

1. **Structural guarantee, not configuration-dependent.** Every path from litellm's `flashnext`/`flashnext-codex` aliases to the model physically passes through `:8011` today, per `litellm-config.yaml`. There is no client-side setting that can route around it. This directly closes the "Cline believes it has 128k" failure mode: the guard inspects the actual bytes sent, not Cline's belief about its own limits.
2. **Correct architectural layer for a hardware constraint.** `--max-kv-size 32768` is a property of the *model process*, not of Cline. Any caller — Cline today, a revived hermes/openjarvis tomorrow — that exceeds it risks degrading or corrupting the one shared 104 GiB model instance this Mac can run. Enforcing the limit at the last shared hop before the model protects the resource for everyone, which is the textbook place to put a resource-level guard.
3. **Minimal new infrastructure.** No new port, no new service, no new "did the client point at the right thing" failure mode. It is a small, additive change (~10–20 lines) to a file that already parses the JSON body (`fix_messages`) — the guard slots into logic that already exists.
4. **Consistent with the stated constraint** ("does not change existing :8000/:8011/:4000 behavior beyond an additive guard") — this is literally naming :8011 as an acceptable guard location.

**Mitigating the one real risk (blast radius across all :8011 consumers):** implement the guard as an isolated function with its own tests (the regression test PROJECT.md already requires), and make it **fail closed**: if token counting itself throws (bad tokenizer load, malformed body, unexpected shape), reject the request rather than silently passing it through. A guard that fails open on its own internal errors is worse than no guard — it would look present in code review while being absent in the one scenario (an edge case in the request shape) most likely to coincide with an oversized request.

### Reject vs. Truncate — Recommendation: REJECT

**Argument, anchored to the Core Value ("no silent failure"):**

Truncation is a second, independent, uncoordinated place where content gets silently cut — on top of the fallback bug the project exists to defend against. A gateway-level truncator has no understanding of message structure: it could cut mid-tool-call JSON, mid-code-block, or drop the system prompt entirely depending on cut direction, none of which would raise an error anywhere. The output would still come back as a normal-looking (if subtly wrong) response — precisely the "quietly wrong" behavior category the project is built to eliminate, now duplicated instead of removed. It also cannot be proven correct: "truncation produced acceptable output" is a subjective, per-model judgment that would need re-validation on every model swap, whereas a hard reject is trivially provable by the required regression test (`assert response.status == 413`, deterministic, model-agnostic).

A REJECT (HTTP 413, forwarded verbatim through litellm to Cline) surfaces immediately as a visible tool/request failure in whichever surface triggered it (Kanban shows a failed task step, Telegram relays an error message, the headless wrapper exits non-zero) — the human or the agent can react to it. This is strictly compatible with the project's other belt-and-suspenders item ("pin Cline's context window to 32768"): correct client-side config should make the guard rarely fire at all; the guard exists for the case where that pin fails or is bypassed, and in that case it must fail loud.

---

## 4. Access Control Architecture

### Requirement recap
Tailscale access: unauthenticated. LAN access: token required. No internet exposure.

### Facts gathered from this machine (2026-08-29)

| Fact | Value |
|---|---|
| This Mac's Tailscale hostname | `ohama-2` |
| This Mac's Tailscale IPv4 | `100.118.140.2` (from `tailscale ip -4`) |
| This Mac's MagicDNS FQDN | `ohama-2.tail318f12.ts.net` (derived from the active Funnel entry in `tailscale status`) |
| Tailnet CGNAT range, confirmed live on this box | `100.64.0.0/10`, routed via `utun4` (`netstat -rn` shows `100.64/10 link#23 UCS utun4`) |
| LAN interface / subnet | `en0`, currently `192.168.75.108/24`, gateway `192.168.75.1` (DHCP — not guaranteed stable across router reboots) |
| Registered iPads (tailnet peers) | `ipad165` → `100.101.4.74` (offline, last seen 3d ago); `ipad-mini-6th-gen-wifi` → `100.88.149.99` (offline, last seen 28d ago). Both are already tailnet members — no additional Tailscale ACL work is needed for them to reach `100.118.140.2:3484` under default personal-account ACLs. |
| **Pre-existing risk found during this research** | `tailscale status` shows **Funnel is currently ON** for this machine (`https://ohama-2.tail318f12.ts.net:8443`) — i.e. something on this Mac is already exposed to the public internet via Tailscale Funnel. This is unrelated to port 8443/Cline, but it is a live violation of the project's own constraint ("no internet exposure") in spirit if ever extended. **Do not enable Funnel for :3484 or any new Cline port; this should be independently audited/turned off, but that is outside this project's scope.** |

Discovery commands to reproduce these facts: `tailscale status` (hostname, peers, Funnel state), `tailscale ip -4` (this box's tailnet IP), `ipconfig getifaddr en0` (current LAN IP), `netstat -rn -f inet | grep 100.64` (confirms CGNAT route exists).

### Options evaluated

| Option | How | Trade-off |
|---|---|---|
| **1. Interface-bound dual-port** | Kanban stays on loopback; one process opens a socket on the *specific* tailnet IP (`100.118.140.2:3484`, no auth) and a *second* socket on a different port for LAN (`0.0.0.0:3485` or `192.168.75.x:3485`, token required) | Strongest boundary — kernel-level separation means a bug in the token-check code literally cannot leak, because LAN clients physically cannot reach the tailnet-bound socket's file descriptor. Cost: cannot use the same port number 3484 for both (binding `0.0.0.0:3484` and a specific-IP `:3484` on the same host conflicts), so it means two different port numbers for two networks. |
| **2. Single proxy, wildcard bind, source-IP inspection** | One process binds `0.0.0.0:3484`. On each connection, check `remote_addr`: if in `100.64.0.0/10` or `127.0.0.1` → pass through; else → require `Authorization: Bearer <token>`, else `401` | Preserves the single documented port `:3484` for every client. Risk is concentrated in one code path (the IP-range check) — mitigated by using Python's standard `ipaddress` module (no hand-rolled CIDR math) and by failing **closed**: any error/ambiguity in determining the source IP defaults to "require token," never to "allow." |
| **3. Tailscale Serve/Funnel** | `tailscale serve` proxies a local port to the tailnet only (not public), with Tailscale injecting an authenticated identity header | Solves the tailnet side elegantly (no app code needed for identity), but does **nothing** for the LAN-token requirement — LAN access still needs a separate, hand-built path. Also, `funnel` (a related but distinct command) would expose to the public internet, which must never be turned on for this port. Net effect: still need a custom LAN path, so this doesn't reduce total complexity versus option 2, and adds a second mechanism to reason about. |

### Recommendation: Option 2 — single gateway process, wildcard bind, source-IP classification, fail-closed

Chosen because it keeps the single externally-documented port (`:3484`) that PROJECT.md specifies, and the residual risk (a bug in IP-range logic) is concretely mitigated rather than theoretical:

- Use the standard library's `ipaddress.ip_address(remote_addr) in ipaddress.ip_network('100.64.0.0/10')` — a single, unit-testable predicate, not hand-rolled string matching.
- **Fail closed on ambiguity**: if `remote_addr` can't be parsed, or arrives in an unexpected form (e.g. IPv6-mapped IPv4 `::ffff:192.168.75.x`), treat it as untrusted and demand a token. Never default to "allow."
- Treat `127.0.0.1` as trusted (no token) — local shell access on this Mac already implies full access to everything else on it, so there is no additional exposure in trusting loopback.
- Token delivery: a static bearer token (e.g. `Authorization: Bearer <token>` header, or a query param fallback for browser bookmarking from a LAN laptop) checked with constant-time comparison; the token value itself is out of scope for this architecture doc (a secrets/config concern) but the check must live in this same gateway process, not in Kanban.

**Upgrade path if this is ever judged insufficient:** move to Option 1 (interface-bound dual-port) for a kernel-enforced boundary at the cost of a second port number. Not recommended as the default because the added operational complexity (two listeners, two URLs to remember/bookmark) isn't justified against a single-user personal deployment behind a home LAN, but it is a clean escalation if the token-based LAN gate is ever found unconvincing.

**Telegram and the headless wrapper are explicitly out of this access-control surface.** The Telegram connector makes outbound long-polling connections to Telegram's servers and opens no inbound port on this Mac; its access control is the bot token (held by Telegram) plus `--allowed-user-id` restricting it to ohama's own Telegram account, independent of tailnet/LAN. The headless wrapper is a local script with no listening port at all (per PROJECT.md scope: "헤드리스 서비스화는 보류"). Neither needs the gateway above.

---

## 5. Sandbox + Repo Whitelist Architecture

### What Cline offers natively — and how enforceable each actually is

| Mechanism | Enforced or advisory | Notes |
|---|---|---|
| `.clineignore` | **Enforced at the Cline tool layer** for `read_file`/`write_to_file`/`list_files`-class tools — blocked calls return a structured error the agent can't override by asking nicely. | **Does not constrain `execute_command`.** A shell command like `cat ~/.ssh/id_rsa` or `python -c "print(open(x).read())"` bypasses `.clineignore` entirely, because it's not a Cline file-tool call — it's arbitrary shell execution. This is a real, documented gap, not a hypothetical. |
| Workspace root (the git repo Kanban/CLI is pointed at) | **Advisory by default.** Cline's tools default to paths relative to the opened workspace, but nothing stops absolute paths or `cd ..` inside `execute_command`. | Per-card git worktrees (Kanban) isolate *concurrent cards from each other* (merge-conflict prevention) — they are not a security boundary against reaching outside the repo tree. |
| `CLINE_COMMAND_PERMISSIONS` (command allowlist env var) | **Enforced at the Cline tool-execution layer**, before a subprocess is even spawned. | Real and useful — can restrict `execute_command` to an allowlist (e.g. `git`, `npm`, `python`, deny `rm`, `curl`, `sudo`). Reduces but does not eliminate risk: an allowed command like `python` can still read/write arbitrary paths within its own semantics. |
| `--hook-command` (connector-level gate) | **Enforced**, but only for *which incoming messages/senders* are allowed to start a task at all (Telegram/Discord/etc.) — it gates admission to the agent, not what the agent can subsequently touch on disk. | Relevant to the Telegram surface's access control, not to filesystem sandboxing. |

**Honest bottom line: nothing Cline offers natively is a real security sandbox against a misbehaving or confused agent using `execute_command`.** The only mechanisms that are unconditionally enforced regardless of what Cline's own code does are OS-level.

### What must be enforced outside Cline

- **macOS Seatbelt (`sandbox-exec`)** wrapping the Cline process (and everything it spawns): a profile that allows read/write only under a whitelisted path set and denies everything else — including explicit denies for `~/.ssh`, `~/.aws`, `~/local-llm-settings` secrets, and Cline's own credential store (`~/.cline/data/settings/providers.json`). This is enforced by the kernel: even `execute_command` running `rm -rf ~` is denied at the syscall level for paths outside the profile, regardless of any bug or gap in Cline's own logic. `sandbox-exec` is a deprecated public API but remains functional on current macOS and requires no extra running process (unlike Docker Desktop's VM, which is worth avoiding here given the constraint that Cline services must not add heavy processes competing for memory against the 104 GiB model).
- A **dedicated restricted OS user account** is the theoretically stronger alternative but is disproportionate for a single-user personal machine (it would complicate access to the user's own home-directory resources, GPU, and Tailscale identity) — not recommended here; note it only as the ceiling option if requirements escalate.

### Concrete proposed layout

```
~/projs/cline-tests/
  workspace/                          ← sandbox root; the ONLY tree the agent can touch
    ALLOWED_REPOS.json                ← single source of truth: list of real absolute repo paths
    <repo-name-1>/  → symlink to real repo path (generated FROM ALLOWED_REPOS.json)
    <repo-name-2>/  → symlink to real repo path
    .clineignore                      ← repo-level template (secrets, .env, node_modules, etc.)
    sandbox.sb                        ← Seatbelt profile, GENERATED from ALLOWED_REPOS.json
  bench/                              ← test harness + captured artifacts — deliberately OUTSIDE
                                          the sandbox (see §6): the agent must not be able to read
                                          its own past prompts/results while doing sandboxed tasks
```

**Known gotcha to design around, not gloss over:** `sandbox-exec` evaluates *resolved* (canonical) paths. Whitelisting `~/projs/cline-tests/workspace/**` does **not** automatically extend to whatever a symlink under it points at — the profile must separately list each real target path. This is exactly why `ALLOWED_REPOS.json` should be the single generator input for **both** the symlinks (for Kanban board browsing/UX) and the Seatbelt profile (for actual enforcement): one file, one script that regenerates both, so the "what's visible" and "what's actually allowed" lists cannot drift apart. Treat this generator step (`sandbox.sb` regeneration) as itself needing a smoke test — a whitelist that silently fails to regenerate after a repo is added is exactly the "convenience worked, safety net didn't" failure mode this project's Core Value is meant to rule out.

---

## 6. Service Supervision Topology

### New launchd labels (proposed, following the existing `com.ohama.*` convention)

| Label | Runs | KeepAlive | ThrottleInterval | Rationale |
|---|---|---|---|---|
| `com.ohama.cline-kanban` | Kanban, `--host 127.0.0.1 --port 33484` | `true` | `10` | Lightweight web server, matches existing convention (litellm/role-shim both use 10) |
| `com.ohama.cline-kanban-gateway` | the NEW access-control reverse proxy, `0.0.0.0:3484` | `true` | `10` | Same class of process as role-shim; cheap to restart |
| `com.ohama.cline-telegram` | Telegram connector | `true` | `10` | Long-polling client process; token injected via env var, left blank until BotFather token exists (per PROJECT.md scope) |

The headless wrapper is explicitly **not** a launchd service (PROJECT.md: "서비스화는 보류") and is not listed here.

### Boot ordering — there is no real dependency graph to lean on

launchd (LaunchAgents, GUI session) has **no supported mechanism for "start after label X is healthy."** All `RunAtLoad` agents in a login session start close together with no guaranteed order. This matters directly here because `com.ohama.flashnext` loads a 104 GiB model into memory and is measurably not instantly ready (mode-switch alone takes 20–45s per `VALIDATED.md`; a cold boot load of the full model is not measured in the existing docs but is clearly non-trivial and should not be assumed fast).

**Design implication: every new Cline service must tolerate litellm/role-shim/flashnext not being ready yet, by design, not by luck.**

- The existing services already do this implicitly: `role-shim` and `litellm` come up immediately (`RunAtLoad`) and simply return upstream errors until `flashnext` is warm; `KeepAlive` + `ThrottleInterval` keeps them alive through any transient failures rather than crash-looping hard. New services should mirror this: **come up immediately, surface upstream failures visibly, never silently retry-and-hide.**
- `cline-kanban`, `cline-kanban-gateway`, and `cline-telegram` should all start unconditionally at boot. If a user opens Kanban or messages the Telegram bot before `flashnext` is warm, the request should fail with a clear, visible error (Kanban shows a failed task step; Telegram relays an error message back to the chat) — this is consistent with "no silent failure," not a regression from it.
- **Do not attempt to hand-roll a "wait for :4000 to answer" sleep-loop inside a `ProgramArguments` wrapper as a substitute for a real dependency graph** — it would only delay the *symptom* (unready model) without eliminating it, since the model can still go down later (crash, restart) after the wait succeeded once. Handle "not ready" as an ongoing, recurring condition each service must tolerate every time it makes a request, not as a one-time boot gate.
- **Optional, not required:** a `/healthz` endpoint on `cline-kanban-gateway` that checks `:4000` reachability, so Kanban's own UI can show a "model warming up" banner instead of a raw connection error — a convenience layered on top of the tolerant design above, not a substitute for it.

### Logs and registration

Following house rules: logs to `~/llm-system/services/logs/` (e.g. `cline-kanban.log`, `cline-kanban-gateway.log`, `cline-telegram.log`), plist originals in `~/Library/LaunchAgents/`, copies in `~/local-llm-settings/launchagents/`, and `~/local-llm-settings/sync.sh` updated to track the three new labels (add to the `LABELS` array and `STATE.md`'s port table) once they exist — this is an explicit PROJECT.md requirement, not optional polish.

---

## 7. Test Harness Placement

### Requirement recap
cline-bench runs must be reproducible, diffable, and preserve **both** prompts and results as files.

### Proposed layout

```
~/projs/cline-tests/bench/
  cline-bench/                         ← clean checkout of github.com/cline/cline-bench, unmodified
  runs/
    2026-08-29T1400_32k-guard-regression/
      config.json                      ← task IDs run, model alias, context limit used, cline-bench git SHA
      prompts/
        <task-id>.request.json         ← exact request body sent, verbatim
      results/
        <task-id>.response.json        ← exact response received, verbatim
        <task-id>.verdict.json         ← harness pass/fail grading output
      summary.md                       ← human-readable rollup with links to the raw files above
    2026-08-30T0900_partial-suite/
      ...
  latest → runs/<most-recent>          ← symlink, convenience only, never the source of truth
```

**Why outside the sandbox (§5):** `bench/` must be **excluded** from `ALLOWED_REPOS.json` / the Seatbelt whitelist. If the agent under test could read `bench/runs/**`, a later benchmark task could accidentally (or via prompt injection from a task's repo content) read its own or a prior run's prompts/answers, contaminating results. Keep `workspace/` (agent-accessible) and `bench/` (harness-only) as sibling directories, never nested.

**Why timestamped, self-contained run directories:** each run captures its own `config.json` recording *which* subset of cline-bench tasks ran and against which harness commit — required because full-suite completion is explicitly out of scope (2400s per-task timeout vs. 64s TTFT at 32K makes some tasks unrealistic), so any two runs may cover different task subsets. Without recording this, `diff -r` between two run directories would be meaningless. `latest` is a symlink for convenience only; nothing should depend on it being any particular run, since re-running always produces a new timestamped directory rather than overwriting.

---

## 8. Suggested Build Order

Ordered by hard dependency first, then by "what should exist before anything becomes network-reachable."

1. **Cline client-side config** (context window pinned to 32768, provider → `flashnext` via `:4000`). No dependencies. Cheapest to build and verify; needed before any surface can be meaningfully tested.
2. **32K guard in `role_shim.py`** (additive, reject-not-truncate) **+ its regression test**. Logically independent of Cline (testable with raw `curl` against `:8011`), but must exist before step 5/6 make the system reachable from anywhere but this Mac's own shell — the project's Core Value should be proven before any remote surface is exposed to it.
3. **Sandbox + repo whitelist** (`ALLOWED_REPOS.json`, generated Seatbelt profile + symlinks, `.clineignore` template). Independent of 1–2, but must land before any surface is wired to a real repo, since this is the safety net for what a remotely-triggered agent can touch.
4. **Headless CLI wrapper** (script only). Depends on 1–3. Cheapest possible smoke test that config + guard + sandbox work together end-to-end in a single-shot, fully-local invocation, before adding always-on network services.
5. **Kanban service** (`cline-kanban`, loopback-only). Depends on 3 (must open a whitelisted repo) and benefits from 4 already having validated the guard/config combination.
6. **Access-control gateway** (`cline-kanban-gateway`, tailnet/LAN split). Depends on 5 existing. Deliberately last of the network-exposure steps — this is the step that makes the system reachable beyond `localhost`, and should only happen once 2 and 3 are proven.
7. **Telegram connector**. Depends on 1–3, same as Kanban; independent of 5/6 (different transport, no inbound port to gate). Can be built in parallel with 5/6. Bot token wiring is deferred (manual BotFather step, per PROJECT.md scope) — everything else should be finished so the token is a one-line addition.
8. **launchd registration + `~/local-llm-settings` sync** for whichever of 5/6/7 became persistent services. Do this once each service's behavior is stable — an always-on, auto-restarting service should not go live before its safety nets (2, 3) are validated.
9. **cline-bench harness skeleton** (directory layout, `cline-bench` checkout). Can be built early, in parallel with 1–3, since it's test infrastructure rather than a production surface — but the regression suite that actually *proves* the guard (step 2) should only be run for real once 2 exists.
10. **Korean usage manual**. Last — documents whatever actually shipped, per PROJECT.md's explicit scoping ("사용법만," no ops runbook).

**Phase-ordering implication for the roadmap:** the natural phase boundary is *not* "one phase per surface" — it is "prove the guard and the sandbox before any surface is network-reachable." Kanban, Telegram, and the headless wrapper are all thin, largely independent consumers of the same guarded/sandboxed core; the risk and the required rigor concentrate in steps 1–3, not in the three surfaces themselves.

---

## Sources

- `~/local-llm-settings/{README,TOPOLOGY,STATE,VALIDATED}.md`, `config/role_shim.py`, `config/litellm-config.yaml`, `sync.sh`, `launchagents/*.plist` — read directly, existing validated system (2026-08-29 snapshot)
- `/Users/ohama/projs/cline-tests/.planning/PROJECT.md` — project requirements, constraints, decisions
- Live system facts: `tailscale status`, `tailscale ip -4`, `ifconfig`, `netstat -rn -f inet` (run 2026-08-29)
- [Cline Kanban — Remote Access](https://docs.cline.bot/kanban/remote-access) — host/port binding, no built-in auth, Tailscale/Cloudflare/ngrok tunneling options
- [Cline Connectors](https://docs.cline.bot/cli/connectors) — Telegram setup (`cline connect telegram -k`), `--hook-command` payload/response contract, `--allowed-user-id`
- [Cline Kanban (GitHub)](https://github.com/cline/kanban) and [Kanban usage docs](https://docs.cline.bot/usage/kanban) — per-card git worktree isolation, default `127.0.0.1:3484` bind, `--host`/`--port` flags
- [Cline OpenAI-Compatible provider config](https://docs.cline.bot/provider-config/openai-compatible) — context window fallback behavior, manual override fields
- [Cline `.clineignore` docs](https://github.com/cline/cline/blob/main/docs/customization/clineignore.mdx) and [Cline Access Control (DeepWiki)](https://deepwiki.com/cline/cline/10.3-access-control) — enforcement scope of `.clineignore` vs. `execute_command`, `CLINE_COMMAND_PERMISSIONS`
- [cline-bench (GitHub)](https://github.com/cline/cline-bench) — task directory structure, Harbor/Docker-based execution
- PROJECT.md-cited Cline issues [#12520](https://github.com/cline/cline/issues/12520), [#13457](https://github.com/cline/cline/issues/13457) — 128k context-window fallback bug this architecture's guard is designed against

---
*Architecture research for: Cline persistent server on macOS, layered on existing local LLM stack*
*Researched: 2026-08-29*
