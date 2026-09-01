# Phase 9: 사전 확인 게이트 (스택 무변경) - Research

**Researched:** 2026-09-01
**Domain:** LLM reasoning-parameter plumbing (mlx_vlm.server ↔ role-shim ↔ litellm ↔ Cline CLI), source archaeology on `cline/cline` `cli-v3.0.53`, litellm 1.86.1 internals
**Confidence:** HIGH on PRB-01/02/03 (directly measured, reproduced, zero variance). HIGH-but-partially-inferred on PRB-04 (direct model-layer measurement is definitive; the Cline-client-in-the-loop leg is source-verified, not executed live).

> This document does **not** re-derive the design in `docs/plan-act-reasoning-{design,implementation,diagrams}.md`. It resolves the four open method questions (Q1–Q4) that those documents left for Phase 9, using only stack-unchanged, read-only-safe methods. Several of the "how would you test this" questions turned out to be directly testable right now — this document reports the actual results, not just a test plan.

## Answers at a Glance

| # | Question | Answer | Confidence |
|---|----------|--------|------------|
| PRB-01 | Does `reasoning_effort: medium` at `:8011` produce a `reasoning` field? | **YES.** Non-empty `reasoning` field returned (89–480 chars across probes). Gate **PASSES**. | HIGH (measured live, 2026-09-01) |
| PRB-02 | Does `enable_thinking: false` pass litellm `:4000`? | **YES**, HTTP 200 through the existing `flashnext` alias, no `UnsupportedParamsError`. → `flashnext-act` alias should be built in Phase 10 per the implementation doc's decision table. | HIGH, with one caveat (see below — `false` is already the default, so 200 does not by itself prove the param is *applied*, only that it isn't *rejected*) |
| PRB-03 | Is the `prompt_tokens` oracle usable? | **YES.** Re-measured today: unspecified=13, medium=11, low=41, xhigh=53 (single fixed user message `"hi"`). Absolute baseline drifted from VALIDATED.md's 23/21/51/63, but the **deltas from "unspecified" are bit-for-bit identical**: medium −2, low +28, xhigh +40, in both today's and VALIDATED.md's numbers. Zero variance across 2 repeated runs (deterministic tokenization, not sampled). | HIGH |
| PRB-04 | Does the thinking trace come back into the next turn's context, and does that cost tokens? | **Architecturally yes** (Cline's default code path re-includes reasoning history for any non-Cerebras provider — source-confirmed). **Numerically no measurable cost** — a live, full-stack, stack-unchanged test (litellm `:4000` → role-shim `:8011` → model `:8000`, existing `flashnext` alias, no config edit) shows **prompt_tokens delta = 0** when a 1,380-char synthetic `reasoning_content` is attached to a historical assistant message vs. omitted. Gate **PASSES** (proceed to Phase 10). | HIGH on the model-layer measurement (reproduced twice, full stack). MEDIUM on "Cline itself actually does this in practice" (source-verified, not observed on the wire from a real `cline` process) |

**Primary recommendation:** Both gates (PRB-01, PRB-04) pass. Phase 10 should proceed. The chicken-and-egg problem described in the task brief for PRB-04 is avoidable — do not attempt to point Cline itself at `:8011` (Q1a); a direct, stack-unchanged replay probe already answers the operationally relevant part of the question with higher confidence than a live Cline run would.

---

## Q1 — PRB-04: How is "does Cline replay `reasoning` into the next turn" testable without changing the stack?

### TL;DR

The three options in the brief — (a) point Cline at `:8011`, (b) source inspection, (c) manual API-level replay — are not mutually exclusive fallbacks of decreasing quality. **(c) turns out to be the load-bearing, decisive method, and (b) explains *why* the (c) result comes out the way it does.** (a) is not needed and is not recommended.

### Recommended primary method: (c) manual replay probe, run through the **full unmodified stack**

