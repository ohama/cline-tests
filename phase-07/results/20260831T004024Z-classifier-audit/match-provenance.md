# Match provenance for `HTTP_400_SEEN` / verdict rule

Scope: the four post-fix tasks in `bench/runs/20260830T122809Z-phase07-fix/`
(`discord-trivia-approval-keyerror`, `telegram-plugin-refactor`, `filmarchiver`,
`v-edit-workspace-tests`). All greps below were re-run by this audit directly against the stored
bytes; no value is taken on trust from `meta/*.json`.

## 1. The verdict rule, verbatim

`phase-07/bench/run_task.sh` lines 471-535:

```bash
471: MODEL_TURN_COUNT="$(grep -c 'Request completed:' "$RUN/server-log/$TASK.flashnext.err.txt" 2>/dev/null)"
472: MODEL_TURN_COUNT="${MODEL_TURN_COUNT:-0}"
473: MAX_PROMPT_TOKENS="$(grep -oE 'prompt_tokens=[0-9]+' "$RUN/server-log/$TASK.flashnext.err.txt" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)"
474: MAX_PROMPT_TOKENS="${MAX_PROMPT_TOKENS:-0}"
475:
476: HTTP_400_SEEN=0
477: if grep -qE '\b400\b' "$RUN/server-log/$TASK.flashnext.err.txt" 2>/dev/null; then
478:   HTTP_400_SEEN=1
479: fi
480: if [ -n "${TRIAL_DIR:-}" ] && [ -f "$TRIAL_DIR/agent/cline.txt" ] && grep -qE '\b400\b' "$TRIAL_DIR/agent/cline.txt" 2>/dev/null; then
481:   HTTP_400_SEEN=1
482: fi
...
523: VERDICT="fail-infra"
524: if [ "$HTTP_400_SEEN" -eq 1 ] || [ "$MAX_PROMPT_TOKENS" -ge 32768 ] 2>/dev/null; then
525:   VERDICT="fail-context"
526: elif [ "$REWARD" = "1" ]; then
527:   VERDICT="pass"
528: elif [ "$REWARD" = "0" ] && [ "$MODEL_TURN_COUNT" -gt 0 ] 2>/dev/null; then
529:   VERDICT="fail-task"
530: elif [ "$MODEL_TURN_COUNT" -gt 0 ] 2>/dev/null; then
531:   VERDICT="fail-task"
532: fi
```

Three inputs feed `VERDICT`: `HTTP_400_SEEN` (OR of two `grep -qE '\b400\b'` calls — server-log
slice, then `agent/cline.txt`), `MAX_PROMPT_TOKENS` (max of `prompt_tokens=NNNN` extracted only
from lines matching that literal token, which in practice only appears on `Request completed:` /
`Generation queued:` / `Prefill started|completed:` lines — never on the `Request failed:` /
MAX_KV rejection line itself, which uses a different phrase, "N context tokens (P prompt + G max
generation)"), and `MODEL_TURN_COUNT`.

`grep -q` short-circuits on the first match and never records *which* substring matched — the
mechanism cannot tell a true signal from a false positive by construction. It only reports
"at least one line somewhere in this file contains the three characters 4-0-0 as a whole word."

## 2. Per-task matches against `\b400\b`

### discord-trivia-approval-keyerror

**Server-log target** (`bench/runs/20260830T122809Z-phase07-fix/server-log/discord-trivia-approval-keyerror.flashnext.err.txt`):
3 matches, quoted verbatim with line numbers:

- L128: `2026-08-30 21:31:21,400 - INFO - Prefill progress: request=82ebe334d0 tokens=2048/11912 (17.2%)`
  — **false-positive**. The "400" is the trailing millisecond digits of the log timestamp
  (`21:31:21,400`), not a status code or token count. A vector not named in this plan's own
  hypothesis list, found by direct inspection.
- L308: `2026-08-30 21:35:16,400 - INFO - Prefill progress: request=82ebdde390 tokens=2048/15548 (13.2%)`
  — **false-positive**, same timestamp-millisecond vector as L128.
- L1218: `2026-08-30 21:56:00,221 - INFO - Decode progress: request=82ed511f70 generated_tokens=400 elapsed=24.410s rate=10.5 tok/s`
  — **false-positive**, the predicted `generated_tokens=400` decode-telemetry vector, confirmed real.

None of the three server-log matches is the authoritative MAX_KV_SIZE rejection (see §3 below —
that line contains no bare `400` at all). **Every server-log match for this task is a
false positive.**

**`agent/cline.txt` target**
(`bench/runs/20260830T122809Z-phase07-fix/jobs/discord-trivia-approval-keyerror/01k7a12sd1nk15j08e6x0x7v9e-disco__mp6a7pB/agent/cline.txt`):
6 matches:

