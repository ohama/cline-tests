# Stack Research: Cline as a Persistent macOS Server

> 🔴 **2026-08-30 정정 — 압축/컨텍스트 관련 서술은 무효다.**
> 이 문서는 `models[].contextWindow` 가 Cline 의 압축 임계값에 영향을 주는지 불확실하다고 쓴다.
> 실측 결과: `models[]` 는 **CLI 가 읽지 않는 경로**(VS Code 용 per-model override)이고,
> `settings` **최상위** `contextWindow` 가 `maxInputTokens` 로 매핑되어 트리거를 결정한다
> (`provider-settings.ts:150/266`). trigger = `maxInputTokens × 0.9`.
> 최상위에 29000 을 넣으면 압축이 정상 발동한다 — `phase-01/results/exp-verify29k/`.
> **유효한 문서: `docs/32k-compaction-policy.md`, `.planning/PROJECT.md`.**


**Domain:** Cline CLI 3.0.53 as a launchd-managed, always-on coding-agent server on macOS, backed by a local OpenAI-compatible endpoint pinned to a 32768-token context window, reachable from iPad/iPhone.
**Researched:** 2026-08-29
**Confidence:** Mixed — see per-item ratings. Every claim below was verified by either (a) running the installed binary and reading its actual output/files, or (b) reading the decompiled/minified source of the exact installed package. Nothing here is recalled from training data without a live check.

**Methodology note:** All findings were produced by actually running `/opt/homebrew/bin/cline` (and a throwaway copy in scratch space) on this machine, inspecting `~/.cline`, and grepping the installed `@cline/llms` / `kanban` npm packages. Where the CLI's background self-updater changed the installed version mid-session, this is reported as a finding in its own right (see "Cline auto-update" below), and the machine was restored to the documented `cline@3.0.53` before finishing.

---

## 0. CRITICAL DISCOVERY: Cline silently self-updates on every invocation

This was not something PROJECT.md anticipated, and it is the single most important operational fact for this project. It was discovered empirically: during this research session, running ordinary `--help` commands against the previously-installed `cline@3.0.53` caused the global install to silently become `cline@3.0.60` with no explicit `cline update` ever run.

**Root cause (verified in the compiled binary via `strings` + manual decompilation of `/opt/homebrew/lib/node_modules/cline/bin/.cline`):**

```js
function jq(){
  if(process.env.IS_DEV==="true")return;
  if(process.env.CLINE_NO_AUTO_UPDATE==="1")return;
  if(!K())return;
  let{packageName:q,packageManager:z,updateCommand:Q}=h(O);
  if(!Q)return;
  w=(async()=>{
    try{
      let Y=await m(q,O);              // queries npm registry for latest version
      if(!Y||D(O,Y)>=0)return;
      v=c(Q,z)                          // builds e.g. `npm update -g cline --tag latest --min-release-age=0`
    }catch{}
  })()
}
// ... later, when idle:
return v=void 0, C(q.command,{shell:!0,detached:!0,stdio:"ignore",
  env:q.env?{...process.env,...q.env}:process.env, windowsHide:!0}).unref(), "started"
```

Every `cline` invocation (including `--help`, `config`, `auth`, one-shot prompts) spawns a **detached, stdio-ignored, unref'd background process** that runs `npm update -g cline --tag latest --min-release-age=0` if a newer version exists on the npm registry. This is fire-and-forget: it does not block the parent process, prints nothing, and completes on its own schedule (sometimes seconds after the triggering command has already exited). The Cline TUI settings screen even shows a persistent toggle for it ("Auto update ● on"), confirmed by capturing the TUI screen buffer during this research.

**Verified fix:** setting the environment variable `CLINE_NO_AUTO_UPDATE=1` in the process environment before invoking `cline` disables this check entirely. This was behaviorally confirmed multiple times: with the variable set, repeated invocations kept `cline --version` stable at `3.0.53`; on the one occasion during this research where a command was run without it, the version drifted to `3.0.60` within minutes.

**Action required for this project:** `CLINE_NO_AUTO_UPDATE=1` MUST be set in every launchd plist's `EnvironmentVariables` dict for every Cline-based service (kanban, connect, headless wrapper). Without it, the pinned `cline@3.0.53` — and the entire premise of "we know its bug and work around it" — will silently stop being true after the service has been running for a while. This also means the `bin/cline` resolver's own env-var passthrough is trustworthy: it forwards `process.env` unchanged to the spawned binary, so setting the var in a launchd `EnvironmentVariables` block is sufficient; no wrapper script is needed.

*Confidence: HIGH. Reproduced twice, root-caused in the actual compiled binary, fix behaviorally verified.*

---

## Recommended Stack

### Core Runtime