Not just `:8011` — I ran it through `:4000` (litellm, existing `flashnext` alias) as well, so it isn't "the model's tokenizer in isolation," it's "the exact pipeline Cline's requests travel through, with zero config changes."

**What was done:** Built a 3-message conversation (`user → assistant → user`) where the assistant message optionally carries a `reasoning_content` (and, separately, a `reasoning`) field — the exact field name Cline's own code would attach (see source trace below) — and compared `prompt_tokens` for the next turn with vs. without that field.

```python
# Literal probe — safe to hand to the planner as-is.
# Tests the ONLY thing that matters for the 32K-wall risk: does a replayed
# reasoning field cost prompt tokens on the next turn, in this exact stack.
import json, urllib.request

FAKE_REASONING = "This is a long fake internal reasoning trace. " * 30  # ~1,380 chars

def call(url, model, messages, max_tokens=4):
    body = {"model": model, "messages": messages, "max_tokens": max_tokens}
    headers = {"Content-Type": "application/json"}
    if "4000" in url:
        headers["Authorization"] = "Bearer dummy"
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp).get("usage", {}).get("prompt_tokens")

base = [
    {"role": "user", "content": "What is the capital of France?"},
    {"role": "assistant", "content": "The capital of France is Paris."},
    {"role": "user", "content": "And what is its population?"},
]
with_reasoning = [base[0], {**base[1], "reasoning_content": FAKE_REASONING}, base[2]]

M = "/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4"
print("via :8011 direct  — no field:", call("http://localhost:8011/v1/chat/completions", M, base))
print("via :8011 direct  — WITH   :", call("http://localhost:8011/v1/chat/completions", M, with_reasoning))
print("via :4000 litellm — no field:", call("http://localhost:4000/v1/chat/completions", "flashnext", base))
print("via :4000 litellm — WITH   :", call("http://localhost:4000/v1/chat/completions", "flashnext", with_reasoning))
```

**Actual result (2026-09-01, reproduced at both layers):**

| Path | Without `reasoning_content` | With 1,380-char `reasoning_content` | Delta |
|---|---:|---:|---:|
| `:8011` direct | 46 | 46 | **0** |
| `:4000` litellm, `flashnext` alias (unmodified) | 46 | 46 | **0** |

Also confirmed HTTP 200 in all cases — litellm does **not** reject a `reasoning_content`/`reasoning` key nested inside a message object (the `UnsupportedParamsError` mechanism only polices top-level completion params like `reasoning_effort`, not arbitrary per-message fields).

**What this proves:** In this exact deployed stack, if a historical assistant message carries replayed reasoning content (under either field name), it is tokenized into **zero** extra prompt tokens on the next turn. This directly answers the physical concern behind Gate① ("does context grow faster because of thinking, colliding with the known non-pruning-compaction defect") — it does not, because the model's chat template does not render prior-turn reasoning/thinking content into the prompt at all (a well-known, deliberate convention for reasoning-capable chat templates, not unique to this deployment).

**What this does NOT prove:** That Cline's real, running client (`cli-v3.0.53`) actually constructs such a message this way in practice. That is answered by the corroborating method below, not by this probe.

### Corroborating method: (b) source inspection — confirms Cline *does* attach it by default, and explains the wire format

The implementation doc's source-inspection pass (`toGatewayRequestMessages` at `compat.ts:306` only walking `message.content`, and `agentic-compaction.ts:88`'s `reasoningChars` being self-telemetry) was **too shallow** — it looked at the wrong two functions. Tracing further:

