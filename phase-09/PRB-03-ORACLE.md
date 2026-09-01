# PRB-03 Oracle — Phase 9 Plan 02

**Run directory:** `phase-09/results/20260901T015706Z-prb03`
**Generated:** 2026-09-01 (UTC timestamps below are as recorded in the run's own `prb03.tsv`/`multiturn.tsv`)

This document reports fresh, independent measurements produced by this phase (09-02). It does
**not** declare a gate verdict. PRB-03 is not a gate; the multi-turn numbers in §3 feed 09-04's
PRB-04 adjudication rather than deciding it here.

---

## §1 Fresh effort sweep

Fixed request shape, held constant across every arm — this is what isolates the effort-driven part
of `prompt_tokens`:

```
POST http://localhost:8011/v1/chat/completions
{"model": "$MODEL", "messages": [{"role": "user", "content": "hi"}], "max_tokens": 4, ...arm-specific keys...}
```

Six arms, the only thing varying is presence/value of `reasoning_effort` and presence of
`enable_thinking`: `unspecified` (neither key), `medium`, `low`, `xhigh`, `et-true`
(`enable_thinking:true` alone), `et-medium` (`enable_thinking:true` **and**
`reasoning_effort:medium` together — the combination `flashnext-plan` will actually ship, CFG-11).

Each of the 12 requests (sweep A, sweep B, 6 arms each) was attributed to its own
`Prefill started` log line by an explicit watermark (line count immediately before firing, then
grep only the newly appended lines, requiring exactly one match) — not by `tail -N` ordering
inference, which a concurrent Kanban/Telegram request could silently corrupt.

| arm | sweep A | sweep B |
|---|---:|---:|
| unspecified | 13 | 13 |
| medium | 11 | 11 |
| low | 41 | 41 |
| xhigh | 53 | 53 |
| et-true | 53 | 53 |
| et-medium | 11 | 11 |

**Sweep A vs sweep B: agree on all six arms, zero variance.** No third sweep was needed — see
`phase-09/results/20260901T015706Z-prb03/sweep-ab-compare.txt`. This is the expected result:
`prompt_tokens` is a deterministic function of tokenized text, not a sampled generation output, so
the only reason to repeat the sweep is to catch the `no Stream(gpu, 1)` flake or incidental drift,
not statistical noise — none was observed (`flake-count.txt` = 0 throughout the whole run,
including Task 2's multi-turn burst below).

Raw evidence: `raw-prb03-{A,B}-{arm}.json` (12 files, all valid JSON), `sweep-lines.txt` (12 raw log
lines), `prb03.tsv`, `verdicts.tsv` (all 12 samples CONFIRMED, CLEAN).

---

## §2 Three-way comparison (unspecified / medium / low / xhigh)

**Absolutes:**

| effort | VALIDATED.md (original) | 09-RESEARCH.md (2026-09-01) | Phase 9 fresh (this document) |
|---|---:|---:|---:|
| unspecified | 23 | 13 | 13 |
| medium | 21 | 11 | 11 |
| low | 51 | 41 | 41 |
| xhigh | 63 | 53 | 53 |

**Delta from `unspecified`, each column:**

| effort | VALIDATED.md delta | 09-RESEARCH.md delta | Phase 9 fresh delta |
|---|---:|---:|---:|
| medium | −2 | −2 | **−2** |
| low | +28 | +28 | **+28** |
| xhigh | +40 | +40 | **+40** |

**Fresh deltas match both prior datasets exactly, bit-for-bit — no divergence found.** This phase's
absolutes also match `09-RESEARCH.md`'s absolutes exactly (13/11/41/53 in both), not just the
delta — the baseline shift documented below happened once, between `VALIDATED.md` and
`09-RESEARCH.md`'s measurement session, and has not moved further since. The oracle's
delta-based design is what makes this stable: the effort-driven part of `prompt_tokens` is
reproducible across sessions weeks apart even while the absolute baseline is not (see §5).

---

## §2b The shipped combination (`enable_thinking:true` + `reasoning_effort:medium`, new 2026-09-01)

| arm | absolute | delta from unspecified |
|---|---:|---:|
| xhigh (reference) | 53 | +40 |
| et-true (`enable_thinking:true` alone) | 53 | **+40** |
| medium (reference) | 11 | −2 |
| et-medium (`enable_thinking:true` + `reasoning_effort:medium`, the shipped combination) | 11 | **−2** |

**Question 1 — does `enable_thinking:true` alone reproduce `xhigh`'s delta, as VALIDATED.md §4
claims?** **Confirmed.** `et-true` = 53, identical to `xhigh` = 53, to the token. The delta
(+40) matches exactly, not just approximately.

**Question 2 — does adding `enable_thinking:true` rescue `medium` from its unusably tight ~−2
margin?** **No — refuted.** `et-medium` = 11, identical to `medium` alone = 11. The delta is
still exactly −2. Adding `enable_thinking:true` on top of an already-explicit
`reasoning_effort:medium` produced **zero** additional change in `prompt_tokens`, in either
direction. The shipped combination inherits `medium`'s fragile margin unchanged; it does not
rescue it.

This is a **token-margin measurement only**. Whether `et-medium` actually produces a `reasoning`
field through the alias — i.e. whether `enable_thinking` is doing anything at all once
`reasoning_effort` is already explicit, or is silently redundant/no-op'd at that point — is
**CFG-16**, owned by Phase 10 and measured through `:8011` and `:4000` directly. This document
does not claim an answer to that; it only reports that the *token cost* of the combination is
indistinguishable from `medium` alone.

---

## §3 Multi-turn growth (ROADMAP criterion 4)

Two sequences of 3 turns each, `:8011` direct, identical fixed 3-turn user script for both:
1. "세 자리 수 중 각 자리 숫자의 합이 7인 가장 큰 수는?"
2. "그 수에서 백의 자리와 일의 자리를 바꾸면 얼마나 줄어드나?"
3. "왜 그런지 한 줄로 설명해줘"

**Sequence ON** (`reasoning_effort: xhigh`, each turn's `reasoning_content` fed back into the next
turn — mirroring Cline's default `shouldIncludeReasoningHistory` behavior for our non-Cerebras
provider). **Sequence OFF** (no `reasoning_effort`, no reasoning fed back). Both capped at
`max_tokens: 300` per turn.

| sequence | turn | prompt_tokens | growth vs prev turn | content chars | reasoning chars |
|---|---:|---:|---:|---:|---:|
| ON | 1 | 69 | NA | 47 | 591 |
| ON | 2 | 127 | +58 | 0 | 917 |
| ON | 3 | 150 | +23 | 0 | 989 |
| OFF | 1 | 29 | NA | 564 | 0 |
| OFF | 2 | 360 | +331 | 548 | 0 |
| OFF | 3 | 681 | +321 | 66 | 0 |

**Reading.** Turn-over-turn growth is far smaller for ON (+58, +23) than for OFF (+331, +321),
despite ON feeding back 591–989 characters of real `xhigh` reasoning into context on every
subsequent turn while OFF fed back none. This is directionally consistent with
`09-RESEARCH.md`'s single-shot replay finding that a fed-back `reasoning_content` field costs zero
extra `prompt_tokens` — larger reasoning payloads did not translate into larger context growth
here.

**However, this comparison is confounded by reply-length differences and must not be read as a
controlled experiment.** OFF's assistant replies were much longer in plain content (564, 548, 66
chars) than ON's (47, 0, 0 chars) — and ON's turns 2 and 3 came back with **empty** content
entirely, because `xhigh` reasoning alone consumed the full 300-token completion budget before any
answer text could be produced (`finish_reason: length` on both turns 2 and 3; see
`raw-multiturn-ON-t2.json`, `raw-multiturn-ON-t3.json`). So ON's smaller growth reflects at least
two entangled effects — "reasoning content doesn't tokenize into the next prompt" and "ON's replies
happened to be much shorter/empty" — and this probe cannot separate them. The controlled,
single-shot replay probe in plan 09-03 (identical messages, `reasoning_content` field present vs.
absent, nothing else different) is the decisive measurement for the PRB-04 gate; this multi-turn
result is corroborating evidence only.

**Real trace capture for 09-03.** 2,497 total characters of real `xhigh` reasoning were captured
across the three ON turns (591 + 917 + 989), saved to
`phase-09/results/20260901T015706Z-prb03/realtrace-t1.txt`,
`realtrace-t2.txt`, `realtrace-t3.txt`, with lengths recorded in
`realtrace-capture.tsv`. All three turns produced non-empty traces; none was empty, so no
INDETERMINATE trace-capture outcome applies here. These are real captured traces, not synthetic
text, closing `09-RESEARCH.md` open item #1 (its zero-cost finding used a ~1,380-char synthetic
trace).

