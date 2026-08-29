# Pitfalls Research

**Domain:** Persistent local-LLM coding-agent server (Cline CLI + Kanban + Telegram connector, backed by a 32K-context local model, exposed over Tailscale/LAN to iPad/iPhone)
**Researched:** 2026-08-29
**Confidence:** HIGH on context-accounting and security findings (verified against live `cline/cline` source at commit `1986fa56` / today's `main`, live GitHub issue states via `gh`, and live curl probes against the running `litellm→role-shim→mlx_vlm.server` stack on this machine). MEDIUM on launchd/cline-bench specifics that could not be safely tested live (would require restarting services or loading a second model, which was out of scope for this research).

**Verification method:** `gh issue view` / `gh pr view` against `cline/cline` (today, 2026-08-29), a fresh `git clone --depth 1` of `cline/cline` read directly for source-of-truth (not memory), and live `curl` probes against `localhost:4000` / `:8011` / `:8000`, `docker info`, `lsof -i`, and `ps` on the actual machine. Every claim below is tagged with how it was verified.

---

## Critical Pitfalls

### Pitfall 1: Cline's context-window fallback silently overrides the real 32,768 ceiling (root cause of the project's Core Value threat)

**What goes wrong:**
Cline's `openai-compatible` provider (which is what `flashnext` via litellm looks like to Cline) does not reliably use the context window you configure. `resolveModelInfo()` in `sdk/packages/llms/src/providers/compat.ts` (confirmed present, byte-identical to the analysis in `cline-analysis.md`, in `main` at commit `1986fa56de5dc91d635ef3a696136f6dc11799dd`, 2026-08-28) is:

```ts
function resolveModelInfo(config: ProviderConfig): ModelInfo {
	return (
		config.modelInfo ??
		(config.modelId ? config.knownModels?.[config.modelId] : undefined) ?? {
			id: config.modelId,
			name: config.modelId,
			capabilities: ["streaming"],
		}
	);
}
```
`resolveRuntimeConfig()` in `agent-runtime.ts` always sets a truthy stub `{ id, provider }` into `config.modelInfo` before this runs. Because `??` only falls through on `null`/`undefined`, that stub — which has no `contextWindow` field — wins, and `knownModels[modelId]` (which *would* have your configured 32768) is **never consulted**. The stub then resolves to `fallbackModelInfo()`, which for `family === "openai-compatible"` hardcodes:
```ts
info.contextWindow  = 128_000;
info.maxInputTokens = 128_000;
```
So even after you set "Context Window: 32768" in Cline's config, Cline's internal compaction math may still use **128,000**, not 32,768. Auto-compact threshold is `max(ctx − 40000, ctx × 0.8)`, so with the 128k fallback, Cline will let the conversation grow to **115,200 tokens before ever considering compaction** — 3.5× past the point where the actual backend can accept the request.

**Why it happens:**
This is not a hypothetical — it is **issue #12520**, filed against CLI 3.0.46, confirmed **still OPEN today** with the exact root cause above, and the two PRs that attempt fixes (**#12643**, **#12678**) are both **OPEN, unmerged, 0 commits toward main** as of 2026-08-29. A third, narrower manifestation for llama.cpp/LM Studio-style servers is **#13457** ("Context window is set to 128k for local models"), filed 2026-08-21 against CLI 4.1.11, **OPEN**, reproduced explicitly on **Qwen 3.8 27B**. Neither issue is fixed in any released version, and the CLI installed on this machine is **3.0.60** (verified via `cline --version`; note this is newer than the `3.0.53` recorded in PROJECT.md — see Pitfall 12).

**Consequences (verified against the actual model server on this machine):**
`mlx_vlm.server` enforces `--max-kv-size 32768` as a hard wall and fails fast and loudly — this is good news, verified by source (`generation.py`):
```python
class PromptTooLongError(ValueError): ...

def _check_configured_context_budget(prompt_tokens, max_tokens):
    context_limit = get_configured_context_limit()
    requested_tokens = prompt_tokens + max(0, int(max_tokens or 0))
    if context_limit is not None and requested_tokens > context_limit:
        raise PromptTooLongError(
            f"Request needs {requested_tokens} context tokens "
            f"({prompt_tokens} prompt + {max_tokens} max generation), "
            f"but MAX_KV_SIZE is {context_limit}."
        )
```
This check runs *before* the expensive prefill (cheap, fast — no 64s wasted), and returns HTTP 400. **Live-verified end-to-end through litellm on this machine:**
```
$ curl localhost:4000/v1/chat/completions -d '{"model":"flashnext","messages":[{"role":"user","content":"hi"}],"max_tokens":40000}'
→ HTTP 400
{"error":{"message":"litellm.BadRequestError: OpenAIException - Error code: 400 - {'detail': 'Request needs 40013 context tokens (13 prompt + 40000 max generation), but MAX_KV_SIZE is 32768.'}. ..."}}
```
So the actual failure mode is **not silent corruption** — it's a **hard stop Cline doesn't expect**, at a point where Cline's own UI still shows headroom (because it thinks the limit is 128k) and Cline's auto-compact hasn't triggered (because 32,768 < 115,200). This exact compound failure — auto-compact never fires, and then a subsequent *manual* compact attempt *also* fails because the compaction target itself is computed against the wrong window — is independently documented in **#7772** ("Auto Compact Fails on Certain Local Models (llama-server)", **CLOSED as not-planned**, but the mechanism it describes is the same one at play here and is still live in current `main`).

**Prevention:**
1. Do not trust Cline's Settings UI "Context Window" field alone — treat it as necessary but not sufficient.
2. Add a **gateway-layer guard in front of litellm** that inspects `prompt_tokens + max_tokens` (or a conservative proxy for it) and returns an early, clear rejection *before* 32,768 real tokens are reached — e.g. reject/compact at ~28-30K, well under the server's hard 32,768 wall and under the point where 64s TTFT makes a wasted round-trip expensive. This is PROJECT.md's own planned "게이트웨이 계층에 32K 초과 요청 가드" — this research confirms it is **not redundant defense-in-depth, it is the actual load-bearing control**, because Cline-side configuration cannot be trusted to work given #12520/#13457 are unfixed.
3. Set Cline's context window config anyway (defense in depth, and it happens to be correct for other code paths), but do not treat "I configured it" as "it is enforced" — see Pitfall 11 (Looks Done But Isn't).
4. Regression-test this specifically: intentionally grow a session past 32,768 tokens and confirm the gateway guard fires *before* mlx_vlm.server's 400, and that Cline surfaces a clean, actionable message rather than retrying blindly.

**Detection signal (what you will actually see if this is NOT fixed):**
- Cline's own context bar keeps reporting comfortable headroom.
- No `Context compacted · X → Y` message appears even though the conversation is clearly long.
- Eventually: an opaque `litellm.BadRequestError ... but MAX_KV_SIZE is 32768` bubbling up mid-task, with no warning beforehand.
- If you then try `/compact` manually, it can fail too, because the compaction target itself may be computed against 128,000 → matches #7772's exact symptom.

