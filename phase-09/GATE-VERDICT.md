# Phase 9 Gate Verdict

**Plan:** 09-04
**Generated:** 2026-09-01
**Adjudicates:** PRB-01 (diagnostic, demoted 2026-09-01), PRB-04 (🔴 the milestone's only remaining
kill condition)

This document is the **only** place in Phase 9 where a gate verdict may be declared. Plans 09-01
through 09-03 deliberately measured without judging (each says so explicitly in its own summary).
Everything below is adjudicated on **this phase's own reproduced values**, not on
`09-RESEARCH.md`'s prior numbers — the research appears only as the comparison column in §2.

---

## §1 Provenance

Three independent run directories, produced by 09-01/09-02/09-03, each wrapped in the shared
`probe_lib.sh` preflight/postflight safety envelope (PID snapshot + config-hash snapshot, taken
immediately before and after every probe burst):

| Run | Directory | Span (UTC) | Flake window | PID check | Config-hash check |
|---|---|---|---|---|---|
| PRB-01 / PRB-02 (09-01) | `phase-09/results/20260901T014027Z-prb01-02` | 01:40:27Z → 01:44:47Z | CLEAN (`flake-count.txt`=0) | before/after identical | before/after identical |
| PRB-03 oracle + multi-turn (09-02) | `phase-09/results/20260901T015706Z-prb03` | 01:57:06Z → 02:02:21Z | CLEAN (`flake-count.txt`=0) | before/after identical | before/after identical |
| PRB-04 replay + source re-check (09-03) | `phase-09/results/20260901T021414Z-prb04` | 02:14:14Z → 02:17:02Z | CLEAN (`flake-count.txt`=0) | before/after identical | before/after identical |

**PID values, identical across all three runs' `pids-before.txt`/`pids-after.txt` and identical to
each other run's:** `com.ohama.flashnext 46573`, `com.ohama.litellm 48525`,
`com.ohama.role-shim 75548`. No run shows a PID delta at any point.

