# Phase 10: 별칭 주입과 도달 증명 - Research

**Researched:** 2026-09-01
**Domain:** litellm 1.86.1 parameter-injection internals, launchd service restart, Cline CLI 3.0.53 non-interactive invocation
**Confidence:** HIGH on the central finding (Q1) — verified against the actual installed package source with line citations AND live in-process execution of the real `litellm.get_optional_params()` function, no stack mutation. HIGH on restart/rollback (an existing, already-battle-tested project script covers it exactly). HIGH on the `cline` CLI invocation shape (an exact working command already exists from Phase 1 of v1, reproduced here with source citations for the NDJSON `reasoning` shape). MEDIUM on the `hosted_vllm` fix's interaction with Cline's own reasoning-history replay (source-verified, not live-tested against a running Cline).

## Summary

Phase 10 has one central risk, and this research resolves it before planning starts: **CFG-11 as literally worded in ROADMAP.md — inject `reasoning_effort: medium` into the new alias's `litellm_params` while keeping the same `openai/` provider prefix the existing `flashnext` alias uses — does not work.** It was verified, by calling the actual installed `litellm==1.86.1` library in an isolated Python process (no server, no config edit, no network call), that a `reasoning_effort` value passed through `litellm_params` is validated by the **exact same code path** as a client-sent one, because litellm's router flattens `deployment["litellm_params"]` and the caller's own request kwargs into one dict before calling `completion()` — there is no "config-injected vs. client-sent" distinction once execution reaches that point. Under the `openai` provider (`model: openai/<path>`), `reasoning_effort` is not in `OpenAIGPTConfig.get_supported_openai_params()`'s list for a non-o-series/non-GPT-5 model name, so it raises `UnsupportedParamsError` (HTTP 400) — **every single call to an alias built this way would fail**, not just ones where a client sends the parameter.

The fix, also verified live against the installed package: change only the **new** alias's `litellm_params.model` prefix from `openai/<path>` to `hosted_vllm/<path>` (same `api_base`, same `api_key`, same upstream URL — `hosted_vllm` inherits nearly all of `OpenAIGPTConfig`'s behavior). `HostedVLLMChatConfig` explicitly whitelists `reasoning_effort` as a supported OpenAI param, so it survives validation and lands as a genuine top-level key in the JSON body sent to `:8011`. `enable_thinking` (which is not a recognized litellm/OpenAI param name at all, under either provider) continues to work exactly as it already does today — it gets swept into `extra_body`, which is flattened onto the top-level request body one layer down, regardless of which of the two providers is used. This explains, with a verified mechanism rather than just an observed asymmetry, exactly why Phase 9 saw `reasoning_effort` 400 and `enable_thinking` 200 through the existing `flashnext` alias — and shows the fix does not require `drop_params` (banned by CFG-14) or any silent-drop mechanism.

**Primary recommendation:** Build `flashnext-plan` (and, per PRB-02's already-passing verdict, `flashnext-act`) with `litellm_params.model: hosted_vllm//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4` — never `openai/...` — while leaving the existing `flashnext` and `flashnext-codex` entries completely untouched. Edit only `/Users/ohama/agent-stack/litellm/config.yaml` (the file litellm's launchd plist actually loads — **not** `~/local-llm-settings/config/litellm-config.yaml`, which is a `sync.sh`-generated mirror, confirmed identical sha256 `12e102cf...` today). Insert the new aliases as pure appended lines after the existing `flashnext-codex` block (after line 33 of the current 50-line file) so the byte-identical-preservation check for `flashnext` (CFG-13) reduces to a trivial `diff` of an unchanged line range. Restart with the project's own `phase-02/infra/restart_service.sh com.ohama.litellm 4000`, already proven safe for exactly this kind of launchd bootout/bootstrap cycle. Run `~/local-llm-settings/sync.sh` afterward — never edit the mirror directly.

---

## Q1 — How does litellm inject/validate `litellm_params`, and why does the asymmetry (`reasoning_effort` 400 / `enable_thinking` 200) exist? (Highest priority)

### The mechanism, traced end-to-end with line citations

All citations are against the actual installed package backing the running `com.ohama.litellm` (PID 48525): `/Users/ohama/agent-stack/venv/lib/python3.12/site-packages/litellm/`, version confirmed live as `1.86.1` (`litellm --version`).

1. **Router merges config params and client kwargs into one dict before any provider ever sees them.** `router.py:2422` copies `deployment["litellm_params"]`; `router.py:2447-2453` builds
   ```python
   input_kwargs = {
       **litellm_params,      # from the alias's config (config.yaml model_list entry)
       "messages": messages,
       "caching": self.cache_responses,
       "client": model_client,
       **kwargs,               # from the actual client request body
   }
   _response = litellm.acompletion(**input_kwargs)
   ```
   **There is no code path distinction between "this came from the alias config" and "this came from the client."** By the time `reasoning_effort` reaches `completion()`, it is an ordinary keyword argument regardless of origin. This is the load-bearing fact that makes the rest of this section apply equally to alias-injected and client-sent values.

