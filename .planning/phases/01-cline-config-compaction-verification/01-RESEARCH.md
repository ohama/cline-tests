# Phase 1: Cline 설정 + 압축 검증 - Research

**Researched:** 2026-08-29
**Domain:** Cline CLI 3.0.53 internal compaction mechanics (decompiled from the installed Bun binary) + multi-turn headless test design against a local 32768-token `mlx_vlm.server`
**Confidence:** HIGH on the compaction formula, the compaction gate, the error-recovery classifier, and the `--id`+`--json` bug (all verified either by reading the exact installed binary's decompiled source or by live reproduction). MEDIUM-LOW on whether the `contextWindow`/`maxTokens` override in `providers.json` is actually threaded into the live request path — this is exactly the thing Phase 1's own regression test must settle, and this document hands the planner a design to settle it.

## Summary

This research went straight at the two things STACK.md/SUMMARY.md flagged as unresolved: the real compaction formula in the exact installed `cline@3.0.53`, and a concrete design for a multi-turn regression test. Both are now resolved with direct evidence. The compaction trigger is not the guessed `max(ctx−40000, ctx×0.8)` — the real, decompiled formula is `effectiveMaxInputTokens = maxInputTokens ?? contextWindow×0.9`, `triggerTokens = effectiveMaxInputTokens×0.9`, `shouldCompact = currentRequestTokens ≥ triggerTokens`. With `contextWindow: 32768` and no `maxInputTokens` override, this predicts a trigger at **≈26,542 tokens** — almost exactly where PROJECT.md's guess landed, but for a different, now-verified reason. Critically, compaction is gated by a session-level `compaction.enabled === true` flag that is computed once at task start; the CLI's own flag parser shows this defaults to `true` (strategy `"agentic"`) whenever `--compaction` is not passed, so a plain `cline "prompt"` run should have compaction armed by default.

The single most damaging new finding is that **Cline's own error classifier, which is supposed to catch a context-overflow rejection and force a recovery-compaction retry, uses eight hardcoded regexes plus one error-code string, and none of them match `mlx_vlm.server`'s actual 400 body** (`"Request needs N context tokens (... prompt + ... max generation), but MAX_KV_SIZE is 32768."`). This was checked pattern-by-pattern against the exact text this stack's server has been observed to return. This means the "safety net" outcome ②-is-graceful-restart is optimistic: if the proactive trigger estimate is even slightly late, Cline does **not** recognize the resulting 400 as recoverable and the task simply dies with an unclassified error — there is no second chance. This closes an open question STACK.md left dangling and should change how the planner frames outcome ② in VER-04's documented response.

The second major finding is operational and load-bearing for test design: **`cline --id <session-id> --json <prompt>` is broken in this exact installed version** — reproduced as a 100% failure across every argument order, quoting style, and stdin-piping variant tried. This kills the "resume a session across separate CLI invocations" design STACK.md tentatively proposed. The verified working alternative — proven empirically twice in this session — is to drive context growth entirely **inside a single `cline` invocation** via the agent's own tool-call loop (ask it to `read_files` a sequence of pre-staged filler files one at a time with a one-word acknowledgement after each). This produces one continuous `--json` NDJSON stream with per-iteration `usage` events, sidesteps the `--id` bug entirely, and was measured to add ≈2,300 tokens per 8.8 KB filler file when that file's lines are realistically wrapped (≈100 chars/line) — a pathological single-line file instead gets silently truncated by Cline's own tool-output limiter to ≈650 tokens, so file shape matters and is documented below as a pitfall.

**Primary recommendation:** Build the regression test as one `cline --json` invocation whose prompt instructs the agent to `read_files` 10–12 pre-staged, normally-line-wrapped ≈9 KB filler files in sequence (one word acknowledgement each), parse the resulting NDJSON stream for `agent_event.event.type==="notice"` with `message` starting `"auto-compact"` (outcome ①) vs. an `agent_event.event.type==="error"` whose text matches the known `mlx_vlm.server` 400 shape with no preceding notice (outcome ②), and cross-check both against `~/llm-system/services/logs/flashnext.err`'s `prompt_tokens=` lines for the same time window. Estimated wall-clock for one full run: 5–8 minutes.

## Standard Stack

No new libraries. Everything here is `cline@3.0.53` CLI mechanics plus a Python/bash test harness the planner will write. Per PROJECT.md, no gateway code (litellm/role_shim) may be added — the test is purely observational.

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|---------------|
| `cline` CLI | 3.0.53 exact, `CLINE_NO_AUTO_UPDATE=1` on every invocation | drives the actual agent/compaction logic under test | it's the thing being tested; STACK.md already confirmed the auto-update kill-switch |
| `--json` NDJSON stream | n/a | primary event oracle (usage + compaction notices) | machine-readable, not the TUI progress bar VER-02 forbids |
| `~/llm-system/services/logs/flashnext.err` | n/a | secondary/cross-check oracle (`prompt_tokens=` per request) | server-side ground truth, independent of anything Cline claims about itself |
| Python 3 (stdlib only: `json`, `re`, `subprocess`, `time`) | already installed (3.14.6) | parse NDJSON + log lines, decide ①/②/③ | no new dependency; matches STACK.md's "zero new runtime deps" stance |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `--config <scratch-dir>` | isolate test runs from the real `~/.cline` | use for exploratory/dev iterations of the harness itself; the final regression test that ships probably targets the real `~/.cline` since that's what CFG-01..06 configure |
| filler-file generator script | produce N properly line-wrapped ≈9 KB `.txt` files with deterministic (seeded) content | growth control — see Pitfall "single-line files get truncated" below |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single-invocation tool-call-loop growth (recommended) | `--id` session resume across multiple invocations | **Does not work** in 3.0.53 — verified broken, not a design choice; see Pitfall below |
| Single-invocation tool-call-loop growth | PTY/tmux-driven interactive (`-i/--tui`) multi-turn session | Works in principle (avoids `--id`), but heavyweight to automate reliably and was not needed once the tool-call-loop method was proven — keep as documented fallback only |
| `read_files` on filler files | One giant first user message with ~27k tokens of pasted text | STACK.md already tried this shape and found it inconclusive: a single first message has no prior messages to compact, so it can't distinguish "tried and failed" from "never tried" — confirmed by reading `basic-compaction`'s own doc comment ("newest turns first... everything else dropped") which presumes multiple prior turns exist |

**Installation:** none — everything above is already present on the host.

## Architecture Patterns

### Recommended test-harness structure
```
phase-01-verification/
├── filler/
│   ├── gen_filler.py         # writes wrapped_01.txt .. wrapped_12.txt (~9KB, ~100 chars/line, seeded)
│   └── wrapped_*.txt
├── run_regression.sh         # the single `cline --json` invocation, captures NDJSON to a timestamped file
├── parse_result.py           # classifies ①/②/③ from the NDJSON + flashnext.err
└── results/
    └── YYYY-MM-DDTHHMMSS/
        ├── ndjson.log
        ├── flashnext_window.log   # grepped slice of flashnext.err bracketing the run
        └── verdict.md             # ①/②/③ + policy per VER-04
```

### Pattern 1: Single-invocation, tool-loop-driven context growth
**What:** One `cline --json --timeout <big> --auto-approve true "<prompt>"` call whose prompt asks the agent to read N filler files one at a time via `read_files`, acknowledging each with one word, so the agent's own iteration loop re-sends the whole growing conversation on every iteration — no external resume mechanism needed.
**When to use:** Any time you need Cline to cross a token threshold across "turns" in an automatable, single-process, single-log-stream way.
**Example (prompt template):**
```
Read {file_1}, then {file_2}, ..., then {file_N} one at a time using the
read_file tool (separate tool calls, not in parallel). After reading each
file reply with exactly one acknowledgement word before reading the next.
When all files are read, say DONE.
```
**Verified real output (proof-of-concept run, this session, 3 files, ≈9KB each but pathologically single-line — see Pitfall):**
```json
{"ts":"...","type":"agent_event","event":{"type":"usage","inputTokens":5598,"outputTokens":96,"totalInputTokens":5598,...}}
... (tool call/result for file 1) ...
{"ts":"...","type":"agent_event","event":{"type":"usage","inputTokens":6232,"outputTokens":100,"totalInputTokens":11830,...}}
... (tool call/result for file 2) ...
{"ts":"...","type":"agent_event","event":{"type":"usage","inputTokens":6895,"outputTokens":100,"totalInputTokens":18725,...}}
... (tool call/result for file 3) ...
{"ts":"...","type":"agent_event","event":{"type":"usage","inputTokens":7547,"outputTokens":43,"totalInputTokens":26272,...}}
{"ts":"...","type":"run_result","finishReason":"completed","iterations":4,...}
```
Note: `inputTokens` per iteration is the **size of that single fresh request** (system prompt + full history so far + tools), not a running total — `totalInputTokens` is the separate cumulative-cost field. The per-iteration `inputTokens` is what should be compared against the ≈26,542 trigger.

### Pattern 2: Compaction-notice detection in the NDJSON stream
**What:** Cline's internal `AgentRuntime` translates its compaction lifecycle into `status-notice` events, which the CLI's event translator turns into a `notice`-typed `agent_event`. This is the exact, decompiled shape (function names are minifier-assigned, logic is verbatim):
```js
// createContextCompactionPrepareTurn's returned closure, decompiled from bin/.cline:
let m = c.overflowRecovery ? "overflow_recovery" : mode;         // "auto" | "manual" | "overflow_recovery"
let f = resolveEffectiveMaxInputTokens(c.model.info) ?? 128000;  // effective budget
let k = f * 0.9;                                                 // triggerTokens (COMPACTION_TRIGGER_RATIO)
let w = requestInputTokens >= k;                                 // shouldCompact
if (mode === "auto" && !w) return;                                // skip: not yet at threshold
// ... on proceeding to compact:
emitStatusNotice(`${prefix}compacting`, {kind, reason, phase:"started", iteration, triggerTokens:k, targetTokens, maxInputTokens:f});
// ... after compaction runs:
emitStatusNotice(`${prefix}compacted`, {kind, reason, phase:"completed", iteration, tokensBefore, tokensAfter, messagesBefore, messagesAfter, maxInputTokens:f});
```
where `prefix` is `"auto-"`, `"overflow-recovery-"`, or `""` (manual). The CLI's event translator turns each `status-notice` into:
```json
{"type":"agent_event","event":{"type":"notice","noticeType":"status","displayRole":"status","message":"auto-compacting","reason":"auto_compaction","metadata":{"kind":"auto_compaction","phase":"started","iteration":N,"triggerTokens":26542,"maxInputTokens":29491,...}}}
```
followed later by a `message:"auto-compacted"` event carrying `tokensBefore`/`tokensAfter`/`messagesBefore`/`messagesAfter`. There is also a distinct human-readable summary generator (used by the TUI/webview transcript) that produces exactly the format previously observed in an earlier session ("Context compacted · 115.3k → 62.2k tokens · 140 → 103 messages") — decompiled verbatim:
```js
function summaryLine(j) {
  if (j.status === "failed") return "...";
  if (j.status === "cancelled") return "Compaction cancelled";
  if (j.status === "skipped") return "Compaction skipped";
  let G = [j.compactionMode === "manual" ? "Context compacted (manual)"
         : j.compactionMode === "inherited" ? "Compacted working context carried over"
         : "Context compacted"];
  if (typeof j.tokensBefore === "number" && typeof j.tokensAfter === "number")
    G.push(`${fmt(j.tokensBefore)} → ${fmt(j.tokensAfter)} tokens`);
  if (typeof j.messagesBefore === "number" && typeof j.messagesAfter === "number")
    G.push(`${j.messagesBefore} → ${j.messagesAfter} messages`);
  ...
}
```
**Test decision rule:** `grep` the NDJSON for `"noticeType":"status"` AND `message` starting with `"auto-compact"` → outcome ①. If absent and the run instead ends in an `agent_event.type==="error"` whose message matches the known 400 shape → outcome ②. Anything else (crash, timeout, unexpected tool error, `"overflow-recovery-compact"` notice appearing — see Pitfall below on why that's unlikely but not impossible) → outcome ③.

### Anti-Patterns to Avoid
- **Relying on `--id` to resume a session across separate `cline` invocations for multi-turn growth.** Confirmed broken in 3.0.53 (see Pitfall). Use the single-invocation tool-loop pattern instead.
- **Growing context by asking the model to *generate* a lot of text.** At 17 tok/s and 32K TTFT of 64.3s, a test that waits on model-generated bulk content is needlessly slow (≈20 min class). Growth should come from tool-call inputs (files), not model outputs — cap `maxTokens`/ask for one-word replies.
- **Using a single giant first user message to test compaction.** Already tried by STACK.md and confirmed inconclusive — there's nothing for the compactor to "cut" on iteration 1 if there's only one message.
- **Trusting `~/.cline/data/settings/providers.json` to still contain your override after several `cline` invocations without re-reading it.** See Pitfall "config fragility" below.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detecting whether compaction fired | A custom heuristic on message counts before/after | Grep the NDJSON `notice`/`status-notice` events (`message` starting `"auto-compact"`) — this is Cline's own, already-emitted, structured signal | It's already there, verbatim, with `tokensBefore`/`tokensAfter`/`triggerTokens` fields; no need to infer anything |
| Per-request token ground truth | A token-counting shim added to `role_shim.py` or litellm | `~/llm-system/services/logs/flashnext.err`'s `prompt_tokens=`/`Request completed:` lines, already logged by the running `mlx_vlm.server`, zero new code | PROJECT.md forbids new gateway code; the log line already exists and was verified live in this session |
| Growing context by a controlled amount | Asking the model to write long text, or trying to hand-craft exact token counts | `read_files` on pre-generated filler files with normal line wrapping; measured empirically at ≈2,300 tokens per 8.8 KB file | Deterministic, cheap (near-zero generation cost), and the exact per-file token contribution was measured directly on this stack, not assumed |

**Key insight:** Everything the test needs to distinguish ①/②/③ is either (a) already emitted by Cline's own `--json` stream in a documented, stable shape, or (b) already logged by the existing, unmodified `mlx_vlm.server`. The regression test is a parser + orchestrator over signals that already exist, not new instrumentation.

## Common Pitfalls

### Pitfall 1: `--id <session-id>` + `--json` is broken for headless multi-turn resume
**What goes wrong:** `cline --config <dir> -P openai-compatible --id <sid> --json --auto-approve true "<prompt>"` fails 100% of the time with `{"type":"error","message":"JSON output mode requires a prompt argument or piped stdin (interactive mode is unsupported)"}`, regardless of whether the prompt is positional, quoted, piped via stdin, placed before/after `--id`, given as `--id=value`, combined with `-z`/`--zen`, or given with a real, pre-existing session ID obtained from `cline history --json`. Without `--json`, `--id` instead demands a TTY (`error: interactive mode requires a TTY`).
**Why it happens:** Empirically confirmed, root cause not fully traced in the decompiled source within this research's budget — but the failure is total and consistent enough (5+ independent argument-order/form variants tried) to treat as a confirmed CLI defect in this exact build, not user error.
**How to avoid:** Do not design the regression test around resuming a session across multiple `cline` process invocations. Use the single-invocation, tool-call-loop pattern (Architecture Pattern 1 above) instead — proven working, twice, in this session.
**Warning signs:** If the planner's test script sees this exact error message, this is the known bug, not a config mistake — don't spend time debugging argument order further.

### Pitfall 2: Cline's overflow-recovery error classifier will not recognize this stack's 400
**What goes wrong:** Cline has a genuine "if the provider rejects a request as context-overflow, force a compaction and retry" recovery path (`generateAssistantMessageWithOverflowRecovery` / `isRecoverableOverflowTurn`). It classifies an error as `context_window_exceeded` only if (a) the HTTP status is one of `{400,413,422}` **and** (b) either the error carries the literal code `"context_length_exceeded"`, or the message matches one of these 8 hardcoded regexes (decompiled verbatim):
```js
[
  /\bcontext\s*(?:length|window|limit)\b/i,
  /\bmaximum\s*context\b/i,
  /\b(?:input\s*)?tokens?\s+exceeds?\b/i,
  /\btoo\s*many\s*tokens?\b/i,
  /\binput\s+is\s+too\s+long\b/i,
  /\bprompt\s+is\s+too\s+long\b/i,
  /reduce\s+the\s+length\s+of\s+the\s+messages\s+or\s+completion/i,
  /requested\s+input\s+length\s+.*exceeds\s+.*maximum/i,
]
```
`mlx_vlm.server`'s actual body — `"Request needs 36367 context tokens (34319 prompt + 2048 max generation), but MAX_KV_SIZE is 32768."` — was checked against every one of these 8 patterns and the `context_length_exceeded` code. **None match.** ("context tokens" ≠ "context length/window/limit"; no word "exceed(s)" anywhere in the message; no "too long" phrase; no "reduce the length" phrase.)
**Why it happens:** The classifier's pattern list was written against OpenAI/Anthropic/vLLM-style error phrasing; `mlx_vlm.server`'s own custom `PromptTooLongError` text was never one of the phrasings anyone tuned this against.
**How to avoid:** Nothing to build (gateway changes are out of scope per PROJECT.md) — but the planner must **document this explicitly** as the reason outcome ② is a genuine dead end, not a soft landing: if the proactive ~26,542-token trigger doesn't fire in time, Cline will not self-heal via overflow-recovery on this stack, and the task simply errors out. This directly informs VER-04's "response policy" documentation requirement — the policy for outcome ② should say "user must start a new task," not "Cline will recover automatically."
**Warning signs:** An `agent_event.type==="error"` in the NDJSON stream with the `PromptTooLongError`/`MAX_KV_SIZE` text, with no preceding or following `"overflow-recovery-compact*"` notice — confirms the classifier missed it, exactly as predicted here.

### Pitfall 3: filler-file shape determines whether growth is real or silently truncated
**What goes wrong:** Two proof-of-concept runs in this session used near-identical file sizes (≈9KB) but very different content shape:
- **Single very long line** (no newlines in the body): the tool result was silently cut short mid-line with a literal `"[line truncated]"` marker, and each file contributed only ≈630–660 tokens to the conversation regardless of its actual byte size.
- **Normal line wrapping** (~12 words / ~100 chars per line, 120 lines): no truncation marker appeared, and each ≈8.8KB file contributed the full ≈2,300 tokens (measured directly from consecutive `usage.inputTokens` deltas: 5591→7894→10226).
**Why it happens:** Cline's tool-output layer applies a per-line (not strictly per-file) output cap, most likely part of the `extensions/tools/executors/output-limits` module found in the installed package's type declarations — a defensive measure against pathological single-line/minified files blowing up context from one tool call.
**How to avoid:** Generate filler files with realistic line lengths (60–100 chars/line). Do not generate one giant line of filler text, even if the total byte count looks right — it will not translate to the token count you expect.
**Warning signs:** A `read_files` tool result containing the literal string `"[line truncated]"` — if you see this, your filler file's per-file token contribution is being silently capped and your growth-rate math is wrong.

### Pitfall 4: `providers.json`'s `maxTokens` override for output-token capping is not proven to work
**What goes wrong:** CFG-03 needs `max_output_tokens ≤ 8192` enforced so a short prompt can't 400 on turn one. Two things were tried and both showed the configured value was **not honored**: (a) `models[].maxTokens: 512` in the `openai-compatible` provider's `models[]` array — the server-side log (`flashnext.err`) showed the outgoing request still carrying `max_tokens=2048` on every subsequent turn; (b) a top-level `settings.maxTokens: 77` on the same provider entry — a later probe run under this config generated **1,228 output tokens** before stopping (`finish_reason=stop`, not `length`), i.e., no output cap was applied at all in that run.
**Why it happens:** Not fully root-caused in the time available. The provider-settings schema does map `maxTokens` → `maxOutputTokens` → the wire `max_tokens` parameter in the decompiled param-mapping code (`COMMON_PARAM_MAPPINGS`), so the field name and mapping exist — but something else (a session/task-level default, a different code path for single-model `openai-compatible` providers vs. the multi-model `models[]` array, or config-file staleness — see Pitfall 5) appears to override or bypass it in practice.
**How to avoid:** Do not assume CFG-03 is satisfied just because `providers.json` contains the field. The Phase 1 implementation must include an explicit verification step: configure the value, run one real request, and grep `flashnext.err`'s `Generation queued: ... max_tokens=<n>` line for that exact request to confirm the configured cap actually reached the server. If it doesn't, this needs its own investigation task (possibly: set it in both the top-level settings **and** the `models[]` entry; check whether `cline auth`'s own flags/TUI settings screen has a dedicated max-tokens control not discovered here; or accept that CFG-03 may require a different mechanism than a `providers.json` field in this version).
**Warning signs:** `flashnext.err` showing `max_tokens=2048` (or any value other than what you configured) regardless of what's in `providers.json`.

### Pitfall 5: `providers.json` custom fields may not survive across invocations
**What goes wrong:** A `models[]` array manually added to the `openai-compatible` provider's settings was present immediately after being written, but was observed to be **absent** from the same file a few `cline` invocations later, with no explicit removal performed by this research.
**Why it happens:** Not root-caused (could be schema-driven stripping of unrecognized/unexpected shapes on a config rewrite, could be an artifact of how the CLI persists settings after certain subcommands). Not enough evidence to say this always happens, only that it was observed to happen at least once in this session.
**How to avoid:** Whatever config-writing task the planner builds for CFG-01..04, add a verification step that **re-reads `providers.json` immediately before and after every actual test run** (a two-line `cat`+`grep`/`jq` check) rather than trusting that a value written once stays written. This should be baked into the regression test itself, not just the initial setup task, since the test's validity depends on the override still being in place when the test executes.
**Warning signs:** `providers.json` missing fields your setup task wrote, discovered only when a downstream behavior (like the compaction threshold, or the max-tokens cap) doesn't match what you configured.

### Pitfall 6: the 3.0.53 CLI has no "Compact Prompt" setting — CFG-04 may need rescoping
**What goes wrong:** CFG-04 asks to verify "Compact Prompt" is enabled. Exhaustive string-search of the decompiled CLI binary (`strings` over the entire 87 MB Bun-compiled executable, ~300k extracted strings) found **zero occurrences** of `"Compact Prompt"`, `compactPrompt`, `"Focus Chain"`, or `focusChain` anywhere. The CLI's own interactive TUI settings menu — found directly in the binary as a literal list of toggle definitions — has exactly four items: `"Compaction"`, `"Auto-approve all"`, `"Auto update"`, `"Verbose"`. There is no fifth "compact prompt" toggle. Public Cline documentation/blog content describes "Use Compact Prompt" as living in **"Cline Settings → Features"**, which (combined with its complete absence from the CLI binary) is almost certainly the **VS Code extension's** settings panel, not a CLI feature at all.
**Why it happens:** "Compact Prompt" and "Focus Chain" both appear to be VS-Code-extension-only features (the extension and the CLI are built from the same monorepo but are materially different products with different feature sets). This project runs exclusively on the CLI (`cline kanban`, `cline connect telegram`, headless wrapper) — none of these ever load the VS Code extension.
**How to avoid:** Flag this to the user/planner explicitly before building a CFG-04 verification task around a setting that may not exist to be verified. Options: (a) treat CFG-04 as N/A for the CLI-based architecture and document why, (b) do one more targeted check — actually open the interactive TUI (`cline --tui`, requires a real TTY, e.g. via `tmux`) and look for a Compact-Prompt-equivalent control not surfaced by string search, or (c) accept that the CLI's baseline system prompt (measured at ≈5,495–5,600 tokens for agentic mode with tools, see below) is simply what it is, with no smaller variant available. This directly affects the ≈26,542-token compaction budget: baseline alone already consumes ~21% of it before any real conversation happens.
**Warning signs:** none — this is a documentation/scoping gap to resolve with the user before writing a task that verifies a setting that may not exist.

## Code Examples

### Non-interactive provider config (already verified in STACK.md, reproduced here)
```bash
CLINE_NO_AUTO_UPDATE=1 cline auth openai-compatible \
  -b http://localhost:4000/v1 \
  -k dummy \
  -m flashnext
```
Produces `~/.cline/data/settings/providers.json`:
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
      "updatedAt": "...",
      "tokenSource": "manual"
    }
  }
}
```
**Target fragment to add for CFG-02/CFG-03** (add both the `models[]` entry AND, given Pitfall 4/5, verify empirically after writing — do not assume either form alone is sufficient):
```json
{
  "providers": {
    "openai-compatible": {
      "settings": {
        "provider": "openai-compatible",
        "apiKey": "dummy",
        "model": "flashnext",
        "baseUrl": "http://localhost:4000/v1",
        "models": [
          { "id": "flashnext", "contextWindow": 32768, "maxTokens": 4096 }
        ]
      }
    }
  }
}
```

### The exact compaction constants (decompiled, `bin/.cline`)
```js
// var names are minifier-assigned; these are the literal values, confirmed
// to match @cline/core's published .d.ts constant names exactly:
const DEFAULT_MAX_INPUT_TOKENS = 128000;      // fallback when no model info at all
const CONTEXT_WINDOW_INPUT_RATIO = 0.9;       // used when only contextWindow is known
const COMPACTION_TRIGGER_RATIO = 0.9;         // trigger = effectiveMaxInputTokens * this
const DEFAULT_TARGET_RATIO = 0.7;
const DEFAULT_PRESERVE_RECENT_TOKENS = 20000;
const DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS = 4096;
const TOOL_RESULT_CHAR_LIMIT = 2000;
const FILE_CONTENT_CHAR_LIMIT = 2000;

