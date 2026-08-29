# phase-04/fixtures/ — provenance and freeze notice

**FROZEN as of the end of plan 04-01 (wave 1).** Every fixture below is mined from a real
capture — none is hand-invented. Plans 04-02 and 04-03 (wave 2) both run in the same wave and
both read `sandbox_denied.ndjson`; neither may write to this directory. Anything a wave-2 plan
needs from a fixture must be authored here, in this plan, not amended later. NDJSON cannot carry
comments, so provenance for each file lives here instead.

| Fixture | Outcome | Source |
|---|---|---|
| `success_no_tools.ndjson` | `success` | Mined from `phase-01/results/2026-08-29T094459Z-42449/ndjson.log` (the run that actually ended `"finishReason":"completed"` — the `below_trigger` run, per `docs/32k-compaction-policy.md` §3③). Lines taken verbatim: line 1 (`hook_event agent_start`), line 3 (`agent_event usage`), line 13 (`agent_event content_end contentType:"text"`), and the final line (`run_result finishReason:"completed"`). Deliberately NOT mined from `.../2026-08-29T095321Z-44990/ndjson.log` — that capture is the 32K FAILURE run (`finishReason:"error"`, `MAX_KV_SIZE`) and is the source for `context_overflow_32k.ndjson` instead. |
| `sandbox_denied.ndjson` | `sandbox_denied` | `04-RESEARCH.md` Pitfall 3 / "Code Examples" section, verbatim: the `read_files` EPERM entry (`Error reading file: EPERM: operation not permitted, stat '/Users/ohama/.zshrc'`, `"success":false`) and the `run_commands` `Operation not permitted` entry, both against the criterion-3 default target `$HOME/.zshrc` (`/Users/ohama/.zshrc`), wrapped in the real `{"type":"agent_event","event":{...}}` envelope. **Also contains**, per this plan's own must-have, a successful in-sandbox positive control: a `read_files` entry whose query names `SANDBOX_INSIDE_CANARY.txt`, `"success":true`, `result` containing the literal line `INSIDE-SANDBOX-READABLE-OK` (same shape as a real successful `read_files` entry per 04-RESEARCH.md's "Successful tool call" schema — the specific canary filename/content is this plan's own authored positive-control payload, not a verbatim research quote). Final line is a synthesized `run_result finishReason:"completed"` (04-RESEARCH.md Pitfall 3 point 3 confirms `finishReason` stays `"completed"` on this exact run shape — the model itself handles the tool failure gracefully). This is the exact fixture `phase-04/verify_sandbox_via_cline.sh` (plan 04-03) consumes read-only as its offline self-test input; it must never be amended by that plan. |
| `tty_approval_rejected.ndjson` | `tty_approval_rejected` | `04-RESEARCH.md` Pitfall 2, verbatim shapes: the `output":{"error":"Tool \"<name>\" requires approval in a TTY session"}` OBJECT shape (not an array — this is what distinguishes it from the denial/success array shape) for `read_files` and `run_commands`, followed by `{"type":"agent_event","event":{"type":"done","reason":"aborted"}}`, the top-level `{"type":"run_aborted","reason":"external_abort","message":"aborted by another client"}` event, and `run_result finishReason:"aborted"` — all per Pitfall 2's live-reproduced transcript (3 rejected tool-call attempts before self-abort). |
| `context_overflow_32k.ndjson` | `context_overflow_terminal` | Copied verbatim (byte-for-byte) from `phase-01/tests/fixtures/outcome2_server400_nested_real.ndjson` — the real, live-captured nested `event.error.message` shape containing `litellm.BadRequestError ... MAX_KV_SIZE is 32768`, already ending in `{"type":"run_result","finishReason":"error","iterations":19}`. No changes made. |
| `crashed_truncated.ndjson` | `crashed` | Authored for this plan: two valid, well-formed lines (`hook_event agent_start`, `agent_event usage`) followed by a deliberately truncated (non-JSON) trailing line simulating a killed process mid-write, and **no** `run_result` event at all — the defining signature of the `crashed`/inconclusive outcome per this plan's classifier contract. |

## Why `run_start` never appears

`04-RESEARCH.md` Open Question 2: `run_start` was NOT observed in either of this session's two
live captures (only in a separately-captured, possibly version- or flag-dependent example in
`STACK.md`). None of these fixtures include a `run_start` event. The classifier keys off
`run_result` instead, which appeared in every real capture this project has made.

## Freeze rule

Once plan 04-01 completes, this directory is **read-only** for the rest of Phase 4. Plans 04-02
and 04-03 (wave 2) consume these fixtures as-is. If a future plan discovers it needs a fixture
this set doesn't cover, that is a signal to re-open a wave-1-style plan, not to hand-edit a file
here.
