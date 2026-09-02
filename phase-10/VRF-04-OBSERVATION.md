# VRF-04-OBSERVATION.md — real `cline` execution against `flashnext-plan`

Phase 10 Plan 05. Closes the deferral `phase-09/GATE-VERDICT.md` §6 recorded: Phase 9 measured
every part of this pipeline with `curl`, and deliberately never launched the real `cline` binary
(the human approved that deferral explicitly). Everything measured before this document —
`REACH-PROOF.md`'s CFG-16/VRF-01/VRF-02/VRF-03 — proves the **gateway** forwards the injected
`reasoning_effort`/`enable_thinking` parameters. It says nothing about whether **Cline's own agent
loop**, run as a real process against that alias, actually surfaces reasoning in what a user or a
downstream wrapper (Phase 11's `cline-plan`) would actually see. This document is that check.

**Bottom line, up front:** reasoning **did** surface in the real `--json` NDJSON stream, and only
in the `flashnext-plan` stream — the `flashnext` control stream carried zero reasoning events under
every extraction method tried, while reaching the identical correct final answer. One important,
unplanned finding surfaced during execution: the real `cline` binary (3.0.60) touches
`providers.json`'s `updatedAt` timestamp as a side effect of a session, even under a per-invocation
`-m` override — contradicting a hard constraint of this plan that was based on a source citation
from an older binary (3.0.53). See §3 and §6.

---

## §1 The invocation

**cline --version, immediately before both runs:** `3.0.60`
**cline --version, immediately after both runs:** `3.0.60` (unchanged — no drift occurred *during*
this particular run, though the version had already moved from Phase 9's `3.0.53` before this plan
started; see §3).

**Provider entry used:** `openai-compatible` (`~/.cline/data/settings/providers.json`, unchanged
`baseUrl: http://localhost:4000/v1`, `apiKey: dummy`, `contextWindow: 29000`; `-P` selects this
entry, `-m` overrides only the model id sent in the request for that invocation).

**Fixed prompt, identical in both runs** (short arithmetic, requires no tool call, so nothing can
block on an approval prompt in a headless run):

```
1부터 20까지의 소수를 모두 더하면 얼마인가? 계산 과정을 간단히 보이고 답을 마지막 줄에 써라.
```

**Run 1 — the subject** (`phase-10/results/20260901T091011Z-vrf04/ndjson-plan.log`):

```
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext-plan \
  --compaction agentic --json -t 600 "1부터 20까지의 소수를 모두 더하면 얼마인가? 계산 과정을 간단히 보이고 답을 마지막 줄에 써라." \
  > ndjson-plan.log 2> stderr-plan.log
```

Exit code `0`. Duration `18s`. `stderr-plan.log` is empty (no auto-update noise, no warnings).
`run_result.model.id` inside the stream itself confirms `"flashnext-plan"` was the model actually
used.

**Run 2 — the control** (`.../ndjson-control.log`), fired sequentially after confirming
`in_flight=0` again, never concurrently with Run 1:

```
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext \
  --compaction agentic --json -t 600 "1부터 20까지의 소수를 모두 더하면 얼마인가? 계산 과정을 간단히 보이고 답을 마지막 줄에 써라." \
  > ndjson-control.log 2> stderr-control.log
```

Exit code `0`. Duration `14s`. `stderr-control.log` is empty. `run_result.model.id` confirms
`"flashnext"`.

**Run 3 (`flashnext-act`) was not run.** It is explicitly optional per `10-05-PLAN.md` ("ROADMAP
criterion 6 accepts `flashnext` *or* `flashnext-act` as the control; `flashnext` is the truer
baseline, so run 3 is a bonus, not a requirement"). `flashnext` was already run as the true control,
and `REACH-PROOF.md` §5 already established `flashnext-act` is indistinguishable from `flashnext`
by curl (`delta=0`); running it here would add a third live `cline` invocation without adding
anything VRF-04 specifically needs. Skipped by design, not by failure.

**Run directory:** `/Users/ohama/projs/cline-tests/phase-10/results/20260901T091011Z-vrf04`
(`phase-10/results/20260901T091011Z-vrf04/` relative to the repo root). Server-side: exactly two model
requests were fired against the shared model during this whole probe (watermark-verified against
`~/llm-system/services/logs/flashnext.err`) — one per `cline` invocation, each single-turn
(`iterations: 1` in both `run_result` events). **Request count: 2 of a planned budget of 2** — no
overage, unlike plan 10-04's 48-vs-17.

**Reproduce with:** `bash phase-10/probe_vrf04_cline.sh`, from the repo root, with the model idle
(`in_flight=0`).

---

## §2 The observation, side by side

| run | documented-path events (`content_start`/`contentType=="reasoning"`) | documented-path reasoning chars | broad text-scan hits | `grep -c reasoning` | `grep -c reasoning_content` | total NDJSON lines | distinct `.event.type` |
|---|---:|---:|---:|---:|---:|---:|---|
| `flashnext-plan` (subject) | **72** | **198** | 50 (capped at head -50; actual matching lines = 73) | 73 | 0 | 277 | `content_end`(2), `content_start`(268), `done`(1), `iteration_end`(1), `iteration_start`(1), no-`.event.type`(3), `usage`(1) |
| `flashnext` (control) | **0** | **0** | 0 | 0 | 0 | 137 | `content_end`(1), `content_start`(129), `done`(1), `iteration_end`(1), `iteration_start`(1), no-`.event.type`(3), `usage`(1) |

**Both extraction methods agree, and agree with each other:** the documented v3.0.53 jq path
(`.event.type=="content_start" and .event.contentType=="reasoning"`) found 72 matching events
in the subject stream and 0 in the control. The independent, shape-agnostic broad scan (does the
stringified line contain the substring `"reasoning"` anywhere) found reasoning in 73 lines of the
subject stream (72 `content_start` + 1 `content_end`, consistent with one full reasoning block
being streamed token-by-token then closed) and in 0 lines of the control. **Neither a hardcoded
path nor a broad scan disagreed with the other on which stream carried reasoning** — this is not a
case where relying on one path would have produced a false negative; both readings point the same
direction. The distinct `.event.type` histograms also show the control stream was not simply
"empty" or broken — it carried the full normal event sequence (`iteration_start` → 129
`content_start`/`content_end` text events → `usage` → `done`), it simply never carried a
`contentType=="reasoning"` event.

**What the observation was, stated in the direction the data went:** reasoning appeared **only in
the `flashnext-plan` stream**, streamed as 72 incremental `content_start` events (one small text
fragment per event) followed by one consolidated `content_end` event, together spelling out (first
and, in this case, only ~200 characters, quoted in full since the whole trace fit in that span):

> "The user is asking me to find the sum of all prime numbers from 1 to 20 and show my work. I'm
> identifying the primes in that range—2, 3, 5, 7, 11, 13, 17, and 19—and adding them together to
> get 77."

The `flashnext` control stream went straight from `iteration_start` to streaming the final answer
text (`contentType=="text"`) with no reasoning block of any kind, at any point, under any of the
extraction methods used. Both runs reached the identical correct numeric answer (77); the
`flashnext-plan` run's final `content_end` text was the Korean explanation ending
`"…\n\n답: 77"`, and the control's was a shorter Korean explanation also ending `"**답: 77**"`.
**Neither stream carried the field name `reasoning_content`** (`grep -c reasoning_content` = 0 in
both) — Cline's own internal event schema names this field `reasoning`, not litellm's/the model
server's `reasoning_content`; a reader should not conflate the two field-name spaces. This is not
the "appeared in both" surprising case (§ below is silent on that paragraph because it did not
occur) — the split was clean.

---

## §3 What this licenses concluding, and what it does not

**Positive observation, and what it licenses:** through the `flashnext-plan` alias, on real
`cline` 3.0.60, on this one short arithmetic prompt, in a single-turn session, Cline's own `--json`
agent-event stream carried a `reasoning` content block that the `flashnext` control did not. This
licenses exactly the claim VRF-04 asks for: **the injected parameters are not just forwarded by the
gateway (`REACH-PROOF.md`) — they visibly change what the real consumer, Cline's own client code,
puts on its own output stream.** It does **not** license "reasoning improves output quality" — both
streams reached the same correct answer on this prompt; that A/B is USE-03's job in Phase 12,
deliberately not attempted here, and a single easy arithmetic prompt is not designed to distinguish
quality either way.

**Scope limits, stated plainly:**
- **Single prompt, single session, single cline version.** This is one observation, not a
  statistical claim. A different prompt, a multi-turn session, or a future cline version could
  behave differently.
- **`CFG-05` (the auto-update problem, unresolved, carried to v1.2+) means the binary can move
  under this conclusion at any time.** The version was checked immediately before and immediately
  after this specific run and did **not** move (`3.0.60` both times) — but it is known to have
  already moved once, silently, between Phase 9 (`3.0.53`) and the start of this plan (`3.0.60`),
  which is exactly why this document does not treat any hardcoded jq path as trustworthy on its
  own (§2, and see the design note at the top of `probe_vrf04_cline.sh`).
- **Phase 9's source-line citations for the NDJSON shape and for the reasoning re-attachment
  mechanism (`ai-sdk.ts:284-289`, `agent-message-codec.ts:231`, `message-builder.ts:1213-1214`)
  were made by reading `cline-src` at tag `cli-v3.0.53`. They were NOT re-verified against 3.0.60
  by this plan.** `/Users/ohama/projs/cline-src` remains checked out at `cli-v3.0.53`
  (`git describe --tags` confirms this, working tree clean) and was left untouched — re-pinning it
  to inspect 3.0.60's source was judged out of this plan's scope (not one of its tasks) and risked
  disturbing state other phases rely on being at the tagged commit. **What this document adds is
  independent, from a live running process, not from source:** the documented v3.0.53 *shape*
  (`content_start`/`contentType=="reasoning"`/`.event.reasoning`) was empirically observed to still
  hold at 3.0.60 (§2) — that is new evidence this plan produced, not a re-verification of the
  earlier source reading itself.
- **An unplanned finding: `providers.json` was written to by the real `cline` process during Run 1**,
  despite `-m` being documented (at 3.0.53) as a per-invocation-only override with no persistence.
  Only the `updatedAt` timestamp on the `openai-compatible` provider entry changed (before:
  `2026-08-31T23:37:50.252Z`, after: `2026-09-01T09:10:32.448Z`); the `model` field itself was
  **not** altered (still `"flashnext"`), and `bash phase-01/config/verify_config.sh` still exits 0
  against the mutated file. An attempt to restore the file to its exact original bytes (verified
  offline to reproduce the exact original sha256) was blocked by this execution environment's own
  permission system and was not worked around. **Net effect:** `providers.json`'s sha256 no longer
  equals `phase-10/BASELINE.txt`'s recorded value; the pinned field values that
  `verify_config.sh` actually asserts are unaffected. Full detail:
  `phase-10/results/20260901T091011Z-vrf04/PROVIDERS-JSON-FINDING.md`. **This is precisely the
  kind of gap this plan exists to catch** — a hard constraint derived from a source citation at one
  version did not fully hold at a later one, discovered only by actually running the real binary.

**Negative-observation framing (for completeness, though this run was positive on the
`flashnext-plan` side):** had reasoning appeared in neither stream, that would have licensed
"the parameter reaches the model (per `REACH-PROOF.md`) but did not surface in Cline's stream on
this prompt" — not "the alias is broken," since a short arithmetic prompt might simply not trigger
visible thinking regardless of the server-side setting, and the correct next step would have been a
harder prompt, not a verdict change. This branch did not occur; recorded per the plan's instruction
to state the counterfactual explicitly.

---

## §4 Relationship to PRB-04

`phase-09/PRB-04-FINDINGS.md` established from source (`cli-v3.0.53`: `ai-sdk.ts:284-289`,
`agent-message-codec.ts:231`) that Cline **re-attaches** reasoning history to subsequent turns, and
`phase-09/results/.../PRB-04-*` measured that doing so costs **0** tokens on this stack (16/16
`delta=0`, controlled replay via curl).

**This run cannot corroborate or contradict that finding.** Both the subject and control sessions
captured here are **single-turn** (`"iterations": 1"` in both `run_result` events) — the fixed
prompt was answered completely in one pass, with no second user turn to observe a reasoning-history
carryover into. This is exactly the honest limitation the plan anticipated ("If the stream is
single-turn, say that it cannot speak to this and leave it as Phase 9's source-verified result") —
PRB-04's finding stands as Phase 9 left it, source-verified at `cli-v3.0.53` and confirmed by
controlled curl replay, neither strengthened nor weakened by this document.

---

## §5 Requirement mapping

- **VRF-04** (`.planning/REQUIREMENTS.md`): "**실제 `cline` CLI 실행**의 `--json` 스트림에
  `reasoning` 이 나타나는지가 `flashnext-plan` 과 대조군 양쪽에서 관측·기록된다." Satisfied: §1–§2
  above are exactly that observation and record, for both arms, from a real process.
  <br>The requirement's own footnote states: **"관측 결과가 부정적이어도 이 요구사항은 충족된다 —
  관측이 요구사항이다."** (`REQUIREMENTS.md` line 91; `10-05-PLAN.md` paraphrases the same point as
  `관찰 결과가 부정적이어도 이 기준은 충족된다`.) This document's result happened to be positive on
  the `flashnext-plan` side, but that is incidental to satisfying the requirement — the requirement
  is satisfied by the act of observing and recording either way, and this document would be equally
  complete had §2's table read all zeros for both arms.
- **ROADMAP criterion 6** (Phase 10): "**그것이 실제 `cline` CLI 실행에서 작동함이 관측되며**" — the
  Phase 10 goal statement itself, not a numbered success criterion sub-item; satisfied by the same
  evidence.
- **Evidence paths:** `phase-10/probe_vrf04_cline.sh` (the re-runnable script);
  `phase-10/results/20260901T091011Z-vrf04/` (`ndjson-plan.log`, `ndjson-control.log`, `vrf04.tsv`,
  `reasoning-events-{plan,control}.jsonl`, `reasoning-textscan-{plan,control}.jsonl`,
  `event-types-{plan,control}.txt`, `cline-version-{before,after}.txt`,
  `providers-{before,after}.txt`, `PROVIDERS-JSON-FINDING.md`, `preflight.txt`, `postflight.txt`,
  `verdicts.tsv`, `flake-count.txt`).

---

## §6 Handoff to Phase 11

For whoever builds the `cline-plan`/`cline-act` wrapper (`USE-01`):

1. **The exact working invocation** is `cline -P openai-compatible -m <alias> --compaction agentic
   --json -t <timeout> "<prompt>"`, with `CLINE_NO_AUTO_UPDATE=1` set in the environment (does not
   guarantee no self-update — CFG-05 — but is still worth setting). No `-p`/`--plan` flag is
   needed or used; alias selection alone (`-m`) is what determines whether reasoning is injected.
2. **`-m` per-invocation override behaved as documented in one respect and not in another:** the
   actual **model id used for the request** was correctly overridden (`run_result.model.id`
   confirmed `"flashnext-plan"` / `"flashnext"` matching the `-m` argument each time) — but the
   claim that this override has **zero persistence side effects** did **not** hold at 3.0.60: see
   §3's `providers.json` finding. A wrapper author should not assume invoking `cline -m <alias>`
   leaves `providers.json` provably byte-identical; it may not, even though the functional model
   selection is correct.
3. **`providers.json`'s pinned field values (`model`, `baseUrl`, `contextWindow`) survived**
   (`verify_config.sh` exits 0 after this plan's runs) — only a timestamp metadata field moved.
   Nothing about CFG-01/CFG-02/CFG-07's regression protection is at risk from this.
4. **Caveats from §3 that carry forward:** single-prompt/single-version observation; CFG-05 auto
   update risk is live and unresolved; Phase 9's source citations for the NDJSON shape and the
   reasoning-reattachment mechanism were made at `cli-v3.0.53` and were not re-verified at 3.0.60 by
   this plan (though the *shape itself* was empirically confirmed still valid, live, at 3.0.60 —
   see §2/§3). A future plan that wants source-level certainty at the currently-installed version
   should re-pin `/Users/ohama/projs/cline-src` (left untouched, at `cli-v3.0.53`, by this plan) and
   re-read the cited lines there.