2. **`reasoning_effort` is a formally declared, validated parameter.** `main.py`'s `completion()` (defined at `main.py:1085`) declares it as an explicit named parameter and lists it in `optional_param_args` at `main.py:1547`. It flows into `get_optional_params()` (`utils.py:3981`), which calls `_check_valid_arg()` against `get_supported_openai_params(model, custom_llm_provider)` (`litellm_core_utils/get_supported_openai_params.py:8`). For `custom_llm_provider == "openai"` (which is what `model: openai/<path>` resolves to — verified live: `litellm.get_llm_provider(model="openai//Users/.../Qwen3.8-Flash-Next-MLX-oQ4")` → `(..., 'openai', None, None)`), `ProviderConfigManager.get_provider_chat_config()` (`utils.py:8319-8333`) returns `OpenAIGPTConfig` for any model name that isn't an o-series or GPT-5 model — our local filesystem path is neither. `OpenAIGPTConfig.get_supported_openai_params()` (`llms/openai/chat/gpt_transformation.py:137-187`) **does not include `"reasoning_effort"` in its `base_params` list.** Therefore `_check_valid_arg` (`utils.py:4067-4098`) raises `UnsupportedParamsError` (HTTP 400) — unless `litellm.drop_params`/`drop_params:true` is set (banned by CFG-14), in which case the param would be silently dropped rather than raising, never even reaching the `allowed_openai_params` extension mechanism's benefit (see below).