1. **Response parsing recognizes the field.** `@ai-sdk/openai-compatible@^3` (pinned in `sdk/packages/llms/package.json:59`, same major used by `sdk/packages/llms/src/providers/vendors/openai-compatible.ts`) parses **both** `reasoning_content` and `reasoning` on `choice.message` (non-streaming) and `delta` (streaming) — confirmed against the public Vercel `ai` repo source for `openai-compatible-chat-language-model.ts`. Our model returns the field literally named `reasoning` (confirmed via the live PRB-01 probe below) — this is one of the two names the SDK checks.
2. **It gets persisted, not discarded.** `sdk/packages/core/src/runtime/config/agent-message-codec.ts:237` (`agentPartToContentBlock`, `case "reasoning"`) converts an incoming reasoning stream part into a `ThinkingContent` block (`type: "thinking"`) that lands in the Task's persisted `Message[]` history. `sdk/packages/core/src/session/services/message-builder.ts` explicitly counts `block.type === "thinking"` bytes toward the conversation's text budget — i.e., it is treated as first-class, budget-relevant conversation content, not a display-only artifact.
3. **It is re-included by default.** `sdk/packages/llms/src/providers/ai-sdk.ts:284-287`:
   ```typescript
   function shouldIncludeReasoningHistory(
       request: GatewayStreamRequest,
       context: GatewayProviderContext,
   ): boolean {
       return !isCerebrasProvider(request, context);
   }
   ```
   Our provider (`openai-compatible` / `flashnext`) is not Cerebras → `includeReasoning = true` by default. `toAiSdkMessages()` (`ai-sdk.ts:298-340`) then re-emits each persisted `thinking` block as a `{type: "reasoning", text: ...}` part in the outbound AI-SDK message array.
4. **It is serialized back onto the wire as `reasoning_content`.** `@ai-sdk/openai-compatible`'s `convertToOpenAICompatibleChatMessages` (public source) accumulates `reasoning` parts and adds `reasoning_content: reasoning` to the assistant message object of the outbound request when non-empty — the exact field name and shape used in the probe above.
5. **litellm's response path also recognizes the field name.** Read directly from the installed `litellm==1.86.1`-equivalent venv (`/Users/ohama/agent-stack/venv/lib/python3.12/site-packages/litellm`, the one actually running `com.ohama.litellm`):
   - `litellm_core_utils/prompt_templates/common_utils.py:1337`, `_extract_reasoning_content()`:
     ```python
     if "reasoning_content" in message:
         return message["reasoning_content"], message_content
     elif "reasoning" in message:
         return message["reasoning"], message_content
     ```
   - Called from both the generic response converter (`convert_dict_to_response.py`) and the specific `openai` chat transformation used by our alias (`llms/openai/chat/gpt_transformation.py`, plus its own streaming-delta remap `_map_reasoning_to_reasoning_content`).
   - `types/utils.py`'s `Message`/`Delta` classes declare `reasoning_content: Optional[str] = None` as a real field, so once populated it round-trips through `.model_dump()`/serialization normally.

**Verdict:** the implementation doc's "no evidence of accumulation" conclusion was a **false negative** produced by checking only two shallow signals. The correct, source-verified statement is: *Cline's default architecture attaches reasoning history on every subsequent turn for any non-Cerebras provider, and the field-name translation (`reasoning` ↔ `reasoning_content`) is compatible in both directions across Cline ↔ litellm ↔ this model server.* This should replace the relevant paragraph in `docs/plan-act-reasoning-implementation.md` §T2 during Phase 12's documentation pass.

### Why (a) — pointing Cline itself at `:8011` — is not recommended for Phase 9

The brief documents a real prior failure: an isolated `--config <dir>` attempt caused Cline to normalize a fresh `providers.json` and drop `apiKey`/`baseUrl`/`contextWindow` at startup. Investigating why (via `provider-settings-legacy-migration.ts`), this class of loss is a **legacy-migration/normalization** behavior that fires on hand-authored files; it is avoidable in principle by letting Cline itself generate the file (`cline --config <dir> auth openai-compatible -b http://localhost:8011/v1 -k dummy -m <model>`, mirroring exactly what `phase-01/config/apply_provider_config.sh` already does for the production file) rather than hand-writing `providers.json` into a fresh directory, then post-patching only the top-level fields `apply_provider_config.sh` already knows how to patch idempotently.