---

## §4 Oracle declaration for Phase 10

On the strength of the fresh deltas in §2 and §2b:

- **`low` (+28) and `xhigh` (+40) are usable as the VRF-01 reach probe.** Both margins are far
  larger than any plausible incidental prompt drift (the entire observed VALIDATED.md-to-fresh
  baseline shift was only −10 tokens across the whole session, see §5 — both +28 and +40 comfortably
  exceed that).
- **`medium` must not be used as the reach probe.** Its ~−2 token margin is too tight to survive
  incidental prompt drift and could be flipped by an unrelated system-prompt revision. Phase 10
  should prove reach with `low` or `xhigh`, then deploy the alias at `medium`.
- **`et-medium` (the shipped combination) is also not usable as its own reach probe** — §2b shows
  its delta is exactly −2, identical to `medium` alone; adding `enable_thinking:true` did not widen
  the margin at all. Phase 10 must prove reach with a different arm (`low`, `xhigh`, or `et-true`,
  which reproduces `xhigh`'s +40 margin) and then deploy the alias at `et-medium` — this is a
  **weaker proof** than proving reach with the exact shipped arm, and should be labelled as such in
  Phase 10's own documentation rather than presented as if `et-medium`'s own margin had been used.
- **The oracle is valid as a delta, never as an absolute.** See §5 — the absolute baseline has
  already been observed to shift once across sessions while every delta stayed bit-for-bit
  identical. Any future reader comparing absolute `prompt_tokens` numbers across documents must
  read them as deltas from that document's own `unspecified` baseline, not as portable constants.

---

## §5 Known unexplained observations (recorded, not chased)

Both flagged by `09-RESEARCH.md`, both explicitly non-blocking, both independently reproduced by
this phase rather than merely re-cited:

**Absolute-baseline shift.** `VALIDATED.md`'s absolutes (23/21/51/63) and this phase's fresh
absolutes (13/11/41/53) differ by a constant **−10** offset, while every delta from `unspecified`
is preserved bit-for-bit. `09-RESEARCH.md` measured the same −10 offset weeks earlier and this
phase's fresh numbers show no further drift beyond that — the shift happened once, cause not
investigated (plausibly a different exact user-message tokenization or a minor system-prompt
revision between measurement sessions). Consequence: a future reader comparing absolute numbers
across `VALIDATED.md` and later documents will be misled unless they read this note; the oracle
itself is unaffected because it is used as a delta (§4).

**`medium`'s system prompt is shorter than unspecified (−2), and `enable_thinking:true` does not
change that (§2b).** Unexplained at the chat-template level; tracing it would require the
Qwen3.8-Flash-Next chat template and `mlx_vlm.server`'s prompt assembly, both outside this repo. It
blocks nothing — PRB-01's direct `reasoning`-field check (plan 09-01) already settles the
operational question of whether `medium` turns thinking on (it does: non-empty `reasoning`,
179 chars, confirmed with a negative control). **Do not chase it.** Recorded so it is not
rediscovered as a surprise, and so that §2b's "`et-medium` doesn't rescue `medium`'s margin"
finding is read as a token-margin fact, not evidence about whether `enable_thinking` is applied
(that is CFG-16, Phase 10's job).

---

## §6 Requirement mapping

- **PRB-03** — this document is its evidence: the effort/enable_thinking sweep oracle (§1–§2b) is
  independently re-measured, its deltas agree exactly with both prior datasets, and its usability
  as a Phase 10 reach probe is declared (§4).
- **ROADMAP Phase 9 success criterion 4** ("thinking on/off 로 각 3턴 이상 실행한 두 시퀀스의
  `prompt_tokens` 증가폭이 비교·기록된다") — satisfied by §3.
- **VRF-01 / VRF-02** (Phase 10, downstream consumers) — §4's oracle declaration is exactly the
  instrument VRF-01 needs ("동일 사용자 메시지를 `flashnext` 와 `flashnext-plan` 으로 각각 보냈을
  때 서버 로그의 `prompt_tokens` 가 다르다"), and VRF-02's requirement that the judgment rest on
  server-side evidence (not HTTP 200) is exactly the watermark-attributed `Prefill started` log
  line this document's every number traces back to.

---

This document reports measurements and an oracle choice, not a gate verdict. PRB-03 is not a gate;
the §3 multi-turn numbers and the §2b margin finding feed 09-04's PRB-04 adjudication rather than
deciding it here.