- L53: `..."path":"/app/Live/bot/database_module.py","start_line":300,"end_line":400}...` — **false-positive**, a tool-call argument (file line range 300-400 the agent asked to read), not a status code.
- L64: `..."result":"300 |                 \"\"\"` (a `readFile` result echoing source lines 300-400, header string contains `300-400`) — **false-positive**, same tool-output vector as L53.
- L777 (x3, litellm retried logging the same line twice into the transcript at adjacent offsets) and L778-779:
  `...estError: OpenAIException - Error code: 400 - {'detail': 'Request needs 33227 conte[xt tokens (31179 prompt + 2048 max generation), but MAX_KV_SIZE is 32768.]'}...`
  — **true-signal**. This is litellm relaying the real MAX_KV rejection (HTTP 400) back to the
  agent, quoting the same numbers (33227/31179/2048) as the authoritative server-log line at
  L1222.

Verdict for this task: `HTTP_400_SEEN=1`, driven by an OR of 3 server-log false positives and a
mix of 2 cline.txt false positives + a genuine true-signal match. The true-signal match exists, so
the `1` is not manufactured out of thin air here — but the server-log check contributed nothing
but noise, and `grep -q`'s all-or-nothing semantics mean this task's `1` would have come out
identical even if the true-signal bytes had never been written.

### telegram-plugin-refactor

**Server-log target** (`.../server-log/telegram-plugin-refactor.flashnext.err.txt`): **0 matches**
(`grep -qE '\b400\b'` finds nothing; independently confirmed with `grep -noE '.{40}\b400\b.{40}'`
returning empty). The real MAX_KV rejection is at L168:
`2026-08-31 02:07:35,961 - WARNING - Request failed: ... error=Request needs 38203 context tokens
(36155 prompt + 2048 max generation), but MAX_KV_SIZE is 32768. in_flight=0` — no bare `400`
present (see §3). For this task the server-log check contributes `0`, correctly.

**`agent/cline.txt` target**
(`.../jobs/telegram-plugin-refactor/01k6zz0nyj31znwsevx4sn6zb2-teleg__KQTna76/agent/cline.txt`):
7 matches:

- L73: `...des('bad request') || message.includes('400')) {...` — **false-positive**, the benchmark
  task's own repository source code (an `if` condition checking for the literal string `'400'`).
- L170 (first hit): `...Error(\`Invalid request: ${data.error}\`, 400, 'Submit search job');...` —
  **false-positive**, repo source, an `ApiError(message, 400, context)` constructor call.
- L170 (second hit, same line, two matches): `...case 400:\n        throw errors.BAD_REQUEST...` —
  **false-positive**, repo source, a `switch` statement branch for HTTP status 400.
- L187-189 (x3, litellm retry duplication as above): `...estError: OpenAIException - Error code:
  400 - {'detail': 'Request needs 38203 conte[xt tokens...]'}...` — **true-signal**, litellm
  relaying the real MAX_KV rejection (same numbers as L168: 38203/36155/2048).

This is the clearest demonstration of the plan's predicted false-positive vector (b): the
benchmark task's own repository source, echoed into the transcript via file-read tool calls,
contains three literal HTTP-400 references that have nothing to do with this run's outcome, and
would have set `HTTP_400_SEEN=1` on their own even with zero real context rejection.

### filmarchiver

Server-log slice is 0 bytes (flashnext never logged a request in this task's wall-clock window —
consistent with `model_turns=0`, `verdict=fail-infra`). `grep -qE '\b400\b'` against an empty file
returns no match: **no match in this file**, correctly `0`.

`agent/cline.txt`: this trial's directory has no `agent/cline.txt`
(`bench/runs/20260830T122809Z-phase07-fix/jobs/filmarchiver/01kbb2wvw29szdjwcs76265t3k-filma__vXrV5kR/agent/`
was not populated with a transcript because the agent never ran) — **no match in this file** (file
absent), correctly `0`. `HTTP_400_SEEN=0` for this task is unambiguously correct; nothing to
adjudicate.

### v-edit-workspace-tests

**Server-log target** (`.../server-log/v-edit-workspace-tests.flashnext.err.txt`): **0 matches** —
`grep -noE '.{40}\b400\b.{40}'` returns empty. The real MAX_KV rejection is at L338:
`2026-08-31 02:24:39,034 - WARNING - Request failed: ... error=Request needs 32891 context tokens
(30843 prompt + 2048 max generation), but MAX_KV_SIZE is 32768. in_flight=0` — no bare `400`
present. Server-log check contributes `0`, correctly.

