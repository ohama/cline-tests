# phase-11/OPEN-ITEMS.md — disposition of `11-RESEARCH.md`'s four open items

`11-RESEARCH.md` closed with four items it could not settle statically. This document is where
plan `11-04` settles the three that a live probe can answer, and explicitly hands the fourth to
plan `11-05`. Every observed value below is quoted from a run directory under `phase-11/results/`
and can be re-derived by reading the cited artefact directly — nothing here is retyped from memory.

---

## OPEN ITEM 1 (11-RESEARCH.md Q4) — what does `reasoning_effort:"high"` actually do through each alias prefix?

**Question as posed:** does a client-sent `reasoning_effort:"high"` (as leaked by `--thinking
high`) actually 400 at litellm through an `openai/`-prefixed alias, and actually reach the model
server and 500 through a `hosted_vllm/`-prefixed alias, all the way through the real
Cline→litellm→role-shim→model chain — or does something else intercept it first? Both branches
were previously *inferred from source*, never *observed end-to-end*.

**Previously known, and from where:** `howto/thinking-and-reasoning-effort.md` §1 and
`~/local-llm-settings/VALIDATED.md` §4 document that the model server itself 500s on the literal
value `"high"` (`"Supported types are xhigh (default), medium, and low."`) when called directly at
`:8011`. `phase-10/ALIAS-DESIGN.md` §3 shows `reasoning_effort` is absent from
`OpenAIGPTConfig.get_supported_openai_params()`, so litellm's own `UnsupportedParamsError` (HTTP
400) should fire before the model server is ever reached for an `openai/`-prefixed alias
(`flashnext`). Neither had been exercised end-to-end.

**Observed here** (`phase-11/results/20260902T045814Z-openitems/oi1.tsv`, 4 canonical rows; the
original operational failure and its retry are preserved separately, see "A note on retries"
below):

| case | endpoint | model (alias) | reasoning_effort | http_status / exit | what happened |
|---|---|---|---|---|---|
| 1a | `:4000/v1/chat/completions` (curl) | `flashnext-plan` (`hosted_vllm/`) | `"high"` | **HTTP 500** | `litellm.InternalServerError: ... Hosted_vllmException - {"detail":"An unexpected error occurred: Unexpected reasoning effort high. Supported types are xhigh (default), medium, and low."}` — full body in `oi1-plan-high.json` |
| 1b | `:4000/v1/chat/completions` (curl) | `flashnext` (`openai/`) | `"high"` | **HTTP 400** | `litellm.UnsupportedParamsError: openai does not support parameters: ['reasoning_effort'], ...` — full body in `oi1-flat-high.json` |
| 1d | `:4000/v1/chat/completions` (curl) | `flashnext-plan` | *(omitted — control)* | **HTTP 200** | `{"content":"4", ..., "reasoning_content":"..."}` — confirms the alias path is healthy; a non-200 in row 1a is attributable to the *value*, not a broken alias. Full body in `oi1-plan-control.json` |
| 1c | real `cline -P openai-compatible -m flashnext-plan --thinking high ...` (raw binary, **not** the phase-11 wrapper — the wrapper refuses `--thinking` by design; this row tests what a user bypassing/predating the wrapper sees) | `flashnext-plan` | `"high"` | **exit 1** | Cline's own NDJSON error event carries the **identical** model-side message verbatim: `{"type":"error","message":"litellm.InternalServerError: ... Unexpected reasoning effort high. Supported types are xhigh (default), medium, and low. ... Received Model Group=flashnext-plan..."}` (`oi1c-cline-thinking-high-retry.stderr`, `.ndjson`) |

**Disposition: RESOLVED, exactly as inferred, now observed end-to-end through all three surfaces
(curl×2, real cline CLI×1) plus a healthy-path control.** The `openai/`-prefixed branch (1b) is
blocked by litellm before the model server; the `hosted_vllm/`-prefixed branch (1a) passes through
litellm and 500s at the model server with the documented message; and (1c) confirms a real user
typing `--thinking high` against the raw binary would see that exact 500 message surfaced as
Cline's own error event, then exit 1.