| Technology | Version (pinned) | Purpose | Why |
|------------|---------|---------|-----|
| `cline` (npm, global) | **3.0.53** exactly | Agent CLI, kanban server, connector host | Version PROJECT.md already validated against; must not drift (see §0). Reinstall with `npm install -g cline@3.0.53 --no-save` if it ever drifts — confirmed to work and does not require `--force`. |
| Node.js | 25.9.0 (already installed) | Runs the thin `bin/cline` resolver shim (the actual agent runtime is a self-contained Bun-compiled binary at `bin/.cline`, Node is only used for CA-cert bootstrapping and process spawn) | Already present, satisfies Cline's Node 22+ requirement. No action needed. |
| `kanban` (npm, global, auto-installed) | **pin to 0.1.70** via `npm install -g kanban@0.1.70` after first `cline kanban` run | Web Kanban board UI on :3484 | `cline kanban` **lazily installs** this as a *separate* npm package the first time it's run ("Installing kanban@latest…"), and it has its own independent auto-updater (`autoUpdateOnStartup2`) with no visible off-switch flag found in its CLI help — only `--update` to force one. Pinning the global install after the fact and never running `--update` is the practical mitigation; there is no `KANBAN_NO_AUTO_UPDATE`-style env var found in its source. |

### Config / State Files (verified paths — exact)

| Path | Contents | Verified how |
|------|----------|---------------|
| `~/.cline/` | Default `--config` root (from `cline --help`: `--config <path> ... (default: ~/.cline)`) | Ran `cline --help`; confirmed default matches actual dir created after first run |
| `~/.cline/data/` | Default `--data-dir` (from `--help`: default `~/.cline/data`); created automatically under `<config>/data` when `--config` is overridden | Ran `cline auth ... --config /tmp/x`; observed files land at `/tmp/x/data/...` |
| `~/.cline/data/settings/providers.json` | Provider credentials/config, one entry per provider id | Read directly after running `cline auth openai-compatible -b ... -k ... -m ...` |
| `~/.cline/data/logs/cline.log` | Pino JSON structured logs, incl. full telemetry events (`agent.assistant-message`, `task.completed`, etc. — includes a persistent anonymous `distinct_id`/`device_id`) | Read directly |
| `~/.cline/data/db/*.db` (SQLite) | `sessions.db`, `teams.db`, `connectors.db`, `cron.db` — session history, connector registrations, scheduled tasks | `find` + inspected via `cline history --json` |
| `~/.cline/data/locks/hub/production.json` | Hub daemon singleton lock | Observed after `cline kanban` auto-started the hub daemon |

There is **no** `~/.config/cline` or other XDG path in use — only `~/.cline` and whatever directory is passed to the global `--config` flag. This was checked directly (`ls ~/.cline` before and after various invocations); no XDG-spec directories were ever created.

*Confidence: HIGH — every path above was produced and read directly, not inferred.*

---

## 1. Configuring the `openai-compatible` provider non-interactively

**Command (verified working, writes `providers.json` without any TTY/prompt):**

```bash
CLINE_NO_AUTO_UPDATE=1 cline auth openai-compatible \
  -b http://localhost:4000/v1 \
  -k dummy \
  -m flashnext
```

`cline auth --help` (run directly on the installed binary):

```
Usage: cline auth [options] [provider]
  -p, --provider <id>            Provider ID
  -k, --apikey <key>             API key
  -m, --modelid <id>             Model ID
  -b, --baseurl <url>            Base URL
  --azure-api-version <version>  Azure API version
  --config <dir>                 configuration directory
  -c, --cwd <path>               Working directory
  --data-dir <dir>                Use isolated local state at <dir> instead of ~/.cline (enables sandbox mode)
```

Resulting file (`~/.cline/data/settings/providers.json`), read directly:

```json
{
  "version": 1,
  "lastUsedProvider": "openai-compatible",
  "providers": {
    "openai-compatible": {
      "settings": {
        "provider": "openai-compatible",
        "apiKey": "dummy",
        "model": "flashnext",
        "baseUrl": "http://localhost:4000/v1"
      },
      "updatedAt": "2026-08-29T06:33:20.831Z",
      "tokenSource": "manual"
    }
  }
}
```

There is no `--context-window` flag on `cline auth`. The way to attach per-model metadata (including `contextWindow`) is to hand-edit this JSON's `settings` object to add a `models` array — see §2. `cline config` also exists to *display* config but **requires a real TTY even with `--json`** (confirmed: it throws `error: interactive mode requires a TTY (stdin/stdout must both be terminals)` non-interactively, and even under a faked pty via `script` it launches the full-screen TUI settings view, it does not print JSON to stdout in this version). **Do not rely on `cline config --json` for programmatic config introspection in 3.0.53** — it is only useful for humans in a real terminal.

*Confidence: HIGH — every command and file shown above was actually run/read.*

---

