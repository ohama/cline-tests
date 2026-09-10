# PHASE-12-FINDINGS.md — Phase 12 requirement and criterion account, and the v1.1 milestone close

Plan 12-08. This document is the phase's account of itself: what changed in each document, whether
USE-04/USE-05 and the three ROADMAP Phase 12 success criteria were met, which of this milestone's
own earlier claims were corrected and why the error happened, and — the section that matters most —
which of those verdicts are weaker than they look. Following `phase-10/PHASE-10-FINDINGS.md` §4 and
`phase-11/PHASE-11-FINDINGS.md` §5's own convention for that section.

**Outcome neutrality, stated once, up front, as both prior phases' findings state it:** this
document reports the phase as it happened. The sweep passing and the hand audit reaching 9/9 are
recorded as what was checked and what was found, not smoothed into a green row — including the one
real documentation bug this phase's own hand audit found and fixed, which neither wave 1's assertion
table nor wave 2's per-plan checks caught.

---

## §1 What changed, per document

Eleven documents, matching exactly the eleven paths `phase-12/verify_docs.sh` tracks
(`FILE_LIST`), across plans 12-02 through 12-07. A twelfth file, `docs/manual/04-32k-operations.md`,
received a one-sentence annotation in 12-06 but is not one of the eleven — it carries no
`verify_docs.sh` assertions of its own and is noted separately below the table for that reason.

