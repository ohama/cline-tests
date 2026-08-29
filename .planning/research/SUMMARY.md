# Project Research Summary

**Project:** Cline 로컬 서버 (Cline persistent macOS server: Kanban + Telegram + headless CLI over a 32K-context local model)
**Domain:** Local-first agentic coding server — launchd-managed always-on Cline CLI layered on an existing, validated local-LLM inference stack (litellm → role-shim → mlx_vlm.server), reachable from iPad/iPhone via Tailscale/LAN
**Researched:** 2026-08-29 (STACK/FEATURES/ARCHITECTURE/PITFALLS), corrected same day after live measurement and user decisions recorded in PROJECT.md
**Confidence:** MEDIUM-HIGH — most operational facts were verified by literally running commands and reading installed source on this exact machine; one mechanism central to the Core Value (does Cline's `contextWindow` override actually change its client-side compaction trigger?) remains empirically unverified and must be proven in the first build phase.

> **Read this first:** PROJECT.md was rewritten after these four research files were produced, and it supersedes several of their conclusions. This summary reflects PROJECT.md's corrected picture, not the original research assumptions. Where a research file's recommendation was overridden, that is called out explicitly below — do not silently re-adopt the superseded recommendation from STACK.md/ARCHITECTURE.md/PITFALLS.md/FEATURES.md during roadmap or requirements drafting.

---

## Executive Summary

This is a single-user, single-machine, local-first coding-agent server: Cline CLI, pinned to `3.0.53` (drifts silently unless `CLINE_NO_AUTO_UPDATE=1` is set — verified reproducible), fronting a local Qwen3.8-Flash-Next model through an already-validated `litellm(:4000) → role-shim(:8011) → mlx_vlm.server(:8000)` chain hard-capped at 32,768 tokens (`--max-kv-size 32768`). Three surfaces share one agent core and one model: a Kanban web board (iPad), a Telegram connector (iPhone), and a headless CLI wrapper (scripting). Experts build this kind of thing by treating the *existing, validated* inference stack as immutable and adding only thin, mostly-independent consumers on top of it — the real engineering is not in the three surfaces (they are largely off-the-shelf Cline features), it is in getting Cline's own client-side belief about its context window to match hardware reality, because Cline's `openai-compatible` provider has a known, currently-unfixed bug (GitHub #12520/#13457, confirmed present in the installed source) that falls back to a hardcoded 128,000-token context window whenever it can't resolve model info from its catalog — which is exactly this project's situation, since `flashnext` is a local-only model name Cline's catalog has never heard of.

The recommended approach, corrected from the original research: **do not build a duplicate gateway-side 32K rejection guard.** Live measurement on 2026-08-29 proved the existing stack already rejects any request where `prompt_tokens + max_tokens > 32768` with a clean HTTP 400 (`PromptTooLongError`) in ~400ms, before any prefill compute is spent — this happens today, with zero new code, at the `mlx_vlm.server` layer, and `role_shim.py`/`litellm` forward it verbatim. STACK.md independently reached this same "do nothing new, the guard already exists" conclusion; ARCHITECTURE.md's recommendation to add a duplicate guard inside `role_shim.py`, and PITFALLS.md's claim that a gateway guard is "the actual load-bearing control," are both **superseded by this measurement and the user's 2026-08-29 decision** — carry neither recommendation forward. The real risk this project must defend against is not rejection, it's *silent task death*: because Cline believes it has 128k of context, its own auto-compact logic waits until ~115,200 tokens before even attempting to summarize, so the moment a real conversation crosses 32,768 tokens, every subsequent request 400s and Cline has no self-recovery path — the task simply dies mid-work. The corrected Core Value is therefore "Cline compacts before reaching the 32K wall so tasks don't die," and the single most important thing to prove empirically, before anything else in this project matters, is whether pinning `models[].contextWindow: 32768` in Cline's `providers.json` actually changes Cline's internal compaction threshold to ~26,214 tokens. This was NOT conclusively testable in the time available to research (a single oversized first message can't distinguish "tried to compact and failed" from "never tried") and is rated MEDIUM-LOW confidence by STACK.md — it must be the first thing validated with a real multi-turn regression test in the build phase.

Key risks, in order of how directly they threaten the Core Value or the hardware: (1) the compaction-trigger question above; (2) `max_output_tokens` must be capped in Cline's config, because the server's accept-time budget check is `prompt_tokens + max_tokens`, verified live (13 prompt tokens + 40,000 max_tokens → instant 400) — a large default `max_output_tokens` can fail a task on turn one regardless of conversation length; (3) unbounded `mlx_vlm.server` continuous-batching concurrency (`--max-num-seqs` defaults to unbounded) against only 4.39 GB of memory headroom at 32K — this must be bounded before Kanban and Telegram are both live simultaneously, since that is the first time this machine will ever have two concurrent near-32K-capable clients; (4) `litellm` is bound to `*:4000` with no `master_key` — currently masked by the macOS application firewall (TCP handshake succeeds from a LAN IP but no data returns), so treat it as a latent gap to close before network exposure, not as an actively-open door today; (5) Cline's silent self-update, which must be neutralized with `CLINE_NO_AUTO_UPDATE=1` in every plist or every other finding in this research decays over time. Compact Prompt is mandatory at 32K and is a hard, documented trade: it disables MCP and Focus Chain entirely. No requirement anywhere in this project may depend on either.

---

## Key Findings

### Recommended Stack

Zero new runtime dependencies are needed anywhere in this stack — the strongest temptation (adding a token-counter to `role_shim.py`) is explicitly rejected. `cline@3.0.53` (npm global) is the pinned agent runtime; `kanban@0.1.70` is a separate, lazily-auto-installed npm package with no discovered opt-out for its own updater (must be re-pinned by hand after each `cline kanban` run). Node 25.9.0 and Python 3.14.6 are already present and sufficient; `uv` resolves cline-bench's Python 3.13 requirement without touching system Python. `litellm@1.86.1` and `role_shim.py` need no version changes — everything new is configuration, not code, except the sandbox/whitelist generator and connector scripts.

**Core technologies:**
- `cline` (npm, global, pinned `3.0.53`) — agent CLI, kanban server, connector host — matches the version PROJECT.md's bug analysis (#12520) was validated against; drifts silently without `CLINE_NO_AUTO_UPDATE=1`
- `kanban` (npm, global, auto-installed on first `cline kanban` run, pin to `0.1.70` after) — web Kanban board on `:3484` — its own independent auto-updater has no documented off-switch, so pin manually and never pass `--update`
- Existing `litellm(:4000) → role-shim(:8011) → mlx_vlm.server(:8000)` chain — UNCHANGED, treated as immutable validated infrastructure; the 32K hard-reject already lives here today
- `sandbox-exec` (macOS Seatbelt) — OS-level enforcement for the workspace sandbox; the only mechanism that is unconditionally enforced regardless of any Cline-level bug, chosen over Docker/a restricted OS user because it adds no competing heavyweight process against the 104 GiB model
- Harbor / `cline-bench` via `--env docker` — local, free, sequential task runner; `DAYTONA_API_KEY` is documented as cloud-only, not required for local Docker execution

**Critical version/config facts a planner needs pinned:**
- Config root: `~/.cline/` (no XDG path in use); provider config at `~/.cline/data/settings/providers.json` (plain JSON, hand-editable); logs at `~/.cline/data/logs/cline.log`; sessions/connectors/cron in `~/.cline/data/db/*.db`
- Non-interactive provider setup: `CLINE_NO_AUTO_UPDATE=1 cline auth openai-compatible -b http://localhost:4000/v1 -k dummy -m flashnext` — writes `providers.json` with no TTY needed. `cline config --json` requires a real TTY even with `--json` in this version — do not use it for programmatic reads.
- `contextWindow` override lives in `providers.json`'s `providers.openai-compatible.settings.models[]` array (`{id, contextWindow, maxTokens, ...}`) — schema accepts it, Cline does not error on it, but whether it changes compaction behavior is the central open question (see Executive Summary).
- Kanban bind default: `127.0.0.1:3484`, zero CLI flags on `cline kanban` itself (unknown-option error on anything else). Host/port ARE controllable via env vars `KANBAN_RUNTIME_HOST` / `KANBAN_RUNTIME_PORT` (verified working through the `cline kanban` wrapper). Binding to any non-loopback host auto-generates and requires an 8-character passcode (`HttpOnly` cookie or Bearer token, 24h TTL, 5-attempts/30s lockout) — no per-source-IP exemption exists inside kanban itself.
- Telegram connector: `cline connect telegram -k <TOKEN> --allowed-user-id <ID> -i` — long-polling only (no webhook flag, no public inbound port ever needed). `-i`/`--interactive` keeps the connector in the foreground, which is the recommended mode under launchd `KeepAlive` (matches house style) rather than relying on Cline's own hub-daemon supervision. Default RPC address `127.0.0.1:25463`.
- `harbor run -p <task-path> -a <agent> -m <provider:model-id> --env docker` — local Docker execution, no Daytona key required; set `API_KEY`/`BASE_URL` scoped to the invocation (generic names, don't export globally).
- launchd house style (read from existing working plists, not modified): plists in `~/Library/LaunchAgents/`, synced copies in `~/local-llm-settings/launchagents/`, labels `com.ohama.*`, `RunAtLoad: true` + `KeepAlive: true` + `ThrottleInterval` (60s heavy/10s light), explicit `PATH` in `EnvironmentVariables`, logs to `~/llm-system/services/logs/`. Modern verbs on this Darwin 25.x host: `launchctl bootstrap/enable/kickstart -k/print/bootout gui/$UID/<label>`.
- Every new Cline-based plist's `EnvironmentVariables` MUST include `CLINE_NO_AUTO_UPDATE=1` — behaviorally confirmed as the actual kill-switch for the self-update background process (found in the compiled binary, not documented in `--help`).

### Expected Features

Compact Prompt is mandatory at 32K and structurally removes MCP and Focus Chain — this is a hard constraint on every feature decision below, confirmed via Cline's own settings copy ("Does not support MCP and Focus Chain").

**Must have (table stakes):**
- Cline pointed at `flashnext`/`:4000` with the context-window override attempted (even though its effect is unverified — cheap, no downside, do it anyway) and Compact Prompt ON
- A real multi-turn regression test proving compaction (or its absence) at ~26.2K tokens — this is the single highest-priority item; everything else is secondary if this doesn't exist
- `max_output_tokens` capped in Cline's config (server budget is `prompt + max_tokens`, verified to fail from turn one otherwise)
- `CLINE_NO_AUTO_UPDATE=1` in every plist
- Kanban and Telegram both boot-persistent via launchd, Tailscale-only reachability, LAN path token-gated
- `--allowed-user-id` on the Telegram connector from the very first launch (never start it without this)
- Workspace sandbox + repo whitelist (`CLINE_SANDBOX`/`CLINE_COMMAND_PERMISSIONS` + OS-level Seatbelt, since `.clineignore` does not constrain `execute_command`)
- Visible "waiting/busy" indication in Kanban and Telegram (64.3s TTFT at 32K is real and non-linear; a UI with no spinner looks hung)
- A small, representative cline-bench subset run locally via `--env docker`, with prompt+result captured to files per run
- Korean manual v1 (CLI/web/iPad-iPhone usage only — ops runbook is explicitly a separate, out-of-scope document)

**Should have (differentiators):**
- The three surfaces genuinely sharing one agent core/model (already the project's thesis, not a stretch goal)
- Kanban dependency-chained cards for queuing multi-step work unattended — well-suited specifically because each turn is slow (64s), so batching turns beats babysitting them
- Inline diff comments as the touch-friendly review mechanic (this is the actual answer to "how do you review code from an iPad")
- The regression test built as a durable, re-runnable artifact (not a one-time check) — proof the guard/compaction still holds after any future Cline upgrade or config drift

**Defer (v2+):**
- `.clinerules`, Skills, `cline schedule` — add only once the base 32K loop is proven reliable; every token they add competes directly with the ~13K working budget left after Compact Prompt's tax
- `--hook-command` custom gating beyond `--allowed-user-id` — nice hardening, not needed for v1
- Anything requiring MCP or Focus Chain, a second model, cloud sync, telemetry dashboards, or full cline-bench suite completion — all explicitly out of scope per PROJECT.md and/or structurally blocked by Compact Prompt or hardware

### Architecture Approach

Layer new, mostly-independent thin consumers on top of an unmodified, already-validated inference chain; concentrate all real engineering risk in three things that must be proven before any surface goes live: Cline's context-window/compaction behavior, the workspace sandbox, and the model server's concurrency ceiling. Do not add a second gateway-level 32K guard (superseded — see below); do fix the two genuinely open infrastructure gaps (`litellm`'s unauthenticated wildcard bind, `mlx_vlm.server`'s unbounded concurrency) before the surfaces that would actually exercise them go live.

**Major components:**
1. Cline agent core (shared by all three surfaces) — task loop, tool execution, sandbox/command-permission enforcement, provider config pointed at `flashnext` via `:4000`
2. `cline-kanban` (new, loopback-only `127.0.0.1:3484` or similar) + a thin access-control gateway in front of it for Tailscale-unauthenticated/LAN-token-gated exposure — since Kanban itself has zero built-in auth for a loopback bind
3. `cline-telegram` (new, outbound long-poll only, no inbound port) — `--allowed-user-id` is the entire access-control surface
4. Headless CLI wrapper (new, script only, explicitly not a service this milestone) — must not inherit Cline's own `--auto-approve=true` default
5. Existing `litellm(:4000) → role-shim(:8011) → mlx_vlm.server(:8000)` — UNCHANGED behavior, already the load-bearing 32K enforcement point

**Superseded architecture recommendation — do not carry forward:** ARCHITECTURE.md recommended an additive token-counting guard inside `role_shim.py` (option "a" in its analysis) as "the actual load-bearing control." This is now explicitly cut. Live measurement showed the existing `mlx_vlm.server --max-kv-size 32768` check already rejects oversized requests in ~400ms before prefill, and duplicating that judgment in `role_shim.py` was judged redundant, latency-adding, and at risk of a tokenizer mismatch with the actual model. **The verification obligation moves from "build a guard" to "prove compaction happens before the wall" — a test, not new production code.**

### Critical Pitfalls

1. **Cline's context-window fallback may still resolve to 128,000 internally even with `providers.json` overridden** — root-caused in `sdk/packages/llms/src/providers/{compat,builtins}.ts` (issues #12520/#13457, both OPEN, unfixed, PRs unmerged). Because the fallback stub always wins over `knownModels[modelId]` for an unrecognized model id like `flashnext`, Cline's auto-compact threshold (`max(ctx−40000, ctx×0.8)`) could still be computed against 128k, deferring compaction to ~115.2K tokens — 3.5× past where the actual backend accepts requests. **Prevention (corrected):** do not build a duplicate gateway guard (superseded); instead build the multi-turn regression test that proves or disproves compaction at ~26.2K, and treat the server's existing fast, clean 400 as the acceptable fallback outcome if compaction turns out not to fire — recovery is "start a new task," not silent corruption.
2. **Cline's own context-usage UI bar is independently unreliable and must never be the regression-test oracle** — at least three separate, differently-caused bugs (#6494/#10375 display-cap, #7383 staleness). Verify token accounting from `mlx_vlm.server`'s own logs (`prompt_tokens=` lines) or the raw API `usage` object, never the UI percentage. (Note: #9433's "usage is null" bug does NOT apply here — verified live, both streaming and non-streaming responses return a fully populated `usage` object on this stack — do not carry forward any mitigation for it.)
3. **Unbounded continuous-batching concurrency against 4.39 GB of headroom** — `mlx_vlm.server` runs genuine concurrent batching (verified live, two simultaneous requests both completed with identical prefill timing) with `--max-num-seqs` defaulting to unbounded. The one thing genuinely new to this machine once Kanban and Telegram are both live is two clients mid-conversation near 32K at once. **Must be bounded (`--max-num-seqs 1` or 2, and/or single-flight at the gateway) before both surfaces go live simultaneously** — untested at 32K concurrency deliberately, treated as an architecturally well-founded but unconfirmed OOM risk, not something to discover by triggering it in production.
4. **`litellm` listens on `*:4000` with no `master_key`** — inherits litellm's `0.0.0.0` CLI default; verified via `lsof`. Currently masked by the macOS application firewall (TCP handshake succeeds from a LAN IP, no data returns), so treat as a **latent** gap, not an actively open door today — but it must be closed (bind to `127.0.0.1` + front with an authenticating layer, and/or set `general_settings.master_key`) before the network-exposure phase, since it currently gives LAN the same unauthenticated access Tailscale is meant to have exclusively.
5. **Chat-bridge / headless default-allow asymmetry** — direct `cline <prompt>` defaults `--auto-approve` to `true`; the Telegram connector path correctly defaults to `off` until `/yolo`. The headless wrapper must never assume the connector's safer default applies to it — always pass `--auto-approve false` explicitly, and always start Telegram with `--allowed-user-id` from the very first launch, never "add it later."

---

## Implications for Roadmap

The natural phase boundary is **not** "one phase per surface." Kanban, Telegram, and the headless wrapper are thin, largely independent, mostly off-the-shelf consumers of the same core. The risk and the required rigor concentrate almost entirely in getting Cline's own config/compaction behavior right, the sandbox, and the concurrency ceiling — build and prove those before any surface becomes reachable from anywhere but this Mac's own shell, and expose to a network last of all.

### Phase 1: Cline Core Config + Compaction Verification
**Rationale:** This is the corrected Core Value and the one open question (does `contextWindow: 32768` actually change Cline's compaction trigger?) that everything else depends on knowing the answer to. Cheapest to build, must be proven before any surface is meaningfully testable.
**Delivers:** Non-interactive `providers.json` config (`flashnext` via `:4000`, `contextWindow: 32768`, capped `max_output_tokens`), `cline@3.0.53` pinned with `CLINE_NO_AUTO_UPDATE=1`, and a multi-turn regression test (resume a session via `--id`, push accumulated history past 26,214 tokens over 2–3 turns, watch the `--json` stream for a compaction-flavored `agent_event` vs. a clean 400 from the existing server-side reject) with pass/fail read from server logs/`usage`, never Cline's UI bar.
**Addresses:** Table-stakes items "32K context pin," "Compact Prompt ON," "regression test proving the guard/compaction actually holds"
**Avoids:** Pitfall 1 (fallback bug), Pitfall 2 (unreliable UI as oracle), Pitfall 10 (version drift)

### Phase 2: Workspace Sandbox + Repo Whitelist
**Rationale:** Nothing that can be remotely triggered (headless wrapper, Kanban, Telegram) should be wired to a real repo before this exists — it is the safety net for what a remote agent session can touch, and `.clineignore` alone does not constrain `execute_command`.
**Delivers:** `ALLOWED_REPOS.json` as the single generator input for both symlinks and a generated Seatbelt (`sandbox-exec`) profile, `CLINE_COMMAND_PERMISSIONS` allowlist, `.clineignore` template — with the sandbox and the bench/test-artifact directory kept as siblings, never nested, so a benchmark task can never read its own prior prompts/results.
**Implements:** Architecture component 2/5 (sandbox layer); uses `CLINE_SANDBOX`/`CLINE_SANDBOX_DATA_DIR`/`CLINE_COMMAND_PERMISSIONS` from STACK.md/FEATURES.md

### Phase 3: Concurrency Guard on the Existing Model Server
**Rationale:** Must land before Phase 5 makes two surfaces simultaneously live — this is the one scenario genuinely new to this machine (previously exactly one client existed). Cheap (one flag), but the window in which it's safe to skip closes the moment Kanban and Telegram are both running.
**Delivers:** `--max-num-seqs 1` (or a conservative 2) added to the existing `com.ohama.flashnext.plist`, converting unbounded concurrent batching into clean FIFO queueing.
**Avoids:** Pitfall 3 (OOM risk against 4.39 GB headroom)

### Phase 4: Headless CLI Wrapper
**Rationale:** Cheapest possible end-to-end smoke test that config (Phase 1) + sandbox (Phase 2) actually compose correctly, in a single-shot, fully-local invocation, before committing to always-on network services.
**Delivers:** A wrapper script with a clean invocation contract, explicit `--auto-approve false` (never relying on the CLI's `true` default), deliberately not made into a service this milestone.
**Avoids:** Pitfall 5 (auto-approve default asymmetry)

### Phase 5: Kanban Service (loopback-only) + Telegram Connector
**Rationale:** Both are thin, mostly independent consumers of the now-proven core (Phases 1–4); can be built in parallel. Neither should be internet- or LAN-reachable yet — Kanban stays bound to loopback, Telegram's bot token slot stays empty pending manual BotFather issuance per PROJECT.md.
**Delivers:** `cline-kanban` launchd service bound loopback-only; `cline-telegram` launchd service with `--allowed-user-id` baked in from the first launch (never added later), foreground (`-i`) under launchd `KeepAlive` per house style; both registered in `~/local-llm-settings` and `sync.sh`.
**Avoids:** Pitfall 5 (Telegram default-allow), Pitfall 7 (launchd boot-ordering — both services must tolerate the model not being warm yet, surfacing errors visibly rather than crash-looping)

### Phase 6: Network Exposure (last)
**Rationale:** Deliberately last — this is the step that makes the system reachable beyond `localhost`, and per PROJECT.md's corrected build order ("network exposure last") should only happen once the core, sandbox, and concurrency guard are all proven. Also the phase that must close the pre-existing `litellm` `*:4000`/no-`master_key` latent gap before it matters.
**Delivers:** Access-control gateway in front of Kanban (Tailscale-unauthenticated, LAN-token-gated, fail-closed source-IP classification using `ipaddress`, never trusting an ambiguous source), and closing the `litellm` exposure (bind to `127.0.0.1` and/or set `general_settings.master_key`). **Hard constraint: nothing in this phase — or any phase — may bind to port 3000**, because the pre-existing Tailscale Funnel (`:8443 → 127.0.0.1:3000`) stays on by user decision and is public-internet-facing.
**Avoids:** Pitfall 4 (litellm exposure)

### Phase 7: cline-bench Verification Subset
**Rationale:** Independent test infrastructure; harness skeleton can be built in parallel with earlier phases, but real runs that mean anything require the guard/compaction behavior (Phase 1) to already be proven — otherwise a bench run can't distinguish "the agent failed the task" from "the 32K wall killed the task."
**Delivers:** `harbor run --env docker` against a small, deliberately-shallow task subset (3–5 tasks, not the full suite — 2400s/task timeout vs. 64.3s TTFT makes full-suite completion unrealistic), with pinned Python 3.13 via `uv`, scoped `API_KEY`/`BASE_URL`, and prompts+results captured to timestamped run directories outside the sandbox.
**Avoids:** Pitfall 8 (environment mismatches), Pitfall 6 (fake `<tool_call>` text hallucination when no tools are registered)

### Phase 8: Korean Usage Manual
**Rationale:** Must be last — documents whatever actually shipped. Writing it earlier means rewriting it once surface details (binding, gating, TOC-relevant behavior) stabilize.
**Delivers:** Usage-only manual (CLI/web/iPad-iPhone), explicitly excluding the ops runbook, structured device-first (iPad → iPhone → terminal → cross-cutting concepts → light troubleshooting that punts to the separate ops doc).
**Addresses:** Explicit PROJECT.md deliverable

### Phase Ordering Rationale

- Config-and-compaction-first, sandbox-second, concurrency-guard-third, network-exposure-last is a direct implementation of PROJECT.md's corrected build order and ARCHITECTURE.md's own §8 conclusion (surfaces are cheap; the guard/sandbox rigor is what's expensive).
- The concurrency guard (Phase 3) is placed deliberately before Phase 5, not folded into it, because it's a one-line change to an *existing* service with zero dependency on anything new — there's no reason to defer it, and deferring it is the exact "acceptable until the second surface ships" technical-debt trap PITFALLS.md calls out.
- Network exposure (Phase 6) is isolated as its own phase, after both new surfaces already exist loopback-only, so that the access-control logic can be built and tested against real running services rather than mocked ones — and so the litellm exposure fix has a natural, non-optional checkpoint before it matters.
- The manual (Phase 8) and cline-bench verification (Phase 7) are ordered last/near-last because both depend on the rest being stable; cline-bench's harness skeleton is the one exception that can start early as pure infrastructure.

### Research Flags

Needs research/deeper empirical investigation during planning:
- **Phase 1 (Cline Core Config + Compaction Verification):** the central open question — whether `models[].contextWindow` in `providers.json` actually changes Cline's internal compaction threshold — was not conclusively testable in this research round (MEDIUM-LOW confidence, STACK.md §2c). This phase's plan must include time to build and run the multi-turn test, and a documented fallback plan if compaction does not fire (e.g., accept the clean-400-and-restart-task failure mode as the interim reality).
- **Phase 6 (Network Exposure):** the fail-closed source-IP classification logic (100.64.0.0/10 tailnet vs. LAN vs. ambiguous) is a security-relevant code path; worth a focused pass to confirm edge cases (IPv6-mapped IPv4, proxies) don't silently default to "allow."

Phases with standard, well-documented patterns (research-phase likely unnecessary):
- **Phase 2 (Sandbox):** `sandbox-exec`/Seatbelt and `CLINE_COMMAND_PERMISSIONS` are documented, existing OS/CLI mechanisms; the main work is the generator script, not novel research.
- **Phase 3 (Concurrency Guard):** a single documented CLI flag (`--max-num-seqs`) on an already-running, already-understood service.
- **Phase 4 (Headless Wrapper):** thin script over already-documented CLI flags.
- **Phase 5 (Kanban/Telegram services):** both are officially documented Cline features with verified flags/env vars; the launchd wiring follows an already-established house pattern on this machine.
- **Phase 8 (Manual):** a documentation phase with an already-drafted proposed TOC (FEATURES.md §4).

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH, with one MEDIUM-LOW item | Every config path, flag, and behavior was directly run/read on this machine or in the exact installed package source. The one exception — whether `contextWindow` override changes Cline's compaction math — is explicitly flagged MEDIUM-LOW and is the top item for empirical verification in Phase 1. |
| Features | MEDIUM-HIGH | Cline's own docs and repo verified directly for most claims; Kanban touch/mobile behavior and exact cline-bench task counts are undocumented by Cline itself and rated LOW/MEDIUM in the source file. Compact Prompt's MCP/Focus Chain conflict is HIGH confidence (verified quote from Cline's own issue tracker). |
| Architecture | HIGH for topology/ports/access control (verified against the live system); MEDIUM for launchd boot-ordering guidance (launchd has no native dependency graph, so this is "design for tolerance," not a verified timing number). **Note:** ARCHITECTURE.md's role_shim.py guard recommendation is superseded — do not weight it. |
| Pitfalls | HIGH on context-accounting and security findings (live GitHub issue states via `gh`, live curl probes, source reads); MEDIUM on launchd/cline-bench specifics not safely testable live. **Note:** Pitfall 1's "gateway guard is the load-bearing control" framing and the #9433 usage-null mitigation are both superseded per the corrections above. |

**Overall confidence:** MEDIUM-HIGH — the operational scaffolding (config paths, flags, ports, launchd patterns, sandbox mechanics) is solidly verified. The one genuine unknown is squarely inside Phase 1's scope and has a clear, cheap test designed to resolve it before anything downstream depends on the answer.

### Gaps to Address

- **Central gap — does `contextWindow: 32768` actually change Cline's compaction trigger?** Not conclusively testable within this research's time budget (a single oversized first message can't distinguish "tried to compact and failed" from "never tried"). Must be resolved with a real multi-turn regression test in Phase 1, per the corrected Core Value. If the answer is "no," the fallback posture is: accept the existing fast, clean 400 rejection as the failure mode, and design surfaces (Kanban/Telegram) to make "start a new task" an easy, low-friction recovery rather than trying to force compaction to work.
- **Whether `cline-bench`'s `agent/cline.txt` captures the raw system/user prompt verbatim, or only the visible transcript** — FEATURES.md rates this MEDIUM/PARTIALLY CONFIRMED. Verify empirically on the first real bench run (grep for system-prompt content); if insufficient, add a lightweight request-logging shim at the gateway, which doubles as prompt capture at no extra cost since request visibility is already needed for Phase 1's regression test.
- **Kanban's dependency-chain card-linking gesture (⌘/Ctrl+click) has no confirmed touch/iPad equivalent** — a concrete, confirmed gap, not a hypothetical. Flag for requirements: either find/build a touch affordance or document "do card-linking from a desktop browser" in the manual.
- **Cold-boot load time of the 104 GiB model is unmeasured** (the existing "20–45s" figure documents a warm mode-switch, not a cold page-cache load). This affects any readiness-probe/timeout values chosen for the new Kanban/Telegram launchd services in Phase 5 — measure once, empirically, before picking numbers.
- **Whether Kanban's own frontend (browser `fetch`) imposes any client-side timeout below 64.3s** was not conclusively found either way — low risk, but worth a manual check once Kanban is actually running against a near-32K request.
- **The `litellm` `*:4000`/no-`master_key` gap** is currently latent (masked by the macOS application firewall) rather than actively exploited, but must not be treated as "fine because nothing has happened yet" — it is an explicit blocking item for Phase 6, not an optional hardening pass.

---

## Sources

### Primary (HIGH confidence — direct execution/inspection on this machine, or direct source reads)
- Direct execution and inspection: `/opt/homebrew/bin/cline`, `/opt/homebrew/lib/node_modules/cline/`, `/opt/homebrew/lib/node_modules/kanban/`, `~/.cline/` — commands run, files read, not inferred
- Fresh `git clone --depth 1 https://github.com/cline/cline.git` at commit `1986fa56de5dc91d635ef3a696136f6dc11799dd` (2026-08-28/29) — `sdk/packages/llms/src/providers/{compat,builtins}.ts`, `vendors/{openai-compatible,ollama}.ts`, `http.ts`, `apps/cli/src/connectors/adapters/telegram.md`, `connector-host.test.ts`
- `~/local-llm-settings/{README,TOPOLOGY,STATE,VALIDATED}.md`, `config/{litellm-config.yaml,role_shim.py}`, `launchagents/*.plist`, `sync.sh` — read only, existing validated system
- Live probes against the running stack (`curl localhost:4000/...`, `lsof -i`, `docker info`, `tailscale status`/`ip -4`, `ps aux`) — 2026-08-29
- `mlx_vlm/server/{generation.py,app.py,cli.py}` (installed package) — `PromptTooLongError`, `_check_configured_context_budget`, `--max-num-seqs` docstring
- `litellm/proxy/{proxy_cli.py,proxy_server.py}`, `litellm/constants.py` (installed v1.86.1)
- GitHub issues, live-verified via `gh issue view` on 2026-08-29: #12520 (OPEN), #13457 (OPEN), #10375 (OPEN/stale), #6494 (CLOSED not_planned), #7772 (CLOSED not_planned, mechanism still live), #9433 (OPEN, confirmed NOT applicable to this stack), #7383 (OPEN)
- `docs.cline.bot/{cli/connectors,cli/cli-reference,kanban/core-workflow,kanban/remote-access,features/checkpoints,features/skills,running-models-locally/read-me-first}` — fetched directly
- `.planning/PROJECT.md` — authoritative, supersedes conflicting research conclusions

### Secondary (MEDIUM confidence)
- `cline-analysis.md` (this session's earlier research artifact) — Terminal-Bench-2.0 89-task pool figure, cross-checked against fresh fetches where overlapping, no contradictions found
- `github.com/cline/cline-bench` README (fetched, two passes) — task structure, `--env docker`/Daytona split, `jobs/` output layout
- `github.com/cline/cline/blob/main/evals/README.md` (search-derived summary) — three-layer eval framework, confirmed absence of any context-limit-specific eval

### Tertiary (LOW confidence, flagged for validation)
- Exact cline-bench task volume (89-task pool vs. 12-task e2e pool — treated as two separate candidate pools, not reconciled)
- Kanban's own frontend timeout behavior and touch/mobile design intent (Cline's docs are silent on both)

---
*Research completed: 2026-08-29*
*Corrections incorporated: 2026-08-29 (gateway guard cut, Core Value rewritten, max_output_tokens promoted, usage-null mitigation dropped, CLINE_NO_AUTO_UPDATE mandated, port 3000 prohibition, Compact Prompt/MCP/Focus Chain hard constraint)*
*Ready for roadmap: yes*