**`agent/cline.txt` target**
(`.../jobs/v-edit-workspace-tests/01k8mwgj1z6kr0a7q59r6ek2ar-v-edi__b8ZqnXb/agent/cline.txt`):
4 matches, **all true-signal**, no false positives found in this file for this task:

- L212 (x2), L213, L214: `...estError: OpenAIException - Error code: 400 - {'detail': 'Request
  needs 32891 conte[xt tokens (30843 prompt + 2048 max generation), but MAX_KV_SIZE is
  32768.]'}...` — litellm relaying the real MAX_KV rejection (same numbers as L338: 32891/30843/
  2048).

This is the one task among the four where the classifier's `1` is produced entirely by true
signal — no false-positive vector happens to be present in either target file.

## 3. False-negative test: does the authoritative MAX_KV_SIZE line itself contain a bare `400`?

The three server-log rejection lines, quoted in full:

- discord-trivia: `error=Request needs 33227 context tokens (31179 prompt + 2048 max generation), but MAX_KV_SIZE is 32768. in_flight=0`
- telegram: `error=Request needs 38203 context tokens (36155 prompt + 2048 max generation), but MAX_KV_SIZE is 32768. in_flight=0`
- v-edit: `error=Request needs 32891 context tokens (30843 prompt + 2048 max generation), but MAX_KV_SIZE is 32768. in_flight=0`

**No. None of the three contains a bare `400`** (confirmed by direct `grep -oE '\b400\b'` against
each quoted line — no output). The numbers present are context-token totals (33227/38203/32891),
prompt-token counts (31179/36155/30843), a fixed `2048` generation budget, and the `32768`
`MAX_KV_SIZE` ceiling — none of which is `400`.

**Finding: the server-log half of `HTTP_400_SEEN` never detects a real context rejection, in any
of the three tasks where one occurred.** The server log carries no HTTP status code at all for
this endpoint's rejection path (mlx_vlm's own server logs its internal error string, not an HTTP
status line); the `400` bare-word match against the server log is testing for something that
literally cannot appear on the one line that matters. Every real detection in this dataset came
exclusively from `agent/cline.txt`, where litellm (which does speak HTTP and relays
`OpenAIException - Error code: 400`) echoes the rejection into the transcript. This is a genuine,
demonstrated false-negative vector on the server-log grep target specifically — it is not merely
theoretical.

Separately, `MAX_PROMPT_TOKENS` (the second half of the OR) is structurally unable to reach 32768
for a rejected request either: it is extracted only from `prompt_tokens=NNNN`, a token that only
appears on successful `Request completed:`/`Generation queued:`/`Prefill ...:` lines, never on the
`Request failed:` rejection line (which spells the prompt count out in prose:
"(P prompt + G max generation)"). Observed `max_prompt_tokens` values in `meta/*.json`
(30463 / 21036 / 30696) are all comfortably below 32768 even though real prompt sizes at the
moment of rejection were higher (31179 / 36155 / 30843) — confirming this field systematically
under-reports and can never independently trigger `fail-context` for a task whose rejection is its
very first over-budget request. This was not asked for by the plan's must_haves but follows
directly from the same bytes and is recorded here as it changes how much weight `07-13` should put
on this field versus `HTTP_400_SEEN`.

## 4. `make_summary.sh` — does it re-derive verdicts?

**No, it only transcribes.** `phase-07/bench/make_summary.sh` line 150:
`verdict = d.get('verdict', 'unknown')` inside a Python one-liner that reads a single `meta/*.json`
file and prints its fields as a tab-separated row (lines 143-157); the row is written directly into
`summary.md`'s table (line 165-167). The script's own comment at lines 67-69 states this
explicitly: "computed here independently (never re-derives verdict/pass-fail from a transcript,
only reads what run_task.sh already extracted)". Confirmed by reading, not just by the comment: no
grep against `\b400\b`, `MAX_KV_SIZE`, or any transcript file appears anywhere in
`make_summary.sh`. Any defect in `run_task.sh`'s classifier propagates unchanged into every
`summary.md` — there is no independent second check.

## 5. `verify_bench.sh` — B2's allowed-verdict set

`phase-07/bench/verify_bench.sh` lines 144-170 (check B2): every `meta/*.json`'s `verdict` field is
required to be one of `pass|fail-task|fail-context|fail-infra` (line 162); any other string fails
B2. B2 checks **membership in the allowed set only** — it does not check that the labeled verdict
is *correct* for the evidence in that task's own server-log slice or transcript. A task can carry
an incorrect `fail-context` label (via a false-positive `HTTP_400_SEEN`) and B2 will still record
`PASS`, because `fail-context` is a member of the allowed set regardless of why it was assigned.
B2 is a schema/vocabulary check, not a correctness check — it cannot catch the defect this plan is
auditing, and 07-13's fix (if any) will not move B2's needle either way.