| Document (plan) | What it said | What it says now | Evidence |
|---|---|---|---|
| `docs/plan-act-reasoning-implementation.md` (12-02) | "상태: 계획. 미착수." Reasoning history claimed **not** re-attached ("누적의 증거가 아니다"; "`reasoning`을 아웃바운드 메시지에 싣는 코드는 발견되지 않았다"). Shell-function wrapper sketch presented as the plan. | "구현됨(v1.1)" — aliases (Phase 10) and wrappers (Phase 11) shipped; `cline-plan → flashnext-plan` is `keep` by human override, not by measured improvement (full disclosure quartet). Reasoning **is** re-attached (`shouldIncludeReasoningHistory`); kept explicitly separate from the still-true zero-token-cost finding. Shell sketch superseded, pointed at the shipped `phase-11/cline-plan`/`cline-act`. Original preserved verbatim in a new §9 appendix. | `phase-09/PRB-04-FINDINGS.md` §3, `phase-11/WRAPPER-DESIGN.md` §2, `phase-11/AB-RESULTS.md` §11 |
| `docs/plan-act-reasoning-design.md` (12-03) | "상태: 제안. 아직 구현되지 않았다." Same superseded shell sketch. `--thinking` presented as a flat 400. | "상태: 채택됨." Both gate verdicts stated with their real reasons (Gate ① zero-cost, not omission; Gate ② no accuracy benefit, `keep` by override). `--thinking` qualified per alias prefix (400/500/exit 1). Sketch superseded, pointer to shipped wrappers. Original preserved in appendix. | `phase-09/GATE-VERDICT.md`, `phase-11/WRAPPER-DESIGN.md`, `phase-11/OPEN-ITEMS.md` Open Item 1 |
| `docs/plan-act-reasoning-diagrams.md` (12-03) | "상태: 계획, 미착수." Gate ① callout: "소스 조사는 '누적되지 않는다' 쪽을 가리킨다." | "상태: 구현됨." Gate ① callout corrected: source shows reattachment **is** real; the zero-token-cost reason for why the gate still passed stated separately. Mermaid diagram itself left unredrawn; K2/K6 dispositions added as an annotation beneath it. Web-mirror row given a staleness caveat. Original preserved in appendix. | `phase-09/PRB-04-FINDINGS.md` §3, `phase-09/GATE-VERDICT.md` §4.2 |
| `docs/manual/01-cli.md` (12-04) | Zero mentions of `cline-plan`/`cline-act`/`flashnext` anywhere in the file. §6's `--mode` claim stood unqualified, sourced to a Phase 8 static `strings` scan. | New §6a: invocation by path, the four-flag whitelist, full exit-code table (with the exit-4-is-not-failure caveat stated twice), `providers.json` write framed as **contained**, never fixed/resolved, dated to commit `017c65e`; §7's honest limitations (dash-prefixed prompts refused, ~15 real flags unreachable, config guard aborts not heals) named explicitly; full A/B disclosure quartet. §6 reconciled: names which evidence (a live 3.0.61 invocation) superseded which (a static 3.0.53 scan) without deleting either flag name; `GAP-PLANMODE` explicitly scoped to `phase-04/run_headless.sh`, not conflated with the wrappers. | `phase-11/WRAPPER-DESIGN.md`, `phase-11/wrapper_common.sh`, `phase-11/AB-RESULTS.md` §11 |
| `docs/cline-config-pins.md` (12-05) | Only Phase 1's four pins (`cline` version, `kanban` version, compaction mode, model). No v1.1 alias record at all. | New §7: the five live aliases (prefix, injected params, status) in a table; the six removed `qwen-*` aliases named historical; `flashnext-reach-xhigh` decided **verification-only, v1.2 removal candidate**, with the explicit "+40 belongs to `flashnext-reach-xhigh`, not the shipped `flashnext-plan` (−2)" disclosure; `--thinking`'s three prefix-dependent outcomes (400/500/exit 1); the pin-vs-measurement rule (names/prefixes/`model`/`contextWindow` are pins; absolute `prompt_tokens` and `max_tokens` are measurements that have already drifted). | `phase-10/REACH-PROOF.md` §3, `phase-11/OPEN-ITEMS.md` Open Item 1, `phase-12/SCOPE-DECISIONS.md` items 3, 7, 8 |
| `docs/32k-compaction-policy.md` (12-06) | §4/§8 (added after the 2026-08-30 correction round): "`max_tokens` 실측값은 `2048`." — fixed wire value, overshoot arithmetic built on it. | Second, additively-stacked 2026-09-10 banner (the 2026-08-30 banner and its own appendix untouched). `max_tokens` is dynamic, sized per request toward `contextWindow × 0.9`, on a 278-sample basis (range 9,442–32,013, zero breaches of the server's 32,768 limit). The overshoot table's `+max_tokens` column marked void; the real `trigger`/`+오버슈트` measurements left standing. | `phase-11/OPEN-ITEMS.md` Open Item 2, `phase-11/AB-PROTOCOL.md` §3, `phase-11/PHASE-11-FINDINGS.md` §5.3 |
| `docs/cline-max-tokens-findings.md` (12-06) | "**`OBSERVED_MAX = 2048`.**" stated as current fact; Branch A budget arithmetic built on it. | No fixed `OBSERVED_MAX` asserted. States the single-sample generalisation that produced `2048`, the `20983` like-for-like remeasurement, and the 278-sample dynamic-sizing finding — without overclaiming it into a guarantee. Branch A's premise (`OBSERVED_MAX < 6226`) stated **void, not re-derived** — no new branch decision invented. Original §2/§4/§5 preserved verbatim in a new §9 appendix. | `phase-11/OPEN-ITEMS.md` Open Item 2, `phase-11/AB-PROTOCOL.md` §3 |
| `howto/fast-and-deep-mode.md` (12-07, plus one further fix in 12-08) | Top banner: "방법 2 — 진행 중", "방법 3 — Phase 11 예정" (mid-milestone in-progress language). **Also**, undetected by wave 1/2: "`-m`... `providers.json` 을 건드리지 않으므로... 안전하다" — a false claim that `-m` does not write `providers.json`. | Both methods stated as shipped, with the 400-vs-500 per-prefix distinction footnoted. **The `-m`/`providers.json` sentence, found by this plan's own hand audit (`phase-12/anti-overclaim.md` claim 6) and fixed here**: `-m` unconditionally rewrites `providers.json`'s `model` field on every call (measured 31/31, 100%); this raw, un-wrapped path is not contained, and the wrapper (method 3) is what contains it. | `phase-10/PHASE-10-FINDINGS.md`, `phase-11/WRAPPER-DESIGN.md` §2, `qanda/004-does-cline-always-write-providers-json.md` |
| `howto/thinking-and-reasoning-effort.md` (12-07) | "**현재는 아니다.** 소스상 연결이 없다... 그 둘을 잇는 것이 v1.1 의 목표다" — Plan/Act and reasoning effort presented as unlinked, a future goal. | "연동된다 — cline 소스 밖에서, 래퍼가" — linked, via the wrapper, outside cline's own source; the underlying source observation (no in-source link) preserved as the reason the link had to be built externally rather than deleted as wrong. | `phase-11/cline-plan`, `phase-11/cline-act` |
| `qanda/001-testing-plan-act-with-cline-cli.md` (12-07) | "래퍼의 기본 별칭은 아직 확정 전입니다... 사용자 비준을 기다리는 중입니다" — awaiting ratification. | Self-corrected in place, `qanda/004`'s own convention: the original wrong sentence kept quoted inside a dated blockquote, escape-marked (`<!-- verify_docs:allow -->`); the actual `keep`-by-override decision stated below it, with the already-correct no-improvement bullet (25/30 vs 25/30, p=0.563) preserved and explicitly linked to the override reasoning. | `phase-11/AB-RESULTS.md` §11 |
| `qanda/003-how-the-wrappers-work.md` (12-07) | "**오염을 막지 못합니다. 사후 탐지만 합니다.**" — detection-only. | Self-corrected in place, same convention: original quoted, escape-marked; the `mktemp`-based containment stated (`CLINE_PROVIDER_SETTINGS_PATH`, commit `017c65e`, exit-3-on-failure), explicitly framed "격리됐다, 고쳐진 게 아니다" (contained, not fixed) — the unconditional write in cline's own startup path is untouched, and the containment has one day of history. | commit `017c65e`, `phase-11/AB-RESULTS.md` §11 |

**`docs/manual/04-32k-operations.md`** (touched in 12-06, not one of the eleven): §3's
`trigger + 3,100 + max_tokens < MAX_KV_SIZE` formula carries a new one-sentence note that
`max_tokens` is not a small constant, pointing at `docs/cline-max-tokens-findings.md` — the page is
otherwise untouched, and it carries no `verify_docs.sh` assertions of its own.

---

## §2 Requirement table

| Requirement | Disposition | Evidence path |
|---|---|---|
| **USE-04** — `docs/manual/01-cli.md` carries usage; `docs/cline-config-pins.md` carries aliases/params as pins; `--thinking`'s litellm-400 fact is stated | Met — **the requirement's own "400" wording is imprecise, annotated below in `.planning/REQUIREMENTS.md`, not silently reworded** | `docs/manual/01-cli.md` (`test -e`) §6a; `docs/cline-config-pins.md` (`test -e`) §7; `phase-12/results/CURRENT_GREEN_RUN` (`test -e`); `phase-12/anti-overclaim.md` (`test -e`) claims 3, 7, 9 |
| **USE-05** — `docs/plan-act-reasoning-design.md`/`-implementation.md` updated with the measured outcome | Met | `docs/plan-act-reasoning-design.md` (`test -e`); `docs/plan-act-reasoning-implementation.md` (`test -e`); `docs/plan-act-reasoning-diagrams.md` (`test -e`, updated alongside though not separately named by the requirement text); `phase-12/results/CURRENT_GREEN_RUN` (`test -e`); `phase-12/anti-overclaim.md` (`test -e`) claim 1 |

---

## §3 ROADMAP Phase 12 criterion table

| Criterion | Evidence path |
|---|---|
| **1** — `docs/manual/01-cli.md` reflects `cline-plan`/`cline-act` usage (USE-04) | `docs/manual/01-cli.md` (`test -e`) §6a — wrapper invocation, whitelist, exit codes, containment framing, limitations |
| **2** — `docs/cline-config-pins.md` gets alias/param pins, and states `--thinking`'s litellm-400 fact (USE-04) | `docs/cline-config-pins.md` (`test -e`) §7.1 (alias table), §7.4 (per-prefix status codes) — **the criterion's own flat "400" wording is annotated in `.planning/ROADMAP.md` below, alongside the same annotation to USE-04** |
| **3** — `docs/plan-act-reasoning-design.md`/`-implementation.md` status badges move from "제안/계획" to this milestone's measured outcome (USE-05) | `docs/plan-act-reasoning-design.md` (`test -e`), `docs/plan-act-reasoning-implementation.md` (`test -e`) — both banners now read 채택됨/구현됨 with both gate verdicts and their reasons |

---

## §4 The corrections this milestone made to its own earlier claims

Each was believed and acted on. Stated as *what was concluded, what was actually true, and why the
error happened* — not just the corrected value.

**"Cline doesn't re-attach reasoning to context"** — it does. `shouldIncludeReasoningHistory`
(`sdk/packages/llms/src/providers/ai-sdk.ts:284-289` at `cli-v3.0.53`) returns `true` by default for
non-Cerebras providers; Phase 9's original source reading missed this and concluded the opposite.
The gate (PRB-04) passed because replayed reasoning costs **zero** measured tokens on this stack
(16/16 at `delta=0`, two endpoints, two field names, synthetic and real traces up to 2,497 chars),
not because it is omitted. *The conclusion (gate passes) survived; the stated reason (nothing is
re-attached) was wrong.*

**"`-m` doesn't persist"** — a **scoping error**, not version drift. Phase 9 read
`session-runtime.ts:109-113` (the connectors' — Slack/Telegram/Kanban — *read* path for the model
field) and correctly found no write there, then generalized that finding to "no write anywhere,"
without ever checking `apps/cli/src/main.ts`, the CLI's own *write* path, which unconditionally calls
`saveProviderSettings({ model: config.modelId, ... })`. Identical code at `cli-v3.0.53` and
`cli-v3.0.61` (`git diff` shows one unrelated line changed). *A module's absence of a write was
generalised to the whole binary's absence of any write.*

**"Cline doesn't use `--thinking`"** — true at `cli-v3.0.53`, false at the installed 3.0.60+, where
`--thinking <level>` is a real flag and a client-sent `reasoning_effort` overrides the alias's
injected value (litellm merges client kwargs after `litellm_params`). *Version drift, and CFG-05
(auto-update not actually blocked) is why the binary moved out from under the original reading.*

**Absolute `prompt_tokens` drifted** 23/21/51/63 → 13/11/41/53 while every delta
(medium −2, low +28, xhigh +40) held bit-for-bit across three independent measurement rounds weeks
apart. Cause never established — left unresolved intentionally, see §5. *The oracle
was always the delta; the absolutes were never the measurement, even before this was stated this
plainly.*

**`max_tokens` was never fixed** — a single historical sample (`2048`) generalised into a constant
that two documents' arithmetic then rested on. Measured: `20983` on a like-for-like remeasurement,
and dynamic per-request sizing toward `contextWindow × 0.9` across 278 samples (9,442–32,013, zero
breaches of the 32,768 server limit). *One sample was read as a ceiling; it was a data point.*

**Unexplained, and left so:** Phase 10's VRF-04 observed `model` unchanged at cline 3.0.60 against
source that is byte-identical to 3.0.53 and 3.0.61 for the relevant path. Phase 11 observed the same
call pattern move `model` on 31/31 (100%) occasions at cline 3.0.61. `phase-11/PHASE-11-FINDINGS.md`
§5.8's own honest reading — that the single 3.0.60 observation is the more likely outlier, given
31 samples on one side against 1 on the other and identical-looking source — is carried forward here
unchanged. **No mechanism is proposed.** Recording it unexplained, rather than inventing an
explanation to make the record feel complete, is the correct outcome.

---

## §5 Disclosures — what is weaker than it looks

This is the section that matters most, in the spirit of `phase-10/PHASE-10-FINDINGS.md` §4 and
`phase-11/PHASE-11-FINDINGS.md` §5.

### 5.1 This phase verified documents, not behaviour

`phase-12/verify_docs.sh` proves a sentence is present (or absent) in a file. It never runs `cline`,
never calls litellm, and never re-executes a probe. Every correction in §1 above rests on Phase 9–11
measurements this phase did not re-run — this phase's own contribution is that the *documents* now
say what those measurements found, not that the underlying system was re-checked today. If Phase
9–11's measurements themselves need re-verifying, that is out of this phase's scope and remains
exactly as provisional as those phases' own findings documents disclosed it to be.

### 5.2 Every version-dependent claim is provisional while CFG-05 is unresolved

The binary drifted `3.0.53 → 3.0.60 → 3.0.61` across Phases 10 and 11, and, per
`phase-11/PHASE-11-FINDINGS.md` §5.5, was found **entirely removed from disk mid-plan** once (11-04),
consistent with an interrupted self-update. `CLINE_NO_AUTO_UPDATE=1` is not proven to work. Every
per-prefix status code, every flag-existence claim, and every exit-code contract this phase documented
was measured against whichever version happened to be installed at measurement time — a future
silent version change could invalidate any of them without this phase's documents knowing.

### 5.3 The A/B's own limits, restated because this phase's documents now carry its conclusion widely

The request cap stopped the main A/B at **66 of 88 authorised cells**. **Never measured at all: task
08 (both bug-localisation tasks) and arm B (the prefix control) in their entirety**, and 4 of arm C's
5 reps on task 07. The equal-N slice (tasks 01–06, N=5 each) is the only comparison that is actually
apples-to-apples: arm A 25/30, arm C 25/30, p=0.563. This phase's documents state this accounting
correctly (see `phase-12/anti-overclaim.md` claims 1–2), but every one of them is now a wider surface
for the same underlying limited-power result to be read past — the more places a correct-but-partial
result is repeated, the more places a future skim could still get it wrong, even though none did
this time.

### 5.4 The containment has one day of history and no production track record

`phase-11/wrapper_common.sh`'s `mktemp`-based `providers.json` isolation (commit `017c65e`) shipped
2026-09-10, the same day this phase closes. It is described throughout this phase's documents as
**contained**, never fixed or resolved, per claim 4's audit — but "contained" itself rests on one
day of measurement (two wrappers, a handful of calls) against zero hours of unattended production
use. The underlying unconditional write in cline's own startup path is untouched; a raw, un-wrapped
`cline -m` call still corrupts the shared file today, exactly as before.

### 5.5 Real-workload compaction still does not prune, and `--compaction basic` is still untested

Both carried forward, unchanged, from v1: `cline-bench` real-workload passes remain **0 of 4**, and
`contextWindow` is not the lever for that defect (PRB-04's zero-cost gate confirms the interaction
without resolving it). `--compaction basic` has never been tested on this stack. Neither is touched
by this phase's documentation-only scope, and no document written or corrected in this phase implies
otherwise.

### 5.6 CFG-05 remains unresolved

`CLINE_NO_AUTO_UPDATE=1` does not actually prevent the installed `cline` from changing version. The
binary self-removed from disk mid-plan once during Phase 11 (§5.2 above). This is the root cause
behind two of §4's corrections (the `--thinking` flag appearing, and the unresolved VRF-04
contradiction being at least plausibly version-related) and remains open, carried to v1.2+.