**A methodologically relevant observation, worth recording alongside the answer:** none of 1a, 1b,
or 1c produced a `Generation queued` line in `~/llm-system/services/logs/flashnext.err` — the
model server's own `reasoning_effort` value validation happens *before* a request enters the
generation queue, so every rejected-value request in this table cost **zero** actual
model-generation work, distinct from a request that reaches generation and is then rejected mid-flight.

**A note on retries (outcome-neutral, operational-failure-only, per this plan's own rule):** the
first attempt at case 1c and at Open Item 2 (below) failed *operationally* — see "Unplanned finding"
below — and each was retried exactly once. The failed first attempt is preserved verbatim in
`oi1-operational-failures.tsv` and `oi1c-cline-thinking-high.{exit,ndjson,stderr}`; the table above
reports only the successful retry, matching the plan's 4-row requirement for `oi1.tsv`.

---

## OPEN ITEM 2 (11-RESEARCH.md Q6.2) — is `max_tokens=2048` still the fixed per-turn value at 3.0.60?

**Question as posed:** `docs/cline-max-tokens-findings.md` measured a fixed wire `max_tokens=2048`
at cline 3.0.53, independent of any `providers.json` setting. Does this still hold at the now-installed 3.0.60/3.0.61?

**Previously known, and from where:** `docs/cline-max-tokens-findings.md` §2, measured at 3.0.53:
`Generation queued: ... prompt_tokens=5495 max_tokens=2048` for a trivial one-word-reply prompt via
the `flashnext` alias — this is documented as the CLI's own fixed value, unaffected by
`providers.json`'s `settings.maxTokens`/`settings.models[].maxTokens` (both were tried in the
original research and neither moved the wire value).

**Observed here**, following that document's own §6 recheck recipe exactly (byte-watermarked
`flashnext.err`, one `CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext --compaction
agentic --json -t 600 "Reply with exactly one word: OK"` call):

```
2026-09-02 14:03:05,161 - INFO - Generation queued: request=835b138b30 prompt_tokens=5494 max_tokens=20983 images=0 audio=0 videos=0
```

(`phase-11/results/20260902T045814Z-openitems/oi2-maxtokens.txt`, `oi2.tsv`). `prompt_tokens=5494`
is essentially identical to the 3.0.53 measurement's `5495` (both runs use the identical
one-word-reply prompt against the same `providers.json` and identical `contextWindow=29000`), so
this is a like-for-like comparison. The NDJSON `usage` event confirms `outputTokens:2` (the model
replied "OK") — nowhere near either cap; only the wire *value cline requests* is being compared,
never the model's actual output length.

**Disposition: RESOLVED, and the answer is NO — it has moved, dramatically.** `max_tokens` went
from a fixed **2048** at 3.0.53 to **20983** at the now-installed 3.0.60/3.0.61 — roughly a 10×
increase, for what appears to be an essentially identical prompt. This is not a small drift; it
falsifies `11-RESEARCH.md` Q6.2's working assumption that "2048 is the *fixed* per-turn completion
budget for both arms" of the planned USE-03 A/B (plan 11-05). **Plan 11-05 must re-derive its
completion-budget fairness control from this new figure (or re-measure again if the binary has
drifted further by the time it runs) rather than carrying the 2048 figure forward.** Whether
`max_tokens` is now a fixed constant again (just a different one) or has become a function of
`prompt_tokens`/`contextWindow` was not re-measured with a second, differently-sized prompt in this
plan — that would be a natural follow-up probe for whoever picks this up next, but was outside this
plan's stated budget and scope.

---

## OPEN ITEM 3 (11-RESEARCH.md Q5) — can repeated `cline -m` calls move `model`/`contextWindow`, not just `updatedAt`?

**Question as posed:** `phase-10/VRF-04-OBSERVATION.md` observed exactly **one** `cline -m
flashnext-plan` call leave `model`/`contextWindow` intact while rewriting only `updatedAt`. Does
**volume** (N≥5, as the shipped wrappers now generate continuously) ever move the judged fields
too?

