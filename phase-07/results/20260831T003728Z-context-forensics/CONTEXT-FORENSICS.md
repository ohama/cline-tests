# Context Forensics — `telegram-plugin-refactor` and `v-edit-workspace-tests`

Plan: `07-11` (gap closure, wave 11). Purely forensic — zero live bench runs, zero model calls.
All evidence below is quoted or derived from files that already existed under
`bench/runs/20260830T122809Z-phase07-fix/` before this plan started. Raw derived tables:
`token-ladder.tsv`, `compaction-events.tsv` (same directory).

## 1. Per-task verdict table

| task | peak_accepted | peak_attempted | max_overshoot (vs trigger 26100) | compaction_fired? | compaction_skipped? | mechanism | confidence |
| --- | ---: | ---: | ---: | --- | --- | --- | --- |
| `telegram-plugin-refactor` | 21036 | 36155 | 12526 (iter 6) | yes, once, on schedule | no | single oversized tool result arrives in the same turn compaction fires for; compaction fires but doesn't shrink the payload; next real request is 36155 tokens | confirmed |
| `v-edit-workspace-tests` | 30696 | 30843 | 1909 (iter 8, the only *completed* event) | yes, once (iter 8), then refuses 4 more times | yes, iters 9/10/11/12 | one non-reducing compaction, then a permanent "skipped" guard lets the prompt creep past the wall over 4 more turns, entangled with one unrelated METAL/OOM failure+retry | confirmed |

(`max_overshoot` above is `tokensBefore − triggerTokens` from `compaction-events.tsv`, i.e. cline's
own internal token estimate at the moment compaction ran — not the server's real tokenizer count.
See §4 for why these two counting systems disagree and by how much.)

## 2. Per-task narrative

### 2.1 `telegram-plugin-refactor`

**Ladder (`token-ladder.tsv`, `task=telegram-plugin-refactor`):** 6 accepted requests
(2861 → 4186 → 12848 → 17848 → 21036 → 330), then 1 rejection. Every accepted-row count matches
`grep -c 'Generation queued' .../telegram-plugin-refactor.flashnext.err.txt` = 6 (verified).
`peak_accepted_prompt_tokens = 21036` (request `82ebd2ff50`, server-log line 93), which equals the
`max_prompt_tokens` field already recorded in `meta/telegram-plugin-refactor.json` — that field is
**not** an undercount for this task once you also read the seq-6 row correctly; the ledger's
21036 genuinely was the accepted peak, exactly as `run_task.sh`'s grep found.

The undercount is in the *fatal* request, which the grep-based ledger construction cannot see
because the server never queues a rejected generation. Server log line 168 (verbatim):

```
2026-08-31 02:07:35,961 - WARNING - Request failed: endpoint=/chat/completions
model=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4 stream=True
error=Request needs 38203 context tokens (36155 prompt + 2048 max generation), but MAX_KV_SIZE is
32768. in_flight=0
```

So `peak_attempted_prompt_tokens = 36155` — 15,119 tokens above the accepted peak the ledger
reports, and the true request the model server actually evaluated (and rejected) at the moment the
task died.

**What produced the extra ~15K tokens in one turn?** Cross-referencing `agent/cline.txt`
(iteration 5, lines 159–172): the assistant's iteration-5 tool calls were two `read_files` calls —
one reading **six entire files** of `plugins/gopher-ai/src` (`index.ts`, `service.ts`,
`contract.ts`, `client.ts`, `utils.ts`, `README.md`) with no line-range limit, and one reading a
140-line tail slice of `plugins/_template/LLM.txt`. Their tool-output payload sizes
(`content_end` events, line 170 and line 172): **42,081 chars (≈10,520 tokens)** for the gopher-ai
dump and **4,976 chars (≈1,244 tokens)** for the LLM.txt tail — combined ≈11,764 tokens added in a
single iteration, by far the largest single-turn addition in the whole trajectory (every earlier
iteration added 1,300–8,700 tokens). This lines up arithmetically with the jump from 21036
(accepted peak) to 36155 (fatal attempt): 21036 + ~11,764 + conversation/formatting overhead ≈
32,800–36,155, consistent within the margin expected from a char/4 token estimate versus the
model's real tokenizer.