### 5.7 The unexplained Phase 10 VRF-04 vs Phase 11 31/31 contradiction

Restated from §4 because it is a disclosure as much as a correction: this phase did not, and could
not, resolve it. It is recorded as unresolved in every document that mentions the `providers.json`
mechanism's discovery history, not smoothed into either side's number.

### 5.8 Grader defects this phase's wave 2 surfaced, recorded because they outlive this phase

`phase-12/verify_docs.sh` is a documentation-string checker, not a general-purpose one, and wave 2's
own execution surfaced three defect classes worth carrying forward to any future checker of this
shape:

1. **Marker collision.** `12-02`'s first draft of `docs/plan-act-reasoning-implementation.md` quoted
   the literal appendix marker text (`부록 — 정정 전 기록`) in a cross-reference near the top of the
   corrected live body. The live/appendix splitter triggers on the **first** occurrence of that
   literal string anywhere in the file, so quoting it early silently reclassified almost the entire
   corrected document as "appendix" — exempting it from `FORBIDDEN`/`CITED_PATHS_EXIST`/
   `TAG_CITATION`/`AB_DISCLOSURE`, which only scan the live body. It was caught only because
   `TAG_CITATION` reported **"does not cite `cli-v3.0.53` (check not triggered)"** rather than a
   pass or a fail — a checker that reports *non-triggering* explicitly is worth more than one that
   only ever reports pass/fail, because a silently-skipped check and a genuinely-passing check look
   identical from the outside otherwise. This is a design property worth keeping in any future
   checker of this shape, not just an incident report.