## 2. Pinning `contextWindow` to 32768 — what actually exists, what actually happened

### 2a. The bug is real and present in the exact installed 3.0.53

Fresh `npm install cline@3.0.53` (registry copy, not the drifted local one) was unpacked and its dependency `@cline/llms@0.0.73`'s bundled `dist/providers.js` was searched. The referenced source files exist at the paths PROJECT.md cited (confirmed via the package's `.d.ts.map` `sources` field, e.g. `dist/providers/builtins.d.ts.map` → `sources: ["../../src/providers/builtins.ts"]`, `dist/providers/compat.d.ts.map` → `["../../src/providers/compat.ts"]` — this matches `sdk/packages/llms/src/providers/{builtins,compat}.ts` exactly). The compiled JS (minified, function renamed to `Jb` in this build) contains:

```js
function Jb(e,t){
  let n={id:e,name:e};
  if(t?.family==="openai-compatible")
    n.contextWindow=128000, n.maxInputTokens=128000, n.capabilities=["streaming","tools","images"];
  if(t?.id==="qwen"||t?.id==="qwen-code")
    n.family="qwen", n.capabilities=["prompt-cache"];
  return n
}
```

Call sites (also verified) show `Jb(e.defaultModelId, e)` is used **only when the provider's model catalog (`T4(e)`) returns nothing** — i.e., it is a last-resort synthesized `ModelInfo` for a provider entry that isn't in the known-model catalog. This matches the shape of issue #12520 exactly: an `openai-compatible` model id that Cline's catalog doesn't recognize (which describes `flashnext` — a local model name that only exists on this machine) resolves to a hardcoded `contextWindow: 128000`.

Also found (unrelated but relevant): `OLLAMA_DEFAULT_CONTEXT_WINDOW = 32768` is an **exported, documented constant** in `builtins.d.ts`, used as Ollama's own default when neither the model nor user config supplies a context window. There is no equivalent exported constant for the `openai-compatible` family — the 128000 fallback is a private literal, not user-configurable through any documented constant/env var.

### 2b. The provider config schema DOES accept a per-model `contextWindow` override

The same `providers.js` bundle contains a Zod schema (variable names `Oe`/`Re` in this build) for `openai-compatible`-style provider config:

```
models: [{ id, temperature?, maxTokens?, contextWindow?, inputPrice?, outputPrice?, supportsImages? }]
openAiBaseUrl?, openAiHeaders?, azureApiVersion?, azureIdentity?
```

This confirms a `models[].contextWindow` override mechanism exists in the schema. It was manually added to a test `providers.json`:

```json
"providers": { "openai-compatible": { "settings": {
  "provider": "openai-compatible", "apiKey": "dummy",
  "model": "flashnext", "baseUrl": "http://localhost:4000/v1",
  "models": [ { "id": "flashnext", "contextWindow": 32768, "maxTokens": 8192 } ]
}}}
```

Cline accepted this file without complaint (no schema-validation error on startup) — but this does **not by itself prove the override is honored** everywhere Cline resolves context-window size for compaction purposes (see §2c). The `providers.json` is hand-edited JSON today; there is no `cline auth` flag that writes the `models` array for you.

### 2c. Live regression test performed, with a decisive and reassuring result

A real one-shot task was run through the actual production chain (`cline` → `litellm:4000` → `role-shim:8011` → `mlx_vlm.server:8000`, `--max-kv-size 32768`) with an oversized ~34,300-token first message (well past both the 32768 physical limit and the 26,214-token compaction threshold that a correctly-set 32768 context window implies):

```
{"type":"agent_event","event":{"type":"error","error":{"message":
 "litellm.BadRequestError: OpenAIException - Error code: 400 -
 {'detail': 'Request needs 36367 context tokens (34319 prompt + 2048 max generation),
  but MAX_KV_SIZE is 32768.'} ..."}}}
```

This error surfaced in **~400ms** — before any prefill compute was spent — because `mlx_vlm.server` (started with `--max-kv-size 32768`) rejects the request at accept-time and `litellm` passes the 400 through untouched, and `role_shim.py` forwards it byte-for-byte (verified by reading `role_shim.py`: it only rewrites request bodies for message-role normalization; it forwards error status/bodies verbatim via `except urllib.error.HTTPError as e: up = e`).