function resolveEffectiveMaxInputTokens({ contextWindow, maxInputTokens }) {
  const cw = isPositiveFinite(contextWindow) ? contextWindow : undefined;
  const mit = isPositiveFinite(maxInputTokens) ? maxInputTokens : undefined;
  if (mit !== undefined) return cw === undefined ? mit : Math.min(mit, cw);
  return cw === undefined ? undefined : cw * CONTEXT_WINDOW_INPUT_RATIO;
}

// Inside createContextCompactionPrepareTurn's returned per-iteration callback:
function shouldCompactThisIteration(currentRequestInputTokens, modelInfo) {
  const effectiveMax = resolveEffectiveMaxInputTokens(modelInfo) ?? DEFAULT_MAX_INPUT_TOKENS;
  const triggerTokens = effectiveMax * COMPACTION_TRIGGER_RATIO;
  return currentRequestInputTokens >= triggerTokens;
}
```
**With `contextWindow: 32768` and no `maxInputTokens` override:**
```
effectiveMaxInputTokens = 32768 * 0.9 = 29491.2
triggerTokens            = 29491.2 * 0.9 = 26542.08  →  ≈ 26,542 tokens
```
**Prediction: outcome ① (proactive compaction) at ≈26,542 tokens, IF the `contextWindow: 32768` override actually reaches `c.model.info.contextWindow` at request time.** This is the one link this research could not 100% close (see Open Questions) — the provider-registry merge function (`s5e`, decompiled) does show a user's `providers.json` `models[]` entry with a matching `id` fully replacing the catalog/fallback entry by the same id, which is the mechanism that *should* make the override win over the 128k-fallback bug — but Pitfall 4/5 (config fragility, unverified `maxTokens` plumbing) mean this must be confirmed empirically, not assumed, exactly as PROJECT.md already anticipated.

**If the override does NOT reach the model info** (128k fallback wins instead): `effectiveMaxInputTokens = 128000 * 0.9 = 115200`, `triggerTokens = 115200 * 0.9 = 103,680` — i.e., compaction would not even be attempted until far past the point the server 400s at 32,768. This is the failure mode PROJECT.md originally worried about, restated with exact numbers from the real code instead of a guessed formula.

### The `--compaction` CLI flag's actual default (decompiled)
```js
// commander.js option handler for --compaction <mode>:
function parseCompactionFlag(value) {
  if (value === undefined) return { enabled: true };        // <-- no flag passed => enabled by default
  if (value === "off")     return { enabled: false };
  return { enabled: true, strategy: value };                 // "agentic" | "basic"
}
```
Combined with the global-settings schema's `compactionStrategy` defaulting to `"agentic"` on parse failure/absence, a plain `cline "prompt"` invocation (no `--compaction` flag) should run with `compaction: { enabled: true, strategy: "agentic" }` — i.e., **compaction is armed by default**, no explicit opt-in needed for the regression test.

### Server-side oracle: real log lines from `~/llm-system/services/logs/flashnext.err`
```
2026-08-29 16:15:03,135 - INFO - Generation queued: request=111ade240 prompt_tokens=303 max_tokens=256 images=0 audio=0 videos=0
2026-08-29 16:15:03,161 - INFO - Prefill started: request=111ade240 backend=continuous_batching prompt_tokens=303 images=0 audio=0 videos=0
2026-08-29 16:15:05,630 - INFO - Prefill completed: request=111ade240 prompt_tokens=303 cached_tokens=0 elapsed=2.456s rate=123.4 tok/s
2026-08-29 16:15:06,905 - INFO - Request completed: endpoint=/chat/completions model=.../Qwen3.8-Flash-Next-MLX-oQ4 stream=False backend=continuous_batching prompt_tokens=303 generated_tokens=54 elapsed=3.777s prefill=123.4 tok/s decode=43.0 tok/s finish_reason=tool_calls in_flight=0
```
Note: the useful lines are in `flashnext.err`, **not** `flashnext.log` (the latter is nearly empty in this deployment — application logging goes to stderr). The single best line per request for the regression test's parser is `Request completed: ... prompt_tokens=<n> generated_tokens=<n> ... finish_reason=<reason>`.

### Verified NDJSON growth trace (real run, this session — the working multi-turn pattern)
```
iteration 1 usage.inputTokens = 5598   (baseline: system prompt + tool schemas + first user message)
iteration 2 usage.inputTokens = 6232   (+634, after reading a truncated single-line filler file)
iteration 3 usage.inputTokens = 6895   (+663)
iteration 4 usage.inputTokens = 7547   (+652)
run_result.usage.inputTokens (final iteration) = 7547; totalInputTokens (cumulative cost) = 26272
```
And with properly line-wrapped files (no truncation):
```
iteration 1 usage.inputTokens = 5591
iteration 2 usage.inputTokens = 7894   (+2303, one 8.8KB properly-wrapped file, no truncation)
iteration 3 usage.inputTokens = 10226  (+2332, second 8.8KB file)
```

## State of the Art

| Old Approach (STACK.md/PROJECT.md guess) | Corrected (this research, decompiled source) | Impact |
|---|---|---|
| `max(ctx − 40000, ctx × 0.8)` → 26,214 at ctx=32768 | `(ctx × 0.9) × 0.9` → 26,542 at ctx=32768 | Nearly the same number, now backed by the actual formula instead of a guess carried over from an old GitHub issue thread about a different Cline version |
| "A clean 400 is an acceptable failure mode; Cline can recover" | Cline's overflow-recovery classifier does **not** recognize this stack's specific 400 text — no automatic recovery happens | Outcome ② must be documented as "task dies, user restarts," not "Cline self-heals" |
| "`--id` should let us resume a session for multi-turn testing" (STACK.md's tentative plan) | Confirmed broken in this exact build | Test design pivots to single-invocation tool-loop growth |

## Open Questions

1. **Does `contextWindow: 32768` in `providers.json`'s `models[]` actually reach `c.model.info.contextWindow` at compaction-check time?**
   - What we know: the provider-registry merge function (`s5e`) shows a user config `models[]` entry with a matching `id` fully replacing whatever the catalog/128k-fallback produced for that same id — mechanically, this *should* make the override win.
   - What's unclear: whether this merge function is actually on the code path that supplies `model.info` to the compaction-trigger check (`Uv`/`createContextCompactionPrepareTurn`), versus a different, lower-level `@cline/llms` resolution path (the one STACK.md originally cited at `compat.ts:629`) that might not consult `providers.json`'s `models[]` at all for a single-model `openai-compatible` provider.
   - Recommendation: this is precisely what Phase 1's regression test settles empirically — run it, and if the observed trigger point (from the `notice` events' `triggerTokens` field) is ≈26,542 rather than ≈103,680, the override worked; if the task instead runs unbounded toward 32,768 with no notice, the fallback won.

2. **Why doesn't `providers.json`'s `maxTokens` field cap the outgoing `max_tokens`?**
   - What we know: two different empirical attempts (nested in `models[]`, and top-level on the provider settings) both failed to change the observed server-side `max_tokens` value.
   - What's unclear: whether there's a different, undiscovered config surface for this (a CLI flag not found in `--help`, a global setting, a TUI-only control), or whether this genuinely doesn't work via `providers.json` in 3.0.53 at all.
   - Recommendation: treat CFG-03 as needing its own small investigation/verification task in the plan, with an explicit "confirm via `flashnext.err`'s `max_tokens=`" acceptance check — don't let CFG-03 be marked done just because a JSON field was written.

3. **Does "Compact Prompt" (CFG-04) exist at all for the CLI?**
   - What we know: zero string matches for "Compact Prompt"/"Focus Chain" anywhere in the compiled CLI binary; the CLI's own TUI settings menu has 4 toggles, none of them this one; public docs describe it as living in "Cline Settings → Features" (VS Code extension UI).
   - What's unclear: 100% certainty requires actually opening the interactive TUI (needs a real TTY, e.g. via `tmux -c` or similar) to visually confirm there is no fifth settings screen not captured by string search of the compiled binary's literal labels.
   - Recommendation: surface this to the user before building a CFG-04 task; likely resolution is to mark CFG-04 as "not applicable to the CLI architecture, documented" rather than spending a task trying to toggle a setting that may not exist outside the VS Code extension.

4. **Root cause of the observed `providers.json` field disappearance (Pitfall 5) — config-write timing, schema stripping, or something else?**
   - What we know: it happened at least once in this session, without an explicit edit removing it.
   - What's unclear: the exact trigger (which specific `cline` subcommand/internal save path caused it).
   - Recommendation: not worth root-causing further given effort/impact — just make the regression test defensively re-verify config state immediately before it runs, every time.

## Sources

### Primary (HIGH confidence — direct decompilation/execution on this exact machine, this session)
- `strings -a /opt/homebrew/lib/node_modules/cline/bin/.cline` (87 MB Bun-compiled binary, `cline@3.0.53`, currently installed) — full-binary string extraction, cross-referenced against `@cline/core@0.0.73`'s published `.d.ts` files (same npm dependency tree) to confirm minified constants/functions match documented names exactly (`DEFAULT_MAX_INPUT_TOKENS`, `CONTEXT_WINDOW_INPUT_RATIO`, `COMPACTION_TRIGGER_RATIO`, `DEFAULT_TARGET_RATIO`, `DEFAULT_PRESERVE_RECENT_TOKENS`, `DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS`, `TOOL_RESULT_CHAR_LIMIT`, `FILE_CONTENT_CHAR_LIMIT`)
- `/opt/homebrew/lib/node_modules/cline/node_modules/@cline/core/dist/extensions/context/{compaction,agentic-compaction,basic-compaction,compaction-shared}.d.ts` — type declarations confirming the compaction module's public shape (implementation is compiled directly into the Bun binary; not shipped as separate `.js` in this npm package)
- Live reproduction, this session: `cline --config <scratch> -P openai-compatible --json --auto-approve true "<prompt>"` (multiple runs) against the real, running `flashnext`/`:4000` production endpoint — captured real NDJSON streams, real `usage` growth, the `--id`+`--json` failure (5+ variants), the single-line-vs-wrapped filler file truncation difference, and the `maxTokens` non-enforcement
- `~/llm-system/services/logs/flashnext.err` — read directly, real production log lines quoted verbatim
- `~/.cline/data/settings/providers.json` (both the real file, read-only, and a `--config`-isolated scratch copy that was actively edited and never touched the real one) — confirmed unchanged before/after this research (`diff` clean)
- `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/research/{SUMMARY,STACK}.md` — authoritative project context, read in full

### Secondary (MEDIUM confidence)
- `docs.cline.bot/cli/cli-reference` (fetched) — confirms `--id`+`--json` *should* work per documentation; contradicted by this session's live reproduction, which is treated as authoritative for "what 3.0.53 actually does" over what the docs claim
- Cline blog "How to Think about Context Engineering in Cline" and web search results (fetched) — source for "Use Compact Prompt" living in "Cline Settings → Features" and disabling MCP/Focus Chain; not independently confirmed against CLI source since the CLI appears not to have this feature at all

### Tertiary (LOW confidence, flagged for validation)
- The exact root cause of `providers.json`'s `models[]`/`maxTokens` fields not taking effect (Pitfalls 4/5) — behavior was reproduced but not traced to a specific line of decompiled source within this research's time budget

## Metadata

**Confidence breakdown:**
- Compaction formula/gate/CLI-flag-default: HIGH — decompiled verbatim from the exact installed binary, constants cross-checked against the published `@cline/core` type declarations for the same version
- Overflow-recovery classifier not matching this stack's error: HIGH — regex-by-regex comparison against the exact, previously-observed real error text
- `--id`+`--json` broken: HIGH — reproduced 5+ ways, 100% failure rate
- Tool-loop multi-turn test design: HIGH — proven working twice, live, this session, against the real production stack
- Whether `providers.json`'s override reaches the live compaction check: MEDIUM-LOW — this is Phase 1's own regression test's job to resolve, not something research could close further without running that exact test
- `maxTokens`/output-cap plumbing (CFG-03): LOW-MEDIUM — reproducibly broken in two tested configurations, root cause unknown
- "Compact Prompt" CLI applicability (CFG-04): MEDIUM-HIGH that it does not exist in the CLI — based on exhaustive negative string search plus corroborating docs language, but not 100% (a live TUI session was not opened)

**Research date:** 2026-08-29
**Valid until:** tied to `cline@3.0.53` specifically — any version drift (this binary self-updates unless `CLINE_NO_AUTO_UPDATE=1` is set on every invocation, per STACK.md §0) invalidates the exact decompiled numbers/behavior above and requires re-verification against the new build.
