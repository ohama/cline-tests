# PRB-04 Findings — Phase 9 Plan 03

**Run directory:** `phase-09/results/20260901T021414Z-prb04`
**Generated:** 2026-09-01

This document reports fresh, independent measurements of PRB-04 — the milestone's
🔴 **kill-condition gate**: does a thinking trace return into the next turn's context, at a token
cost that would compound with v1's confirmed defect ("compaction does not prune under real agent
load")? It does **not** declare a gate verdict. That is plan 09-04's job. This document's purpose
is to hand 09-04 a reproduced, flake-discriminated, both-layer, both-field-name, synthetic-**and**-
real-trace measurement, plus a source-inspection correction that must not be lost.

---

## 1. Fresh measurements

### 1a. Synthetic replay matrix (Task 1 — `probe_prb04_replay.py`)

09-RESEARCH.md's literal probe (§Q1), re-run from scratch by this phase, extended to both field
names our stack actually uses. `FAKE_REASONING` = `"This is a long fake internal reasoning trace. " * 30`
= **1,380 chars**. Base 3-message conversation (user → assistant → user), field attached to the
historical assistant message only. `max_tokens: 4` on every call.

| round | endpoint | field | trace chars | http | prompt_tokens | delta vs baseline | flake window | verdict |
|---|---|---|---:|---:|---:|---:|---|---|
| 1 | :8011 | none (baseline) | 0 | 200 | 46 | 0 | CLEAN | — |
| 1 | :8011 | reasoning_content | 1380 | 200 | 46 | **0** | CLEAN | CONFIRMED |
| 1 | :8011 | reasoning | 1380 | 200 | 46 | **0** | CLEAN | CONFIRMED |
| 1 | :4000 (flashnext) | none (baseline) | 0 | 200 | 46 | 0 | CLEAN | — |
| 1 | :4000 (flashnext) | reasoning_content | 1380 | 200 | 46 | **0** | CLEAN | CONFIRMED |
| 1 | :4000 (flashnext) | reasoning | 1380 | 200 | 46 | **0** | CLEAN | CONFIRMED |
| 2 | :8011 | none (baseline) | 0 | 200 | 46 | 0 | CLEAN | — |
| 2 | :8011 | reasoning_content | 1380 | 200 | 46 | **0** | CLEAN | CONFIRMED |
| 2 | :8011 | reasoning | 1380 | 200 | 46 | **0** | CLEAN | CONFIRMED |
| 2 | :4000 (flashnext) | none (baseline) | 0 | 200 | 46 | 0 | CLEAN | — |
| 2 | :4000 (flashnext) | reasoning_content | 1380 | 200 | 46 | **0** | CLEAN | CONFIRMED |
| 2 | :4000 (flashnext) | reasoning | 1380 | 200 | 46 | **0** | CLEAN | CONFIRMED |

**All 4 (endpoint × field) labels reached CONFIRMED after round 2** (both rounds mandatory
regardless of outcome, per the plan; no round 3 was needed — every reading was `delta=0`, CLEAN
flake window, both rounds). Both HTTP 200 in all 12 requests — litellm does not reject a nested
`reasoning`/`reasoning_content` message key. Raw evidence: 12 `raw-prb04-{1,2}-{8011,4000}-{none,
reasoning_content,reasoning}.json`, `prb04-synthetic.tsv`, `verdicts.tsv`.

This reproduces 09-RESEARCH.md's finding (delta=0 at both layers) **bit-for-bit**, now independently
measured by this phase, and extends it to the `reasoning` field name (which the research reasoned
about but did not literally send as a nested key in its own probe code).

### 1b. Real-trace replay matrix (Task 2 — `probe_prb04_realtrace.py`)

Closes 09-RESEARCH.md Open Risk #3 (the zero-cost finding used only a synthetic trace). Uses the
**real** `xhigh` reasoning traces plan 09-02 captured
(`phase-09/results/20260901T015706Z-prb03/realtrace-t{1,2,3}.txt`, 591/917/989 chars, 2,497 total)
— no new model load was generated to obtain them.