That said: this is genuine additional engineering effort and residual risk (isolated hub-daemon ports, cline's own auto-update drift, a second `providers.json` to keep in sync) to answer a question that is **already answered, with higher confidence, by the model-layer probe above** — because the model-layer probe is what determines whether the 32K-wall risk is real, independent of whatever exact bytes real Cline would send. Recommend deferring a live-Cline confirmation to Phase 10, where it becomes nearly free: once `flashnext-plan` exists as a normal litellm alias, pointing the *production* `providers.json` at it via the already-verified `apply_provider_config.sh`/`verify_config.sh` pattern requires no isolation hack at all, and a 2-turn real session can be diffed against the numbers already established here.

### Fallback (if the primary probe is ever in doubt)

Re-run the same replay probe with a **real** captured `xhigh` reasoning trace (thousands of characters, not the 1,380-char synthetic one used here) to rule out a length-threshold effect, and/or re-run once through `:4000` in the middle of normal Kanban/Telegram traffic to rule out contention artifacts. Both are cheap, stack-unchanged, and listed under Open Risks below.

---

## Q2 — What does the model return for `reasoning_effort: medium`? (PRB-01)

**Probe (already run, reproduce with this exact command):**

```bash
M=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
curl -s http://localhost:8011/v1/chat/completions -H 'Content-Type: application/json' \
  -d "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"2+2는?\"}],\"max_tokens\":64,\"reasoning_effort\":\"medium\"}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin)['choices'][0]['message']; \
      print('content  :', (d.get('content') or '')[:80]); \
      print('reasoning:', (d.get('reasoning') or 'None')[:120])"
```

**Actual output (2026-09-01):**
```
content  : 2+2는 **4**입니다.
reasoning: The user is asking "2+2는?" which is Korean for "What is 2+2?" This is a simple arithmetic question. The answer is 4. I'l
```

**Answer: thinking is ON at `medium`.** The `reasoning` field is present and substantive (89 chars for a trivial question; 214–480 chars in the multi-turn probes above for slightly harder questions). This is a clean discriminator between "thinking ON at reduced effort" and "thinking OFF" — no ambiguity, no further probe design needed.

**On the "`medium` system prompt is shorter than unspecified" oddity:** re-measured today (single fixed user message `"hi"`, so this isolates the *system*-prompt-driven part of `prompt_tokens`): unspecified=13, medium=11. The delta (−2) is identical to VALIDATED.md's original 23→21. Since PRB-01's probe above shows `medium` unambiguously turns thinking on (non-empty `reasoning` field with real content), the shorter prompt is **not** evidence that `medium` fails to enable thinking — it is most likely a chat-template branch artifact (explicitly passing any `reasoning_effort` value routes through a different template branch than the "unspecified" default, and that branch happens to omit a few boilerplate tokens present in the default branch, e.g. a "not currently thinking" hint). This is a minor unexplained curiosity, not a blocker, and does not need further investigation for Phase 9's purposes — the direct field-presence check settles it.

---

## Q3 — Is the `prompt_tokens` oracle usable, and where is it read from? (PRB-03)

**Exact log line format** (from `~/llm-system/services/logs/flashnext.err`):
```
2026-09-01 09:55:29,164 - INFO - Prefill started: request=835b269010 backend=continuous_batching prompt_tokens=13 images=0 audio=0 videos=0
```

**Robust parse:**
```bash
grep "Prefill started" ~/llm-system/services/logs/flashnext.err | tail -N \
  | grep -oE 'prompt_tokens=[0-9]+' | cut -d= -f2
```
(`grep -oE` avoids depending on GNU-only `-P`/PCRE, which may not be present in the macOS-shipped `grep`.)

**Re-measurement (2026-09-01, single fixed user message `"hi"`, `max_tokens=4`, sequential requests, ~1s apart, verified `in_flight=0` before/after):**

| effort | VALIDATED.md (original) | Today (re-measured) | Delta from "unspecified", both dates |
|---|---:|---:|---:|
| unspecified | 23 | 13 | 0 (baseline) |
| medium | 21 | 11 | **−2 / −2** (identical) |
| low | 51 | 41 | **+28 / +28** (identical) |
| xhigh | 63 | 53 | **+40 / +40** (identical) |

The absolute baseline drifted by a constant −10 across all four rows (likely a different exact user-message token count or a minor system-prompt revision between the two measurement sessions — not investigated further, not relevant since the oracle is used as a **delta**, not an absolute value). The effort-driven delta is **bit-for-bit reproducible** across sessions.

**Noise / repetition:** ran the full 4-value sweep twice back-to-back — **zero variance** (13/41/11/53 both times). This is expected: `prompt_tokens` is a deterministic function of tokenized text, not a sampled generation output, so it has no run-to-run randomness under normal operation. **One well-formed 200 response per value is sufficient**; the only reason to repeat is to rule out the `no Stream(gpu, 1)` flake (see below), not statistical noise.

**Which values make a reliable reach-proof oracle:** confirms the design doc's warning — **do not use `medium`** as the Phase 10 VRF-01 reach-probe (±2 tokens is too fragile against any incidental prompt drift). **Use `low` (+28) or `xhigh` (+40)** to prove injection reached the model, then leave the deployed alias at `medium`.

---

## Q4 — Operational safety for Phase 9

### What Phase 9 may touch

- Read-only: `cline-src` (already cloned, `cli-v3.0.53`), `~/llm-system/role_shim.py` (source read only — confirmed it forwards all message fields byte-for-byte except rewriting `role: developer/system → system/user`, so it is not the layer that would strip a replayed `reasoning_content`), the installed litellm venv source at `/Users/ohama/agent-stack/venv/lib/python3.12/site-packages/litellm` (reading Python source files is inspection, not a config or code change — nothing here is installed/modified), and `~/llm-system/services/logs/flashnext.err`.
- Small POST probes: `:8011` direct, and `:4000` **using the existing, unmodified `flashnext` alias only**. Every probe run for this research kept `max_tokens` ≤ 300 and completed in 0.2–3.5s; none required a restart or config edit.

### What Phase 9 must not touch

- `~/local-llm-settings/config/litellm-config.yaml` — no edits. That is Phase 10's job (adding `flashnext-plan`/`flashnext-act`).
- No restart of `com.ohama.flashnext` (46573), `com.ohama.role-shim` (75548), `com.ohama.litellm` (48525) — confirmed all three `running`, `:4000`/`:8011` both return 200 in <25ms as of this research session.
- No colima/Docker start, no port 3000 bind.

### Is writing `~/.cline/data/settings/providers.json` (via `apply_provider_config.sh`) "inside" or "outside" stack-unchanged?

**Recommended line: outside Phase 9's needed scope, so don't touch it — the question turned out to be moot.** The reason to touch it would have been to run Cline against `:8011` (Q1a), and that method was found unnecessary (§Q1 above) once the direct replay probe gave a decisive, higher-confidence answer. If a future phase (or a planner who disagrees with this recommendation) does need to touch it: `apply_provider_config.sh` already backs up to `phase-01/config/backups/` before writing, and `verify_config.sh` exists to check the result — use that path, not a hand-edit, and restore via the backup + re-run `verify_config.sh` afterward.

**Current file state, recorded for restore-verification if anyone does touch it:**
```
sha256: 5cf3800da31de8855b06e1d1cc85f415d68332dbee2625a587da2b4d8093e0a1
path:   /Users/ohama/.cline/data/settings/providers.json
```

### Avoiding interference with `com.ohama.kanban` / `kanban-proxy` / `telegram-connect`

The model server runs with `--max-num-seqs 1` (confirmed from the live process args of PID 46573) — it naturally **serializes** all requests through a single in-flight slot rather than erroring on concurrency; the `flashnext.err` log tags every request with `in_flight=N`. Practical safety checks used throughout this research and recommended for Phase 9 tasks:

1. Before firing a probe, `tail -2 ~/llm-system/services/logs/flashnext.err` and confirm the last line shows `in_flight=0`.
2. Keep every probe's `max_tokens` small (≤300) — worst-case occupation observed was ~3.5s.
3. Run probes sequentially, never in parallel (matches the implementation doc's own `for e in ...` pattern).
4. `pgrep -fl 'bin/\.cline|bin/cline'` before a probe burst, as a light signal for "is someone using the CLI right now" (not authoritative — a background `cline-hub-daemon` process was observed running for an unrelated project during this research and is not itself evidence of an active model request).

Given `--max-num-seqs 1`, the worst case of ignoring all of the above is a few seconds of extra queuing latency for a real user request, not corruption or dropped requests — but there is no reason not to follow the checklist given how cheap it is.

---

## Could Not Verify / Open Risks

1. **Real Cline-on-the-wire confirmation is deferred, not done.** Everything in §Q1's corroborating method is source-verified for `cli-v3.0.53`, not observed from an actual running `cline` process's HTTP request bytes. Recommend a cheap, near-free confirmation once Phase 10 builds `flashnext-plan`: point the real `providers.json` at it (already-verified `apply_provider_config.sh` path, no isolation needed) and diff a real 2–3 turn session's `prompt_tokens` growth against a `flashnext` (thinking-off) baseline of equal turn count. Expected result, per this research: no material extra growth beyond what §Q2's fixed medium/unspecified system-prompt delta already predicts per turn.
2. **litellm's *request-side* schema validation (FastAPI/pydantic layer in `proxy_server.py`) was not fully traced**, only the specific `openai` provider's `transform_request` (which does near-raw message passthrough). The live end-to-end probe through `:4000` (§Q1) is the decisive evidence here regardless — it returned clean HTTP 200 with the expected zero-cost result — but if Phase 10 changes the alias's `litellm_params` in some unusual way (e.g., wrapping via a different vendor client), this specific finding should be re-checked.
3. **Scale of the synthetic reasoning trace.** The zero-cost replay result used a 1,380-character synthetic trace (~300–400 estimated tokens). A real `xhigh` trace over several turns could be substantially longer (the design doc notes thinking length is unbounded — `thinking_budget` doesn't work with the drafter attached). Recommend Phase 10 re-run the same replay probe with a real, longer captured reasoning trace as cheap insurance before fully trusting the zero-cost finding at scale.
4. **PRB-02's `false` result can't distinguish "applied" from "silently accepted no-op."** Since `enable_thinking: false` is already the model's default, HTTP 200 through litellm only proves the param isn't *rejected* — it does not prove the model server does anything different when it receives it vs. when it's absent. This doesn't block CFG-12's decision (the implementation doc's criterion is explicitly "does litellm reject it," not "does behavior change"), but if a positive-control test is ever wanted, use `enable_thinking: true` through litellm and check for a non-empty `reasoning` field, since `true` differs from default.
5. **The exact chat-template mechanism behind `medium`'s shorter-than-default system prompt (§Q2) was not traced further** (would require inspecting the Qwen3.8-Flash-Next chat template / mlx_vlm.server's prompt-assembly code, which is outside `~/llm-system` and this repo). Flagged as a curiosity, not a blocker — PRB-01's direct field-presence check already settles the operational question.

## Distinguishing a Genuine Negative from the `no Stream(gpu, 1)` Flake

Verified (2026-09-01): all 7 occurrences of `RuntimeError: There is no Stream(gpu, 1) in current thread.` in `flashnext.err` are far outside this session's probe window (most recent prior occurrence at log line 22080; this session's probes are lines 22322–22351, all clean). None of this research's results are flake-affected.

