# Candidate x Root-Cause Matrix

Plan `07-14` (gap closure, wave 13). Pure analysis over evidence already on disk — zero live bench
runs, zero model calls. Every number below is quoted or arithmetically derived from
`phase-07/results/20260831T003728Z-context-forensics/{token-ladder.tsv,compaction-events.tsv,CONTEXT-FORENSICS.md}`
and `phase-07/results/20260831T004024Z-classifier-audit/CLASSIFIER-AUDIT.md`
(`match-provenance.md` for the discord-trivia rejection quote), plus
`phase-07/results/20260831T010013Z-reclassify/RECLASSIFICATION.md` for the synthetic-vs-real
compaction comparison. `docs/32k-compaction-policy.md` and `docs/cline-max-tokens-findings.md`
supply the standing formulas (`trigger = maxInputTokens x 0.9`) and the CLI flag surface.

## 0. Per-task required headroom (arithmetic)

`required_headroom = (attempted prompt_tokens + max_tokens at the fatal request) - 32,768`. Where
the peak came from a rejected request (never queued), the attempted figure is used, per this
plan's instruction, not the accepted-only ledger figure.

| task | fatal prompt_tokens (attempted) | max_tokens at fatal request | attempted sum | MAX_KV_SIZE wall | **required headroom (deficit)** | source |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `telegram-plugin-refactor` | 36,155 | 2,048 | 38,203 | 32,768 | **5,435** | token-ladder.tsv row 7 (`rejected-maxkv`); server-log line 168 |
| `v-edit-workspace-tests` | 30,843 | 2,048 | 32,891 | 32,768 | **123** | token-ladder.tsv row 15 (`rejected-maxkv`); server-log line 338 |
| `discord-trivia-approval-keyerror` | 31,179 | 2,048 | 33,227 | 32,768 | **459** | CLASSIFIER-AUDIT.md §1 row 1, quoting server-log line 1222 verbatim: "Request needs 33227 context tokens (31179 prompt + 2048 max generation), but MAX_KV_SIZE is 32768" |

All three fatal requests independently show `max_tokens=2048` — the observed floor
(`docs/cline-max-tokens-findings.md` §2/§3: `providers.json`'s `maxTokens` field, tried at 512,
4096, and 77 across two separate probes, never changed the wire value). This floor recurring
identically across three unrelated tasks, three different conversation lengths, and both stored
run directories is itself evidence it is a hard internal default, not a per-task artifact.

**Caveat carried forward from 07-11 (`CONTEXT-FORENSICS.md` §5):** cline's own internal token
accounting and the server's real tokenizer disagree by a wide, non-constant margin on these same
trajectories — three different "before" figures were recorded for the telegram compaction alone
(38,626 / 45,507 / ~33,920 vs. the real 36,155). Any arithmetic below that projects a *hypothetical*
value (a different `contextWindow`, a different `max_tokens` floor) inherits this same
several-thousand-token uncertainty. Where a margin computed below is smaller than roughly 3,000
tokens, it is flagged as **not a safe margin**, not as a proof of survival.

## 1. Root-cause mechanisms (one row per distinct mechanism)