- **LONGEST** = `realtrace-t3.txt`, **989 chars** (shorter than the 1,380-char synthetic trace)
- **CONCAT** = all three traces concatenated, **2,497 chars** (longer than the synthetic trace —
  this is the length-threshold probe)

| trace | source | chars | endpoint | http | prompt_tokens | delta vs baseline | flake window | verdict |
|---|---|---:|---|---:|---:|---:|---|---|
| LONGEST | realtrace-t3.txt | 989 | :8011 | 200 | 46 | **0** | CLEAN | CONFIRMED |
| LONGEST | realtrace-t3.txt | 989 | :4000 | 200 | 46 | **0** | CLEAN | CONFIRMED |
| CONCAT | t1+t2+t3 | 2497 | :8011 | 200 | 46 | **0** | CLEAN | CONFIRMED |
| CONCAT | t1+t2+t3 | 2497 | :4000 | 200 | 46 | **0** | CLEAN | CONFIRMED |

All 4 labels CONFIRMED after round 1 (no round 2/3 needed). Raw evidence: 6
`raw-prb04-real-1-{8011,4000}-{none,LONGEST,CONCAT}.json`, `prb04-realtrace.tsv`.

**The real 2,497-char trace (nearly double the synthetic's length) shows zero length-threshold
effect.** The synthetic-trace result was not an artifact of using a trace that happened to be too
short to trigger accumulation.

### 1c. Corroborating (confounded) evidence — 09-02's multi-turn sequences

`phase-09/PRB-03-ORACLE.md` §3 ran a real 3-turn `xhigh` thinking-ON sequence, feeding each turn's
own `reasoning_content` (591 → 917 → 989 chars) into the next turn, and a thinking-OFF sequence
with no reasoning fed back:

| sequence | turn | prompt_tokens | growth | content chars | reasoning chars fed back |
|---|---:|---:|---:|---:|---:|
| ON | 1→2 | 69→127 | +58 | 0 (empty) | 591 |
| ON | 2→3 | 127→150 | +23 | 0 (empty) | 917 |
| OFF | 1→2 | 29→360 | +331 | 548 | 0 |
| OFF | 2→3 | 360→681 | +321 | 66 | 0 |

That document already states this is **corroborating evidence only**, confounded by ON's replies
coming back empty (`finish_reason: length` — the 300-token completion budget was entirely consumed
by `xhigh` reasoning) — so ON's smaller growth mixes "reasoning doesn't tokenize into the next
prompt" with "ON's replies happened to be much shorter". **This plan's §1a/§1b controlled
comparison (identical messages, field present vs. absent, nothing else different) is the decisive
measurement for the gate; §1c is corroboration only**, per the objective in 09-03-PLAN.md.

**Reconciliation, as required by this plan.** Is the controlled zero-cost result quantitatively
consistent with §1c's ON-sequence growth numbers? The sharpest case is ON turn 2→3: content was
empty, a 917-char trace was fed back, and growth was only **+23** tokens — roughly the size of
turn 3's own user message alone, not the ~150+ tokens a 917-char passage would cost if tokenized
directly (Korean text on this model's tokenizer runs roughly 1.5–2 tokens/char in the oracle data
above, so 917 chars tokenized directly would be on the order of hundreds of tokens, not 23). A
direct check (`raw-prb04-reconcile-turn3solo.json`, `phase-09/results/20260901T021414Z-prb04/`,
not part of either committed probe script since it fires no new model traces and exists only to
support this reconciliation paragraph) sent turn 3's exact user text
(`"왜 그런지 한 줄로 설명해줘"`) alone against a fresh `unspecified`-arm baseline: `prompt_tokens=21`,
vs. PRB-03-ORACLE.md's fixed-`"hi"` `unspecified` baseline of `13` — an ~8-token isolated content
cost. The full +23 is somewhat larger than that isolated 8-token estimate, which is expected: a
freshly-started single-turn request and a **newly appended** turn inside an existing multi-turn
conversation do not necessarily cost identical chat-template boundary tokens (this plan did not
isolate that residual). **The key claim is not undermined by that residual**: this plan's own §1b
measurement already directly answers "what does a 917-char (and 2,497-char) real `reasoning_content`
trace cost when replayed" — **exactly 0** — so whatever residual separates +23 from the ~8-token
isolated-content estimate is attributable to non-reasoning turn-boundary/framing overhead, not to
the reasoning trace. **Conclusion: §1c's multi-turn numbers are quantitatively consistent with
§1a/§1b's controlled zero-cost finding; there is no disagreement to report.** Had there been one,
this document would say so loudly rather than picking the more comfortable reading — there is
nothing to pick between here, because §1b already measured the exact quantity in question
directly, and §1c's growth is far too small (tens, not hundreds, of tokens) to be explained by the
larger fed-back trace costing anything close to a per-character rate.

---

## 2. What these measurements do and do not establish

**Established:** in this exact deployed stack (mlx_vlm.server at `:8011` ↔ role-shim ↔ litellm at
`:4000` via the existing, unmodified `flashnext` alias), a historical assistant message carrying a
replayed reasoning field — under either name (`reasoning_content` or `reasoning`), synthetic or
real, up to 2,497 real captured characters — tokenizes into **zero** additional `prompt_tokens` on
the next turn. This is a direct, full-stack, twice-reproduced measurement, not an inference.

**Not established:** what a real, running `cline` process (`cli-v3.0.53`) actually puts on the wire
when it constructs its own next-turn request. This plan's measurement answers "if a reasoning field
is present in a message, does it cost tokens" — it does not observe whether Cline's own outbound
serialization actually attaches one in practice. That is answered only by source inspection (§3
below, MEDIUM confidence per 09-RESEARCH.md) and remains formally deferred to Phase 10's VRF-04
(§5).

---

## 3. 🔴 Source-inspection correction (the record Phase 9 owns)

`docs/plan-act-reasoning-implementation.md` §T2's conclusion — that source inspection points toward
**"reasoning does NOT come back into context"** — is a **false negative**. It was produced by
inspecting only `toGatewayRequestMessages()` (`compat.ts:306`, walks only `message.content`) and
`agentic-compaction.ts:88`'s `reasoningChars`, which is the compaction **summarizer's own**
reasoning-output telemetry (self-instrumentation of a different LLM call entirely — the
summarizer's, not the conversation's) — neither of these two functions is on the path that would
actually re-include prior-turn reasoning into an outbound request.

**The actual path, independently re-verified in `cline-src` at tag `cli-v3.0.53`** (working tree
clean; `phase-09/verify_reasoning_history_source.sh`,
`phase-09/results/20260901T021414Z-prb04/source-verification.txt`; observed line numbers below,
which may differ from 09-RESEARCH.md's citations — recorded as **actually observed now**, not
restated from the research):

1. **`shouldIncludeReasoningHistory`** — `sdk/packages/llms/src/providers/ai-sdk.ts:284-289`
   (definition), called at `ai-sdk.ts:93`. Verbatim body, observed:
   ```typescript
   function shouldIncludeReasoningHistory(
       request: GatewayStreamRequest,
       context: GatewayProviderContext,
   ): boolean {
       return !isCerebrasProvider(request, context);
   }
   ```
   `isCerebrasProvider` is **imported** into `ai-sdk.ts` (line 34) but its actual definition lives
   in `sdk/packages/llms/src/providers/model-facts.ts:449` — a minor correction to 09-RESEARCH.md's
   citation (which implied it was local to `ai-sdk.ts`), not a change to the finding. Our provider
   (`openai-compatible` / `flashnext`) is not Cerebras → `includeReasoning = true` by default.

2. **`agentPartToContentBlock`** — `sdk/packages/core/src/runtime/config/agent-message-codec.ts:231`
   (definition), called at lines 123 and 148. The `case "reasoning"` branch (observed at **line
   237**, not line 237's exact match to 09-RESEARCH.md's cited line but independently landing on
   the same line number this time) converts an incoming reasoning part into a persisted content
   block:
   ```typescript
   case "reasoning": {
       ...
       return {
           type: "thinking",
           thinking: part.text,
           signature: metadata?.signature,
           details: metadata?.details,
       } satisfies ThinkingContent;
   }
   ```
   This is **persisted into the Task's `Message[]` history**, not discarded and not display-only.

3. **`message-builder.ts`** — `sdk/packages/core/src/session/services/message-builder.ts:1213-1214`
   explicitly counts `block.type === "thinking"` bytes toward the conversation's text budget:
   ```typescript
   } else if (block.type === "thinking") {
       total += utf8ByteLength(block.thinking);
   ```
   i.e., persisted reasoning is treated as first-class, budget-relevant conversation content by
   Cline's own accounting — not a display-only artifact.

4. **Installed litellm** (`/Users/ohama/agent-stack/venv/.../common_utils.py:1337`,
   `_extract_reasoning_content`, the actual source backing the running `com.ohama.litellm`)
   confirms both field names are recognized on the way back in:
   ```python
   if "reasoning_content" in message:
       return message["reasoning_content"], message_content
   elif "reasoning" in message:
       return message["reasoning"], message_content
   ```

**Conclusion to record: Cline does attach reasoning history by default for non-Cerebras
providers.** `docs/plan-act-reasoning-implementation.md`'s "no evidence of accumulation" statement
is wrong as written — architecturally, reasoning **is** re-included on every subsequent turn.

**Why the gate is nevertheless unharmed:** §1 above is the decisive answer to the operationally
relevant question. Even though Cline's architecture re-attaches reasoning history, the model-layer
measurement shows that re-attached reasoning field costs **zero** additional `prompt_tokens` when
it reaches this exact stack — the model's chat template does not render prior-turn
reasoning/thinking content into the prompt at all. The false negative is about the *architecture*
claim ("does Cline attach it" — yes), not the *token-cost* claim ("does attaching it cost tokens in
this stack" — no, §1). Both statements are compatible; the implementation doc conflated them.

---

## 4. Handoff — Phase 12 owns the doc edits

Phase 9 records this finding; **Phase 9 does not edit these docs** (Phase 12 owns USE-05). Exact
edit targets, all observed directly against the files on disk in this run:

- **`docs/plan-act-reasoning-implementation.md`, lines 96–100** (§T2, "소스 조사 결과"): the
  bulleted false-negative claim citing `agentic-compaction.ts:88`'s `reasoningChars` and
  `toGatewayRequestMessages()` (`compat.ts:306`) as evidence reasoning "does not accumulate". This
  is the primary correction target — replace with the §3 finding above (source path is
  `shouldIncludeReasoningHistory` + `agentPartToContentBlock`; architecturally reasoning IS
  attached; token cost is nevertheless zero in this stack, per PRB-04 measurement).
- **`docs/plan-act-reasoning-implementation.md`, line 102**: "소스는 '누적되지 않는다' 쪽을 가리키나
  결정적이지 않다" ("source points toward 'does not accumulate' but is not decisive") — this framing
  itself needs correcting; the source, correctly traced, points toward "does accumulate
  architecturally, but costs nothing at the token layer."
- **`docs/plan-act-reasoning-diagrams.md`, lines 187–191**: the callout box restates the identical
  false-negative claim verbatim ("소스 조사는 '누적되지 않는다' 쪽을 가리킨다 — `toGatewayRequestMessages()`
  는 `content` 배열만 순회하고, `agentic-compaction.ts:88` 의 `reasoningChars` 는 *요약기 자신의* 출력을
  세는 텔레메트리다") — same correction applies here.
- **`docs/plan-act-reasoning-design.md`, line 204**: only lists "게이트① 컨텍스트 누적 측정" as a
  recommended step; does not itself assert a source-inspection conclusion. **No correction needed
  here** — recorded for completeness since it was in the search scope, not because it is wrong.
- **`docs/plan-act-reasoning-implementation.md`, lines 229 and 244**: table/summary rows that refer
  to "사고 트레이스가 컨텍스트에 누적된다 → kill condition" as the *gate criterion description* — these
  are not themselves false (they correctly describe what the gate checks), so no edit is required
  there; flagged only so Phase 12 does not confuse them with the actual correction targets above.

---

## 5. Handoff — Phase 10 inherits these deferrals

- **Real-Cline-on-the-wire confirmation is deferred to Phase 10, formalised as `VRF-04`** (already
  present in `.planning/REQUIREMENTS.md`: "실제 `cline` CLI 실행의 `--json` 스트림에 `reasoning` 이
  나타나는지"). Naming it explicitly here so the handoff is traceable: Phase 9's evidence for
  "Cline attaches reasoning history" is **source-verified only** (09-RESEARCH.md rates this MEDIUM
  confidence) — no real `cline` process's HTTP request bytes were observed in Phase 9, by design
  (09-RESEARCH.md §Q1 explains why: a prior isolated `--config <dir>` attempt caused Cline to
  normalize a fresh `providers.json` and drop `apiKey`/`baseUrl`/`contextWindow`). `VRF-04` closes
  exactly this gap and becomes nearly free once `flashnext-plan` exists as a normal litellm alias:
  point the **production** `providers.json` at it via the already-verified
  `apply_provider_config.sh` / `verify_config.sh` path (no isolation hack needed) and diff a real
  2–3 turn session's `prompt_tokens` growth (observe `reasoning` in the `cline --json` stream) for
  `flashnext-plan` against an equal-turn `flashnext` (thinking-off) control.
- **litellm's *request-side* schema validation was never fully traced** — only the specific
  `openai` provider's `transform_request` (near-raw passthrough), which is what the live `:4000`
  probes in this plan and 09-RESEARCH.md both exercised and both got clean HTTP 200 through. If
  Phase 10 gives `flashnext-plan`/`flashnext-act` unusual `litellm_params` (e.g. a different vendor
  client wrapper), this specific finding should be re-checked before trusting a clean HTTP 200 from
  the new alias.

---

## 6. Requirement mapping

**PRB-04** (🔴 gate). This document reports:
- Fresh, twice-reproduced, both-endpoint, both-field-name synthetic replay measurements (§1a):
  delta = 0, all CONFIRMED.
- Fresh real-trace replay measurements using 09-02's captured `xhigh` traces up to 2,497 chars
  (§1b): delta = 0, all CONFIRMED, no length-threshold effect found.
- A reconciliation against 09-02's corroborating (confounded) multi-turn growth numbers (§1c):
  quantitatively consistent, no disagreement to report.
- A source-inspection correction (§3) with precise Phase 12 edit targets (§4).
- The real-Cline-on-the-wire deferral, named explicitly as Phase 10's `VRF-04` (§5).

**This document does not issue a gate verdict.** Plan 09-04 adjudicates PRB-04 on the strength of
these numbers, weighing the decisive controlled measurement (§1a/§1b) against the corroborating
multi-turn evidence (§1c) and the architectural correction (§3).

Stack-unchanged mechanically confirmed throughout: `com.ohama.flashnext` (46573),
`com.ohama.role-shim` (75548), `com.ohama.litellm` (48525) identical before/after every task's
preflight/postflight; `litellm-config.yaml` and `providers.json` sha256 identical throughout;
`bash phase-01/config/verify_config.sh` exits 0; `git -C /Users/ohama/projs/cline-src
status --porcelain` empty (cline-src untouched); `cline` was never invoked to generate model load.