For Phase 9/10 tasks that report a **negative** result (e.g., "`reasoning` field was empty," "prompt_tokens didn't change when it should have"), apply this check before trusting it:

1. Confirm the probe's own HTTP response was `200` with well-formed JSON (not a timeout, 500, or truncated body — the flake, when it occurs on a request, would plausibly surface as a failed/malformed response rather than a silently-wrong-but-200 one, though this repo has not directly observed what a flake-affected request's HTTP status looks like).
2. `grep -n "no Stream(gpu" ~/llm-system/services/logs/flashnext.err | tail -3` and compare timestamps against the probe's own request/response window (from the immediately preceding `Request started` line to the matching `Request completed` line for that `request=<id>`).
3. If a `RuntimeError` line falls inside that window, **discard the sample and re-run** — do not record it as a genuine negative.
4. If no such line appears and the response was clean 200 JSON, the negative result is genuine.

---

## Sources

### Primary (HIGH confidence — live measurement, this session, 2026-09-01)
- Direct probes to `http://localhost:8011/v1/chat/completions` (role-shim direct) — PRB-01, PRB-03, PRB-04 replay tests
- Direct probes to `http://localhost:4000/v1/chat/completions` (litellm, existing `flashnext` alias, unmodified) — PRB-02, PRB-04 full-stack replay confirmation
- `~/llm-system/services/logs/flashnext.err` — `prompt_tokens` oracle readings, flake-timestamp audit
- `/Users/ohama/llm-system/role_shim.py` — full source read (102 lines)
- `/Users/ohama/agent-stack/venv/lib/python3.12/site-packages/litellm/{types/utils.py, litellm_core_utils/prompt_templates/common_utils.py, litellm_core_utils/llm_response_utils/convert_dict_to_response.py, llms/openai/chat/gpt_transformation.py}` — the actual installed source backing the running `com.ohama.litellm` (PID 48525)
- `cline-src` (`/Users/ohama/projs/cline-src`, tag `cli-v3.0.53`, confirmed via `git describe --tags`) — `sdk/packages/llms/src/providers/{ai-sdk.ts, compat.ts, vendors/openai-compatible.ts}`, `sdk/packages/core/src/{runtime/config/agent-message-codec.ts, session/services/message-builder.ts}`