2. **Substring false-positive.** `docs/cline-max-tokens-findings.md`'s original §4 sentence "Branch
   A/B1/B3 는 이 두 스크립트를 건드릴 필요가 없다" contains the literal substring `A/B` (from
   `A/B1`), which unconditionally tripped `AB_DISCLOSURE` — a check with no relationship to this
   file's actual subject (`max_tokens` sizing), demanding disclosure elements (`p=0.563`, `25/30`,
   override language) that had nothing to do with the sentence. `AB_DISCLOSURE`'s trigger is a bare
   substring match; it cannot distinguish "the A/B experiment" from "Branch A, B1, and B3."
3. **Glob citations are flagged as dead paths, correctly per spec, but worth noting as a usage
   constraint.** `CITED_PATHS_EXIST` resolves every backtick-cited token against the real filesystem;
   a glob like `` `phase-09/probe_*.sh` `` or `` `phase-09/results/*-prb01-02/prb02.tsv` `` never
   resolves, because `test -e` does not expand globs. This is the checker working as designed (a
   glob is not a citation of a specific artifact), but two wave-2 plans (`12-06`, `12-07`) each had
   to resolve a pre-existing glob citation into a concrete path to pass — worth stating explicitly so
   a future document author does not write a glob citation expecting it to pass.