**Did compaction fire, fire late, or refuse?** It fired exactly once, on schedule, and on time.
`cline.txt` line 175 (`ts=2026-08-30T17:07:26.188Z`): `phase=started, iteration=6,
triggerTokens=26100, targetTokens=18270, maxInputTokens=29000`. This is 8ms after iteration 6
began — i.e. compaction ran *before* the fatal request was ever sent, not after a failure. Line 176
(`ts=2026-08-30T17:07:35.891Z`): `phase=completed, tokensBefore=38626, tokensAfter=49750,
messagesBefore=16, messagesAfter=16`. The compaction step itself is visible in the server log as
its own generation: request `82ebd73b00`, server-log line 130, `prompt_tokens=330 max_tokens=4096`,
decode completing with `generated_tokens=319` at line 165 — timing (queued 02:07:26,177 local =
17:07:26.177Z, 11ms before the "started" notice; decode completes 02:07:35,829, 62ms before the
"completed" notice) and content (the persisted
`agent/sessions/1788109523872_h90ba/1788109523872_h90ba.compaction.json` contains a
`"kind": "compaction_summary"` message whose text is a "Context summary" / Goal / State / Next
digest, generated at `1788109655891` epoch-ms = 17:07:35.891Z, exactly the "completed" timestamp)
together identify this small request unambiguously as the compaction subsystem's own summarization
call, not a fluke or an unrelated in-flight request. This matches `docs/32k-compaction-policy.md`
§5.3's own note that "압축 자체가 요약 호출을 발생시켜 지연을 만든다 (실측: 압축 턴에 요약용 짧은
호출 ~458 토큰이 추가로 발생)" — here it was ~330 in / 319 out, the same phenomenon at a similar
scale.

But `messagesBefore=16, messagesAfter=16` — **no message was removed.** Reading the compaction
JSON directly: `source_message_count: 16`, and the persisted `messages` array is *also* 16 entries,
with entry 0 being the new `compaction_summary` message and entries 1–15 being the **original,
unpruned** conversation, including the 42,081-char gopher-ai dump verbatim at index 14 (42,196
chars in the stored record — the ~115-char difference is JSON-escaping overhead, not a discrepancy
in content). Summing the character length of all 16 persisted messages gives 135,682 chars ≈ 33,920
approximate tokens — already close to the real 36,155-token fatal count. In other words: the
compaction call *ran*, produced a correct-looking summary, and cline logged it as "completed" — but
the actual message array that gets sent to the model on the next turn was not shortened. It grew
(the notice's own `tokensAfter=49750 > tokensBefore=38626` says as much, in cline's own
bookkeeping), because a summary was added on top of the original, un-pruned history rather than
replacing it.

**Smallest change to the token budget that would have kept every observed request under the
wall (arithmetic only, no recommendation):** the fatal request needed 38,203 total
(`prompt+max_tokens`) against a 32,768 ceiling — short by 5,435 tokens. Even against the *intended*
29,000-token safe ceiling from `docs/32k-compaction-policy.md` §4, the real prompt (36,155) is 7,155
tokens over. No feasible `contextWindow` value alone fixes this while `MAX_KV_SIZE=32768` is fixed,
because the single tool result that caused the jump (~10,520 tokens for the gopher-ai dump) would
need the compaction's *actual pruning*, not just its trigger threshold, to work as advertised. This
is arithmetic only; the remediation decision belongs to 07-14.

### 2.2 `v-edit-workspace-tests`

**Ladder (`token-ladder.tsv`, `task=v-edit-workspace-tests`):** 13 accepted requests, 1
`failed-other` (METAL/OOM), 1 `rejected-maxkv`. Accepted-row count (13) matches
`grep -c 'Generation queued' .../v-edit-workspace-tests.flashnext.err.txt` = 13 (verified).
`peak_accepted_prompt_tokens = 30696` (request `82eaacd220`, server-log line 313), matching
`meta/v-edit-workspace-tests.json`'s `max_prompt_tokens: 30696` exactly — again, not an undercount
for the accepted-peak field itself.

The fatal, never-queued request (server-log line 338, verbatim):

```
2026-08-31 02:24:39,034 - WARNING - Request failed: endpoint=/chat/completions
model=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4 stream=True
error=Request needs 32891 context tokens (30843 prompt + 2048 max generation), but MAX_KV_SIZE is
32768. in_flight=0
```