**Previously known, and from where:** `phase-10/PHASE-10-FINDINGS.md` §4.4 / `VRF-04-OBSERVATION.md`
§3/§6: N=1 at cline **3.0.60**, invoked as bare `cline -P openai-compatible -m flashnext-plan
--compaction agentic --json -t 600 "<prompt>"` (no `-p`), left `settings.model` at `"flashnext"`
and `contextWindow` at `29000` — only `updatedAt`/sha256 moved.

**Observed here** (`phase-11/results/20260902T050726Z-volume/volume.tsv`, `postflight.txt`):

The planned protocol was six sequential invocations of the real shipped wrappers, alternating
`phase-11/cline-plan`/`phase-11/cline-act`, checking `verify_config.sh` after each. **The probe
stopped after call 1 of 6**, per this plan's own pre-registered stop condition ("if either judged
field ever moves, stop immediately, do not attempt to restore the file, record the exact call
number"):

```
seq=1  wrapper=cline-plan  exit_code=4  duration_s=11
model=flashnext-plan  contextWindow=29000
updatedAt=2026-09-02T05:07:29.335Z
verify_config_exit=1
```

`phase-11/cline-plan --timeout 120 "Reply with exactly one word: OK"` — real argv
`/opt/homebrew/bin/cline -P openai-compatible -p -m flashnext-plan --compaction agentic -t 120
"Reply with exactly one word: OK"` — completed successfully (cline's own exit code 0, correct
reasoning-annotated "OK" output, visible in `call-1.stdout`), but **`providers.json`'s
`settings.model` became `"flashnext-plan"`** (was `"flashnext"`). `contextWindow` stayed `29000`.
The wrapper's own post-run guard caught this immediately and surfaced it correctly, exactly per its
documented exit-code contract: wrapper exit **4** (`WARNING[CONFIG]: cline exited 0, but the
post-run config guard failed`, `call-1.stderr`) — this is the exit-4 branch's first live-fire, and
it worked.

**Disposition: the underlying question was superseded by a more severe finding.** A single call
(not N≥5) already moved the judged `model` field — contradicting VRF-04's own N=1 observation. Two
candidate explanations exist and were **not** disambiguated within this plan's budget/scope (doing
so would require additional live `-m` calls, which the plan's own stop condition explicitly forbids
once a judged field has moved):

1. **Version drift.** VRF-04's clean observation was made at cline **3.0.60**. This call ran at
   cline **3.0.61** — cline self-updated again during this plan's own Task 2 (see "Unplanned
   finding" below) before Task 3 ever started. `-m`'s persistence behavior may simply differ between
   these two patch versions, exactly the CFG-05 risk this project has repeatedly flagged.
2. **The `-p` flag.** VRF-04's invocation never included `-p`/Plan-mode. `phase-11/cline-plan`
   always does (ROADMAP Phase 11 criterion 1). Plan mode's own code path could plausibly interact
   with `-m` persistence differently than Act-mode/no-flag invocations do.