| # | Mechanism | Tasks | Key measured numbers | Confidence |
| --- | --- | --- | --- | --- |
| **M1** | A single tool-output turn adds more tokens than the entire remaining safe budget, landing right after a compaction that reported "completed" but changed nothing. | `telegram-plugin-refactor` | Two `read_files` calls, no line-range limit, added ~11,764 tokens (42,081 + 4,976 chars) in one iteration — by far the largest single-turn addition in the trajectory (every other iteration: 1,300–8,700 tokens). Compaction fired on schedule at iteration 6 (trigger 26,100, 8ms after iteration start) but `messagesBefore==messagesAfter==16`. | confirmed |
| **M2** | Compaction fires once (also non-reducing), then is permanently `skipped` for every subsequent iteration, letting the prompt creep unchecked over several more turns until it crosses the wall. | `v-edit-workspace-tests` | One completed compaction at iteration 8 (`messagesBefore==messagesAfter==16`), then 4 consecutive `auto-compaction-skipped` notices (iterations 9–12), each firing within 0–1ms of its own `started` notice (a synchronous, no-model-call decision). Prompt crept 27,173 → 29,218 → 30,117(x2) → 30,696 → 30,843 over those same 4 turns — a 3,670-token creep in small increments (~680–870/turn), not one jump. | confirmed (the fact and consequence of the skip); the skip's own cause predicate is indeterminate (07-11 §5) |
| **M3** | Terminal `MAX_KV_SIZE` rejection following several recovered GPU/host-memory (METAL OOM) events; compaction timeline not independently forensically dissected for this task (out of 07-11's 2-task scope). | `discord-trivia-approval-keyerror` | 6 distinct OOM events (`failure-composition.tsv`) at prompt sizes 15,965 / 22,722 / 25,868 / 28,162 / 29,262 / 29,490 (a spread, not a tight cluster), each recovered via retry; terminal rejection at 31,179 prompt (deficit 459). Whether this task shows the M1 shape, the M2 shape, or a third shape is **not measured** — 07-11 scoped its compaction-timeline forensics to `telegram-plugin-refactor` and `v-edit-workspace-tests` only. | deficit: confirmed; proximate shape: **indeterminate — not measured** |
| **M4** | Compaction, when it does fire and reports "completed," does not remove any messages from the tracked conversation on real bench workloads — it only prepends a summary on top of the intact original history, so the tracked token count grows (not shrinks) even on a "successful" compaction. This is the cross-cutting defect underlying M1 and M2 (both real fatal tasks show it). | `telegram-plugin-refactor`, `v-edit-workspace-tests` (both real captured `completed` events) | `messagesBefore==messagesAfter==16` in both. `tokensAfter > tokensBefore` in both: 49,750 > 38,626 (telegram) and 48,554 > 28,009 (v-edit) — the tracked total *grew* after a "successful" compaction, in both captured instances. Contrast: **5/5** completed events in the Phase 1 *synthetic* filler-file regression (`phase-01/results/exp-verify29k/run.ndjson`) both shrank tokens and dropped messages (e.g. iter 8: 28,409→22,165, messages 15→9). Same notice schema confirmed identical between synthetic and real producer (07-13's `RECLASSIFICATION.md` §4). | confirmed on n=2 real events; **generalization to a third real task is an open hypothesis, not proven** (07-11 §3, 07-13 §4) |
| **M5** | GPU/host memory (METAL) exhaustion during high-context turns, recovered via automatic same-content retry; entangled with but not the terminal cause of any of the 3 fail-context deaths. | `v-edit-workspace-tests` (1 event, at a 30,117-token request), `discord-trivia-approval-keyerror` (6 events, 15,965–29,490 tokens) | Every OOM event in this dataset was followed by a successful retry of the identical prompt size 2.2–36s later; in all 3 fail-context tasks the run's *terminal* event was the `MAX_KV_SIZE` rejection, never the OOM. Whether host memory pressure (e.g. colima/Docker competing for wired memory) caused these OOM events is **explicitly indeterminate** — 07-12 found no `vm_stat`/`colima status`/memory-pressure capture exists anywhere under either run directory for these events. | OOM occurrence + non-terminal role: confirmed; causal link to host memory contention: **indeterminate — no telemetry captured** |

`telegram-plugin-refactor` has zero OOM events (M5 does not apply to it at all).

## 2. Candidate x mechanism scoring

Legend: `closes` / `partially closes` / `does not close` / `not applicable` / `unknown-from-evidence`.

### A. Lower `contextWindow` further

Trial values 26,000 / 24,000 / 20,000. `trigger = value x 0.9`. Per-task literal check using the
formula the plan specifies — `trigger + measured_overshoot + max_tokens` — with each task's own
measured `overshoot_tokensBefore_minus_trigger` from `compaction-events.tsv` (12,526 for telegram
at iteration 6; 1,909 for v-edit at iteration 8) and the observed floor `max_tokens=2048`:

| trial `contextWindow` | trigger | telegram (`trigger+12526+2048`) | v-edit (`trigger+1909+2048`) |
| ---: | ---: | ---: | ---: |
| 26,000 | 23,400 | 37,974 → over by 5,206 | 27,357 → under by 5,411 |
| 24,000 | 21,600 | 36,174 → over by 3,406 | 25,557 → under by 7,211 |
| 20,000 | 18,000 | 32,574 → under by **194** | 21,957 → under by 10,811 |

Read literally, `contextWindow=20000` "survives" both. **This literal reading is misleading for
both tasks and is not trusted as a survival proof:**

- **Telegram:** a 194-token margin is an order of magnitude smaller than the 2,471–9,124-token
  discrepancy already measured between cline's internal token count and the server's real count on
  this exact trajectory (`CONTEXT-FORENSICS.md` §5). It is also not a real prediction: it assumes
  the same fixed-position ~11,764-token tool read recurs unchanged at a different trigger, when in
  fact M4 shows an earlier-firing compaction *adds* tokens rather than removing any — so triggering
  earlier (or triggering an extra time before the read happens) makes the conversation larger by
  the time of the read, not smaller. Net effect: uncertain-to-negative, not a safety margin.
- **V-edit:** the large apparent margin only reflects the *first* compaction event. It does not
  model M2's actual proximate cause — the permanent post-compaction skip and the 4-turn creep that
  follows it, which is untethered from `contextWindow`/trigger value entirely (those turns are not
  gated by compaction at all once the skip guard engages). No trial value changes the skip
  predicate (07-11 §5: cause of the skip is not stored anywhere in the record).

| Mechanism | Verdict | Justification |
| --- | --- | --- |
| M1 (telegram jump) | **does not close** | Every trial value tested exceeds the wall except a spurious 194-token "margin" at 20,000 that is smaller than known measurement noise and rests on an assumption M4 directly contradicts (earlier compaction adds tokens, it does not remove them). |
| M2 (v-edit creep) | **does not close** | The literal formula only scores the first compaction, not the actual failure driver (post-skip creep, unrelated to trigger value). MAX_KV_SIZE (32,768) is fixed; a lower `contextWindow` changes *when* the ineffective compaction fires, not whether the skip guard engages or what it lets through afterward. |
| M3 (discord-trivia) | **unknown-from-evidence** | Deficit (459) is the narrowest of the three, but no compaction-timeline forensics exist for this task — cannot determine which of M1/M2's dynamics (if either) applies, so cannot score this candidate against it specifically. |
| M4 (non-pruning compaction) | **does not close** | This *is* the mechanism at issue. `contextWindow` controls trigger timing only; it does not touch whether the compactor removes messages. Direct evidence both real completed events grew, not shrank, the tracked total. |
| M5 (OOM/memory) | **unknown-from-evidence** | A smaller `contextWindow` could plausibly reduce peak KV-cache memory pressure at any given point (less content retained before compaction attempts), which *might* reduce OOM frequency — directionally plausible but untested; no capture isolates `contextWindow` value from OOM incidence. |

**Cost if applied anyway:** more frequent compactions (each one a real model round-trip, ~330–460
tokens observed, adding wall-clock latency per `docs/32k-compaction-policy.md` §5.3), a smaller
working set for tasks that need to read multiple whole files, and — per M4 — each additional
non-pruning compaction nearly doubles the internally-tracked token count on top of an already
un-shrunk history, which could bring the *next* compaction's own trigger check closer to the wall
sooner, not further from it.

### B. Cap tool-output size

**Not reachable through Cline's CLI configuration surface.** The full flag surface of the pinned
3.0.53 top-level `cline <prompt>` command is confirmed and exhaustive (`docs/headless-wrapper.md`
§4, sourced from live `cline --help` and cross-referenced in `phase-01/config/cline-invocation.env`):
`-c/--cwd`, `--compaction`, `--auto-approve <boolean>`, `-m/--model`, `-P/--provider`,
`-t/--timeout`, `--id`, `--config`, `--data-dir`. None of these bound a tool result's size. Changing
`read_files`'s chunking/line-range behavior would require modifying Cline's own source — upstream
code, out of scope per `PROJECT.md` (no upstream PRs).

| Mechanism | Verdict | Justification |
| --- | --- | --- |
| M1 (telegram jump) | **not applicable** — unreachable configuration surface | Would arithmetically close the deficit if it existed: the combined read was 11,764 tokens against a 5,435-token deficit; capping it at ≤6,329 tokens (11,764 − 5,435, everything else held constant) would keep the fatal request at or under 32,768. But per this plan's own instruction, an unavailable remedy scores zero, not "promising" — there is no cline CLI knob to set it. |
| M2 (v-edit creep) | **does not close** | V-edit's fatal creep (27,173→30,843) is many small increments (~680–870/turn) after the skip guard engages, not one oversized tool result. A tool-output cap does not address a skip-guard defect even where it is reachable. |
| M3 (discord-trivia) | **unknown-from-evidence** | No tool-call-size forensics exist for this task. |
| M4 (non-pruning compaction) | **not applicable** | A tool-output cap bounds input size; it does not change whether compaction removes messages. Orthogonal. |
| M5 (OOM/memory) | **not applicable** | Unrelated to memory contention. |

**Cost:** N/A — the candidate cannot be applied through any surface this project can change.

### C. A different `--compaction` strategy

Pinned 3.0.53 exposes exactly three values: `agentic` (default — confirmed in use both in
`phase-07/bench`'s underlying invocation, whose `cline-cw-providers.json` matches the shipped
`contextWindow=29000`, and in the shipped Kanban service via
`phase-01/config/cline-invocation.env`'s `CLINE_COMPACTION_MODE=agentic`), `basic`, `off`
(`phase-01/config/cline-invocation.env:20-21`, confirmed from `cline --help`). `off` is not a
candidate remedy (removes the only mechanism currently attempting to help at all).

**No stored evidence exists of `--compaction basic`'s behavior on this stack.** No run directory,
probe, or forensic capture in this project has ever invoked cline with `--compaction basic`. This
is the **one candidate where the answer is genuinely unknown rather than arithmetically ruled out**
— it is untested, not disproven.

| Mechanism | Verdict | Justification |
| --- | --- | --- |
| M1 (telegram jump) | **unknown-from-evidence** | Cannot determine whether `basic` mode's summarization/pruning behavior would have shrunk the pre-existing 21,036-token history enough to absorb the 11,764-token read within the wall. Would require a live capture. |
| M2 (v-edit creep) | **unknown-from-evidence** | Cannot determine whether `basic` mode is subject to the same permanent-skip guard `agentic` mode showed, or whether it would have kept compacting (and, more importantly, pruning) through iterations 9–12. |
| M3 (discord-trivia) | **unknown-from-evidence** | Same — untested, and this task's own compaction shape is separately unmeasured (M3). |
| M4 (non-pruning compaction) | **unknown-from-evidence — the single candidate most directly aimed at this mechanism** | If `basic` mode actually removes messages (as opposed to `agentic`'s observed additive-summary-only behavior), it would directly address the confirmed defect. This is not established either way by any evidence this project holds. |
| M5 (OOM/memory) | **not applicable** | Compaction strategy does not touch host memory allocation. |

**What would settle it:** a fresh live capture reproducing a near-32K trajectory under
`--compaction basic`, checking specifically whether a `completed` notice shows
`messagesAfter < messagesBefore` and `tokensAfter < tokensBefore`. This is a live-run question,
out of this plan's zero-live-run scope.

**Cost if it does work:** none identified beyond whatever quality/behavior tradeoff `basic` mode
has versus `agentic` (unmeasured — no comparative task-completion data exists for `basic` mode on
this stack).

### D. Reduce `max_tokens`

**Not configurable through any surface this project has found.**
`docs/cline-max-tokens-findings.md` §3 documents three separate probes of `providers.json`'s
`maxTokens` field (`4096`, `512`, `77`) against both the top-level and `models[]` locations — the
wire value never changed from the observed floor. The root cause is undetermined and believed to
be an internal Cline default (§3: "이 `2048`이 Cline 바이너리에 하드코딩된 내부 기본값인지 ...
이 플랜의 범위 밖"). No `--max-tokens`-shaped CLI flag exists in the confirmed 9-flag surface
either (Candidate B's list, same source).

Per-task arithmetic if it *were* configurable, holding the fatal prompt size fixed:

| task | fatal prompt alone | wall | margin at `max_tokens=0` | deficit | closeable by floor reduction alone? |
| --- | ---: | ---: | ---: | ---: | --- |
| `telegram-plugin-refactor` | 36,155 | 32,768 | **−3,387** (prompt alone already exceeds the wall) | 5,435 | **no — arithmetically impossible at any `max_tokens` ≥ 0** |
| `v-edit-workspace-tests` | 30,843 | 32,768 | +1,925 | 123 | yes, in principle — cutting the floor from 2,048 to ≤1,925 exactly closes it on this one trace |
| `discord-trivia-approval-keyerror` | 31,179 | 32,768 | +1,589 | 459 | yes, in principle — cutting the floor from 2,048 to ≤1,589 exactly closes it on this one trace |

| Mechanism | Verdict | Justification |
| --- | --- | --- |
| M1 (telegram jump) | **does not close** | Arithmetic-certain: the prompt alone (36,155) already exceeds the 32,768 wall by 3,387 tokens, independent of `max_tokens`. No floor value, including zero (which would also break response generation entirely), can close this. |
| M2 (v-edit creep) | **not applicable — unconfigurable; would partially close in principle** | Would arithmetically close the measured 123-token deficit on this one trace, but there is no confirmed way to set it, and doing so costs truncated model responses on every turn of every task, not just this one. |
| M3 (discord-trivia) | **not applicable — unconfigurable; would partially close in principle** | Same shape as M2: 459-token deficit, arithmetically closeable if the floor were reachable, which it is not. |
| M4 (non-pruning compaction) | **not applicable** | Orthogonal — does not touch compaction's pruning behavior. |
| M5 (OOM/memory) | **not applicable** | Orthogonal — does not touch host memory allocation. |

**Cost if it were reachable:** truncated model responses on every turn (not just the fatal one) —
a task whose final answer needs more than the reduced floor to complete would fail differently,
trading a context-ceiling death for a truncation failure.

### E. Address memory contention (Docker/colima)

07-12 found OOM events entangled in 2 of the 3 fail-context tasks (M5) but explicitly could not
establish a causal link to host memory contention (colima/Docker) — no `vm_stat`/`colima
status`/memory-pressure telemetry was captured concurrently with either run. Separately, and more
directly decisive for this candidate: **in all 3 fail-context tasks, the terminal event was the
`MAX_KV_SIZE` rejection, never the OOM.** Every OOM event in this dataset was followed by a
successful retry.

| Mechanism | Verdict | Justification |
| --- | --- | --- |
| M1 (telegram jump) | **not applicable** | Zero OOM events occurred in this task's entire run — nothing for a memory-contention remedy to address. |
| M2 (v-edit creep) | **does not close** | The task recovered from its 1 OOM event via retry and died 3 turns later of the context ceiling, not of memory exhaustion. Eliminating the OOM event does not touch the skip-guard creep that actually killed the task. |
| M3 (discord-trivia) | **does not close** | Same structure at larger scale: 6/6 OOM events recovered, terminal death was the `MAX_KV_SIZE` rejection. |
| M4 (non-pruning compaction) | **not applicable** | Orthogonal — memory contention and compaction pruning are unrelated subsystems. |
| M5 (OOM/memory, itself) | **partially closes (the OOM component only, not causally proven)** | An operational precaution (do not run bench/production tasks while colima/Docker holds significant wired memory) could plausibly reduce OOM *frequency* if the untested causal link is real, at zero monetary/config cost. It does not, even at best, address any of the 3 confirmed terminal causes. |

**Cost:** effectively free as an operational habit (avoid concurrent heavy Docker/colima load
during bench or production tasks) — but it is a precaution against an unproven risk, not a fix for
anything confirmed to have killed a task.

### F. Accept the limit

Per task, does **any** of A–E close the mechanism that actually killed it, using only what this
matrix can confirm (not the untested Candidate C)?

| task | A | B | C | D | E | **Forced to F by confirmed evidence?** |
| --- | --- | --- | --- | --- | --- | --- |
| `telegram-plugin-refactor` (M1) | does not close | not applicable (unreachable) | unknown | does not close (arithmetic-certain) | not applicable | **Yes for every characterized candidate.** Only the untested C remains open. Given the deficit (5,435) exceeds the wall even at `max_tokens=0`, and the specific failure is one indivisible 11,764-token tool read landing on top of an already-21,036-token conversation that non-pruning compaction cannot shrink, this is the strongest candidate for F in the dataset. |
| `v-edit-workspace-tests` (M2) | does not close | does not close | unknown | not applicable/partial-in-principle | does not close | **Forced among reachable candidates**, but the deficit (123) is the narrowest in the set — two orders of magnitude smaller than telegram's. If C's `basic` mode actually prunes, or if D's floor were ever found configurable, this task looks the most plausibly saveable of the three. F is not as strongly forced here as for telegram. |
| `discord-trivia-approval-keyerror` (M3) | unknown | unknown | unknown | not applicable/partial-in-principle | does not close | **Not forced — mechanism unmeasured.** Deficit (459) is small, but 07-11 never forensically characterized this task's compaction timeline, so A/B/C's cells are honestly unknown rather than ruled out. Calling F here would overclaim beyond what was measured. |

**F is a first-class win for `telegram-plugin-refactor`, not a fallback framing**: every candidate
this matrix can characterize with confirmed evidence fails to close its deficit, and the one that
might (C) is untested by construction (zero live runs, this plan). F is **not** established for
`v-edit-workspace-tests` or `discord-trivia-approval-keyerror` — their narrow deficits remain open
questions pending either a live test of C or further forensics on M3.