`peak_attempted_prompt_tokens = 30843` — only **147 tokens** above the accepted peak. This is a
completely different shape of undercount from `telegram-plugin-refactor`: not a 15K-token single
jump hidden behind a rejection, but a task that had already climbed to within 123 tokens of the
32,768 wall (`30843 + 2048 = 32,891`, over by 123) through many small increments.

**A confound the milestone audit's single `fail-context` label does not surface:** at server-log
line 256, 36 seconds after request `82ea9db440` (prompt=30117) was queued, the server logs:

```
2026-08-31 02:22:33,225 - WARNING - Request failed: ... error=[METAL] Command buffer execution
failed: Insufficient Memory (00000008:kIOGPUCommandBufferCallbackErrorOutOfMemory). in_flight=0
```

This is a transient hardware/resource failure, not a context-sizing rejection (classified
`failed-other` in `token-ladder.tsv`, not `rejected-maxkv`). 2.2 seconds later, request
`82ebd23860` is queued with the **identical** `prompt_tokens=30117` (server-log line 287) — an
automatic retry of the same content, which this time succeeded. `v-edit-workspace-tests` therefore
survived one non-context crash via retry before it ultimately died of the context ceiling on its
next-but-one request. The near-32K prompt size is a plausible reason the OOM happened where it did
(KV-cache memory pressure scales with context length), but this plan found no stored evidence that
directly proves that causal link — flagged as indeterminate in §5.

**Did compaction fire, fire late, or refuse?** Both — fired once, then refused four times running.
`cline.txt` lines 132–133 (`iteration=8`): `started` at `17:19:52.413Z`
(`triggerTokens=26100, targetTokens=18270, maxInputTokens=29000`), `completed` at `17:20:04.469Z`
(`tokensBefore=28009, tokensAfter=48554, messagesBefore=16, messagesAfter=16`). Exactly the same
"completed but not reduced" pattern as `telegram-plugin-refactor`: reading
`agent/sessions/1788110203697_678s2/1788110203697_678s2.compaction.json` directly,
`source_message_count=16` and the persisted `messages` array is again 16 entries (index 0 the new
summary, indices 1–15 the original conversation unpruned, including a 58,881-char message at index
5 — matching the 58,766-char `read_files` tool output at `cline.txt` line 50, reading
`workspace.h`/`workspace.cpp`/`workspace_unit_test.cpp` in full). Summed content length across all
16 persisted messages: 131,190 chars ≈ 32,797 approximate tokens — already over the 29,000 safe
ceiling immediately after compaction reportedly "completed." The compaction's own summarization
call is again visible in the server log at line 140 (`prompt_tokens=321 max_tokens=4096`, queued
`02:19:52,446` = `17:19:52.446Z`, 33ms after the `started` notice), corroborating the same
mechanism identified in `telegram-plugin-refactor`.

Then, for every subsequent iteration, compaction is attempted and immediately skipped:

| iteration | started ts | skipped ts | Δ (ms) |
| --- | --- | --- | --- |
| 9 | 17:20:58.181Z | 17:20:58.181Z | 0 |
| 10 | 17:21:57.224Z | 17:21:57.225Z | 1 |
| 11 | 17:23:37.032Z | 17:23:37.033Z | 1 |
| 12 | 17:24:38.943Z | 17:24:38.944Z | 1 |

Each skip fires within 0–1ms of the "started" notice — this is a synchronous, local decision with
no LLM call involved (unlike the one real compaction, which took ~9.7–12s because it made a model
call). Note that the real prompt right after the one successful compaction (27,173 tokens, the
request queued at server-log line 179, immediately following the `completed` notice) was *already*
above the 26,100 trigger — so the compactor had every numeric reason to fire again at iteration 9,
and didn't. The `skipped` notice's own metadata (`cline.txt` lines 160, 177, 194, 211) carries only
`{kind, reason: "auto_compaction", phase: "skipped", iteration, maxInputTokens}` — `"reason"` here
names the *subsystem*, not a cause; no stored field explains *why* it skipped. Given that
`source_message_count` stayed identical (16) across the one real compaction, a plausible
(unconfirmed) explanation is a same-prefix/no-further-candidate guard: because the prior compaction
did not actually remove any of the 15 original messages, the compactor's next invocation sees
nothing new that crossed whatever boundary it uses to select messages for pruning, and skips rather
than reprocessing the same messages again. **This causal chain (why it skips) is not directly
readable from the stored record and is marked indeterminate below; the fact and consequence of the
skip (allowing the prompt to climb unchecked for 4 more turns) is directly readable and is marked
confirmed.**