**The residual gap this project already knew about, restated because it is the reason claim 1's hand
audit exists rather than a mechanical check:** `AB_DISCLOSURE`'s trigger is a literal-string match
(`'A/B'` or `'AB-RESULTS'`). A document discussing the A/B purely in Korean paraphrase, using
neither literal, would dodge the check entirely. No such document was found in this phase's eleven
targets (checked by reading every A/B-adjacent paragraph by hand — `phase-12/anti-overclaim.md`
claim 1), but the gap itself is not closed and is not closeable by this class of checker; it is
closed, if at all, only by a human reading the prose, every time.

### 5.9 A hand-audit finding the mechanical sweep missed, recorded as a method lesson

`phase-12/anti-overclaim.md` claim 6 found a real, live, false sentence in
`howto/fast-and-deep-mode.md` (that `-m` "does not touch `providers.json`," when it unconditionally
does) that no `FORBIDDEN` literal in `phase-12/verify_docs.sh` was ever written to catch, because
wave 1's assertion table was built against the eleven documents' *already-known* debt, and this
sentence was not among it. It was caught only by reading the document as a user would and noticing
it contradicted `qanda/001`/`qanda/004`'s corrected accounts of the same mechanism — exactly the
"mechanical sweep necessary, not sufficient" property this plan's own objective states. It is fixed
(`howto/fast-and-deep-mode.md:161-168`) and re-verified (`phase-12/verify_docs.sh` still `CASES
134/134`, exit 0). Recorded here as a finding about method, following
`phase-10/PHASE-10-FINDINGS.md` §4.6's own precedent for naming this pattern once rather than as a
buried footnote: a checker's clean run proves what it was told to check, never what it wasn't.

---

## §6 Scope decisions

Cross-referenced, not restated: `phase-12/SCOPE-DECISIONS.md` records all eight scope decisions this
phase made or inherited, with their reasons — `max_tokens` dynamism in scope (item 1),
`howto`/`qanda` staleness in scope (item 2), `flashnext-reach-xhigh` staying as a documented,
verification-only, v1.2-removal candidate (item 3), `-p` superseding the static `--mode` scan without
resolving `GAP-PLANMODE` (item 4), the "three, not four" `howto/` count (item 5), the
`cli-v3.0.53`-citation-form requirement (item 6), `providers.json`'s point-in-time framing (item 7),
and the per-prefix `--thinking` status-code correction this document's own §2/§3 tables above cite
as satisfying USE-04/criterion 2 (item 8). All eight were read again before this document was
written; none needed revisiting.

---

**Closing line, as both prior phases' findings documents do:** this document reports the phase's
results. It does not adjudicate the milestone.