**Config-hash values, identical across all three runs' before/after and identical to each other:**
`litellm-config.yaml` sha256 `12e102cf...` , `providers.json` sha256 `5cf3800d...` (full digests in
each run's `hashes-before.txt`/`hashes-after.txt`). No run shows a hash delta at any point.

**`verify_config.sh` was run as an independent, non-fatal check at every postflight and printed
`OK: ...` every time** (`postflight.txt` in all three run directories).

**Every verdict recorded across all three runs is `CONFIRMED`.** Combined `verdicts.tsv` counts:
7 (09-01) + 18 (09-02) + 12 (09-03) = 37 individual sample verdicts, **zero** `DISCARDED-FLAKE`,
**zero** `PROVISIONAL-NEGATIVE`, **zero** `INDETERMINATE`. No gate-relevant reading in this phase
required a retry or was excluded for flake.

**`cline` was never invoked to generate model load in any of the three runs** — each run's own
`RESULT.md`/`FINDINGS.md`/`ORACLE.md` states this explicitly (09-01's `RESULT.md` §"Deliberate
non-action"; 09-02/09-03's summaries). A pre-existing, unrelated background process
(`cline-hub-daemon`, PIDs 4672/4673/43410, servicing a different project's toy-lang directory) was
already running before Phase 9 started and remained running, unchanged, through all three runs'
preflight advisories — this is the same background process `09-RESEARCH.md` itself noted and
explained is not evidence of an active model request; it is recorded here as a hint-only advisory,
not a hard gate, per `probe_lib.sh`'s own design.

**No config file was written by this phase.** `litellm-config.yaml` and `providers.json` hashes are
identical at every before/after checkpoint across all three runs (see above) — that is nine
independent hash comparisons (3 runs × before/after × the check re-confirmed once more below in
§6), all agreeing.

---

## §2 Fresh vs. research comparison

One row per measured claim. `agree?` is `yes` when the fresh value matches the research's
directional/numeric claim, `no` when it diverges (investigated in §3), `n/a` when the research did
not measure this at all (new evidence this phase produced).

| claim | 09-RESEARCH.md value | Phase 9 fresh value | agree? | evidence path |
|---|---|---|---|---|
| PRB-01: `reasoning` non-empty at `reasoning_effort: medium` (`:8011`) | yes, 89–480 chars | yes, 179 chars (both samples) | yes | `phase-09/results/20260901T014027Z-prb01-02/prb01.tsv`, `RESULT.md` |
| PRB-01 negative control: `reasoning` at unspecified effort | not measured | empty (both samples) | n/a (new evidence) | `phase-09/results/20260901T014027Z-prb01-02/prb01.tsv` |
| PRB-02: HTTP status for `enable_thinking: false` at `:4000` | 200 | 200 | yes | `phase-09/results/20260901T014027Z-prb01-02/prb02.tsv` |
| PRB-02 at `:8011` direct | covered only indirectly (implementation doc's T1-b framing; research's own probes ran at `:8011`/`:4000` but did not isolate this exact row) | 200, empty `reasoning` (indistinguishable from default) | n/a (research does not give a directly comparable row) | `phase-09/results/20260901T014027Z-prb01-02/prb02.tsv` |
| PRB-02 `enable_thinking: true` positive control | not run (research's own Open Risk #4) | 200, `reasoning_content` non-empty (30 chars) — evidence of application, not mere tolerance | n/a (new evidence) | `phase-09/results/20260901T014027Z-prb01-02/prb02.tsv`, `raw-prb02-4000-true.json` |
| PRB-03 absolutes: unspecified/medium/low/xhigh | 13/11/41/53 | 13/11/41/53 (sweep A and sweep B, bit-for-bit) | yes | `phase-09/PRB-03-ORACLE.md` §1–§2, `phase-09/results/20260901T015706Z-prb03/prb03.tsv` |
| PRB-03 deltas from unspecified: medium/low/xhigh | −2/+28/+40 | −2/+28/+40 | yes | `phase-09/PRB-03-ORACLE.md` §2 |
| PRB-04 synthetic replay delta at `:8011` (1,380-char trace) | 0 | 0 (both field names, both rounds, both `CONFIRMED`) | yes | `phase-09/PRB-04-FINDINGS.md` §1a, `phase-09/results/20260901T021414Z-prb04/prb04-synthetic.tsv` |
| PRB-04 synthetic replay delta at `:4000` (flashnext alias) | 0 | 0 (both field names, both rounds, both `CONFIRMED`) | yes | `phase-09/PRB-04-FINDINGS.md` §1a, `phase-09/results/20260901T021414Z-prb04/prb04-synthetic.tsv` |
| PRB-04 real-`xhigh`-trace replay delta (up to 2,497 chars) | not run (research's own Open Risk #3) | 0 (LONGEST 989 chars and CONCAT 2,497 chars, both endpoints, all `CONFIRMED`) | n/a (new evidence, closes the research's stated gap) | `phase-09/PRB-04-FINDINGS.md` §1b, `phase-09/results/20260901T021414Z-prb04/prb04-realtrace.tsv` |
| PRB-04 multi-turn growth, thinking-on vs thinking-off, per turn | not run (research's own Open Risk #1's "cheap confirmation" was left to a later phase; multi-turn sequences did not exist in the research) | ON +58/+23 vs OFF +331/+321 (confounded by reply-length, stated as corroborating only) | n/a (new evidence produced by 09-02; the only row satisfying ROADMAP criterion 4) | `phase-09/PRB-03-ORACLE.md` §3, `phase-09/results/20260901T015706Z-prb03/multiturn.tsv` |
| PRB-04 source path: `shouldIncludeReasoningHistory` returns true for non-Cerebras | yes | yes (verbatim function body re-observed, `ai-sdk.ts:284-289`) | yes, with one non-blocking citation correction (see §3) | `phase-09/PRB-04-FINDINGS.md` §3, `phase-09/results/20260901T021414Z-prb04/source-verification.txt` |

`grep -c '09-RESEARCH.md' phase-09/GATE-VERDICT.md` will be well above 1 — every row above cites it
by name in the comparison column.

---

## §3 Disagreements

**No substantive numeric or directional disagreement was found.** Every row in §2 that has a
research counterpart to compare against (i.e. every row not marked `n/a`) agrees exactly —
including PRB-03's four absolutes and three deltas, which is the row set with the most numeric
surface area to diverge on and did not, across two independent measurement sessions weeks apart in
absolute-baseline terms (`VALIDATED.md` → `09-RESEARCH.md` → this phase). **This agreement across
independent runs is what makes the gate calls below trustworthy — that is the point of the
adjudication exercise, and it is stated here rather than left implicit**, per this plan's own
objective.

Two items are recorded below because they are not "silent" — they are things a careful reader must
not have buried, even though neither is a numeric disagreement between fresh and research values.

### 3.1 Minor citation correction (research error, not a measurement disagreement)

`09-RESEARCH.md`'s source citation for `isCerebrasProvider` implied the function's definition lives
in `ai-sdk.ts` (it only says "`shouldIncludeReasoningHistory` ... `isCerebrasProvider`" without
naming a separate file). Re-verification in `phase-09/verify_reasoning_history_source.sh`
(`phase-09/results/20260901T021414Z-prb04/source-verification.txt`) found the actual **definition**
site is `sdk/packages/llms/src/providers/model-facts.ts:449`; `ai-sdk.ts` only imports it (line 34)
and calls it (line 288). **Cause: (d), an imprecision in the research's own citation** — not flake
(this is a static source-code grep, not a probabilistic model response), not interleaving (no HTTP
traffic involved), not stack drift (`cline-src` tag `cli-v3.0.53` confirmed unchanged, working tree
clean). **This does not change the underlying finding** (our provider is non-Cerebras, so
`includeReasoning = true` by default) and is not resolved "in the research's favour" — the fresh,
independently re-observed line number is what this document and Phase 10/12 should cite going
forward.

### 3.2 The design rationale for injecting `enable_thinking` did not survive measurement — record plainly, do not bury

This is the finding that most needs stating in the open, because it complicates rather than
confirms the milestone's premise, and burying it would look like this phase is protecting a design
decision rather than testing it.

**The premise, as written into `CFG-11`:** the alias was changed on 2026-09-01 to inject **both**
`enable_thinking: true` and `reasoning_effort: medium` together, because `enable_thinking`'s default
is `false` and there was no guarantee that `reasoning_effort` alone would turn thinking on — the
`medium`(21) < unspecified(23) system-prompt-length oddity in `VALIDATED.md` was cited as
circumstantial doubt.

**What Phase 9 measured, independently, in three separate probes:**
- PRB-01 (09-01, fresh): `reasoning_effort: medium` **alone** (no `enable_thinking` key at all)
  produces a 179-char non-empty `reasoning` field, against an unspecified-effort negative control
  that is completely empty. `medium` alone turns thinking on. There is no ambiguity in this reading
  — it is a clean binary discriminator, not a borderline case.
- PRB-03 §2b (09-02, fresh): `et-medium` (`enable_thinking:true` **and** `reasoning_effort:medium`
  together — the shipped combination) produces the **exact same** `prompt_tokens` value as `medium`
  alone (11, delta −2 from unspecified, to the token). Adding `enable_thinking:true` on top of an
  already-explicit `reasoning_effort:medium` changed nothing measurable.
- PRB-03 §2b (09-02, fresh), the mirror case: `et-true` (`enable_thinking:true` **alone**, no
  `reasoning_effort` key) produces the exact same value as `xhigh` (53, delta +40) — confirming
  `VALIDATED.md` §4's separate claim that `enable_thinking:true` alone reproduces `xhigh`'s margin.

**Reading these three together:** once `reasoning_effort` is explicit, adding `enable_thinking`
changes nothing measurable at the prompt-token level (`et-medium` = `medium`); and independently,
`enable_thinking` alone reproduces the highest-effort arm's margin (`et-true` = `xhigh`). Both facts
were measured fresh, by two different probes, in two different plans, and agree with each other.
The doubt CFG-11's own justification cited — "effort alone might not turn thinking on" — is refuted
by PRB-01's own negative-control result: effort alone unambiguously does turn thinking on.

**Cause classification:** this is not a disagreement between fresh and research values (research
never measured `et-medium`/`et-true` — those arms didn't exist until this phase's six-arm sweep) —
it is **this phase's fresh work correcting the milestone's own premise**, which is the specific
category this plan's objective warns must not be silently resolved in favour of the existing
design. It is recorded here, plainly, rather than folded quietly into §4's gate call.

**Consequence for CFG-16 (Phase 10) — the question is now narrower than when it was written.**
CFG-16 was written to ask "does the two-parameter combination actually produce a `reasoning`
field." Phase 9's fresh evidence already answers the effort-alone half of that question
affirmatively (PRB-01) and shows the combination's *token cost* is indistinguishable from effort
alone (PRB-03 §2b) — consistent with, though not itself proof of, `enable_thinking` being redundant
once effort is explicit (PRB-03-ORACLE.md §2b is explicit that a token-margin measurement cannot by
itself distinguish "redundant" from "silently no-op'd"; only a direct `reasoning`-field check
settles that, which is CFG-16's job, not this document's). There is also a known **asymmetry**
between the two parameters at the litellm layer: `09-01`'s PRB-02 fresh evidence shows
`enable_thinking` passes cleanly through the unmodified `flashnext` alias at `:4000` with a plain
top-level key (HTTP 200 for both `false` and `true`, no `UnsupportedParamsError`), whereas
`docs/plan-act-reasoning-design.md` §1-3 documents (as an already-established, pre-Phase-9 fact,
not something Phase 9 itself re-tested through litellm) that **`reasoning_effort` sent as a raw
top-level client parameter is rejected by litellm with HTTP 400**
(`litellm.UnsupportedParamsError: openai does not support parameters: ['reasoning_effort']`) unless
the alias's own config allowlists it. Phase 10's `flashnext-plan` alias is designed to sidestep this
by injecting both parameters at the alias-definition level (`litellm_params`), not asking the client
to send them — but this asymmetry means CFG-16's real remaining question is narrower than "does the
combination turn thinking on" (already yes, and specifically because of the `reasoning_effort` half,
per this phase's fresh measurement): it is now **"does litellm's alias-level injection actually
deliver `enable_thinking` through to the model at all, given `enable_thinking` and `reasoning_effort`
are known to be treated differently by litellm's own parameter-validation layer."** Phase 10 should
scope CFG-16's `:8011`/`:4000` check accordingly, and should not treat a positive CFG-16 result as
confirmation that `enable_thinking` is doing anything once `reasoning_effort:medium` is already
present — Phase 9's own evidence points the other way.

---

## §4 Gate adjudication

### 4.1 PRB-01 — diagnostic (demoted from gate on 2026-09-01)

**Rule (from `REQUIREMENTS.md`):** originally, if `reasoning` is empty at `reasoning_effort: medium`,
`medium` does not turn thinking on and the milestone ends. This was **demoted to diagnostic** on
2026-09-01 when `CFG-11` changed the alias design to inject `enable_thinking: true` alongside
`reasoning_effort: medium` — a negative PRB-01 result is no longer, by itself, a reason to end the
milestone, because the combination could still turn thinking on even if effort alone does not. The
diagnostic question that remains is: **"is effort alone sufficient?"** — informative for whether the
alias could later be simplified, not load-bearing for this milestone's continuation.

**Decision on the fresh evidence:** PRB-01 is **positive**. The discriminating fact is the negative
control added by 09-01 that the research itself did not run: `reasoning_effort: medium` produced a
179-character non-empty `reasoning` field on both samples, while the unspecified-effort control
produced a completely empty `reasoning` field on both samples
(`phase-09/results/20260901T014027Z-prb01-02/prb01.tsv`, verdicts `CONFIRMED`, `CLEAN` flake
window). This is a cleaner result than the research's own finding, which showed `medium` was
non-empty but never established that the *default* was empty by contrast.

**Basis cited:** `phase-09/results/20260901T014027Z-prb01-02/prb01.tsv`,
`phase-09/results/20260901T014027Z-prb01-02/RESULT.md` — this phase's own reproduced values, not
`09-RESEARCH.md`'s.

**Note on the stricter combined rule below (§5):** even though PRB-01 is no longer independently
gate-deciding, `09-04-PLAN.md`'s own §5 verdict rule requires **both** PRB-01 and PRB-04 to be
"decided and positive" for a `Phase 10 진행` verdict. This creates no actual tension here, because
PRB-01's fresh evidence is positive — but it is worth naming explicitly: had PRB-01 come back
negative this phase, that would **not** have been a milestone-ending fact under `CFG-11`'s design,
yet it would still have blocked a clean `Phase 10 진행` verdict under this plan's literal §5 rule
without an explicit read-through to the demotion note. That situation did not arise, so no further
resolution is needed, but a future reader of this document should not assume the two documents
(`REQUIREMENTS.md`'s demotion vs. `09-04-PLAN.md`'s §5 wording) were in perfect alignment by
design — they happen to agree in outcome here because the measured fact is positive.

### 4.2 PRB-04 — 🔴 gate (the milestone's only remaining kill condition)

**Rule (from `REQUIREMENTS.md`):** if the thinking trace accumulates into the next turn's context
**at a token cost**, it compounds v1's confirmed non-pruning-compaction defect and the milestone is
discarded. The rule is explicitly about **measured token cost**, not about whether Cline's
architecture attaches the field — Phase 9 has confirmed Cline's architecture *does* attach it (see
`PRB-04-FINDINGS.md` §3, re-verified independently by 09-03 at `cli-v3.0.53`, working tree clean),
and the gate still passes if the measured cost is nil.

**Which evidence governs, stated before it is applied:** the **controlled replay comparison** in
09-03 (`PRB-04-FINDINGS.md` §1a/§1b) — identical messages, `reasoning`/`reasoning_content` field
present vs. absent, nothing else different, both endpoints, both field names, synthetic **and**
real traces up to 2,497 characters — is **decisive**. 09-02's multi-turn growth numbers
(`PRB-03-ORACLE.md` §3) are **corroborating only**, because that comparison is confounded: the
thinking-ON sequence's replies came back empty (`finish_reason: length`, the 300-token completion
budget entirely consumed by `xhigh` reasoning) while the thinking-OFF sequence's replies were long
plain text, so ON's smaller per-turn growth mixes "reasoning doesn't tokenize into the next prompt"
with "ON's replies happened to be much shorter." If the controlled and multi-turn evidence had
pointed in opposite directions, that would itself be a finding requiring write-up in §3, not an
average. **They do not conflict.** `PRB-04-FINDINGS.md` §1c performed the plan-required
reconciliation directly: an isolated probe of turn 3's own user text (21 tokens) against a
13-token fixed baseline accounts for most of the ON sequence's +23 turn-3 growth as ordinary
turn-boundary/content-token cost, not as evidence that the 917-char reasoning trace fed back that
turn cost anything close to a per-character rate — which is fully consistent with, not contradicted
by, this phase's own controlled measurement that the exact same class of trace costs exactly 0
tokens when replayed directly.

**Real-trace vs. synthetic-trace deltas:** identical. Both are 0. The real-trace measurement
(`PRB-04-FINDINGS.md` §1b, up to 2,497 real captured `xhigh` characters, nearly double the
1,380-character synthetic trace's length) shows **no length-threshold effect** — closing
`09-RESEARCH.md`'s own stated Open Risk #3 with real, not synthetic, evidence. Since the real-trace
result does not differ from the synthetic one, there is no case here of "if the real-trace deltas
differ from the synthetic ones, the real-trace result governs" needing to be invoked — both agree,
and both are cited as the basis below.

**Decision on the fresh evidence:** PRB-04 is **positive** (gate passes). All 16 delta-bearing
readings across `PRB-04-FINDINGS.md` §1a (12 readings: 2 endpoints × 2 field names × 2 mandatory
rounds) and §1b (4 readings: LONGEST/CONCAT × 2 endpoints) are `CONFIRMED` at `delta = 0`, in a
`CLEAN` flake window, with zero retries consumed. Cline's architecture does attach reasoning history
by default for non-Cerebras providers (source-confirmed, §3 of `PRB-04-FINDINGS.md`) — but the
measured token cost of that attachment, in this exact deployed stack, is nil. The gate's rule is
about cost, and the cost is zero.

**Basis cited:** `phase-09/PRB-04-FINDINGS.md` §1a/§1b/§1c, `phase-09/results/20260901T021414Z-prb04/prb04-synthetic.tsv`,
`phase-09/results/20260901T021414Z-prb04/prb04-realtrace.tsv`,
`phase-09/results/20260901T021414Z-prb04/verdicts.tsv` — this phase's own reproduced values, not
`09-RESEARCH.md`'s (which agrees with these values but is not cited as the basis for this decision).

### 4.3 Anti-flake / INDETERMINATE rule

**Stated:** a gate may be decided only on values that `record_verdict` marked `CONFIRMED` or
`CONFIRMED-NEGATIVE`. A `PROVISIONAL-NEGATIVE`, a `DISCARDED-FLAKE`, or an `INDETERMINATE` sample
**may not** decide a gate. If a gate's evidence is `INDETERMINATE`, the verdict is neither "진행"
nor "종료" on that gate's account: the gate is recorded as **UNDECIDED**, the document states
precisely what re-measurement would settle it, and the verdict routes to the Task 3 checkpoint as a
blocked decision rather than either terminal string. A single flaky run must never flip a
milestone.

**Applied:** every one of the 37 verdicts across all three run directories'
`verdicts.tsv` files (7 + 18 + 12) is `CONFIRMED`. Zero `DISCARDED-FLAKE`, zero
`PROVISIONAL-NEGATIVE`, zero `INDETERMINATE`, anywhere, for either gate's evidence. PRB-01's rule
did not need to be invoked (no flaky sample exists to exclude). PRB-04's decisive evidence (§1a/§1b,
16 delta-bearing readings) is entirely `CONFIRMED`; its corroborating evidence (§1c) required no
verdict machinery at all (it is a reconciliation calculation over already-measured numbers, not a
fresh gate-deciding probe). **Neither gate is UNDECIDED.** Had even one of the 16 PRB-04
delta-bearing readings come back `INDETERMINATE` after exhausting the anti-flake round-extension
loop (`probe_prb04_replay.py`'s 3-round cap), this document would record PRB-04 as UNDECIDED and
route to `판정 보류 — 재측정 필요` regardless of what the other 15 readings showed — no single
flaky reading, and no majority of clean readings alongside one indeterminate one, is sufficient to
decide this gate. That situation did not arise.

---

## §5 Verdict

## Phase 10 진행

Both PRB-01 (diagnostic, §4.1) and PRB-04 (🔴 gate, §4.2) are decided, on this phase's own
reproduced values, and both are positive. Per `09-04-PLAN.md`'s §5 rule, this is the only verdict
this phase's evidence supports.

### What would have produced the opposite verdict

This verdict is falsifiable on the following specific measured facts — had any of these come out
differently, the verdict below would not be `Phase 10 진행`:

- **PRB-01:** an empty `reasoning` field at `reasoning_effort: medium` (matching the unspecified
  negative control instead of diverging from it) would have made PRB-01 negative. Under `CFG-11`'s
  demotion this alone would not have ended the milestone, but it would have removed PRB-01 as a
  positive input to §5's combined rule, and this document would have needed to route to a decision
  about whether the demotion note or the plan's literal §5 wording governs — a genuine ambiguity
  flagged in §4.1, not resolved here because it did not arise.
- **PRB-04, the decisive fact:** a **non-zero `prompt_tokens` delta** on any of the 16 controlled
  replay readings (§1a/§1b) — synthetic or real trace, either endpoint, either field name — would
  have meant a replayed reasoning field costs context, which is the exact condition
  `REQUIREMENTS.md` names as compounding v1's confirmed non-pruning-compaction defect. That would
  have produced `마일스톤 종료`, regardless of how clean the corroborating multi-turn numbers looked.
- **A length-threshold effect:** if the 2,497-character real-trace replay had shown a nonzero delta
  where the 1,380-character synthetic trace showed zero, the real-trace result would have governed
  (stated explicitly in §4.2, before the actual reading came in) and PRB-04 would have gone
  negative.
- **A conflict between the controlled and multi-turn evidence:** if the +58/+23 multi-turn growth
  numbers had turned out to be inexplicable by anything other than a per-character reasoning cost
  (i.e. the §1c reconciliation had failed to account for the residual), that conflict would itself
  have been written up as an unresolved finding in §3 and would have prevented a clean positive
  PRB-04 call.
- **Any INDETERMINATE reading among the 16 delta-bearing PRB-04 measurements**, surviving the
  3-round anti-flake cap, would have forced PRB-04 to UNDECIDED and this verdict to
  `판정 보류 — 재측정 필요` instead, per §4.3 — no amount of agreement among the other readings
  would substitute for it.

None of these facts occurred. All 16 controlled readings are `CONFIRMED` at `delta = 0`; the
negative control is clean; the real trace shows no length effect; the corroborating evidence
reconciles without conflict.

### What Phase 10 inherits

- **The reach-probe oracle choice from `phase-09/PRB-03-ORACLE.md`:** use `low` (+28) or `xhigh`
  (+40) — not `medium` or `et-medium`, both of which carry only a −2 token margin, too fragile to
  survive incidental prompt drift — to prove `VRF-01` reach, then deploy the alias at
  `medium`/`et-medium` as designed.
- **The CFG-12 input from 09-01's `RESULT.md`:** `enable_thinking: true` was shown to change model
  behavior (non-empty `reasoning_content`, 30 chars) where `false` and the default show none — this
  is evidence of application, not mere tolerance, and supports building the `flashnext-act` alias
  with `enable_thinking` wired through.
- **The narrowed CFG-16 question from §3.2 above:** Phase 10's `:8011`/`:4000` check for the shipped
  combination should be scoped as "does litellm's alias-level injection deliver `enable_thinking`
  through at all, given the parameter-validation asymmetry with `reasoning_effort`" — not "does the
  combination turn thinking on" (already yes, driven by the `reasoning_effort` half per this
  phase's own measurement).
- **litellm has no hot reload** — Phase 10 owns a restart maintenance window that will interrupt
  Kanban/Telegram traffic. This was never exercised in Phase 9 (stack-unchanged throughout, §1) and
  remains entirely Phase 10's to plan.

---

## §6 Deferral and handoff register

Every open item from `09-RESEARCH.md`'s "Could Not Verify / Open Risks" section, marked `CLOSED`,
`DEFERRED`, or `RECORDED`, each with an owner and one line of rationale. `09-RESEARCH.md` listed
five open risks; one (PRB-02's applied-vs-no-op ambiguity) was **already closed within Phase 9
itself** by 09-01's positive control (see the note below the numbered list) — the remaining four are
items 1, 2, 3, and 5 below, mapped onto this plan's six-entry register alongside two additional
facts (the absolute-baseline shift and the doc false-negative correction) that this phase's work
also surfaced and must not be left unaccounted for.

1. **Real-`xhigh`-trace replay (research Open Risk #3 — "scale of the synthetic reasoning trace")**
   — **CLOSED by Phase 9.** 09-02 Task 2 captured 2,497 real characters of `xhigh` reasoning across
   a 3-turn sequence; 09-03 Task 2 replayed them (LONGEST 989 chars, CONCAT 2,497 chars) at both
   endpoints. All 4 readings `CONFIRMED` at `delta = 0` — no length-threshold effect found. Evidence:
   `phase-09/PRB-04-FINDINGS.md` §1b.
2. **Real-Cline-on-the-wire confirmation (research Open Risk #1)** — **DEFERRED -> Phase 10**, now
   formalised there as **`VRF-04`** in `REQUIREMENTS.md` (observe `reasoning` in a real `cline
   --json` stream for `flashnext-plan` and a control). Nearly free once `flashnext-plan` exists
   (production `providers.json` via `apply_provider_config.sh`/`verify_config.sh`, then diff a 2–3
   turn session against an equal-turn `flashnext` baseline). Phase 9 deliberately did not attempt
   the isolated-`--config` route (`09-RESEARCH.md` §Q1 explains the prior `providers.json`
   normalization failure that route risks). Phase 9's "Cline attaches reasoning history" evidence
   is source-verified only (MEDIUM confidence per `09-RESEARCH.md`), which is the gap `VRF-04`
   closes.
3. **`medium`'s unexplained −2 shorter-than-default system prompt (research Open Risk #5)** —
   **RECORDED, NOT CHASED.** Re-confirmed unchanged by 09-02's fresh sweep (`et-medium` also shows
   the identical −2, see §3.2 above) and blocks nothing — PRB-01's field-presence check already
   settles the operational question of whether `medium` turns thinking on. Tracing the mechanism
   would need the Qwen3.8-Flash-Next chat template and `mlx_vlm.server`'s prompt assembly, both
   outside this repo. **Owner: none — deliberately not assigned, per `09-RESEARCH.md`'s own
   recommendation not to chase it.**
4. **Absolute-baseline shift between `VALIDATED.md` and later measurements** — **RECORDED.** The
   constant −10 offset (`VALIDATED.md` 23/21/51/63 vs. `09-RESEARCH.md`/Phase-9-fresh 13/11/41/53)
   is unexplained and not investigated further; every delta from `unspecified` holds bit-for-bit
   across all three datasets, so the oracle itself is unaffected. Recorded because a future reader
   comparing absolute numbers across documents, rather than deltas, would be misled. **Owner: none
   — the oracle's delta-based design makes chasing this unnecessary** (`PRB-03-ORACLE.md` §5).
5. **The `docs/plan-act-reasoning-implementation.md` false-negative correction** — **DEFERRED ->
   Phase 12** (owns `USE-05`), with file:line edit targets already captured in
   `phase-09/PRB-04-FINDINGS.md` §4 (`docs/plan-act-reasoning-implementation.md:96-100,102`,
   `docs/plan-act-reasoning-diagrams.md:187-191`). Phase 9 recorded, but deliberately did not edit,
   these documents.
6. **litellm request-side schema validation never fully traced (research Open Risk #2)** —
   **DEFERRED -> Phase 10**, re-check if the new alias gets unusual `litellm_params` (e.g. a
   different vendor client wrapper than the plain `openai`-compatible passthrough this phase's
   probes exercised, which returned clean HTTP 200 throughout).

**Note on the item already closed inside Phase 9 (not one of the six above):** research Open Risk
#4 ("PRB-02's `false` result can't distinguish applied from silently-accepted no-op") was closed by
09-01's own `enable_thinking: true` positive control in the same plan that reproduced PRB-02 —
HTTP 200 with a non-empty `reasoning_content` (30 chars) is evidence of application, not mere
tolerance (`phase-09/results/20260901T014027Z-prb01-02/RESULT.md` §"not-rejected vs applied"). This
is why the register above has six entries covering four of the research's five original open
risks plus two additional facts, rather than five.

`grep -cE 'CLOSED|DEFERRED|RECORDED' phase-09/GATE-VERDICT.md` covers items 1 (CLOSED), 2
(DEFERRED), 3 (RECORDED), 4 (RECORDED), 5 (DEFERRED), 6 (DEFERRED) — six matches at minimum.

### End-to-end stack-unchanged proof (re-run now, at verdict time)

```
$ launchctl list | grep -E 'com\.ohama\.(flashnext|role-shim|litellm)'
48525	0	com.ohama.litellm
46573	0	com.ohama.flashnext
75548	0	com.ohama.role-shim
```

These three PIDs are **identical** to the values recorded in
`phase-09/results/20260901T014027Z-prb01-02/pids-before.txt` (the earliest snapshot taken in Phase
9, at 01:40:27Z) and to every other before/after snapshot taken across all three runs (§1). No
`com.ohama.*` service was restarted at any point across the entire phase, from the first probe to
this verdict.

```
$ bash phase-01/config/verify_config.sh
OK: providers.json holds flashnext @ localhost:4000/v1, top-level contextWindow=29000, no models[] override, no codex alias
trigger = maxInputTokens x 0.9 = 26100 — PROVEN to fire: phase-01/results/exp-verify29k/ (2026-08-30, 서버 400 0건)
exit: 0
```

`litellm-config.yaml` and `providers.json` sha256 hashes match the values recorded in every run
directory's `hashes-before.txt`/`hashes-after.txt` (§1) — no config file was written by this phase,
from the first probe to this verdict.

---

*Phase: 09-preflight-gates*
*Plan: 09-04*
*Verdict document written: 2026-09-01*