3. **`enable_thinking` is not a recognized parameter anywhere in litellm** (`grep -rn "enable_thinking"` across the installed package returns zero hits outside of an unrelated error-message string). It falls into `get_non_default_completion_params()`'s catch-all (`utils.py:9517-9524`: anything not in `OPENAI_CHAT_COMPLETION_PARAMS + all_litellm_params`), then `add_provider_specific_params_to_optional_params()` (`utils.py:4798-4855`) — for providers in `["openai","azure","text-completion-openai"] + litellm.openai_compatible_providers`, **any unrecognized key is swept into `optional_params["extra_body"]`** (`utils.py:4809-4846`), never subjected to the `_check_valid_arg` whitelist at all. `extra_body` is later handed to the actual OpenAI Python SDK client as its own well-known escape-hatch parameter — `llms/openai/openai.py:478-480`: `openai_client.chat.completions.with_raw_response.create(**data, timeout=timeout)`, where `data` (built by `transform_request`, `llms/openai/chat/gpt_transformation.py:446`: `{"model": model, "messages": messages, **optional_params}`) contains the nested `extra_body` key — and the OpenAI SDK itself flattens `extra_body`'s keys onto the top-level outgoing JSON body (this is the SDK's own documented vendor-extension mechanism, not litellm code). This is *why* `enable_thinking` reaches the model as a real top-level field while `reasoning_effort` does not: one is a recognized, provider-whitelisted param; the other is an unrecognized pass-through param.

4. **Empirical confirmation, run live against the installed package in an isolated Python process** (no server/network/config touched — pure library call):
   ```python
   import litellm
   model = "openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4"
   litellm.get_optional_params(model=model, custom_llm_provider="openai", reasoning_effort="medium")
   # -> UnsupportedParamsError: openai does not support parameters: ['reasoning_effort'], for model=...
   litellm.get_optional_params(model=model, custom_llm_provider="openai", enable_thinking=True)
   # -> {'stream': False, 'extra_body': {'enable_thinking': True}}   (no exception)
   ```
   This proves the alias-injection design (CFG-11) as literally worded would 400 on every call, not merely on client-sent attempts.

### The fix — verified at the library level

`HostedVLLMChatConfig` (`llms/hosted_vllm/chat/transformation.py:34-93`), which subclasses `OpenAIGPTConfig`, overrides `get_supported_openai_params()`:
```python
def get_supported_openai_params(self, model: str) -> List[str]:
    params = super().get_supported_openai_params(model)
    params.extend(["reasoning_effort", "thinking"])
    return params
```
Switching the **new alias's** `litellm_params.model` prefix to `hosted_vllm/<path>` (leaving `api_base`/`api_key` unchanged) makes `custom_llm_provider` resolve to `"hosted_vllm"` (verified live: `litellm.get_llm_provider(model="hosted_vllm//Users/.../Qwen3.8-Flash-Next-MLX-oQ4")` → `(..., 'hosted_vllm', 'fake-api-key', None)`). Confirmed live with the identical CFG-11 combination:
```python
litellm.get_optional_params(model=model, custom_llm_provider="hosted_vllm",
                             reasoning_effort="medium", enable_thinking=True)
# -> {'stream': False, 'reasoning_effort': 'medium', 'extra_body': {'enable_thinking': True}}
```
Both params survive: `reasoning_effort` as a genuine top-level `optional_params` key (because `HostedVLLMChatConfig.map_openai_params()` → `_map_openai_params()` checks `self.get_supported_openai_params(model)`, which now includes it), `enable_thinking` still correctly bucketed into `extra_body`.

`hosted_vllm`'s request path differs from `openai`'s (it uses `base_llm_http_handler.completion()`, `llms/custom_httpx/llm_http_handler.py:377`, a raw-httpx handler, instead of the OpenAI SDK client) — but this handler pops `extra_body` from `optional_params` and flattens it into the JSON body the same way (`llm_http_handler.py:399,448-449`: `extra_body = optional_params.pop("extra_body", None)` ... `if extra_body is not None: data = {**data, **extra_body}`), so `enable_thinking` still lands as a real top-level key, not nested. `HostedVLLMChatConfig` does not override `validate_environment`/`get_complete_url` (inherited from `OpenAIGPTConfig`, `gpt_transformation.py:665-710`), so the outgoing URL (`api_base.rstrip("/") + "/chat/completions"` → `http://localhost:8011/v1/chat/completions`, identical to today) and the `Authorization: Bearer <api_key>` header behavior are unchanged from the existing `flashnext` alias.

**Confidence: HIGH.** Both the failure and the fix were demonstrated by executing the actual installed library function, not inferred from documentation or by analogy.

### What this means for `flashnext-codex`

Not investigated deeply (out of scope, never call it — see Q6), but worth noting: its `litellm_params.model` uses `openai/chat_completions/<path>` — a distinct prefix meaning "Responses-API-to-chat-completions bridge," a completely different code path from either `openai/` or `hosted_vllm/`. It is unrelated to the CFG-11 mechanism above; do not pattern-match its shape when building `flashnext-plan`.

### Recommended YAML (append after existing line 33 of `/Users/ohama/agent-stack/litellm/config.yaml`)

```yaml
  # ── Plan/Act reasoning aliases (Phase 10, v1.1) ─────────────────────────
  #   provider prefix is hosted_vllm/, NOT openai/ — litellm's `openai`
  #   provider does not whitelist reasoning_effort for a non-o-series model
  #   name and returns HTTP 400 UnsupportedParamsError (verified 2026-09-01,
  #   see 10-RESEARCH.md Q1). hosted_vllm/ whitelists it; enable_thinking
  #   passes through via extra_body under either prefix.
  - model_name: flashnext-plan
    litellm_params:
      model: hosted_vllm//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
      api_base: http://localhost:8011/v1
      api_key: dummy
      reasoning_effort: medium
      enable_thinking: true

  - model_name: flashnext-act
    litellm_params:
      model: hosted_vllm//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
      api_base: http://localhost:8011/v1
      api_key: dummy
      enable_thinking: false
```
`flashnext-act` is created because PRB-02 already passed in Phase 9 (`enable_thinking:false` returns HTTP 200, not rejected — `phase-09/GATE-VERDICT.md` §2). Whether `flashnext-act` needs to exist as a distinct alias at all (since `enable_thinking:false` is already the model's default and thus behaviorally identical to plain `flashnext`) is a design question the plan should note explicitly rather than silently resolve — Phase 11's `cline-act` wrapper could equally target the existing `flashnext` alias unchanged. Recommend creating it anyway for explicitness/symmetry with `flashnext-plan` and because ROADMAP's criterion 2 implies it, but flag the redundancy in the plan's own documentation.

**Do not add `model_info` blocks or any `allowed_openai_params`/`additional_drop_params` keys** — they are unnecessary once the provider prefix is correct, and CFG-14 explicitly bans the `drop_params` family as a matter of project policy (silent-failure risk), even though this specific case (`hosted_vllm`) doesn't need it at all.

---

## Q2 — Restart procedure for `com.ohama.litellm`

**VERIFIED**, all of the below, by reading the plist and by using the project's own existing infra:

- Label `com.ohama.litellm`, loaded via `~/Library/LaunchAgents/com.ohama.litellm.plist`. `ProgramArguments`: `/Users/ohama/agent-stack/venv/bin/litellm --config /Users/ohama/agent-stack/litellm/config.yaml --port 4000 --host 127.0.0.1`. `KeepAlive: true`, `ThrottleInterval: 10`, logs at `/Users/ohama/agent-stack/litellm/litellm.{log,err.log}`. Current live PID 48525 (`launchctl list | grep litellm`).
- **litellm has no hot-reload** (`/config/reload` → 404 on 1.86.1, already established by Phase 9/PROJECT.md constraints) — a full process restart is mandatory for the config change to take effect.
- **Use the project's own existing, already-battle-tested restart helper — do not write a new one:**
  ```bash
  phase-02/infra/restart_service.sh com.ohama.litellm 4000 --timeout 240
  ```
  This script (`phase-02/infra/restart_service.sh`, explicitly documented in its own header as "the ONLY sanctioned launchd restart helper in the whole project; it is extended in place, never forked") does, in order: `plutil -lint` the plist (abort before touching anything if malformed) → `launchctl bootout gui/<uid>/com.ohama.litellm` (tolerates "No such process") → **polls for teardown** (`launchctl print` no longer resolves the label AND port 4000 no longer listening) before bootstrapping, because `bootstrap` racing an in-flight teardown fails opaquely (`Bootstrap failed: 5: Input/output error` — the script's own comment documents this being hit for real against `com.ohama.flashnext`) → `launchctl bootstrap gui/<uid> <plist>` → polls until `state=running` AND port 4000 is listening, up to `--timeout` seconds. On any failure it prints an exact rollback recipe to stderr (restore from `phase-02/infra/backups/`, re-lint, bootout, bootstrap) via a trap.
  litellm is far lighter than `flashnext` (no 104 GiB model load) — expect this to complete in well under the flashnext-tuned 240s timeout; a smaller `--timeout` (e.g. 60) is reasonable but not necessary.
- **Config parse failure at startup:** litellm's plist has no `--config` fallback and `KeepAlive: true` — if `config.yaml` fails to parse (bad YAML, or e.g. a bad `LiteLLM_Params` value that pydantic validation rejects at startup), the process will exit immediately and **launchd will restart-loop it under KeepAlive** (governed by `ThrottleInterval: 10` — one restart attempt per 10s) rather than silently staying down. This is exactly the scenario `restart_service.sh`'s health poll (`state=running` AND port listening) is designed to catch: a crash-looping job will show `state != running` (or a rapidly-changing pid, though the script's poll doesn't sample twice for the port-bound case the way it does for portless labels — see the OPEN ITEM below) and the poll times out, triggering the script's own rollback-recipe print rather than a false "success."
- **In-flight Kanban/Telegram requests during the restart window:** these route through the SAME `com.ohama.litellm:4000` process (`~/local-llm-settings/sync.sh`'s tracked `LABELS` list includes `com.ohama.kanban`, `com.ohama.telegram-connect`, `com.ohama.kanban-proxy`, all downstream of litellm per the stack diagram in PROJECT.md). Any in-flight completion request during the bootout→bootstrap window will fail (connection refused/reset); this is already acknowledged in STATE.md ("가동 중인 Kanban/Telegram 요청이 끊긴다") and accepted as the cost of Phase 10. Recommend running the restart at a time with no known active Kanban/Telegram session, and stating the exact downtime window in the plan's own log.
- **Rollback if the edited config is bad:** restore `/Users/ohama/agent-stack/litellm/config.yaml` from the pre-edit backup (see Q5's backup step) and re-run the same `restart_service.sh` invocation. `restart_service.sh`'s own trap prints this exact recipe automatically on any failure.

**OPEN ITEM:** `restart_service.sh`'s port-bound health-poll branch (used here, since litellm binds :4000) accepts `state=running AND port listening` on the FIRST sample — it does not do the portless branch's "same pid across two ≥10s-separated samples" stability check. If litellm crash-loops with a startup delay just over the poll's 2s tick but happens to bind the port briefly before crashing, this could in principle report a false success. **Proposed probe:** after restart, independently re-confirm with `launchctl print gui/$(id -u)/com.ohama.litellm | grep -E 'pid|state'` sampled twice, ≥10s apart, before proceeding to any verification step — cheap, read-only, and closes the gap the existing script's port-bound branch leaves open.

---

## Q3 — `sync.sh` and its relationship to `~/local-llm-settings/config/litellm-config.yaml`

**VERIFIED, and this corrects a premise in the phase brief.** `~/local-llm-settings/config/litellm-config.yaml` is **not** the file litellm loads. It is a **mirror**, generated and overwritten by `~/local-llm-settings/sync.sh`, whose `FILES` array (`sync.sh` lines ~15-21) explicitly maps:
```
"/Users/ohama/agent-stack/litellm/config.yaml:config/litellm-config.yaml"
```
i.e., `cp -p` **from** `/Users/ohama/agent-stack/litellm/config.yaml` **to** the mirror path, one-directional, only when `sync.sh` (no `--check`) runs and detects a diff (`cmp -s` first). The litellm plist's actual `--config` argument is `/Users/ohama/agent-stack/litellm/config.yaml` (verified via `launchctl print` and the plist XML directly) — confirmed today both files are byte-identical (sha256 `12e102cf66e50f5abc19f6d2dd1f322d548cee25549d65ddb9adbbcd2aaf599c`, matching the hash Phase 9's `GATE-VERDICT.md` recorded as the stack-unchanged baseline).

**Implication for Phase 10's plan: edit `/Users/ohama/agent-stack/litellm/config.yaml` directly. Never hand-edit the `~/local-llm-settings` mirror** — `sync.sh` (no flag) will silently overwrite any hand-edit there on its next run, and editing the mirror alone leaves the real litellm process running the OLD config forever (the mirror is not read by anything, per `sync.sh`'s own header: "이 디렉터리는 살아 있는 기준점이다. 시점 스냅샷(백업)이 아니다" / "설정을 바꿨으면 이 스크립트를 돌려 여기 내용을 실제와 맞춘다").

**Criterion 5's exact sequence, satisfying both VRF-03 and CFG-15:**
1. Edit `/Users/ohama/agent-stack/litellm/config.yaml` (the real source).
2. Restart `com.ohama.litellm` (Q2).
3. Run VRF-01/VRF-02 verification scripts against the live, restarted service.
4. Run `~/local-llm-settings/sync.sh` (no `--check`) — this copies the new `config.yaml` into the mirror, regenerates `STATE.md` (which includes a `## litellm 별칭` table parsed live from `/Users/ohama/agent-stack/litellm/config.yaml` via an embedded `python3`/`yaml.safe_load` snippet — `flashnext-plan`/`flashnext-act` will appear there automatically), and regenerates `SHA256SUMS` over the whole `local-llm-settings` tree.
5. Confirm with `./sync.sh --check` (dry-run) immediately after: it should report "✅ 실제 시스템과 일치한다" (exit 0) — this is the "sync.sh 실행 결과에 이번 변경이 반영된다" acceptance check literally as ROADMAP phrases it, and it is read-only.
6. Commit the mirror's own git repo (`~/local-llm-settings` is a git repo, unlike `/Users/ohama/agent-stack/litellm/` which is **not** under git — confirmed via `git rev-parse --show-toplevel` failing there) if the project's convention is to commit config changes there (matches its existing commit history pattern, e.g. `10bf203 32K 강제 동작을 실측으로 확인해 기록`).

---

## Q4 — Running `cline` non-interactively for criterion 6 (VRF-04)

**VERIFIED, and an exact working invocation already exists from v1 Phase 1** (`.planning/milestones/v1-phases/01-cline-config-compaction-verification/01-05-SUMMARY.md`), no need to rediscover it:
```bash
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext-plan --compaction agentic --json -t 600 "<short prompt>"
```
- `-P/--provider` selects which entry of `providers.json`'s `providers` map to use for `baseUrl`/`apiKey`/`contextWindow` (`openai-compatible`, already configured and pinned — `apiKey: dummy`, `baseUrl: http://localhost:4000/v1`, `contextWindow: 29000`).
- `-m/--model <model-id>` **overrides the `model` field of that provider's settings for this invocation only** — confirmed from source: `apps/cli/src/main.ts:1054-1055`, `args.model ?? selectedProviderSettings?.model ?? ...` (CLI arg wins over the stored value if present), and `apps/cli/src/commands/program.ts:47-48,225`, `.option("-m, --model <model-id>", ...)` → `if (opts.model !== undefined) result.model = opts.model`. **This means VRF-04 does not require editing `providers.json` at all** — pass `-m flashnext-plan` (or `-m flashnext` / `-m flashnext-act` for the control) per invocation, and `providers.json`'s own stored `model: "flashnext"` is left completely untouched. This directly resolves a tension the phase brief flags: `phase-01/config/verify_config.sh` hard-asserts `settings.get("model") == "flashnext"` (line ~35) and would **fail** if `providers.json` itself were pointed at `flashnext-plan` — but since `-m` overrides per-invocation, `verify_config.sh`'s invariant is never touched by VRF-04's test runs, and the project's rule that all `providers.json`-touching work must go through `apply_provider_config.sh`/`verify_config.sh` (PROJECT.md) is simply not implicated at all for this step.
- `--json` mode: **every** agent event is emitted as one NDJSON line verbatim, unfiltered: `apps/cli/src/utils/events.ts:97-101`:
  ```typescript
  export function handleEvent(event: AgentEvent, config: Config): void {
      if (getCurrentOutputMode() === "json") {
          emitJsonLine("stdout", { type: "agent_event", event });
          return;
      }
      ...
  ```
  A reasoning chunk arrives as a `content_start` event with `contentType: "reasoning"` and a `reasoning` string field (confirmed from the human-readable-mode branch immediately below, `events.ts:126-140`, which reads `event.reasoning`/`event.redacted` off the same event object) — so in the NDJSON stream, the field appears as `.event.type=="content_start"`, `.event.contentType=="reasoning"`, `.event.reasoning=="<the actual thinking text>"`. Grep/jq pattern for VRF-04:
  ```bash
  jq -c 'select(.event.type=="content_start" and .event.contentType=="reasoning")' ndjson.log
  ```
- `CLINE_NO_AUTO_UPDATE=1` is mandatory on every invocation (established v1 finding: bare `cline --version`/`cline auth` reliably spawns a detached background `npm update cline` that lands on 3.0.60 regardless of this env var in some cases — still set it, it is the only available mitigation, and re-check `cline --version` immediately before and after the VRF-04 run).
- **`providers.json` does not need a change for the new alias**, confirmed above via `-m`. The phase brief's concern about `contextWindow: 29000`/`models[]` normalization loss (Pitfall 5) is therefore **not triggered** by this test, since no write to `providers.json` occurs at all.
- **`cline config --json` cannot be used as an evidence source in this exact build** — confirmed by v1 Phase 1 (`01-01-SUMMARY.md`): it requires a real TTY and fails headlessly. Do not attempt it; rely on the `--json` NDJSON stream itself, as v1 already established.
- **`cline --id <session-id> --json <prompt>` (resuming a session across separate invocations) is broken in this exact installed version** — 100% failure reproduced across every argument form (`01-RESEARCH.md`). If VRF-04 wants multi-turn growth, drive it **inside one `cline` invocation** via the agent's own tool-call loop (the pattern v1 already validated: ask it to read a short sequence of pre-staged files, or simply have a short multi-step conversation prompt), not via `--id` resume.

---

## Q5 — Byte-identical preservation check for the existing `flashnext` alias (CFG-13)

**Do not use a whole-file sha256 as the "unchanged" signal** — the file legitimately changes (new aliases added), so its hash will differ, and that's expected here (unlike Phase 9, where an unchanged hash was itself the pass condition).

**Recommended mechanism, chosen to match how this file is actually structured and edited** (hand-written, heavily comment-annotated flat YAML — confirmed 50 lines today, `flashnext` at lines 22-27, `flashnext-codex` at 29-33): **edit by pure line-appending only, never by loading-and-re-dumping through a YAML library.** A `yaml.safe_load()` + `yaml.dump()` round-trip would silently destroy every comment in the file (all the 🔴-flagged operational notes) even if semantically lossless on the `model_list` data — this file's comments carry real operational history and must survive.

1. **Before editing:** `cp -p /Users/ohama/agent-stack/litellm/config.yaml /Users/ohama/agent-stack/litellm/config.yaml.bak.$(date -u +%Y%m%dT%H%M%SZ)` (or into a project-tracked backups dir, matching the `phase-01/config/backups/` convention already established elsewhere in this project).
2. **Edit by inserting new lines after line 33** (end of the `flashnext-codex` block), before the existing blank line 34. This guarantees lines 1-33 of the file are untouched by construction, not merely by inspection.
3. **Primary check (exact, trivial, survives nothing but proves everything needed):**
   ```bash
   diff <(head -n 33 config.yaml.bak.<ts>) <(head -n 33 /Users/ohama/agent-stack/litellm/config.yaml)
   # must be empty
   ```
   This proves byte-identical preservation of both `flashnext` AND `flashnext-codex` (stronger than CFG-13 strictly requires, which only names `flashnext`, but there is no reason to weaken it).
4. **Secondary check (whole-file diff shape):**
   ```bash
   diff config.yaml.bak.<ts> /Users/ohama/agent-stack/litellm/config.yaml | grep '^<'
   # must be empty — a non-empty result means an existing line was
   # removed or altered, not purely appended
   ```
5. **Defense-in-depth, semantic (optional, catches the case where someone touches an existing line and the two checks above are somehow bypassed):** parse both files with `yaml.safe_load()` and assert the `model_list` entry with `model_name: flashnext` deep-equals between old and new. **Failure mode of this check on its own:** it is blind to comment loss and to key-reordering-if-order-mattered (it doesn't here), and it would report a false PASS if someone rewrote the whole file through a YAML dumper that happened to preserve semantics — which is exactly the scenario the primary line-range diff (step 3) is designed to catch instead. Use both; they cover each other's blind spot.

---

## Q6 — Why `flashnext-codex` kills the model server (and how to avoid repeating it)

**Established from prior project record, not re-derived here (out of scope to re-investigate root cause deeply; the constraint is simply "never call it").** v1's `PROJECT.md`/`REQUIREMENTS.md` record: "`flashnext-codex` 별칭 차단 (호출 시 모델 서버 사망, 29초 다운 실측)" — calling it caused a measured 29-second `mlx_vlm.server` outage, with launchd's `KeepAlive` bringing it back up on its own. `docs/cline-config-pins.md:17` and `phase-01/config/verify_config.sh` (which greps for the literal string `flashnext-codex` anywhere under `~/.cline` and fails if found) are the standing guards.

**Structural reason it's a different code path, confirmed from `litellm-config.yaml` itself:** `flashnext-codex`'s `litellm_params.model` uses the prefix `openai/chat_completions/<path>` (config.yaml line 31) — the comment above it says "Codex(Responses API) 전용 — responses→chat 브릿지가 필요하다." This is litellm's Responses-API-to-Chat-Completions bridge marker, a distinct transformation path from either the plain `openai/` prefix (`flashnext`) or the `hosted_vllm/` prefix this research recommends for `flashnext-plan`/`flashnext-act`. It very likely sends `mlx_vlm.server` (which only speaks Chat Completions) a request shaped for a different API surface, which the server does not handle gracefully.

**How Phase 10 avoids repeating it:** the new aliases use `hosted_vllm/<path>` — not `openai/chat_completions/<path>`, not any Responses-API bridge prefix. This is a categorically different, well-trodden litellm provider path (used for self-hosted OpenAI-compatible chat servers) with no Responses-API involvement. No `flashnext-plan`/`flashnext-act` invocation should ever produce the `flashnext-codex` failure mode, because neither uses the bridge marker. **Never test this by invoking `flashnext-codex` directly** — the mechanism above is sufficient to explain the difference without needing to reproduce the crash.

---

## Q7 — Interaction with `--max-num-seqs 1`

**VERIFIED (inherited from Phase 9 research, still applicable, no new stack behavior introduced by Phase 10):** `mlx_vlm.server` (PID confirmed running with `--max-num-seqs 1` in its live process args per `09-RESEARCH.md`) serializes ALL requests through one in-flight slot, tagged `in_flight=N` in `~/llm-system/services/logs/flashnext.err`. **Adding new litellm aliases does not create new backend capacity or change this at all** — `flashnext`, `flashnext-plan`, and `flashnext-act` all route to the exact same upstream `api_base: http://localhost:8011/v1` (role-shim) → the same single `mlx_vlm.server` process. They are three named front doors to one backend queue, not three backends. A request to `flashnext-plan` and a concurrent request to `flashnext` will queue behind each other exactly as two concurrent requests to `flashnext` alone would today.

**Polite-tenant discipline for Phase 10's probes (reuse Phase 9's established checklist verbatim, `09-RESEARCH.md` §Q4):**
1. `tail -2 ~/llm-system/services/logs/flashnext.err` and confirm `in_flight=0` before firing any probe.
2. Keep every probe's `max_tokens` small for reach-proof purposes (Phase 9 used ≤300; VRF-04's real `cline` runs will need a somewhat larger budget to let a real short task complete, but should still stay modest — a few hundred tokens, not thousands).
3. Fire probes strictly sequentially, never in parallel.
4. `pgrep -fl 'bin/\.cline|bin/cline'` as an additional (non-authoritative) signal before a probe burst.
Given serialization, the worst-case failure mode of ignoring this is queuing latency, not corruption — but Phase 9 already showed clean discipline throughout, and Phase 10 (now mutating the live stack) should be at least as careful, arguably more so since a restart is also involved.

---

## Common Pitfalls

### Pitfall 1: Assuming alias-level injection bypasses client-side validation
**What goes wrong:** Designing `flashnext-plan` with `reasoning_effort` under the same `openai/` provider prefix as `flashnext`, on the (reasonable-sounding but false) assumption that "injected via config" is treated differently from "sent by the client."
**Why it happens:** The established Phase 9 asymmetry ("client-sent `reasoning_effort` → 400, client-sent `enable_thinking` → 200") is easy to over-generalize into "so injecting server-side avoids the 400." It doesn't — see Q1.
**How to avoid:** Use the `hosted_vllm/` provider prefix for the new aliases only, as this research verifies.
**Warning signs:** Every single request to `flashnext-plan` returns HTTP 400 immediately after the restart, including ones with a completely empty extra body.

### Pitfall 2: Editing `~/local-llm-settings/config/litellm-config.yaml` directly
**What goes wrong:** The edit has zero effect on the running service (litellm never reads this path), and the next `sync.sh` run silently overwrites it back to match the real source — making it look like the edit "reverted itself."
**How to avoid:** Always edit `/Users/ohama/agent-stack/litellm/config.yaml`; treat the `local-llm-settings` copy as generated output only.

### Pitfall 3: Pointing `providers.json` at `flashnext-plan` for VRF-04
**What goes wrong:** Breaks `verify_config.sh`'s hard-coded `model == "flashnext"` assertion, and risks the previously-documented Pitfall 5 (Cline's own invocations silently stripping hand-added `providers.json` fields).
**How to avoid:** Use `cline -m flashnext-plan` per-invocation override instead (Q4) — `providers.json` never needs to change for this test.

### Pitfall 4: Round-tripping `config.yaml` through a YAML dump tool
**What goes wrong:** Destroys the file's extensive comment history (operational warnings accumulated since 2026-08-29), even if the `model_list` data is semantically preserved — and could resequence/reformat the untouched `flashnext`/`flashnext-codex` blocks in ways that make the CFG-13 byte-identical check ambiguous to satisfy.
**How to avoid:** Hand-append new list items as raw text, matching the file's existing style exactly (see Q5's recommended insertion point).