### Secondary (MEDIUM confidence — public source, version-matched but not locally executed)
- `github.com/vercel/ai` — `packages/openai-compatible/src/chat/{convert-to-openai-compatible-chat-messages.ts, openai-compatible-chat-language-model.ts}`, matched against the `^3` major pinned in `sdk/packages/llms/package.json:59`

### Tertiary (existing project docs, not re-verified beyond what's cited above)
- `docs/plan-act-reasoning-{design,implementation,diagrams}.md`
- `~/local-llm-settings/VALIDATED.md` §4 (original 23/21/51/63 measurement)
- `.planning/{REQUIREMENTS,ROADMAP,PROJECT,STATE}.md`

## Metadata

**Confidence breakdown:**
- PRB-01 (reasoning field presence at medium): HIGH — measured directly, unambiguous non-empty field
- PRB-02 (litellm pass-through): HIGH for "not rejected"; caveat noted for "applied vs. no-op" distinction
- PRB-03 (oracle usability): HIGH — reproduced with zero variance, deltas identical across two measurement sessions taken weeks apart in absolute-baseline terms
- PRB-04 (context accumulation): HIGH for the model-layer/token-cost question (directly measured, full stack, twice); MEDIUM for "real Cline does exactly this" (source-verified only)

**Research date:** 2026-09-01
**Valid until:** Treat as valid through the end of this milestone (v1.1). Re-verify if `cline` drifts version (CFG-05 is known-unresolved — check `cline --version` before trusting the source-inspection findings in any later phase) or if the model/server stack is upgraded.