**Per the plan's explicit instruction, `providers.json` was NOT restored and no further wrapper
calls were attempted.** As of this document, the live `providers.json` still holds
`settings.model="flashnext-plan"` — this is a real, live, production-affecting state (Kanban and
Telegram share this same provider entry and would now default to the reasoning-heavy alias for any
of their own `cline` invocations that do not pass an explicit `-m` override), and restoring it is
outside this plan's authority (hard constraint: do not edit `providers.json`) and outside its scope
(the plan's job here is to observe and record, not repair). **This needs a human decision** —
whether to run `phase-01/config/apply_provider_config.sh` (the tool that owns restoring this file)
is not this plan's call to make.

**A goal explicitly NOT met, stated plainly rather than glossed over:** `verify_config.sh`'s
providers.json section runs *before* its wrapper section in file order and `exit 1`s immediately on
a providers.json failure — so the wrapper section (`phase-11/verify_wrappers.sh`'s Group A/B
checks) was **never reached, not even once**. The goal of observing `OK[WRAPPER]` on all six of the
probe's own live, unsuppressed `verify_config.sh` calls was not achieved for any call — call 1's
`verify_config_live-1.txt` contains only `FAIL: model expected 'flashnext', observed
'flashnext-plan'`, neither `OK[WRAPPER]` nor `SKIP[WRAPPER]`. This is recorded honestly as **0 of 6
wrapper-check live-exercises completed**, not claimed as partial success.

---

## OPEN ITEM 4 (11-RESEARCH.md, A/B repetition count and task-set sizing) — NOT resolved here

Explicitly deferred to **plan 11-05**, per the plan's own scope split. This document's silence on
it is not an omission: 11-RESEARCH.md's own "Open Questions" §4 already frames this as belonging to
the plan that actually runs the A/B, and `AB-TASKSET.md` (plan 11-02) already establishes the
8-task pool this sizing decision will be made against. Nothing about items 1–3 above changes that
scope split — if anything, Open Item 2's `max_tokens` finding (2048→20983) is now an *input* 11-05
needs when it makes this sizing decision, not a substitute for making it.

---

## Instruments exercised live

**Part A0 — 11-03's opt-in `WRAPPER_CHECK_ALIAS_LIVE=1` branch of `phase-11/verify_wrappers.sh`,
run against the live gateway for the first time** (`phase-11/results/20260902T050726Z-volume/alias-live-check.{txt,exit}`,
`gateway-models.json`):

- **Exit status: 0** (all wrapper assertions, including the live alias check, passed).
- **Observed alias ids** from `http://127.0.0.1:4000/v1/models`: `flashnext`, `flashnext-codex`,
  `flashnext-plan`, `flashnext-act`, `flashnext-reach-xhigh` — all 5 configured aliases are listed.
  This is a **listing only** — `/v1/models` is served by litellm itself and never reaches the model
  server, and `flashnext-codex` appearing in this list is not a call to it (the hard constraint
  forbids *calling* `flashnext-codex`, not seeing its name in a model list).
- **Cost proven zero, not assumed:** `Generation queued` count in `flashnext.err` was **904 before
  and 904 after** Part A0 (`alias-live-check-cost.txt`) — no new model-generation request occurred.
  Excluded from `budget.tsv`/the 14-request cap for this reason.

**The wrapper's internal (always-suppressed) guard call vs. the probe's own unsuppressed call —
kept distinct, per the plan's own explicit warning.** `phase-11/wrapper_common.sh` (owned by plan
11-01, not edited by this plan) always calls its pre-/post-run guard with
`VERIFY_CONFIG_NO_WRAPPER_CHECK=1`, so `verify_config.sh`'s wrapper section is *structurally always
skipped* there. That call's own stdout is captured into a shell variable inside
`wrapper_common.sh` and echoed **only on a non-zero exit** — meaning on a normal passing run its
`SKIP[WRAPPER]` line is generated and then discarded, never touching any stream this plan can
observe from outside without editing that file (forbidden, hard constraint 8). `probe_wrapper_volume.sh`
therefore **replays** the identical command (`VERIFY_CONFIG_NO_WRAPPER_CHECK=1 bash
phase-01/config/verify_config.sh`) immediately before and after each wrapper call, against the same
`providers.json` state, and captures *that* output — labelled explicitly as a replay, never claimed
as literal interception. For call 1 (the only completed call), both replay files
(`wrapper-internal-guard-seq1-pre.txt`, `-post.txt`) contain the exact line
`SKIP[WRAPPER]: wrapper check suppressed by VERIFY_CONFIG_NO_WRAPPER_CHECK=1` — the brake is
observed firing on both the pre- and post-run replay. **What actually exercises the wrapper check
live is the probe's own separate, unsuppressed `verify_config.sh` call** — for the one completed
call, that call's output (`verify_config_live-1.txt`) contains neither `OK[WRAPPER]` nor
`SKIP[WRAPPER]`, because `verify_config.sh`'s providers.json section failed and exited before ever
reaching the wrapper section (see Open Item 3 above) — the internal call is never mistaken for
having exercised the wrapper check live, and the live call never got the chance to either, both
recorded exactly as observed.

---

## Budget accounting

**Stated cap: 14 live model requests**, enforced in code (`phase-11/probe_lib11.sh`'s
`assert_budget`, called before every live request in every probe script this phase runs) against a
single persistent watermark shared across every probe script this plan executes, not remembered or
recomputed per script.