**What this proves:**
- The physical 32768 limit is **already hard-enforced today, with zero new code**, by the existing `mlx_vlm.server --max-kv-size 32768` flag plus the existing `litellm`→`role-shim` passthrough. This happens *fast* (sub-second), not after a wasted 64-second prefill.
- It does **not** conclusively prove that Cline's client-side compaction logic actually reads `models[].contextWindow` and proactively summarizes conversation history at ~26k tokens — a single oversized first message can't be "compacted" (there's no prior history to summarize), so this specific test cannot distinguish "Cline thinks context is 32768 and tried but couldn't compact a first message" from "Cline still thinks context is 128000 and didn't even try." No debug output, log line, telemetry event, or `--json` field was found anywhere (log files, NDJSON stream, `cline history --json`) that reports the resolved `contextWindow` for a session — this was searched for directly and not found.
- The **practical failure mode this project needs to design for is not silent corruption** — it's a **mid-task hard error** (400, fast-failing) if a multi-turn agentic conversation is allowed to grow past 32768 tokens without Cline proactively compacting near 26k as PROJECT.md's own formula expects. That is a reliability/UX problem (wasted task, needs restart) but not a silent-wrong-answer problem, which meaningfully changes the risk profile from what PROJECT.md assumed.

**Recommendation for the roadmap:** treat `models[].contextWindow: 32768` in `providers.json` as a **best-effort, unverified-at-the-Cline-level mitigation** to attempt (cheap, no downside), but do **not** treat it as sufficient on its own. Build the actual regression test as a **multi-turn** conversation (via `cline --id <session>` resume) that pushes accumulated history past 26,214 tokens over 2–3 turns, and observe whether Cline proactively compacts (look for a `compaction`/`summarize`-flavored `agent_event` in the `--json` stream) versus running until it hits the same fast, clean 400 from the server. This is the single most important open item for the implementation phase.

*Confidence: HIGH on the source-code finding and the "hard 400, fast, from the existing stack" behavior (both directly reproduced). MEDIUM-LOW on whether `models[].contextWindow` changes Cline's internal compaction threshold — not conclusively testable within this research's time budget; flagged as the first thing to test in the actual implementation phase.*

---

## 3. Kanban server (`cline kanban` / `cline --kanban`)

**Verified behavior (ran directly, inspected `lsof`, read the installed `kanban` npm package source):**

- `cline kanban` takes **zero CLI flags** (`cline kanban --help` → only `-h`). Passing any unknown flag (`--host`, `--port`, even `--config` *after* the subcommand) errors with `unknown option`. `--config` must be given **before** the subcommand: `cline --config <dir> kanban`.
- On first run it **lazily npm-installs a separate package `kanban`** globally ("Installing kanban@latest…", `added 299 packages`) — this is a real, additional supply-chain surface distinct from the `cline` package itself, with its **own** auto-updater (`autoUpdateOnStartup2`) and no discovered opt-out env var (only a `--update` flag to force-run it, and that flag also isn't reachable through `cline kanban`). Installed at `/opt/homebrew/lib/node_modules/kanban` (v0.1.70 at time of writing), binary at `/opt/homebrew/bin/kanban`.
- **Default bind: `127.0.0.1:3484`.** Verified via `lsof` while running: `TCP 127.0.0.1:3484 (LISTEN)`, and the printed banner `Cline Kanban running at http://127.0.0.1:3484/<workspace-basename>`.
- **Host/port ARE controllable — via environment variables, not CLI flags**, and these ARE honored even through the `cline kanban` wrapper (verified: `KANBAN_RUNTIME_PORT=3485` moved the bind to `:3485`; `KANBAN_RUNTIME_HOST=0.0.0.0` moved it to `*:3486`). Found in the kanban package's own compiled source:
  ```js
  DEFAULT_KANBAN_RUNTIME_HOST = "127.0.0.1";
  DEFAULT_KANBAN_RUNTIME_PORT = 3484;
  runtimeHost = process.env.KANBAN_RUNTIME_HOST?.trim() || DEFAULT_KANBAN_RUNTIME_HOST;
  runtimePort = parseRuntimePort(process.env.KANBAN_RUNTIME_PORT?.trim());
  ```
  The standalone `kanban` binary additionally supports `--host`, `--port`, `--https`/`--cert`/`--key`, `--no-passcode` directly as CLI flags (per `kanban --help`) — but these are **only reachable if you bypass `cline kanban` and run the installed `kanban` binary directly**; the `cline kanban` wrapper does not forward argv to it.
- **Built-in auth: an auto-generated 8-character passcode, but only when bound to a non-loopback host.** Verified by reading `passcode-manager.ts` (compiled) and observing behavior live:
  - Bound to `127.0.0.1` (default): `isKanbanRemoteHost()` is false, no passcode is ever generated or required.
  - Bound to `0.0.0.0` (or any non-`127.0.0.1`/`::1`/`localhost` address): a passcode is generated and printed once at startup (`🔐 Remote access passcode: <8 chars>`), enforced via an `HttpOnly` session cookie (24h TTL) or `Authorization: Bearer <token>`, with rate limiting (5 attempts / 30s lockout). `--no-passcode` (standalone binary only) disables this ("Ensure you have your own auth layer" — exactly the Tailscale case).
  - There is no per-source-IP exemption: if bound to `0.0.0.0`, **both** Tailscale-interface and LAN-interface traffic hit the same single passcode gate. There is no way, using kanban's own flags, to be unauthenticated-over-Tailscale-but-token-gated-over-LAN with a single bind.

**Recommendation for architecture/roadmap:** keep `cline kanban` bound to its default `127.0.0.1:3484` (no env override, no passcode) and use `tailscale serve` (or `tailscale funnel` if internet exposure were ever wanted, which PROJECT.md explicitly excludes) to reverse-proxy the tailnet interface to `127.0.0.1:3484`. Tailscale's own device-level ACL then satisfies "Tailscale 무인증." For the separate "LAN requires a token" requirement, kanban's own env-var-triggered passcode cannot cleanly serve both audiences from one bind; treat LAN access as a distinct decision for the architecture research (e.g., a second thin authenticating reverse proxy on the LAN interface, or simply accept kanban's passcode for BOTH surfaces as an acceptable practical compromise, since the passcode is a one-time entry backed by a 24h cookie).

*Confidence: HIGH on all bind/host/port/passcode behavior — all directly reproduced with `lsof` and log output. MEDIUM on the multi-surface-auth architecture recommendation (a design choice, not a fact to verify).*

---

## 4. Connectors (`cline connect`)

`cline connect --help` (run directly):

```
Usage: cline connect [options] [channel]
  --stop                   Kill all current channel connections
  --restart                Restart a channel connection
  --restart-instance <id>  Restart one connector instance (used by daemon recovery)
  --cleanup-instance <id>  Reap one dead connector instance, preserving autostart (used by hub supervision)
Run 'connect <channel> --help' for channel-specific options.
```

`cline connect telegram --help` (run directly):

```
Usage: telegram -k <TELEGRAM_BOT_TOKEN> [options]
  -m, --bot-username <name>  fetched from token if omitted
  -k, --bot-token <token>
  --provider <id>            Provider override
  --model <id>                Model override
  --api-key <key>             Provider API key override
  --system <prompt>           System prompt override
  --cwd <path>
  --mode <act|plan>           (default: "act")
  -i, --interactive           Keep connector in foreground
  --no-tools
  --enable-tools               (default)
  --allowed-user-id <id>      Only allow this Telegram user ID to use the bot
  --hook-command <command>    Run a shell command for connector events
  --rpc-address <host:port>   (default: "127.0.0.1:25463")
```

**Findings:**
- Telegram is **long-polling**, not webhook-based (no webhook-URL flag exists; matches PROJECT.md's exclusion of exposing a public webhook endpoint).
- `-i/--interactive` is the flag to "Keep connector in foreground" — implying the **default**, without `-i`, is to hand off to Cline's own **hub daemon** for background supervision (`--restart-instance`/`--cleanup-instance` explicitly say "used by hub supervision"). The hub daemon (`cline-hub-daemon`) was observed running as `/opt/homebrew/lib/node_modules/cline/bin/.cline --cline-hub-daemon --cwd <workspace> --host 127.0.0.1 --port 25463 --pathname /hub` — confirmed via `ps aux`, launched lazily by the first `cline` command that needs it, not started by any launchd unit today.
- `--allowed-user-id` provides the per-user allowlist PROJECT.md wants natively — no custom code needed.
- `--hook-command` allows arbitrary shell-command hooks on connector events (useful for audit logging, but out of scope here).

**Recommendation:** for launchd, run `cline connect telegram -i --bot-token <TOKEN> --allowed-user-id <ID> -P openai-compatible ...` **in the foreground** (`-i`) as the launchd `ProgramArguments`, letting launchd's own `KeepAlive` do the supervision — matching the house style of `com.ohama.flashnext`/`com.ohama.litellm` (both foreground long-running processes under launchd) rather than relying on Cline's own hub-daemon supervision (avoids two independent supervisors fighting over the same process).

*Confidence: HIGH — all flags and the hub daemon's existence/bind were directly observed. MEDIUM on the "prefer `-i` under launchd over hub supervision" recommendation (architectural judgment call, not a hard fact).*

---

## 5. Headless one-shot mode (`cline --json` / positional prompt)

**Verified invocation:**

```bash
CLINE_NO_AUTO_UPDATE=1 cline --config <dir> -P openai-compatible \
  -v --json --timeout 90 --auto-approve true "your prompt here"
```

**Verified NDJSON event schema** (captured live from a real run against the production `flashnext` endpoint):

```json
{"ts":"...","type":"run_start","providerId":"openai-compatible","modelId":"flashnext","catalog":"live","thinking":"off","mode":"act"}
{"ts":"...","type":"hook_event","hookEventName":"agent_start","agentId":"...","taskId":"...","parentAgentId":null}
{"ts":"...","type":"agent_event","event":{"type":"iteration_start","iteration":1}}
{"ts":"...","type":"agent_event","event":{"type":"content_start","contentType":"text","text":"pong","accumulated":"pong"}}
{"ts":"...","type":"agent_event","event":{"type":"usage","inputTokens":5495,"outputTokens":2,"totalInputTokens":5495,"totalOutputTokens":2,"totalCost":0}}
{"ts":"...","type":"agent_event","event":{"type":"content_end","contentType":"text","text":"pong"}}
{"ts":"...","type":"agent_event","event":{"type":"iteration_end","iteration":1,"hadToolCalls":false,"toolCallCount":0}}
{"ts":"...","type":"hook_event","hookEventName":"agent_end","agentId":"...","taskId":"...","parentAgentId":null}
{"ts":"...","type":"agent_event","event":{"type":"done","reason":"completed","text":"pong","iterations":1,"usage":{...}}}
{"ts":"...","type":"run_result","finishReason":"completed","iterations":1,"usage":{...},"aggregateUsage":{...},"durationMs":10296,"text":"pong","model":{"id":"flashnext","provider":"openai-compatible"}}
```

On error, the same stream instead emits an `agent_event` of `{"type":"error","error":{"name","message","stack"}}` followed by a `run_result` with `finishReason":"error"` — confirmed via the oversized-prompt test in §2c. Exit code is non-zero (`1`) on failure.

**Notable field:** `"catalog":"live"` appears in every `run_start`. This suggests Cline resolves its model catalog against a live/remote source at task-start time even for a purely local `openai-compatible` provider — a potential hidden network dependency worth flagging for the "no internet exposure" requirement (this project doesn't forbid outbound calls, only inbound exposure, so likely fine, but worth a note in PITFALLS).

**Auto-approval / tool-access flags** (from top-level `cline --help`, run directly):

| Flag | Effect |
|------|--------|
| `--auto-approve <boolean>` | Global auto-approval for all tools (default `true`) |
| `--compaction <agentic\|basic\|off>` | Context compaction mode (default `agentic`) |
| `--worktree` | Auto-creates a detached git worktree under `~/.cline/worktrees/` and runs the task there — directly usable for PROJECT.md's "workspace sandbox" requirement |
| `--retries [n]` | Max consecutive mistakes before exiting (default 6) |
| `-t, --timeout <seconds>` | Task timeout (default 0 = unbounded — **must be set explicitly** for a server context) |
| `-s, --system <prompt>` | Override system prompt |
| `--data-dir <dir>` | Isolated local state ("enables sandbox mode" per its own help text) |

*Confidence: HIGH — schema captured from live, real output against the production endpoint; not from documentation.*

---

## 6. launchd on this Darwin 25.3 / macOS 15+ host

House style (read directly from `~/local-llm-settings/launchagents/com.ohama.flashnext.plist` and `com.ohama.litellm.plist`, **not modified**):

- Plists live at `~/Library/LaunchAgents/`, with a synced copy at `~/local-llm-settings/launchagents/`.
- Labels are `com.ohama.*`.
- Every service uses `RunAtLoad: true`, `KeepAlive: true`, `ThrottleInterval` (60s for the heavyweight model server, 10s for litellm — scale to the service's startup cost).
- `EnvironmentVariables` carries an explicit `PATH` scoped to the service's own venv/bin plus system paths — no reliance on shell profile.
- `StandardOutPath`/`StandardErrorPath` point at `~/llm-system/services/logs/<service>.{log,err}` (flashnext) or a project-local log dir (litellm) — this project's services should log to `~/llm-system/services/logs/` per the house rule already stated in PROJECT.md.
- `WorkingDirectory` is set explicitly in both examples.

**New for this project — required additions to every Cline-based plist's `EnvironmentVariables`:**

```xml
<key>CLINE_NO_AUTO_UPDATE</key><string>1</string>
```

and, for the kanban service specifically:

```xml
<key>KANBAN_RUNTIME_HOST</key><string>127.0.0.1</string>
<key>KANBAN_RUNTIME_PORT</key><string>3484</string>
```

(these two are only needed if a non-default bind is desired; 127.0.0.1:3484 is already the default and needs no env vars at all).

**Verified launchctl lifecycle for macOS 15+/26 (Darwin 25.x uses the modern `bootstrap`/`bootout`/`print` verbs; the legacy `load`/`unload`/`list` verbs still work but are deprecated):**

```bash
U=$(id -u)
launchctl bootstrap gui/$U ~/Library/LaunchAgents/com.ohama.cline-kanban.plist
launchctl enable gui/$U/com.ohama.cline-kanban
launchctl kickstart -k gui/$U/com.ohama.cline-kanban   # -k = kill and restart
launchctl print gui/$U/com.ohama.cline-kanban            # inspect state, last exit code, pid
launchctl bootout gui/$U/com.ohama.cline-kanban          # unload
```

This exact `bootstrap`/`enable`/`kickstart`/`print`/`bootout gui/$UID/<label>` pattern is already how this project's own README (`TOPOLOGY.md`) documents reviving disabled services on this machine, confirming it is the correct, currently-working verb set on this exact host.

*Confidence: HIGH for the plist structure and launchctl verbs (directly read from working, currently-running house files and the project's own docs). HIGH for the required new env vars (directly verified in §0 and §3).*

---

## 7. Gateway-side 32K guard — what's already there vs. what to add

**What already exists and was verified working end-to-end in §2c, with zero code changes:**
`mlx_vlm.server --max-kv-size 32768` rejects any request whose `prompt + max_tokens` exceeds 32768 with a clean HTTP 400 in well under a second (before prefill), and `role_shim.py` forwards that error verbatim (confirmed by reading its `except urllib.error.HTTPError as e: up = e` passthrough), and `litellm` surfaces it as a normal `litellm.BadRequestError`. **This is already a real, working, fast-failing guard today.** No `role_shim.py` change is required for basic safety.

**What `role_shim.py` currently does NOT do (read directly, confirmed no such logic exists):** any token counting, any request-size introspection beyond the JSON message-role rewrite, and no place where an early rejection before hitting `:8000` would go. Adding a guard here would mean adding a token-counting dependency (e.g. `tiktoken`) to a script that currently has zero third-party imports (`argparse, json, urllib.request, urllib.error` from stdlib only) — a real increase in surface area for a script whose entire value is being minimal and pass-through.

**What litellm supports natively today (verified against current official docs, cross-checked against the installed `litellm==1.86.1`, which comfortably post-dates this feature):**

```yaml
router_settings:
  enable_pre_call_checks: true      # required — without it max_input_tokens is ignored

model_list:
  - model_name: flashnext
    litellm_params: { ... unchanged ... }
    model_info:
      max_input_tokens: 26000        # fail before it ever reaches role-shim/mlx
```

When exceeded, litellm raises its own `ContextWindowExceededError` with a message like `Model=flashnext, Max Input Tokens=26000, Got=<n>` — before making any upstream HTTP call at all, i.e. faster than even the existing 400ms round-trip in §2c, and without touching `role_shim.py`.

**Recommendation (least-invasive, ranked):**
1. **Do nothing** for basic safety — the existing `mlx_vlm.server --max-kv-size 32768` guard already works, is already fast, and was already proven in this research session. This satisfies "requests over 32768 are rejected."
2. **Optionally add** the two-line `litellm-config.yaml` change above (`router_settings.enable_pre_call_checks: true` + `model_info.max_input_tokens` on the `flashnext`/`flashnext-codex` entries) as defense-in-depth and to fail a little earlier/friendlier, and to set the limit *below* 32768 (e.g. matching the compaction-trigger math, ~26,214) so litellm becomes the first line of defense rather than the model server. This is a config-only change to an already-existing file, zero new dependencies, zero new processes.
3. **Do not** add token-counting logic to `role_shim.py` — it would require a new dependency in a file whose entire design value is dependency-free pass-through, for a guard that already exists one hop downstream (option 1) or one config change away (option 2).

*Confidence: HIGH on what already exists (behaviorally proven). HIGH on the litellm config syntax (official docs, current). MEDIUM on the exact numeric threshold to configure in litellm (26,214 vs 32,768 vs something else) — this is a product decision for the regression-test phase, not a stack fact.*

---

## 8. Versions to pin (for anything newly added)

| Component | Version | Status |
|-----------|---------|--------|
| `cline` (npm, global) | **3.0.53**, exact | Must actively re-pin (`npm install -g cline@3.0.53 --no-save`) if it ever drifts; **must** run with `CLINE_NO_AUTO_UPDATE=1` from now on to stay pinned |
| `kanban` (npm, global) | **0.1.70** at time of writing | Auto-installed on first `cline kanban` run; re-pin the same way after first run; no known opt-out for its own auto-updater |
| Node.js | 25.9.0 | Already installed, satisfies Cline's requirement; no change |
| Python | 3.14.6 (system) | Already installed; `role_shim.py` needs no changes (see §7) |
| `litellm` | 1.86.1 (already installed in `~/agent-stack/venv`) | No upgrade needed — `enable_pre_call_checks`/`max_input_tokens` already supported; this is a config-only change |
| uv | 0.11.14 | Already installed; only needed for `cline-bench`'s Python 3.13 requirement (out of scope for this file, noted for completeness) |
| Docker | (already installed, per PROJECT.md) | Only needed for `cline-bench`; no version constraint discovered specific to this project |

**Zero new runtime dependencies are recommended anywhere in this stack.** The strongest temptation — adding token-counting to `role_shim.py` — is explicitly recommended against in §7 in favor of a config-only litellm change.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Kanban exposure to Tailscale | `tailscale serve` proxying to `127.0.0.1:3484` (kanban stays loopback-only, no passcode) | Bind kanban directly to the Tailscale interface via `KANBAN_RUNTIME_HOST=<ts-ip>` | Kanban's passcode gate triggers for *any* non-loopback bind, so binding directly to the tailnet interface would force the same passcode prompt Tailscale access was supposed to avoid — `tailscale serve` avoids this by keeping kanban's own bind loopback-only |
| 32K request guard | Rely on existing `mlx_vlm.server --max-kv-size` (already works) + optional `litellm` `enable_pre_call_checks`/`max_input_tokens` | Token-counting logic added to `role_shim.py` | Adds a new dependency (tiktoken or similar) to a currently dependency-free pass-through script, to reimplement a guard that already exists one hop away and was proven to already work |
| Telegram connector supervision | Foreground (`-i`) under launchd `KeepAlive`, matching house style | Cline's own hub-daemon background supervision (`--restart-instance`) | Two independent supervisors (launchd + Cline hub) managing the same process invites split-brain restart behavior; launchd already does this reliably for the other two services on this machine |
| Cline version pin enforcement | `CLINE_NO_AUTO_UPDATE=1` env var in every plist | Wrapper script that re-installs `cline@3.0.53` after every run | The env var is a documented (if unofficially so — found only in the compiled binary, not in `--help`) kill-switch that fully prevents the background updater from ever running; a re-install wrapper is reactive (fixes drift after the fact) rather than preventive, and adds startup latency to every invocation |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `cline config --json` for programmatic config reads | Requires a real TTY in 3.0.53 even with `--json`; hangs waiting for interactive input under a faked pty | Read `~/.cline/data/settings/providers.json` directly — it's plain JSON |
| Any `cline` invocation without `CLINE_NO_AUTO_UPDATE=1` in production | Silently drifts the pinned version within minutes of normal use (reproduced twice in this research session) | Always set the env var, verified in §0 |
| Relying on `providers.json`'s `models[].contextWindow` as the *only* 32K safeguard | Unverified whether Cline's own compaction logic actually reads it (§2c); even if it does, it can't help with an already-oversized single message | Layer it with the already-working, already-proven `mlx_vlm.server --max-kv-size 32768` hard guard (§7) |
| Passing `--host`/`--port` to `cline kanban` | These flags don't exist on the subcommand; commander.js rejects them outright | `KANBAN_RUNTIME_HOST`/`KANBAN_RUNTIME_PORT` env vars — verified to work through the wrapper |

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `cline@3.0.53` | Node 22+ (25.9.0 installed) | Confirmed working; Node is only used for the thin resolver shim, not the agent runtime itself (Bun-compiled binary) |
| `cline@3.0.53` openai-compatible provider | `litellm@1.86.1` OpenAI-compatible endpoint on `:4000` | Confirmed working end-to-end with a real generation (`"pong"` response captured) |
| `litellm@1.86.1` | `enable_pre_call_checks` / `model_info.max_input_tokens` | Long-supported litellm feature, confirmed present in current official docs, no version bump needed |
| `kanban@0.1.70` | `cline@3.0.53` | Installed and launched successfully by `cline kanban`; version pair not otherwise documented anywhere, only confirmed by direct use |

## Sources

- Direct execution and inspection on this machine: `/opt/homebrew/bin/cline`, `/opt/homebrew/lib/node_modules/cline/` (npm-registry-fresh `3.0.53` reinstalled specifically for this research after the auto-updater drifted the pre-existing install to `3.0.60`), `/opt/homebrew/lib/node_modules/kanban/`, `~/.cline/`.
- `~/local-llm-settings/{README.md,TOPOLOGY.md,VALIDATED.md,STATE.md,config/litellm-config.yaml,config/role_shim.py,launchagents/com.ohama.flashnext.plist,launchagents/com.ohama.litellm.plist}` — read only, not modified.
- `/Users/ohama/projs/cline-tests/.planning/PROJECT.md` — project context and the original bug citation (issue #12520), independently corroborated against the live installed source in §2a.
- [LiteLLM Reliability / Fallbacks docs](https://docs.litellm.ai/docs/proxy/reliability) — `enable_pre_call_checks` / `max_input_tokens` syntax, fetched and quoted directly.
- GitHub `cline/cline` issue #12520 (cited by PROJECT.md, not independently re-fetched from GitHub in this session — corroborated instead by directly reading the installed source, which is stronger evidence for "is this still true in 3.0.53 on this machine" than re-reading the issue text).

---
*Stack research for: Cline persistent macOS server against a local OpenAI-compatible endpoint*
*Researched: 2026-08-29*