**Smallest change to the token budget (arithmetic only):** the fatal request needed 32,891 total
against 32,768 — short by only 123 tokens. This is the narrowest miss of the two tasks by two
orders of magnitude (123 vs 5,435 for telegram). Purely arithmetically, almost any intervention that
shaved off even ~150 tokens somewhere in the last four turns (real compaction, or dropping the
retried-duplicate 30,117-token request's redundant content) would have kept this specific run under
the wall — very different from `telegram-plugin-refactor`, where no small adjustment would have
sufficed. No config recommendation is made here; that is 07-14's job.

## 3. Are these the same phenomenon?

**No — not at the level the milestone audit's shared `fail-context` label implies, though both
share one plausible common defect.**

They differ in the proximate cause the record actually shows:

- `telegram-plugin-refactor` fails because **one iteration's tool output is, by itself, larger
  than the entire safe budget** (~11,764 tokens added in one turn against a ~29,000-token ceiling,
  overshooting the wall by 5,435 tokens on the very next request after compaction "completed").
  The failure is a single large jump.
- `v-edit-workspace-tests` fails because, after one compaction, **every further compaction attempt
  is silently skipped**, and the prompt creeps up gradually over four more turns (27,173 → 29,218 →
  30,117[×2, one OOM retry] → 30,696 → 30,843), missing the wall by only 123 tokens. The failure is
  a slow, multi-turn creep, and it is additionally entangled with one unrelated hardware transient
  (METAL OOM) that the task survived via retry.

What *is* shared, and directly evidenced in both tasks' `.compaction.json` files: the one real
compaction event in each run reports `messagesBefore == messagesAfter == 16` and produces a
persisted message array whose total content size (≈33,920 tokens for telegram, ≈32,797 for v-edit)
is barely smaller than — in telegram's case, essentially equal to — the size before compaction. In
neither captured case did compaction actually shrink the payload sent to the model; it only
prepended a summary on top of an otherwise-intact history. If this pattern generalizes, it would be
one shared underlying defect (compaction not pruning), but it manifests through two different
proximate failure paths (one triggered by a subsequent oversized tool result, the other by a
downstream skip-guard), which is why the audit's single `fail-context` bucket is doing more
lumping than the evidence supports. This plan does not have a third example to confirm the shared
defect is systemic rather than coincidental to these two captures — see §5.

## 4. The `max_prompt_tokens` measurement artifact

For **both** tasks, the `max_prompt_tokens` field already recorded in `meta/*.json` — 21036 for
`telegram-plugin-refactor`, 30696 for `v-edit-workspace-tests` — is **the true peak of accepted
requests only**, and both values are independently reproducible: `awk`/`grep`-deriving the max
`prompt_tokens` from `Generation queued:` lines in each server-log slice matches the meta field
exactly (verified, see `token-ladder.tsv`). In that narrow sense, the field is correctly computed
for what it measures.

But the field is silent on the request that actually killed the task, because a server-rejected
request is never queued and therefore never appears in the `Generation queued:` grep `run_task.sh`
uses. The **undercount relative to the fatal attempt** is:

| task | ledger `max_prompt_tokens` | true fatal `prompt_tokens` | undercount (delta) |
| --- | ---: | ---: | ---: |
| `telegram-plugin-refactor` | 21036 | 36155 | **15,119** |
| `v-edit-workspace-tests` | 30696 | 30843 | **147** |

The undercount's *size* is wildly different between the two tasks (15,119 vs 147) even though both
are nominally the "same" measurement artifact — this itself is evidence for §3's "different
proximate mechanisms" conclusion, since a metric that undercounts by two orders of magnitude
differently across two tasks is telling you the failures happened at different distances from the
wall, not the same distance.

**Handing forward to 07-12 (classifier audit) by name:** any classifier or dashboard that reads
`max_prompt_tokens` from `meta/*.json` as "the request that killed this task" is wrong for
`telegram-plugin-refactor` by 15,119 tokens and approximately right (147-token gap) for
`v-edit-workspace-tests`. 07-12 should treat `max_prompt_tokens` as a lower bound on the true peak,
not the peak itself, and should look for a `rejected-maxkv` row (or equivalent) if it wants the
real fatal size. This plan does not modify the classifier or the ledger — that is explicitly out of
scope here (07-11 constraints) and 07-12's job.

## 5. Limits of this analysis

- **Why the four `skipped` compactions in `v-edit-workspace-tests` were skipped is not determined.**
  The stored `metadata` on each `skipped` notice contains no cause field beyond the subsystem name
  `auto_compaction`. A same-prefix/no-new-candidate guard is a plausible hypothesis consistent with
  `messagesBefore==messagesAfter` on the one real compaction, but this plan found no artifact that
  states the actual skip predicate. **What would settle it:** the cline CLI's own debug/verbose
  logging for the compaction subsystem (if it exists) capturing the skip decision's inputs, or a
  fresh capture with `--verbose`/debug logging enabled around a similar skip event.
- **Why the real compaction in both tasks reports `messagesBefore==messagesAfter` (no pruning) is
  inferred from message-array evidence, not from cline's own source or a log line that says "did
  not prune."** This plan cross-checked the persisted `.compaction.json` message counts and content
  sizes, which is strong circumstantial evidence, but did not have access to cline's compaction
  implementation source to confirm this is the intended behavior, a bug, or a deliberate "summary
  is additive context, not a replacement" design. **What would settle it:** reading the relevant
  `cline` CLI source (compaction/session-management module) at the pinned version (3.0.53) actually
  used for these runs, which is out of scope for a forensic-evidence-only plan.
- **The tokensBefore/tokensAfter inconsistency across records is noted but not explained.** Three
  different "before" figures appear for the telegram compaction alone: the notice's
  `tokensBefore=38626` (cline.txt line 176), the compaction_summary message's own
  `metadata.tokensBefore=45507` (inside the `.compaction.json`), and the derived ≈33,920 (from
  summing the persisted messages' content length) / real 36,155 (from the server log) for the very
  next request. These may be using different tokenizers, different points in the pipeline, or
  different definitions of "before" (e.g. including vs excluding the newest un-sent tool outputs).
  This plan does not have enough information to reconcile them into one number, and reports all
  three rather than picking one. **What would settle it:** an authoritative definition of each
  field from cline's own source, or a fresh capture instrumenting the tokenizer used at each of the
  three measurement points.
- **cline's own per-message token accounting (the `totalInputTokens` running counter in the
  `usage` events) uses a different tokenizer than the model server (mlx), and the two are not
  reconciled here beyond order-of-magnitude sanity checks (approx `chars/4` vs the server's real
  count).** This plan used the ratio only to build plausibility, not as a precise cross-check.
  **What would settle it:** a capture that logs both cline's estimated prompt token count and the
  server's real count for the *same* request, which the current logs do not co-locate (cline logs
  the response's `inputTokens` after the fact; the server logs `prompt_tokens` at queue time — these
  should be the same number for accepted requests and were spot-checked as consistent for the
  accepted rows, e.g. telegram iteration 5's `usage.inputTokens=21036` exactly matches server-log
  `prompt_tokens=21036` — but no such cross-check is possible for the *rejected* requests, since
  cline logs the resulting error, not an independent token count).
- **Whether the METAL/OOM failure in `v-edit-workspace-tests` was caused by proximity to the 32K
  ceiling (memory pressure) or is unrelated (e.g. a concurrent load spike from another process on
  the host) is not determined.** The timing (occurring at a 30,117-token request, the second-highest
  in the run) is suggestive but not proof. **What would settle it:** host-level memory/GPU
  telemetry captured concurrently with the bench run, which was not being collected at the time.
- **No third `fail-context` example exists in this evidence set to test whether the "compaction
  completes without pruning" pattern is systemic or coincidental to these two captures.** The
  milestone audit records exactly these two genuine context-ceiling deaths among the tasks that
  reached the model server; a third occurrence, if one is ever captured, would substantially
  strengthen or weaken the shared-defect hypothesis in §3.