**Planned breakdown:** 4 for Open Item 1 (2 curl pairs — 1a/1b/1d as curl, 1c as one real cline
call), 1 for Open Item 2, 6 wrapper invocations for Open Item 3, 3 spare for a single operational
retry = 14.

**Actual measured count: 3**, well under the cap:

| task | requests that reached the model's generation queue | detail |
|---|---|---|
| Task 1 (`selftest_probe_lib11.sh`) | 0 | offline only, `flashnext.err` line count unchanged (23396→23396) |
| Task 2 (`probe_open_items.sh`) | 2 | only 1d (control, HTTP 200) and oi2-retry actually reached generation; 1a/1b/1c/1c-retry were all rejected before the generation queue (value validation, either at litellm or at the model server) and cost 0 each |
| Task 3 (`probe_wrapper_volume.sh`) | 1 | call 1 only — the loop stopped there per its own design; Part A0 excluded (0, proven) |
| **Total** | **3** | of the stated cap of **14** |

**Overage: none.** The actual count (3) is dramatically under the planned breakdown (14) — not
because fewer requests were *attempted* (7 attempts were made across curl calls, cline invocations,
and their retries: 1a, 1b, 1d, 1c, 1c-retry, oi2, oi2-retry, plus call-1 in Task 3 = 8 attempts
total), but because several of the planned requests (1a, 1b, 1c, 1c-retry, and the original failed
1c/oi2 attempts) never reached the model's generation queue at all — either rejected by litellm
before forwarding (1b), rejected by the model server before queueing (1a, 1c, 1c-retry), or an
operational failure that never reached litellm (the original 1c/oi2 attempts, see below). This
plan's cap is defined, per its own text, on **requests observed in the server log**
(`Generation queued` lines), not on invocations attempted — so this is the correct count against
that definition, reported honestly even though it is far under budget, per
`phase-10/PHASE-10-FINDINGS.md` §4.5's own standing lesson (report the actual number regardless of
which direction it differs from the plan).

**Cross-checked independently** in both `probe_open_items.sh` and `probe_wrapper_volume.sh` via a
second arithmetic path (`grep -c` total minus a `head -n <watermark> | grep -c` baseline, rather
than the `tail -n +` path `count_requests_since`/`log_budget_row` use) — both scripts' own output
confirms the two paths agree.

---

## Unplanned finding: cline's own npm package was found removed mid-plan (CFG-05, live)

Not one of the four items above, but load-bearing enough to record here rather than only in the
plan's SUMMARY: during `probe_open_items.sh`'s very first live `cline` invocation (case 1c), the
raw binary was found **entirely missing** — `/opt/homebrew/bin/cline: No such file or directory`,
and `/opt/homebrew/lib/node_modules/cline/` did not exist at all (`npm ls -g` showed no `cline`
package). The still-running `com.ohama.*`-unrelated hub-daemon process (pid 43410, started the
previous day) held an open file handle to the now-unlinked binary (`lsof` showed a deleted `/cline`
inode), confirming the package really was removed from disk while at least one process still had it
open — consistent with an in-progress or interrupted self-update, not a deliberate action by this
plan. `npm view cline versions` showed `3.0.61` newly available on the registry at the time this was
investigated. Restored via `npm install -g cline@3.0.60` (pinned explicitly, to keep this plan's own
measurements on a version consistent with what `preflight11` had already recorded, rather than
accepting whatever `latest` would install and introducing a second, undocumented drift on top of an
already-disrupted session). This is a **more severe** manifestation of CFG-05 than previously
documented: prior findings characterized cline's auto-update as *silently changing version/flags*;
this plan observed it can **silently and completely break the CLI's own invocability mid-session**.
It then drifted again, silently, from 3.0.60→3.0.61 sometime during the two retried live calls
(`probe_open_items.sh`'s own `postflight11` recorded and loudly flagged the drift) — and Open Item
3's `model`-field corruption (above) occurred at this newly-drifted 3.0.61, not the 3.0.60 version
VRF-04 tested. **This connects the two most significant findings in this document**: CFG-05's
unblocked auto-update is not just a documentation-staleness risk, it may be the direct cause of a
previously-clean invariant (`cline -m` never moving `model`/`contextWindow`) now failing.