---

## Open Questions

1. **Does the reasoning field actually appear when both injected params combine on this exact model/stack, at real (non-`max_tokens:4`) generation lengths?** (ROADMAP criterion 1b / CFG-16's remaining, narrower question.)
   - What we know: Phase 9's PRB-03 measured the `et-medium` combination's *token cost* (11, identical to `medium` alone) at `max_tokens:4`, which likely truncates or suppresses visible reasoning content — it did not inspect the response body's `reasoning`/`reasoning_content` field content for that arm.
   - What's unclear: whether the model, when it actually reaches `medium` effort **and** `enable_thinking:true` together with room to generate, produces non-empty `reasoning_content` through `:8011` and through the new `flashnext-plan` alias at `:4000`.
   - Recommendation: after building `flashnext-plan` and restarting, the plan's first live check should be a single `curl` to `:4000`/`flashnext-plan` with a normal `max_tokens` (e.g. 128-300) and inspect `choices[0].message.reasoning_content` (or `.reasoning`) for non-empty content — independent of and prior to the VRF-01 token-delta proof. Also repeat directly against `:8011` with the literal JSON body `{"reasoning_effort":"medium","enable_thinking":true}` for the two-endpoint proof ROADMAP criterion 1b explicitly asks for.

2. **Does switching only the new aliases to `hosted_vllm/` introduce any request-shape difference from `flashnext`'s `openai/`-prefix requests, beyond the two injected params, that could confound VRF-01's `prompt_tokens` comparison?**
   - What we know: both providers inherit the same `transform_request()` (`OpenAIGPTConfig`, unchanged by `HostedVLLMChatConfig`), so the JSON body shape should be identical except for the injected keys. `HostedVLLMChatConfig._transform_messages` adds handling for `thinking_blocks`/video-file fields on messages that our text-only agentic workload should never populate.
   - What's unclear: whether litellm's two different low-level request paths (`openai_chat_completions.completion()` for `openai`, vs `base_llm_http_handler.completion()` for `hosted_vllm`) produce any incidental byte-level difference in the request (e.g. header ordering, an extra default field) that role-shim/mlx_vlm.server's tokenizer could be sensitive to.
   - Recommendation: as a sanity check, before trusting VRF-01's delta as caused only by the injected params, run one baseline request through `flashnext-plan` with a config temporarily lacking both injected params (or compare against a manual `:4000` call using `hosted_vllm/<path>` with no reasoning params) against the existing `flashnext` (`openai/<path>`) baseline — if their `prompt_tokens` for an identical plain message already match, the provider-prefix swap introduces no confound and VRF-01's delta can be attributed cleanly to the injected params.

3. **Restart health-poll false-positive window** (see Q2's OPEN ITEM) — proposed probe already stated there (double-sample `launchctl print` ≥10s apart after `restart_service.sh` reports success).

4. **Is a distinct `flashnext-act` alias worth creating at all**, given `enable_thinking:false` is already the model's default and thus behaviorally identical to the unmodified `flashnext` alias? Not a blocking question — ROADMAP's criterion 2 implies creating it — but the plan should record the reasoning explicitly rather than silently duplicating an alias with no behavioral difference from an existing one.

## Sources

### Primary (HIGH confidence — read directly from the files that govern current behavior, or executed live against the installed library with no stack mutation)
- `/Users/ohama/agent-stack/venv/lib/python3.12/site-packages/litellm/` (v1.86.1, the actual installed package backing `com.ohama.litellm` PID 48525) — `router.py:2370-2456`, `utils.py:3981-4103,4680-4692,4798-4855,9517-9524`, `litellm_core_utils/get_supported_openai_params.py:1-110`, `llms/openai/chat/gpt_transformation.py:100-250,423-450,665-710`, `llms/hosted_vllm/chat/transformation.py` (full file), `llms/openai/openai.py:611-780`, `llms/custom_httpx/llm_http_handler.py:377-460`, `types/router.py:291-405`
- Live execution of `litellm.get_optional_params()` and `litellm.get_llm_provider()` against the installed package, isolated Python process, no network/config/server touched (see Q1)
- `/Users/ohama/agent-stack/litellm/config.yaml` (the real, live litellm config; confirmed via `~/Library/LaunchAgents/com.ohama.litellm.plist`'s `ProgramArguments`) and `~/local-llm-settings/config/litellm-config.yaml` (mirror, sha256-confirmed identical today)
- `~/local-llm-settings/sync.sh` (full script read)
- `~/Library/LaunchAgents/com.ohama.litellm.plist`, `launchctl print gui/$(id -u)/com.ohama.litellm`
- `phase-02/infra/restart_service.sh`, `phase-02/infra/config.env`, `phase-02/infra/verify_no_regression.sh`
- `phase-01/config/apply_provider_config.sh`, `phase-01/config/verify_config.sh`
- `cline-src` at tag `cli-v3.0.53` (`git describe --tags` confirmed, working tree clean): `apps/cli/src/commands/program.ts:44-48,225`, `apps/cli/src/main.ts:1054-1055`, `apps/cli/src/utils/events.ts:97-140`
- `~/.cline/data/settings/providers.json` (current live content)
- `phase-09/GATE-VERDICT.md`, `phase-09/PRB-03-ORACLE.md`, `phase-09/PRB-04-FINDINGS.md`, `.planning/phases/09-preflight-gates/09-RESEARCH.md` (all read in full)
- `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.planning/STATE.md` (all read in full)
- `~/local-llm-settings/VALIDATED.md` (full read)
- v1 milestone archive: `.planning/milestones/v1-phases/01-cline-config-compaction-verification/{01-01,01-02,01-04,01-05,01-06}-{PLAN,SUMMARY}.md`, `01-RESEARCH.md` — established `cline --json` invocation pattern, TTY limitation of `cline config --json`, `--id` resume bug, `flashnext-codex` crash record

### Secondary
- None used — all findings above trace to primary sources or live execution.

## Metadata

**Confidence breakdown:**
- Q1 (litellm injection mechanism, the central finding): HIGH — verified from source with line citations AND live execution of the actual installed library function, zero inference
- Q2 (restart/rollback): HIGH — existing project script already covers this exact scenario, read in full
- Q3 (sync.sh / source-vs-mirror): HIGH — read the script directly, confirmed live sha256 match
- Q4 (cline CLI invocation): HIGH for the invocation shape and NDJSON field (existing v1 precedent + source citation); MEDIUM for whether Cline's own reasoning-history serialization behaves exactly as PRB-04's source trace predicts once a live `cline` process is actually run (this is explicitly what VRF-04 itself is for — Phase 9 deferred it, this research does not resolve it, only prepares the exact command)
- Q5 (byte-identical check): HIGH — mechanism designed directly against the actual current file's exact line structure, verified today
- Q6 (flashnext-codex danger): MEDIUM — root cause reasoning is inferred from the config's own comments and the provider-prefix mechanism traced in Q1, not independently reproduced (deliberately, per constraints — never call it)
- Q7 (concurrency): HIGH — directly inherited from Phase 9's already-verified live process inspection, unchanged by anything Phase 10 does

**Research date:** 2026-09-01
**Valid until:** Valid through Phase 10's execution window. Re-verify Q1's mechanism if `litellm` is ever upgraded past 1.86.1 (provider param-support lists change between releases) — check `litellm --version` before trusting this document's specific line citations in any later phase.