**Severity:** CRITICAL — this is the literal Core Value the project exists to protect ("Cline이 조용히 고장 나지 않고 정직하게 동작하는 것").

**Phase to address:** The phase that configures Cline's provider + context window, AND the phase that builds the gateway 32K guard — these must ship together, not sequentially, because #1 alone (Cline config) is proven insufficient.

---

### Pitfall 2: Cline's context-window *display* is independently unreliable — do not use it as your regression-test oracle

**What goes wrong:**
Even if Pitfall 1's compaction-math bug were fixed, the *percentage bar shown in the UI* has at least three more independently-reported and independently-caused bugs. Live-checked statuses (2026-08-29):

| Issue | Status (verified today via `gh`) | Symptom |
|---|---|---|
| [#6494](https://github.com/cline/cline/issues/6494) | **CLOSED, not_planned** (P2) | LM Studio set to 262,144 context, but usage bar always caps at 32.8k. Workaround from a user comment: manually set LM Studio's context slightly *below* its max before loading the model. |
| [#10375](https://github.com/cline/cline/issues/10375) | **OPEN**, labeled `stale` | Same 32.8k display cap bug, now on CLI 3.80.0 / `qwen3.6-35b-a3b`; percentage exceeds 100% once real usage passes 32.8k. Purely a display bug per the reporter — the actual context window works, only the shown max is wrong. |
| [#9433](https://github.com/cline/cline/issues/9433) | **OPEN** | If the OpenAI-compatible endpoint returns `"usage": null`, the bar sticks at 0% for the entire session (NaN from dividing by null). PR **#9613** ("hide the bar when usage is unavailable") is **OPEN, unmerged**. |
| [#7383](https://github.com/cline/cline/issues/7383) | **OPEN** | The bar shows usage from the *last completed* API request, not what the *next* request will actually send — large tool outputs / images added since the last request aren't reflected, so the bar can under-report by ~100K tokens right before a hard failure. |

**Why it happens:** These are four structurally different bugs (a hardcoded `32.8k` display constant that leaks in regardless of configured window; a null-safety gap when a provider omits `usage`; and a staleness gap in what the bar measures) — not one bug. Fixing one does not fix the others.

**Consequences for this project specifically:** #9433 is **not currently applicable to our exact stack** — verified live: both non-streaming and streaming (`stream_options: {"include_usage": true}`) responses from `litellm→role-shim→mlx_vlm.server` return a fully-populated `usage` object (see Pitfall/finding under "usage object" below). So #9433's specific trigger doesn't fire *today*. But #10375/#6494's "32.8k display cap" bug is worth double-checking empirically once Cline is actually pointed at `flashnext`, precisely because **our real ceiling (32,768) happens to numerically equal the buggy display constant (32.8k) that those two issues report** — meaning the bug could accidentally look "correct" for us even while being wrong for the reason described in the issue. Don't assume it's fine just because the number matches; verify it's reading your actual configured value and not coincidentally hitting the same hardcoded fallback.

**Prevention:** Never use Cline's own context bar as the pass/fail signal for the regression test required by PROJECT.md. Verify actual token counts from **mlx_vlm.server's own logs** (`~/llm-system/services/logs/flashnext.log` / `.err`, which log `prompt_tokens=` per request — verified live) or from the `usage.prompt_tokens` field in the raw API response, not from the UI.

**Detection signal:** UI shows a percentage that doesn't move, that caps oddly at "32.8k" for reasons unrelated to your real 32,768 ceiling, or that lags one request behind reality.

**Severity:** CRITICAL (undermines the only visible safety signal a user has) but easy to route around once known.

**Phase to address:** Regression-test phase — build the test harness against server-side logs/usage fields, not the Cline UI.

---

### Pitfall 3: Unbounded continuous batching + 4.39 GB headroom = the concurrency risk is real and currently unmitigated

**What goes wrong:**
`mlx_vlm.server` (verified by reading its installed source at `.venv-mlxvlm-new/lib/python3.12/site-packages/mlx_vlm/server/`) is **not** a naive single-request server — it runs a genuine `ResponseGenerator` with `continuous_batching`, confirmed live in `flashnext.err`:
```
Request started: ... in_flight=1
Request started: ... in_flight=2
Prefill started: request=A backend=continuous_batching prompt_tokens=27
Prefill started: request=B backend=continuous_batching prompt_tokens=27
Prefill completed: request=A elapsed=1.483s   Prefill completed: request=B elapsed=1.483s   ← genuinely concurrent, not queued
```
Two concurrent short requests were sent live during this research and both completed successfully with **identical prefill timing** — real batching, not serialization, not rejection. This is good for throughput, but the server's own CLI documents `--max-num-seqs`:
> "Maximum number of sequences decoded concurrently in the continuous batch. Requests beyond this wait in the queue (backpressure), bounding peak memory. **Default: unbounded.**"

The currently-running `com.ohama.flashnext` launchd service (verified from its plist) does **not** pass `--max-num-seqs`, so it is running with **no backpressure limit**.

**Why it happens:** Nobody has needed concurrency limits yet because there has been exactly one client. The moment Kanban (parallel cards) and/or Telegram and Kanban dispatch simultaneously, two or more sessions can be mid-conversation near the 32K ceiling at the same time.

**Consequences:** VALIDATED.md's own measured number is the entire risk surface: at 32K, peak memory is **120.16 GB against a 124.55 GB `iogpu.wired_limit_mb` — 4.39 GB headroom**, and that number was measured with exactly **one** in-flight 32K sequence. A second concurrent near-32K sequence adds its own KV cache (~1 GB at 32K per VALIDATED.md's own KV-cache table) *and* its own prefill activation buffers — the exact mechanism the docstring calls out ("bounding peak memory" is the entire point of the flag). There is no empirical measurement of 2-concurrent-32K on this machine (deliberately not tested in this research — it would consume real headroom against a live production service and risks exactly the failure being investigated), so treat this as an **unverified but architecturally well-founded risk**, not a confirmed crash.

**Prevention:**
1. Set `--max-num-seqs 1` (or a very conservative 2) explicitly in `com.ohama.flashnext.plist` before Kanban/Telegram go live — this converts "unbounded concurrent batching that could blow the 4.39 GB headroom" into "clean FIFO queueing," which is exactly the tradeoff PROJECT.md already implicitly wants (single-user, single-model machine).
2. Alternatively/additionally, enforce single-flight at the gateway (litellm or a thin layer in front of it) so Kanban's parallel-card execution and the Telegram connector cannot both be mid-prefill at once regardless of what the model server allows.
3. If concurrency is ever actually tested, do it at low context sizes first (the existing 2-concurrent-short test is safe; do not repeat this at 32K without deliberately budgeting for potential OOM).

**Detection signal:** `flashnext.err` shows `in_flight=2` (or higher) with prompt_tokens each in the tens-of-thousands; `peak_memory` in the `timings` block of any response approaching 124 GB; macOS memory pressure spiking; in the worst case, the model process being killed by the kernel for exceeding `iogpu.wired_limit_mb`.

**Severity:** CRITICAL for the multi-surface (Kanban + Telegram) design point of this project specifically, because it is the one scenario genuinely new to this machine (previously only one client existed).

**Phase to address:** Should be addressed in the same phase that stands up the second and third surfaces (Kanban launchd service, Telegram launchd service) — before both can run concurrently, not after.

---

### Pitfall 4: litellm is already listening on all interfaces with no master key — this is a live gap today, not a future risk

**What goes wrong:**
`litellm`'s CLI defaults `--host` to `0.0.0.0` (verified in the installed package: `litellm/proxy/proxy_cli.py:456: "--host", default="0.0.0.0"`). The running `com.ohama.litellm` launchd service does not pass `--host`, so it inherits this default. **Live-verified right now on this machine:**
```
$ lsof -i :4000 -sTCP:LISTEN
python3.1 76864 ohama ... TCP *:4000 (LISTEN)      ← all interfaces, not 127.0.0.1
```
By contrast, `role-shim` (8011) binds `127.0.0.1` explicitly in its own source, and `mlx_vlm.server` (8000) is started with `--host 127.0.0.1` in its plist — both correctly localhost-only. **litellm (:4000) is the one exposed leg of the current chain**, and its config (`litellm-config.yaml`, read directly) has no `general_settings.master_key` block — every model alias accepts `api_key: dummy`, i.e., anyone who can route a packet to port 4000 (any LAN device, and by extension anyone on the Tailscale tailnet once Tailscale is added as a client surface) can call the model with zero authentication today.

**Why it happens:** litellm's proxy is designed to be fronted by something else (a reverse proxy, or its own `master_key`) in production; the quickstart/default config used here never turned that on because the only prior clients were local.

**Consequences:** This directly contradicts the project's own stated constraint ("Tailscale 무인증, LAN 은 토큰 요구") — right now, LAN gets exactly the same unauthenticated access as Tailscale, because nothing distinguishes them at the litellm layer.

**Prevention:** Set `general_settings.master_key` (or per-key virtual keys) in `litellm-config.yaml`, and/or bind litellm to `127.0.0.1` and put a small authenticating reverse proxy or firewall rule in front of it for LAN access, while allowing Tailscale's own network-layer trust to remain unauthenticated as designed. Verify with `lsof -i :4000` after the change — do not just check the config file, check the actual bound address, since defaults can silently win (as they did here).

**Detection signal:** `lsof -i :4000` shows `*:4000` instead of `127.0.0.1:4000`; a curl from another device on the LAN to `http://<mac-ip>:4000/v1/chat/completions` with any/no `Authorization` header succeeds.

**Severity:** CRITICAL — live, present-tense exposure, verified today.

**Phase to address:** Security/auth phase ("Tailscale 무인증 접근 + LAN 접근은 토큰 요구") — should be treated as fixing an existing gap, not adding a new feature.

---

### Pitfall 5: Chat-bridge default-allow — a leaked bot token or username is full shell access, by design unless opted out

**What goes wrong:** Cline's own documentation states this plainly (fetched live from `docs/cli/connectors.mdx` in today's `main`):
> "By default, anyone who finds your bot can message it and it will execute tasks on your machine... Without `--allowed-user-id` or `--hook-command`, everything is auto-approved, so restrict Telegram bots that can reach a running Cline instance."

This was cross-checked against the actual CLI: `cline connect telegram --help` shows `--allowed-user-id <id>` as an **optional** flag with no default restriction — the bot works, and accepts messages from anyone, without it.

Separately, and independently: running `cline` directly (not through a connector) defaults `--auto-approve` to **`true`** — verified live via `cline --help`:
```
--auto-approve <boolean>  Set tool auto-approval for all tools (default: true)
```
This matters for the planned headless wrapper (PROJECT.md: "헤드리스 CLI 래퍼 스크립트") — if it shells out to `cline "<prompt>"` without explicitly passing `--auto-approve false`, every tool call is auto-approved with no human in the loop, by default, silently.

Good news, also verified live: the **connector** path (Telegram) does NOT inherit that same default — a live test-suite assertion in `connector-host.test.ts` shows connectors start with `yolo=off (disabled by connector startup)`, and the docs describe per-message `Y`/`N` approval unless `/yolo on` is explicitly sent. So the two auto-approve defaults are inconsistent across surfaces: **direct CLI = auto-approve on by default; connector = auto-approve off by default until a user opts in with `/yolo`.** Anyone building the headless wrapper needs to know which one they're getting.

**Why it happens:** `cline <prompt>` is designed as a "just do it" one-shot tool for a trusted local terminal session; connectors are designed for remote/multi-user surfaces and default conservative. The risk is treating them as interchangeable.

**Prevention:**
1. Telegram: always pass `--allowed-user-id <your-numeric-id>` (get it from `@userinfobot`). Never run the connector without it or a `--hook-command` validator.
2. Never pass `--auto-approve` or enable `/yolo` for a chat-bridge surface — this project's own README-in-progress already plans to say this; this research confirms it's the documented, explicit warning from Cline itself, not a hypothetical.
3. Headless wrapper: explicitly set `--auto-approve false` (or design the wrapper to require an explicit opt-in flag) rather than relying on the CLI's own default, since that default is `true`.
4. Kanban board: has **no auth flags at all** (`cline kanban --help` shows only `-h/--help` — confirmed live). Access control for Kanban is Tailscale-network-level only; anyone who can reach `:3484` (LAN included, unless explicitly firewalled) has full read/write board access. This must be covered by the same LAN-token plan as litellm (Pitfall 4), or Kanban should not be exposed on LAN at all — only Tailscale.

**Detection signal:** A Telegram bot that responds to a message from an unrecognized user; a headless wrapper invocation that executes a destructive command without ever asking; being able to open `http://<lan-ip>:3484` from a browser on a different LAN device and seeing the board.

**Severity:** CRITICAL (remote code execution risk if the bot token or LAN address leaks).

**Phase to address:** Telegram connector phase (bake `--allowed-user-id` into the launchd `ProgramArguments` from day one, not as an afterthought); headless wrapper phase (explicit `--auto-approve false` in the wrapper's invocation, not left to CLI defaults); Kanban phase (LAN access decision).

---

## Moderate Pitfalls

### Pitfall 6: The model can hallucinate a fake tool-call in plain text when no real tools are registered but strict output-format instructions are given

**What goes wrong:** This already happened once, and is documented in this machine's own accuracy run (`~/projs/qwen38-flash-next-tests/results/09_12_accuracy.md`, STEP 10, task-07, the project's single agent-eval failure: 14/15 = 93.3%). The request had `tools=None` (no tools registered) and instructed a strict text contract (`FILE: <path>` + fenced code, "output nothing else after the last code block"). The model ignored the contract and emitted:
```
Let me start by understanding the repository structure and reproducing the failing tests.

<tool_call>
<function=bash>
<parameter=command>
PYTHONPATH=src python3 -m unittest discover -s tests -t . 2>&1
</parameter>
```
...then stopped, having produced zero usable file output. This is an **instruction-following failure specific to when no real tool-calling API is wired up but the model's training gives it a strong latent bias toward emitting tool-call-shaped text.** It is not a parser bug — the harness's own `parse_mode` field correctly recorded `none` and this was independently confirmed by reading the raw response.

Separately (verified live in this research), when real `tools` **are** registered in the request, the model correctly emits proper native `tool_calls` in the OpenAI JSON schema (confirmed with both a single-tool test and a 4-tool Cline-shaped test with `read_file`/`write_to_file`/`execute_command`/`ask_followup_question` — both returned clean, correctly-typed `tool_calls` with `finish_reason: "tool_calls"`).

**Why it happens:** The model appears to have strong tool-call-format priors (consistent with its Qwen-family training) that surface even when the caller hasn't opted into function calling.

**Prevention:** This specific failure mode should not affect Cline itself (Cline always registers a real `tools` array via native function calling). It **is** a real risk for:
- The planned headless wrapper, if it ever calls the model directly with a text-only contract (no `tools` array) for cheapness/simplicity.
- **cline-bench**, whose harness format (`instruction.md` / text diffs, not necessarily native tool calls) may resemble the exact shape that triggered this failure — worth watching for during the cline-bench validation runs planned for this project.

**Detection signal:** A response with `finish_reason: "stop"` (not `"tool_calls"`) whose content contains a literal `<tool_call>` string and no actual file/diff output.

**Severity:** MODERATE (measured failure rate: 1 in 15 agent-style tasks on this exact model/runtime, and only in the no-tools-registered condition).

**Phase to address:** cline-bench validation phase, and headless wrapper phase — both should sanity-check for literal `<tool_call>` text appearing in plain-text responses.

---

### Pitfall 7: launchd startup ordering — dependent services will start before the 104 GiB model finishes loading, and before Tailscale is up

**What goes wrong:** `com.ohama.flashnext`, `com.ohama.role-shim`, and `com.ohama.litellm` all carry `RunAtLoad: true` and start in parallel at login — there is no launchd-native "wait for dependency" mechanism being used (and macOS launchd doesn't have a clean declarative one). `role-shim` and `litellm` will accept connections and appear "running" via `launchctl list` well before `mlx_vlm.server` has finished loading and validating its ~104 GiB of weights, so any request that arrives in that window gets a connection-refused or 502 from the downstream leg, not a clean "still loading" response. The same applies to any new Kanban/Telegram launchd service depending on the model being ready, and to the Telegram connector needing outbound network / Tailscale connectivity that may not be up yet at the moment its `RunAtLoad` fires.

No cold-boot load time for the 104 GiB model was found or measured in this research (FLASHNEXT_OPS.md's "20~45초" figure is documented as the cost of a **fast/deep mode switch while weights are likely still warm in the OS page cache from a prior run**, not a cold boot with a cold page cache) — this should be measured empirically (e.g. `sudo purge` + reboot + timestamp until `:8000` responds) before assuming any specific number for readiness-probe timeouts.

**Why it happens:** launchd's `RunAtLoad`/`KeepAlive` model is designed for independent services, not a dependency chain; this stack has an implicit chain (`litellm → role-shim → mlx_vlm.server`) that launchd has no native concept of.

**Prevention:**
- Give new dependent services (Kanban, Telegram) their own retry/backoff on startup rather than crash-looping if `:4000`/`:8011` aren't answering yet.
- Keep `ThrottleInterval` generous for the model server itself (already 60s in the current plist — reasonable) and don't shorten it in the name of "faster recovery," since a rapid restart loop during a genuine load failure will repeatedly re-trigger a multi-minute weight load.
- Be deliberate about `KeepAlive` semantics: plain `KeepAlive: true` restarts on **any** exit, including a clean `exit(0)` (e.g., from `cline --update` triggering a graceful restart, or a deliberate `doctor fix`/stop). Consider `KeepAlive: {SuccessfulExit: false}` for services where a clean exit should NOT trigger an automatic relaunch, to avoid fighting an intentional stop.
- Measure actual cold-load time once, empirically, before picking any timeout/readiness-probe values for dependent services.

**Detection signal:** New services' logs showing `ECONNREFUSED` / 502 in the seconds-to-minutes after boot; `launchctl list` showing a nonzero recent-exit-code churn for a service in a tight loop.

**Severity:** MODERATE (annoying, not silent-data-corrupting, but will look like "it's broken" on every reboot if not handled).

**Phase to address:** Whichever phase adds the Kanban and Telegram launchd services.

---

### Pitfall 8: cline-bench's environment assumptions don't match this machine by default

**What goes wrong, itemized (verified against cline-bench's own README and this machine's actual state):**
1. **Python version:** cline-bench requires Python 3.13. This machine's `python3` resolves to **3.14.6** (Homebrew). However, `uv` already has **3.13.13** installed and available (`uv python list` shows `cpython-3.13.13-macos-aarch64-none` at `~/.local/share/uv/python/...`) — PROJECT.md's own note that "uv 로 해결" is correct and low-risk, but the harness/runner must be explicitly told to use `uv run --python 3.13` (or an equivalent pinned venv) rather than relying on whatever `python3` resolves to in the shell, or it will silently pick 3.14 and fail in ways that look unrelated to the version mismatch.
2. **Local execution vs Daytona:** cline-bench supports both a cloud path (Daytona, needs `DAYTONA_API_KEY`) and a local path (`--env docker`, no Daytona dependency) — confirmed from the README. PROJECT.md's plan to run locally via Docker is the correct, lower-friction path; just be explicit about passing `--env docker` since the default/documented quickstart path may assume Daytona.
3. **Generic env var names:** cline-bench expects `API_KEY` (for whichever LLM provider you point it at) and, for the OpenAI-compatible path specifically, `BASE_URL`. These are checked live on this machine — **not currently set** — but they are generic enough names that they can silently collide with other tools' `.env` files or shell profile exports in the future. Set them explicitly and scoped to the cline-bench invocation (e.g. via a wrapper script or `env API_KEY=... BASE_URL=http://localhost:4000/v1 ...`), not exported globally.
4. **Memory contention with Docker:** Docker on this machine runs via **colima** (a Lima/QEMU VM), currently allocated only **3.8 GiB / 4 CPUs** (`docker info` confirms `Total Memory: 3.813GiB`). This VM's memory is separate from `iogpu.wired_limit_mb` (which governs only GPU-wired/Metal memory), so colima itself is not going to blow the model's 4.39 GB GPU headroom directly. But it **does** compete for the same finite physical RAM pool (137.44 GB total, ~120 GB of which is already claimed by the model at 32K) — if a cline-bench task needs colima's VM memory bumped up (e.g. to build a heavier Docker image than the current 3.8 GiB allows), that reduces the already-thin non-GPU headroom (STATE.md recorded as low as ~0.7 GiB free system-wide at one measurement) and risks system-wide swap thrashing while the model server is live, even though the GPU-wired memory itself is protected from being swapped out.
5. **Per-task timeout vs 64s TTFT:** cline-bench's own guidance says complex tasks take 20-30 minutes even on capable cloud models; combined with this project's own 2,400s/task timeout figure and 64.3s TTFT at 32K, PROJECT.md's decision to run only a subset of tasks (not the full suite) is correct and should stay that way — do not be tempted to "just run them all overnight," since each turn near the context ceiling costs over a minute before generation even starts.

**Prevention:** Pin the Python invocation explicitly (`uv run --python 3.13`); always pass `--env docker`; scope `API_KEY`/`BASE_URL` to the invocation; do not run cline-bench Docker tasks concurrently with an active Kanban/Telegram session that's mid-conversation near 32K (see Pitfall 3 — this compounds the concurrency/memory risk); keep the "partial suite only" decision.

**Detection signal:** cline-bench failing with an unrelated-looking Python syntax/typing error (actually a 3.14-vs-3.13 mismatch); Docker build failures under memory pressure that don't reproduce when run in isolation; system-wide sluggishness (not a model crash) when running bench tasks while the model server is also serving other requests.

**Severity:** MODERATE.

**Phase to address:** cline-bench validation phase.

---

## Minor Pitfalls

### Pitfall 9: World-readable launchd plists as the eventual home for the Telegram bot token

**What goes wrong:** All plists checked on this machine — including `com.ohama.flashnext.plist`, `com.ohama.litellm.plist`, and every other `~/Library/LaunchAgents/*.plist` — are mode `644` (`-rw-r--r--`, verified with `ls -la`), i.e. world-readable by any local account on the machine. PROJECT.md's own plan is to leave the Telegram token slot empty "for now" and fill it in later — when that happens, if the token is placed directly into a plist's `EnvironmentVariables` block (the pattern already used for `PATH` in the existing plists), it becomes readable by any local user, not just `ohama`.

**Prevention:** Prefer reading the token from a file with restrictive permissions (`chmod 600`) that the connector process reads at startup, or from the macOS Keychain, rather than embedding it directly as plaintext in a plist's `EnvironmentVariables`. If a plist must reference it, reference a path to a protected file, not the literal secret.

**Severity:** MINOR on a genuinely single-user machine (verify this project's threat model actually includes other local accounts before over-engineering this), but worth a one-line note in the eventual manual.

**Phase to address:** Telegram connector phase, at the moment the token is actually injected.

---

### Pitfall 10: `cline` is a globally npm-installed, unpinned package that can drift out from under a "persistent server"

**What goes wrong:** PROJECT.md records the installed version as `cline@3.0.53`. Live-checked in this research: `cline --version` reports **3.0.60**, and `npm view cline dist-tags` shows `latest: 3.0.60` with no version constraint pinning the global install. For a project whose explicit premise is "this exact version's fallback bug is what we're defending against," an unpinned global install means a future `npm update -g` (or the CLI's own built-in `cline update` / `--update` flag) can silently change provider-resolution behavior, potentially resolving or altering the exact bugs (#12520, #13457) this project is built around — in either direction (fixed, or newly broken elsewhere).

**Prevention:** Pin the installed version explicitly (`npm install -g cline@3.0.60`, or whatever version is validated), record the exact version in PROJECT.md/README, and re-run the 32K regression test after any deliberate version bump — do not assume a `cline update` is safe just because it's convenient.

**Severity:** MINOR today, but compounds over the life of a "persistent" server that isn't supposed to need re-validation on every restart.

**Phase to address:** Initial provider-config phase (record and pin the version at the same time the context-window config is locked in).

---

### Pitfall 11: Compact Prompt is not free — it silently removes MCP/Focus Chain/other features

**What goes wrong:** PROJECT.md and cline-analysis.md both correctly note that Compact Prompt is mandatory at 32K (it's roughly 10% the size of the full system prompt, and the full prompt alone would eat most of the ~13K working budget left after the 26.2K compaction threshold). What's easy to miss operationally: turning Compact Prompt on is a mode switch that removes capabilities (MCP tool definitions, Focus Chain, per VALIDATED/cline-analysis notes) without necessarily a loud, persistent UI indicator reminding the user *why* those features are unavailable in every session from now on. A future self (or the user, months later) may file a "why doesn't MCP work anymore" bug against their own setup.

**Prevention:** Document this tradeoff prominently in the user-facing manual (already planned), not just in internal research notes — make the causal link ("32K ⇒ Compact Prompt ⇒ no MCP/Focus Chain") explicit and easy to find when someone notices a missing feature.

**Severity:** MINOR (already a known, accepted tradeoff per PROJECT.md's Key Decisions table) — listed here only to make sure it survives into the user manual.

**Phase to address:** Manual-writing phase.

---
### Pitfall 12: The 64s TTFT problem — investigated in full; verdict is "safe today, but margins are thinner than headline numbers suggest"

**What was checked:** every layer a request passes through between a client and the model, looking for a timeout shorter than the measured 64.3s TTFT at 32K.

- **litellm (:4000):** the installed package (v1.86.1) resolves chat-completion request timeouts to `COMPLETION_HTTP_FALLBACK_SECONDS = 600.0` (10 minutes) by default when no per-call timeout is set (confirmed by reading `litellm/constants.py` directly). No `--request-timeout` override is passed in the running `com.ohama.litellm.plist`, so this default applies. **600s gives roughly 9.3× headroom over 64.3s** — comfortable today, but note this margin shrinks fast if concurrent requests (Pitfall 3) stack additional wait time on top of prefill.
- **Cline's own client (`openai-compatible` provider):** reading `sdk/packages/llms/src/providers/vendors/openai-compatible.ts` directly shows it uses `@ai-sdk/openai-compatible`'s `createOpenAICompatible()` with no explicit response-timeout wrapper — unlike the **native Ollama provider**, which *does* wrap its fetch in a response-timeout (`OLLAMA_DEFAULT_TIMEOUT_MS = 300_000`, i.e. 5 minutes, confirmed in `vendors/ollama.ts`, with the code comment explicitly referencing the historical "Ollama Request Timed Out After 30 Seconds" class of bugs — issues #2941/#9182/#6549/#9484 — as the reason the default was later raised from a legacy 30s to the current 300s). **This project uses the `openai-compatible` path (via litellm), not the native Ollama provider, so the Ollama-specific timeout code doesn't apply either way** — openai-compatible has no client-side response deadline of its own, meaning the effective floor is whatever Node's underlying `fetch`/undici stack defaults to (industry-standard default is a 300s header timeout), which still clears 64.3s comfortably.
- **A separate, generic `fetchJson()` helper** in `sdk/packages/llms/src/providers/http.ts` does default to a 30-second timeout — but grepping its usages across the entire monorepo shows it is **not imported or used by the openai-compatible or Ollama chat-completion request paths** (only referenced within its own file at the time of this research). It is very likely legacy/utility code for other API calls (e.g. auth, model listing), not the completion call itself. Confirmed empirically too: the earlier direct probes against `:4000` with `-m 90` and `-m 120` curl timeouts, well past 30s, completed normally.
- **Telegram connector:** confirmed via `apps/cli/src/connectors/adapters/telegram.md` (fetched from today's `main`) that it is explicitly a **polling connector** ("It is a polling connector, so it does not need a public webhook URL"), unlike Slack/Discord/WhatsApp/Linear which need a public `--base-url` for webhook mode. Polling means there is no synchronous webhook-response deadline to blow through during a 64s generation — the connector can take as long as it needs before calling Telegram's `sendMessage` API. **This specific concern is not applicable to this project's Telegram surface.**
- **Kanban / browser (iPad Safari):** no client-side fetch timeout was found in the portion of the CLI source searched; standard browser `fetch()` has no default timeout unless the app code sets one via `AbortController`. Not conclusively verified either way for Kanban's own frontend code (the Kanban server's exact source location was not found in this pass of the `apps/cli` tree) — flag as **unverified, low-risk-but-worth-a-manual-check** once Kanban is actually running: watch for whether a long-pending request in the Kanban UI shows a stalled/error state before 64s elapses.

**Why this matters despite the "safe" verdict:** every one of the timeout ceilings above is measured against the *single-request* 64.3s figure. None of them account for what happens if that request is queued behind another one (Pitfall 3) or if a degraded scenario pushes real end-to-end latency past a minute or two — the safety margins are real today but not enormous, and they were sized around a different, higher-timeout use case (corporate gateways, cloud APIs) than "one Mac serving a 104 GiB model to itself."

**Prevention:** No code change appears necessary today given the actual measured numbers. Do: (1) keep the litellm default request timeout as-is (600s is plenty; don't shorten it while "cleaning up" the config later), (2) if the Kanban frontend is ever found to impose its own fetch timeout, raise it well past 64s, (3) re-verify this whole chain if `cline` is ever upgraded past the pinned version (Pitfall 10), since a future release could reintroduce a client-side timeout the way the legacy Ollama provider once had one.

**Detection signal:** A request that fails with a timeout-shaped error (`AbortError`, `ETIMEDOUT`, "request timed out") at close to a round number like 30s or 120s, rather than completing or failing with the model server's own clear `PromptTooLongError` message, would indicate a timeout is firing somewhere in this chain — worth re-checking this analysis if it happens, since it would mean an assumption above no longer holds (e.g., a `cline` upgrade changed the client).

**Severity:** MINOR (informational — investigated per explicit request, verdict is "not currently a problem," but margins are worth remembering rather than assuming are infinite).

**Phase to address:** No dedicated phase needed; worth a one-line note in the manual or ops notes that these numbers were checked and are currently safe, so a future re-check has a baseline.

---


## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|-----------------|
| Trust Cline's "Context Window" setting alone, skip the gateway guard | Faster to ship | Directly re-exposes Pitfall 1 (#12520/#13457 unfixed) — the exact silent-failure mode the project exists to prevent | Never |
| Leave `--max-num-seqs` unbounded on `mlx_vlm.server` | One less flag to think about | Silent OOM risk the moment 2 surfaces (Kanban + Telegram) are both live | Only until the second concurrent-capable surface ships; must be fixed before then |
| Run the headless wrapper by shelling out to bare `cline "<prompt>"` | Simplest possible wrapper | Inherits `--auto-approve=true` default silently — every tool call auto-executes | Never for a wrapper reachable from anything but a fully-trusted local terminal |
| Skip pinning the `cline` npm version | Nothing to maintain | Silent behavior drift on a "persistent" server whose entire premise is version-specific bug avoidance | Never, given this project's explicit framing |
| Leave litellm on its default `0.0.0.0` bind during initial bring-up | One less config line while iterating solo | Already-live LAN exposure with zero auth (verified) | Only for the first few minutes of interactive bring-up on a trusted LAN, never past the security phase |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|-------------------|
| Cline ↔ litellm (`openai-compatible`) | Assume setting "Context Window" in Cline's UI is sufficient | Add an independent gateway-side token-budget guard; verified the UI-only path is broken by #12520/#13457, both open, unfixed as of today |
| litellm ↔ role-shim ↔ mlx_vlm.server | Assume `usage` is unreliable across this chain (per #9433's general OpenAI-compatible warning) | It is NOT unreliable here — live-verified both streaming (with `stream_options.include_usage: true`, which Cline's `createOpenAICompatible({ includeUsage: true })` sends automatically) and non-streaming responses return a fully populated `usage` object end-to-end |
| Telegram connector | Start it with just `-k <token>` "to get it working first, add `--allowed-user-id` later" | Bake `--allowed-user-id` into the very first launchd `ProgramArguments`, per Cline's own documented warning that the unrestricted default is intentional-but-dangerous |
| cline-bench ↔ litellm | Run cline-bench with its default provider assumptions (Anthropic/OpenAI/Daytona) | Explicitly set `BASE_URL=http://localhost:4000/v1`, a dummy `API_KEY`, and `--env docker`, matching this machine's actual local-only setup |
| Docker (cline-bench) ↔ mlx_vlm.server | Assume Docker's memory is invisible to the GPU-wired budget, so "it's fine to run both" | True for GPU-wired memory specifically, but false for total system memory pressure — colima's VM RAM and the model's ~120 GB both draw from the same 137.44 GB physical pool |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Designing UI/UX around "typical" latency instead of worst-case | Feels fine in short sessions, then a near-32K turn takes 64.3s with zero visual feedback, user assumes a hang | Show an explicit "thinking, this can take a minute near the context limit" indicator, tied to actual prompt-token count, not a flat spinner | Any turn where accumulated context approaches 32K (prefill scales roughly with context: 6s @ 4K → 64.3s @ 32K, non-linear) |
| Assuming 2-concurrent-requests testing at low context generalizes to high context | "I tested concurrency and it worked" (true at ~30 tokens/request) | Explicitly test-or-guard for the case that actually matters: 2 sessions both near 32K at once | The moment Kanban parallel cards + Telegram overlap while both mid-conversation |
| Relying on MTP drafter's speed boost as a constant | Drafter helps below 8K (1.09-1.21×) but this project runs at 32K where the measured gain is only 1.028× — negligible, and at 64K (out of scope, but worth knowing) it's actively a 29% regression | Don't assume the "43 tok/s" headline number applies at the context sizes this project actually targets; the validated 32K generation number is ~17 tok/s, already accounted for in PROJECT.md but easy to forget when reading marketing-style benchmark tables | Any context size where acceptance rate drops with MTP attached — measured at 64K, plausibly also true well before 32K under adversarial/incompressible outputs |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| litellm bound to `0.0.0.0` with no `master_key` | Anyone on the LAN (or, once added, anyone who can route to the box) can call the model and, via Cline, execute agent tasks with zero auth — verified live today | Bind to `127.0.0.1` + front with an authenticating proxy, or set `general_settings.master_key` in litellm's own config |
| Telegram connector without `--allowed-user-id` | Bot-token/username leak = full remote shell-equivalent access, by Cline's own documented design | Always pass `--allowed-user-id`; never rely on "security through obscurity" of an unpublished bot username |
| Headless wrapper shelling to bare `cline` | Inherits `--auto-approve=true` default; every tool call silently executes | Explicit `--auto-approve false` (or an equivalent opt-in-only design) in the wrapper, never relying on CLI default |
| Kanban board with no built-in auth | Anyone reaching `:3484` (LAN, unless firewalled) gets full board read/write | Tailscale-only exposure, or a token requirement matching the LAN policy planned for litellm |
| Secrets in world-readable plists | Any local account can read `EnvironmentVariables` in any `~/Library/LaunchAgents/*.plist` (verified: all are mode 644) | Read secrets from a `chmod 600` file or Keychain at process start, not from plist `EnvironmentVariables` directly |
| Sandbox/workspace whitelist not yet built (per PROJECT.md, still "Active"/pending) | Until it ships, a remote agent session (Telegram, Kanban) can potentially reach any path the `ohama` user can, not just approved repos | Treat this as a blocking prerequisite for exposing Telegram/Kanban beyond localhost, not a nice-to-have that ships later |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| No visible indication during a 64s prefill | User assumes the app is frozen/crashed, may cancel and retry (wasting another 64s) or open a second parallel session (triggering Pitfall 3) | Explicit, context-size-aware "this may take up to a minute" messaging in the Kanban/iPad UI specifically, since Telegram/CLI users may be more tolerant of silent waits than a web UI user tapping a screen |
| Context bar showing false headroom (Pitfall 2) | User keeps working past the real limit, then hits an abrupt, unexplained hard failure mid-task | Surface the gateway guard's own token accounting somewhere the user can see it, rather than exclusively relying on Cline's native (unreliable) bar |
| Compact Prompt silently disabling MCP/Focus Chain (Pitfall 11) | User notices "MCP stopped working" as an apparently unrelated regression | One-line, persistent note in the manual and ideally in-product, tying the 32K/Compact-Prompt decision to the feature loss directly |

## "Looks Done But Isn't" Checklist

- [ ] **"Cline's Context Window is set to 32768"**: does NOT mean compaction math actually uses it — verify with a real regression test that deliberately grows a session past 32K and checks the *log*, not the UI, per Pitfall 1/2. #12520/#13457 are both open, unfixed, on the version installed here.
- [ ] **"litellm has an `api_key` configured"**: does NOT mean the endpoint is protected — `api_key: dummy` accepts literally the string "dummy" from anyone who can reach the port, and the port is currently reachable from the whole LAN (`lsof -i :4000` shows `*:4000`). Verify actual bind address and require a real `master_key`.
- [ ] **"Telegram connector is running"**: does NOT mean it's restricted — check the actual running process's arguments (not just the setup docs you followed) for `--allowed-user-id`.
- [ ] **"`--max-kv-size 32768` is set on the model server"**: correctly hard-walls at the model-server layer (verified, HTTP 400 with a clear message) — but this alone does NOT prevent Cline from wasting a turn or confusing the user before hitting that wall; the gateway guard is still required upstream.
- [ ] **"cline-bench ran a task successfully"**: does NOT confirm it exercised our actual guard/config — verify `BASE_URL`/`API_KEY` in the run's logs actually point at `localhost:4000`, not a Daytona-hosted default or an unrelated provider picked up from a stray global env var.
- [ ] **"MTP drafter is enabled (fast mode)"**: does NOT mean it's helping at the context sizes this project runs at — the validated gain at 32K is only 1.028× (essentially noise); don't cite the headline 32.8% number from short-context tests as if it applies here.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|-----------------|------------------|
| Cline hits the 32,768 wall mid-task (Pitfall 1) | MEDIUM | Do not trust `/compact` to fix it (may fail again per the #7772 pattern); start a fresh session/task. Checkpoints (file-level diffs) survive independently of the chat session, so in-progress file edits are not lost even if the conversation is. |
| litellm found exposed on LAN without auth (Pitfall 4) | LOW | Add `general_settings.master_key` (or rebind to `127.0.0.1`), restart the service, verify with `lsof -i :4000` from a second LAN device that access is now refused. No persistent damage expected on a single-user machine, but treat any unexpected model activity in logs during the exposure window as suspect. |
| Telegram bot token leaked without `--allowed-user-id` (Pitfall 5) | LOW-MEDIUM | `cline connect --stop telegram`, revoke and reissue the token via `@BotFather` (`/revoke`), restart the connector with `--allowed-user-id` set from the first launch this time. Review any session history created by unrecognized senders during the exposure window before trusting it. |
| Concurrent near-32K sessions push memory past the wired limit (Pitfall 3) | HIGH if it triggers a kernel-level kill of the model process | Restart `com.ohama.flashnext` (already `KeepAlive`d, so it should self-recover), but this loses all in-flight sessions across every surface simultaneously (Kanban + Telegram + headless), not just the offending one — strongly prefer preventing this (set `--max-num-seqs`) over relying on recovery. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|----------------|
| 1. Context-window fallback silently overrides 32,768 | Cline provider config + gateway 32K guard (must ship together) | Regression test that grows a session past 32K and checks server-side logs for the exact point of rejection, confirming it happens *before* mlx_vlm.server's own 400, not after |
| 2. Context bar / display unreliable | Regression-test phase | Test harness reads `usage.prompt_tokens` / server logs, never the Cline UI percentage, as its oracle |
| 3. Unbounded batching + thin memory headroom | Whichever phase makes 2+ concurrent-capable surfaces live simultaneously (Kanban + Telegram) | `--max-num-seqs` set explicitly in the flashnext plist; a deliberate low-context concurrency test (not high-context) confirms queueing behavior before either surface goes live for real use |
| 4. litellm exposed with no auth | Security phase (Tailscale/LAN auth) | `lsof -i :4000` shows `127.0.0.1` only, or an unauthenticated curl from a second LAN device is rejected |
| 5. Chat-bridge / headless default-allow | Telegram connector phase + headless wrapper phase | Running process args include `--allowed-user-id`; wrapper's actual invocation includes an explicit auto-approve=false equivalent, verified by reading the wrapper script, not assuming |
| 6. Model hallucinates fake tool_call with no tools registered | cline-bench validation phase + headless wrapper phase | Response-content scan for literal `<tool_call>` strings in any no-tools-registered call path |
| 7. launchd ordering / cold-load races | Kanban + Telegram launchd service phase | New services retry/backoff rather than crash-loop in the first N minutes after boot; empirically measure cold-load time once and size timeouts to it |
| 8. cline-bench environment mismatches | cline-bench validation phase | Explicit `uv run --python 3.13`, `--env docker`, and scoped `API_KEY`/`BASE_URL` all visible in the actual invocation command, not assumed from docs |
| 9. Secrets in world-readable plists | Telegram connector phase (token-injection step) | Token sourced from a `chmod 600` file/Keychain, not literal plaintext in `EnvironmentVariables` |
| 10. Unpinned `cline` version drift | Initial provider-config phase | Exact installed version recorded in PROJECT.md/README and re-verified after any deliberate upgrade |
| 11. Compact Prompt feature loss undocumented | Manual-writing phase | Manual explicitly states the 32K → Compact Prompt → no MCP/Focus Chain chain of consequences |
| 12. Timeout chain (litellm/Cline client/Telegram/Kanban) — verified currently safe | No dedicated phase; note in ops/manual | Re-check this chain after any `cline` version upgrade (Pitfall 10) or if a timeout-shaped error appears in logs |

## Sources

**GitHub issues (all statuses live-verified via `gh issue view cline/cline#N` on 2026-08-29):**
- [#12520](https://github.com/cline/cline/issues/12520) — OPEN. Root cause confirmed by reading `sdk/packages/llms/src/providers/compat.ts` directly in a fresh clone of `cline/cline` at commit `1986fa56de5dc91d635ef3a696136f6dc11799dd` (2026-08-28). Fix PRs [#12643](https://github.com/cline/cline/pull/12643) and [#12678](https://github.com/cline/cline/pull/12678) both OPEN, unmerged.
- [#13457](https://github.com/cline/cline/issues/13457) — OPEN, filed 2026-08-21, reproduced on Qwen 3.8 27B.
- [#10375](https://github.com/cline/cline/issues/10375) — OPEN, labeled stale.
- [#6494](https://github.com/cline/cline/issues/6494) — CLOSED, not_planned.
- [#7772](https://github.com/cline/cline/issues/7772) — CLOSED, not_planned, but mechanism confirmed still present in current code.
- [#9433](https://github.com/cline/cline/issues/9433) — OPEN. Fix PR [#9613](https://github.com/cline/cline/pull/9613) OPEN, unmerged. Confirmed NOT applicable to this project's stack today (usage object verified populated).
- [#7383](https://github.com/cline/cline/issues/7383) — OPEN.

**Source code read directly (not from memory) in a fresh `git clone --depth 1 https://github.com/cline/cline.git`, 2026-08-29:**
- `sdk/packages/llms/src/providers/compat.ts` (`resolveModelInfo`)
- `sdk/packages/llms/src/providers/builtins.ts` (`fallbackModelInfo`, `OLLAMA_DEFAULT_CONTEXT_WINDOW`)
- `sdk/packages/llms/src/providers/vendors/openai-compatible.ts` (`includeUsage: true` passed to `createOpenAICompatible`)
- `sdk/packages/llms/src/providers/vendors/ollama.ts` (`OLLAMA_DEFAULT_TIMEOUT_MS = 300_000`, historical 30s-timeout context in code comments referencing #12829)
- `sdk/packages/llms/src/providers/http.ts` (generic 30s `fetchJson` timeout — confirmed NOT used by the openai-compatible/chat-completion request path)
- `apps/cli/src/connectors/adapters/telegram.md`, `docs/cli/connectors.mdx` (documented default-allow behavior, quoted verbatim)
- `apps/cli/src/connectors/connector-host.test.ts` (`yolo=off (disabled by connector startup)`)

**Live probes against the running stack on this machine (2026-08-29):**
- `curl localhost:4000/v1/chat/completions` — non-streaming: full `usage` object present.
- Same, `stream:true` without `stream_options`: no usage chunk. With `stream_options:{include_usage:true}`: usage present in final SSE chunk.
- Same, with a `tools` array (1 tool, then 4 Cline-shaped tools): clean native `tool_calls` responses, `finish_reason: "tool_calls"`.
- `curl` with `max_tokens: 40000`: HTTP 400, exact error text captured, end-to-end through litellm.
- Two concurrent short requests to `:8000`: both succeeded; `flashnext.err` confirmed `backend=continuous_batching`, `in_flight=2`, simultaneous prefill completion.
- `lsof -i :4000` → `*:4000` (all interfaces). `lsof -i :8011` → `localhost:8011` only.
- `cline --version` → `3.0.60` (vs. `3.0.53` recorded in PROJECT.md). `cline --help`, `cline connect telegram --help`, `cline kanban --help` — flag defaults quoted verbatim.
- `docker info` → colima backend, `Total Memory: 3.813GiB`, 4 CPUs.
- `ls -la ~/Library/LaunchAgents/*.plist` → all mode 644 (world-readable).
- `litellm/proxy/proxy_cli.py` and `litellm/proxy/proxy_server.py`, `litellm/constants.py` (installed package, version 1.86.1) — `--host` default `0.0.0.0`; chat-completion timeout resolves to 600s default (`COMPLETION_HTTP_FALLBACK_SECONDS`), far above the 64.3s TTFT at 32K.
- `mlx_vlm/server/generation.py`, `app.py`, `cli.py` (installed package) — `PromptTooLongError`, `_check_configured_context_budget`, `--max-num-seqs` docstring ("Default: unbounded").

**This machine's own prior research (read directly, not summarized from memory):**
- `~/local-llm-settings/README.md`, `TOPOLOGY.md`, `STATE.md`, `config/litellm-config.yaml`, `config/role_shim.py`, `launchagents/*.plist`
- `~/local-llm-settings/VALIDATED.md`
- `~/projs/qwen38-flash-next-tests/results/09_12_accuracy.md` (task-07 `<tool_call>` hallucination, verbatim)
- `~/projs/qwen38-flash-next-tests/FLASHNEXT_OPS.md`
- `/Users/ohama/projs/cline-tests/cline-analysis.md` (prior session's research — cross-checked, not merely trusted; #12520/#13457/etc. statuses re-verified live rather than assumed still current)

**cline-bench:**
- [cline/cline-bench](https://github.com/cline/cline-bench) README (fetched live) — Python 3.13 requirement, `--env docker` local execution path, `DAYTONA_API_KEY`/`API_KEY`/`BASE_URL` env vars, 8GB Daytona sandbox tier, 20-30 minute complex-task duration.

---
*Pitfalls research for: persistent local-LLM Cline server (Kanban + Telegram + headless), Qwen3.8-Flash-Next @ 32K, macOS launchd*
*Researched: 2026-08-29*
