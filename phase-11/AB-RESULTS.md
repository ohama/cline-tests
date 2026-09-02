# AB-RESULTS.md — USE-03 main A/B: what came back

Plan 11-06. Runs the A/B at the size `AB-PROTOCOL.md` §4 authorised and reports exactly what the
pre-registered decision rule outputs against the measured table. This document does not decide
whether to keep or revert `cline-plan → flashnext-plan` — that is plan 11-07's, with a human, per
`AB-PROTOCOL.md`'s own text (this decision changes the default behaviour of a shipped tool).

**Bottom line, up front, stated once and not softened:** the run did **not** reach its authorised
size — it stopped at the pre-registered **request cap (88)**, not a void condition, after
completing 66 of the 88 authorised invocations, because several tasks turned out to need more than
one model turn per invocation (a behaviour the pilot never exercised). Task 08 (both
bug-localisation tasks) and arm B (the prefix control) were never reached. On the data actually
collected, arm C's raw correct-count is **4 lower** than arm A's (26 vs 30) — far short of, and in
the opposite direction from, the ≥7 needed to keep. **RULE OUTPUT: revert.** But the raw gap is
mechanically produced by unequal N and a single shared floor task, not by any measured accuracy
difference: excluding that one task, both arms are **100% correct on every task actually attempted
by both**, and the permutation test finds no distinguishable difference (p=0.563). See §4 and §8
before reading the gap as "arm C performed worse."

---

## §1 What was run

**Arms and aliases**, per `AB-PROTOCOL.md` §1 — flag-minimal invocation, no `-p`, wrappers
deliberately bypassed (see below):

```
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m <alias> --compaction agentic --json -t 600 "<prompt>"
```

| arm | alias | litellm prefix | reasoning injected |
|---|---|---|---|
| A (control) | `flashnext` | `openai/` | none |
| B (prefix control) | `flashnext-act` | `hosted_vllm/` | none |
| C (shipped Plan alias) | `flashnext-plan` | `hosted_vllm/` | `enable_thinking:true`, `reasoning_effort:medium` |

**The wrappers (`phase-11/cline-plan`/`cline-act`) were deliberately not used.** `AB-PROTOCOL.md`
§2: `cline-plan` sets `-p` (Plan-mode, restricted toolset), which would confound the
reasoning-parameter effect with a tool-availability effect. Every arm here omits `-p`, holding the
mode flag constant so the measurement is of the **alias**, which is what USE-03's keep-or-revert
decision is actually about.

**Task ids:** all 8 (`phase-11/tasks/MANIFEST.tsv`), attempted in task-major/arm-minor order,
01→08, per `AB-PROTOCOL.md` §3 ("Order"). **Authorised N:** 5 for arms A and C, 1 for arm B (the
reduced-replication prefix control) — 8 tasks × (5+5+1) = **88 invocations**, authorised at plan
11-05's Task 3 human checkpoint (`approve-as-proposed, invocation ceiling 88`, recorded verbatim in
`AB-PROTOCOL.md` §4).

**Authorised request cap: 88. Actual measured requests: 88 — the cap, exactly, not exceeded.**
Independently cross-checked three ways, all agreeing at 88:
1. `run_ab.sh`'s own `budget.tsv`, final data row: `running_total=88 cap=88`.
2. `tail -n "+23984" ~/llm-system/services/logs/flashnext.err | grep -c 'Generation queued'` = 88
   (watermark line 23983 — this run's own fresh preflight watermark, reset by the orchestrator
   immediately before this run so its own spend would not be conflated with plan 11-04's or the
   pilot's prior 9-request spend against the same persistent counter file).
3. `Prefill started` cumulative count: 999 vs the orchestrator-recorded 911 baseline → delta 88.

**But 88 requests bought only 66 of the 88 authorised invocations, not all of them** — see §1a.

**Run directory:** `phase-11/results/20260902T062649Z-ab-main` (`$(cat
phase-11/results/CURRENT_AB_MAIN_RUN)`). Contains `ab.tsv` (66 data rows), `streams/` (66 raw
NDJSON captures, one per cell, none empty), `budget.tsv`, `manifest.txt`, `preflight.txt`,
`postflight.txt`, `regrade-check.txt` (0 verdict differences — see §1b), `providers-drift.tsv` (31
rows, see §1c), `interruptions.txt` (the full account of the cap-triggered stop).

**`cline --version`:** `3.0.61` before, `3.0.61` after. **Stable — the version-stability void
condition was not triggered** (see §7).

**Live compaction trigger in force:** 26,100 (`contextWindow=29000 × 0.9`, unchanged all run,
confirmed by `verify_config.sh` at both preflight and postflight).

### §1a — Why the run stopped short: an emergent tool-calling behaviour the pilot never exercised

`AB-TASKSET.md` §2's design intent was a **bounded-turn (1–3), no-tool-required** instrument, and
the pilot (2 tasks × 3 arms × N=1, plan 11-05) never saw more than 1 model request per invocation.
`AB-PROTOCOL.md` §4's sizing arithmetic (88 invocations × ~17s ≈ 25 minutes; cap = 88 requests, set
equal to the invocation count) implicitly assumed that pattern would hold for all 8 tasks.

It did not. Tasks 01–04 ran exactly as the pilot predicted (1 request per invocation throughout).
Starting at **task 05** ("list-aliasing", code-trace), the model began **spontaneously invoking the
`run_commands` tool** to execute the Python snippet itself and read off the real answer, rather than
reasoning it out in text — confirmed directly from the raw stream (`05-A-r1.ndjson`:
`"toolName":"run_commands"`, `run_result` shows `"iterations":2`). This is not a violation of
§2's "answerable without tool use" design constraint (tools were never withheld — the A/B
deliberately runs without `-p`, i.e. full Act-mode tool availability, in every arm, per
`AB-PROTOCOL.md` §2) — the model simply chose to use an available tool on a task it did not
strictly need one for. From task 05 onward most cells needed 2 requests, and one (`07-A-r1`) needed
3 — still under the per-cell runaway-guard threshold of >3 (never triggered this run; see §7) —
but this consumed the 88-request budget against only 66 of the 80 arm-A/C invocations attempted,
and invocation 2 (arm B) never started because invocation 1 exited non-zero on the cap.

**What is, and is not, in the dataset as a result:**

| task | arm A | arm C | arm B |
|---|---|---|---|
| 01–06 | complete (N=5) | complete (N=5) | not attempted |
| 07 (index-shift-bug) | complete (N=5) | **1 of 5** (rep 1 only) | not attempted |
| 08 (zero-div-bug) | **0 of 5** | **0 of 5** | not attempted |

66 of 88 authorised invocations completed; the remaining 22 (07-C reps 2–5, all of 08, all of B)
were never attempted, because the very next cell after `07-C-r1` (`07-C-r2`) was refused by
`assert_budget`'s pre-check before firing (running_total=88 ≥ cap=88). **This is not a void
condition** (see §7) and **is not treated as grounds to raise the cap and continue** — per this
plan's hard constraint 5, "the cap is not raised to finish the sweep." Full blow-by-blow, including
the three-way budget cross-check and a `run_ab.sh` defect this exposed (the cap-abort path skips
`run_ab.sh`'s own `postflight11` call, unlike every other abort path — worked around here by running
`postflight11` manually against the same run directory within seconds of the abort), is in
`phase-11/results/20260902T062649Z-ab-main/interruptions.txt`.

**`--resume` was not attempted**, and would not have recovered any data: every remaining cell would
fail the identical `assert_budget` pre-check the moment it ran, since the cap was not raised.

### §1b — The aggregate is reproducible from the raw evidence

`phase-11/grade_ab.py` was re-run over all 66 retained streams in a fresh pass
(`regrade-check.txt`): `cells_checked=66`, `cells_total_in_ab_tsv=66`, `verdict_differences=0`. The
verdict column is fully reproducible from the raw streams alone. `git log`/`git diff` over
`phase-11/tasks/` and `phase-11/grade_ab.py` confirm neither the task set, the answer keys, nor the
grader were touched before, during, or after this run (last commits `0856098`/`b4eec84`, both from
plan 11-02, predating this run by days).

### §1c — `providers.json` drift: the orchestrator-directed mitigation, and what it measured

**This deviates from the plan text as written**, by explicit instruction from the orchestrator that
spawned this execution, recorded here because the plan itself does not say this — the reasoning is
the orchestrator's, not `AB-PROTOCOL.md`'s or plan 11-06's original text.

`cline -m flashnext-plan` had already been reproduced twice (11-04's Open Item 3; the 11-05 pilot's
own `04-C-r1` cell) rewriting `providers.json`'s `model` field, both at cline 3.0.61.
`probe_lib11.sh`'s `postflight11` treats any such drift as a hard, no-self-repair failure — correct
for a probe issuing a handful of requests, but this run makes 31 real `flashnext-plan` invocations
(arm C), so unmodified it would have halted the entire main run at the very first C-arm cell,
leaving `providers.json` drifted **and** producing no A/B. The orchestrator's instruction: **repair
immediately after every invocation instead of halting on `model` drift, log every occurrence, and
still hard-stop on any `contextWindow` drift** (never observed before; auto-repairing something
unprecedented would risk hiding a new failure mode). This was implemented as a new check in
`run_ab.sh` itself (`check_and_repair_providers()`, called after every `cline` invocation,
including retries), calling `phase-01/config/apply_provider_config.sh` — the same pre-existing tool
the orchestrator used out-of-band after the pilot — never writing `providers.json` directly.

**Measured result: 31 of 31 arm-C invocations (100%) drifted `providers.json`'s `model` field**
(`flashnext` → `flashnext-plan`) after every single call; **all 31 were detected and repaired**
before the next cell started (`providers-drift.tsv`, `restore_outcome=repaired` on every row); **0
halts, 0 `contextWindow` drifts** (it held at `29000` on every check, including the 31 drift
events). This raises the two prior single/handful-count observations (11-04: 1 occurrence; the
pilot: 1 occurrence) to **31 consecutive occurrences at 100% frequency**, removing any remaining
doubt that this is probabilistic or wrapper-specific — every bare `-m flashnext-plan` call at cline
3.0.61 drifts the shared config, deterministically, whether wrapped (`cline-plan`, `-p` present) or
bare (this A/B, `-p` absent). **This count is evidence for plan 11-07**, which owns the
keep-or-revert ratification and cannot pass over this mechanism regardless of what §8 below finds
on answer quality — it is recorded here, not suppressed as probe noise. The narrowed exposure
window (mitigation, not a fix) was roughly one cell (~17–40s) per occurrence, since requests run
strictly sequentially and the repair completes before the next invocation starts.

---

## §2 The task list and its answer keys

One row per task, from `phase-11/tasks/MANIFEST.tsv` and each task's `.expected` file — a reader can
confirm the grading was fixed before any data existed by re-running each `derivation` command
directly.

| id | slug | category | match | expected | derivation |
|---|---|---|---|---|---|
| 01 | pipe-rate | word-problem | numeric (tol 0.01) | 8 | `python3 -c "rateA=1/6; rateB=1/12; combined=rateA+rateB; filled=2*combined; remaining=1-filled; extra=remaining/rateB; total=2+extra; print(total)"` → 8.0 |
| 02 | salt-mixture | word-problem | numeric (tol 0.01) | 60 | `python3 -c "salt=40*0.20; total=salt/0.08; water=total-40; print(water)"` → 60.0 |
| 03 | reinvested-interest | word-problem | numeric (tol 0.01) | 2484 | `python3 -c "p=2000; i1=p*0.05*3; t1=p+i1; i2=t1*0.04*2; final=t1+i2; print(final, round(final))"` → 2484.0 |
| 04 | loop-sum | code-trace | numeric (tol 0) | 90 | `python3 phase-11/tasks/04-loop-sum.truth.py` → 90 |
| 05 | list-aliasing | code-trace | numeric (tol 0) | 7 | `python3 phase-11/tasks/05-list-aliasing.truth.py` → 7 |
| 06 | mode-char | code-trace | exact_normalized | a | `python3 phase-11/tasks/06-mode-char.truth.py` → a |
| 07 | index-shift-bug | bug-localisation | numeric (tol 0) | 4 | `python3 phase-11/tasks/07-index-shift-bug.truth.py` → 4 (IndexError line number) |
| 08 | zero-div-bug | bug-localisation | numeric (tol 0) | 6 | `python3 phase-11/tasks/08-zero-div-bug.truth.py` → 6 (ZeroDivisionError line number) |

All 8 derivations were re-verified against source at the time this document was written; none
changed from their original plan-11-02 commit.

---

## §3 The raw per-cell table

Every row of `ab.tsv` (66 data rows — this run stopped at cell 67/07-C-r2, refused before firing;
see §1a). `retried` is `no` on every row (zero operational retries this run). `qualifier` is empty
on every row (no `answer-seen-in-reasoning-only` cases — every cell reached a definitive `correct`
or `incorrect` verdict via the visible-output `ANSWER:` line; zero `no-answer`, zero `no-output`,
zero `unparseable`).

| task | arm | alias | rep | verdict | extracted | expected | prompt_tok | completion_tok | max_tok | finish_reason | dur_s | requests |
|---|---|---|---|---|---|---|---:|---:|---:|---|---:|---:|
| 01 | A | flashnext | 1 | correct | 8 | 8 | 5588 | 160 | 20851 | stop | 15 | 1 |
| 01 | A | flashnext | 2 | correct | 8 | 8 | 5588 | 160 | 20851 | stop | 14 | 1 |
| 01 | A | flashnext | 3 | correct | 8 | 8 | 5588 | 160 | 20851 | stop | 14 | 1 |
| 01 | A | flashnext | 4 | correct | 8 | 8 | 5588 | 160 | 20851 | stop | 14 | 1 |
| 01 | A | flashnext | 5 | correct | 8 | 8 | 5588 | 160 | 20851 | stop | 14 | 1 |
| 01 | C | flashnext-plan | 1 | correct | 8 | 8 | 5450 | 269 | 20851 | stop | 17 | 1 |
| 01 | C | flashnext-plan | 2 | correct | 8 | 8 | 5450 | 269 | 20851 | stop | 18 | 1 |
| 01 | C | flashnext-plan | 3 | correct | 8 | 8 | 5450 | 269 | 20851 | stop | 21 | 1 |
| 01 | C | flashnext-plan | 4 | correct | 8 | 8 | 5450 | 269 | 20851 | stop | 18 | 1 |
| 01 | C | flashnext-plan | 5 | correct | 8 | 8 | 5450 | 269 | 20851 | stop | 18 | 1 |
| 02 | A | flashnext | 1 | correct | 60 | 60 | 5575 | 74 | 20873 | stop | 13 | 1 |
| 02 | A | flashnext | 2 | correct | 60 | 60 | 5575 | 74 | 20873 | stop | 12 | 1 |
| 02 | A | flashnext | 3 | correct | 60 | 60 | 5575 | 74 | 20873 | stop | 13 | 1 |
| 02 | A | flashnext | 4 | correct | 60 | 60 | 5575 | 74 | 20873 | stop | 13 | 1 |
| 02 | A | flashnext | 5 | correct | 60 | 60 | 5575 | 74 | 20873 | stop | 12 | 1 |
| 02 | C | flashnext-plan | 1 | correct | 60 | 60 | 5437 | 120 | 20873 | stop | 13 | 1 |
| 02 | C | flashnext-plan | 2 | correct | 60 | 60 | 5437 | 120 | 20873 | stop | 15 | 1 |
| 02 | C | flashnext-plan | 3 | correct | 60 | 60 | 5437 | 120 | 20873 | stop | 15 | 1 |
| 02 | C | flashnext-plan | 4 | correct | 60 | 60 | 5437 | 120 | 20873 | stop | 16 | 1 |
| 02 | C | flashnext-plan | 5 | correct | 60 | 60 | 5437 | 120 | 20873 | stop | 16 | 1 |
| 03 | A | flashnext | 1 | correct | 2484 | 2484 | 5601 | 208 | 20847 | stop | 16 | 1 |
| 03 | A | flashnext | 2 | correct | 2484 | 2484 | 5601 | 208 | 20847 | stop | 16 | 1 |
| 03 | A | flashnext | 3 | correct | 2484 | 2484 | 5601 | 208 | 20847 | stop | 17 | 1 |
| 03 | A | flashnext | 4 | correct | 2484 | 2484 | 5601 | 208 | 20847 | stop | 17 | 1 |
| 03 | A | flashnext | 5 | correct | 2484 | 2484 | 5601 | 208 | 20847 | stop | 17 | 1 |
| 03 | C | flashnext-plan | 1 | correct | 2484 | 2484 | 5463 | 275 | 20847 | stop | 20 | 1 |
| 03 | C | flashnext-plan | 2 | correct | 2484 | 2484 | 5463 | 275 | 20847 | stop | 18 | 1 |
| 03 | C | flashnext-plan | 3 | correct | 2484 | 2484 | 5463 | 275 | 20847 | stop | 20 | 1 |
| 03 | C | flashnext-plan | 4 | correct | 2484 | 2484 | 5463 | 275 | 20847 | stop | 21 | 1 |
| 03 | C | flashnext-plan | 5 | correct | 2484 | 2484 | 5463 | 275 | 20847 | stop | 21 | 1 |
| 04 | A | flashnext | 1 | correct | 90 | 90 | 5636 | 195 | 20833 | stop | 18 | 1 |
| 04 | A | flashnext | 2 | correct | 90 | 90 | 5636 | 195 | 20833 | stop | 17 | 1 |
| 04 | A | flashnext | 3 | correct | 90 | 90 | 5636 | 195 | 20833 | stop | 17 | 1 |
| 04 | A | flashnext | 4 | correct | 90 | 90 | 5636 | 195 | 20833 | stop | 18 | 1 |
| 04 | A | flashnext | 5 | correct | 90 | 90 | 5636 | 195 | 20833 | stop | 16 | 1 |
| 04 | C | flashnext-plan | 1 | correct | 90 | 90 | 5498 | 236 | 20833 | stop | 19 | 1 |
| 04 | C | flashnext-plan | 2 | correct | 90 | 90 | 5498 | 236 | 20833 | stop | 20 | 1 |
| 04 | C | flashnext-plan | 3 | correct | 90 | 90 | 5498 | 236 | 20833 | stop | 21 | 1 |
| 04 | C | flashnext-plan | 4 | correct | 90 | 90 | 5498 | 236 | 20833 | stop | 20 | 1 |
| 04 | C | flashnext-plan | 5 | correct | 90 | 90 | 5498 | 236 | 20833 | stop | 20 | 1 |
| 05 | A | flashnext | 1 | correct | 7 | 7 | 5619 | 119 | 20835 | stop | 29 | **2** (tool call) |
| 05 | A | flashnext | 2 | correct | 7 | 7 | 5619 | 119 | 20835 | stop | 32 | **3** (tool call) |
| 05 | A | flashnext | 3 | correct | 7 | 7 | 5619 | 119 | 20835 | stop | 26 | **2** (tool call) |
| 05 | A | flashnext | 4 | correct | 7 | 7 | 5619 | 119 | 20835 | stop | 25 | **2** (tool call) |
| 05 | A | flashnext | 5 | correct | 7 | 7 | 5619 | 119 | 20835 | stop | 27 | **2** (tool call) |
| 05 | C | flashnext-plan | 1 | correct | 7 | 7 | 5481 | 305 | 20835 | stop | 40 | **2** (tool call) |
| 05 | C | flashnext-plan | 2 | correct | 7 | 7 | 5481 | 305 | 20835 | stop | 36 | **2** (tool call) |
| 05 | C | flashnext-plan | 3 | correct | 7 | 7 | 5481 | 305 | 20835 | stop | 38 | **2** (tool call) |
| 05 | C | flashnext-plan | 4 | correct | 7 | 7 | 5481 | 305 | 20835 | stop | 42 | **2** (tool call) |
| 05 | C | flashnext-plan | 5 | correct | 7 | 7 | 5481 | 305 | 20835 | stop | 36 | **2** (tool call) |
| 06 | A | flashnext | 1 | **incorrect** | `'a'` | a | 5635 | 142 | 20802 | stop | 30 | 2 |
| 06 | A | flashnext | 2 | **incorrect** | `'a'` | a | 5635 | 142 | 20802 | stop | 29 | 2 |
| 06 | A | flashnext | 3 | **incorrect** | `'a'` | a | 5635 | 142 | 20802 | stop | 29 | 2 |
| 06 | A | flashnext | 4 | **incorrect** | `'a'` | a | 5635 | 142 | 20802 | stop | 30 | 2 |
| 06 | A | flashnext | 5 | **incorrect** | `'a'` | a | 5635 | 142 | 20802 | stop | 29 | 2 |
| 06 | C | flashnext-plan | 1 | **incorrect** | `'a'` | a | 5497 | 322 | 20802 | stop | 22 | 1 |
| 06 | C | flashnext-plan | 2 | **incorrect** | `'a'` | a | 5497 | 322 | 20802 | stop | 25 | 1 |
| 06 | C | flashnext-plan | 3 | **incorrect** | `'a'` | a | 5497 | 322 | 20802 | stop | 25 | 1 |
| 06 | C | flashnext-plan | 4 | **incorrect** | `'a'` | a | 5497 | 322 | 20802 | stop | 25 | 1 |
| 06 | C | flashnext-plan | 5 | **incorrect** | `'a'` | a | 5497 | 322 | 20802 | stop | 25 | 1 |
| 07 | A | flashnext | 1 | correct | 4 | 4 | 5631 | 156 | 20820 | stop | 39 | **3** (tool call — highest this run) |
| 07 | A | flashnext | 2 | correct | 4 | 4 | 5631 | 156 | 20820 | stop | 29 | 2 (tool call) |
| 07 | A | flashnext | 3 | correct | 4 | 4 | 5631 | 156 | 20820 | stop | 29 | 2 (tool call) |
| 07 | A | flashnext | 4 | correct | 4 | 4 | 5631 | 156 | 20820 | stop | 32 | 2 (tool call) |
| 07 | A | flashnext | 5 | correct | 4 | 4 | 5631 | 156 | 20820 | stop | 32 | 2 (tool call) |
| 07 | C | flashnext-plan | 1 | correct | 4 | 4 | 5493 | 188 | 20820 | stop | 15 | 1 |

**07-C reps 2–5 do not appear — never attempted, cap reached at cell 67 (07-C-r2).** Full stream
paths for every row above are under `phase-11/results/20260902T062649Z-ab-main/streams/`, named
`<task>-<arm>-r<rep>.ndjson`.

---

## §4 Per-arm aggregate, four categories

| arm | n | correct | incorrect | no-answer | no-output | unparseable |
|---|---:|---:|---:|---:|---:|---:|
| A (`flashnext`) | 35 | 30 (85.7%) | 5 (14.3%) | 0 (0%) | 0 (0%) | 0 (0%) |
| C (`flashnext-plan`) | 31 | 26 (83.9%) | 5 (16.1%) | 0 (0%) | 0 (0%) | 0 (0%) |
| B (`flashnext-act`) | 0 | — never reached this run, see §1a and §5 — | | | |

**No `no-answer` or `no-output` cells occurred in either arm.** `finish_reason=stop` on all 66
cells — the completion-budget-starvation risk `AB-PROTOCOL.md` §3 flagged (Phase 9's fixed-300-token
finding) did not materialise at the measured dynamic budget (~20,800–20,873 tokens this run).

**Every single incorrect verdict, in both arms, is task 06 — a shared floor result, not a
differentiator.** Excluding task 06: arm A is **30/30 (100%)** correct on every other task attempted
(01–05, 07); arm C is **26/26 (100%)** correct on every other task attempted (01–06 minus... —
concretely: 01–05 complete plus 07-r1). **Both arms tied at 0/5 on task 06.** The raw per-arm
percentages above (85.7% vs 83.9%) look close but are driven entirely by arm A simply having 4 more
total cells (35 vs 31) while both arms fail task 06 identically — see §8 for why this matters to
reading the decision-rule gap correctly.

**Task 06's shared floor, root-caused (not a grader defect — see below):** both arms answered with
the correct character wrapped in Python quote marks — `ANSWER: 'a'` — against an expected bare `a`
under `exact_normalized` matching (`grade_ab.py`'s `normalize_exact` strips trailing periods,
commas, and whitespace, but not surrounding quote characters — this is the grader behaving exactly
as pre-registered, not a bug: the prompt explicitly instructs "respond ... in exactly this form and
nothing else on that line: `ANSWER: <value>`," and `'a'` is not the instructed value `a`). Confirmed
directly from the raw stream (`06-A-r1.ndjson`: literal text `ANSWER: 'a'"`). This is reported as
observed, **not corrected** — hard constraint 8 forbids editing the grader mid-run or after because
a result is disappointing, and this is not a grader defect in any case, it is the grader doing its
documented job on a task where both arms shared the same formatting habit.

**Duration and completion length, printed together per `AB-PROTOCOL.md` §3's confound requirement:**

| arm | median dur_s | p90 dur_s | min–max dur_s | median completion_tok | mean completion_tok | median prompt_tok |
|---|---:|---:|---|---:|---:|---:|
| A | 17 | 31.2 | 12–39 | 156 | 150.6 | 5619 |
| C | 20 | 36.0 | 13–42 | 269 | 252.4 | 5481 |

**Arm C's completions run ~68% longer on average (252.4 vs 150.6 tokens) than arm A's.** Per
`AB-PROTOCOL.md` §3's own pre-registered instruction, **the ~3s/18% median latency gap between the
arms is not read as "thinking cost"** given generation lengths differ this materially — a
meaningful fraction of the extra wall clock is plausibly just more tokens to stream, not slower
per-token reasoning. This confound is inherent to a dynamic completion budget and was expected;
`AB-PROTOCOL.md` did not claim latency would isolate reasoning cost cleanly, only that it should be
reported alongside length, which this table does.

**An emergent, unplanned finding: arm C needed the tool-execution path less often than arm A.**
Mean `requests_this_cell` (a direct proxy for turn/tool-call count): **A = 1.49** (max 3, tasks
05/07), **C = 1.16** (max 2, task 05 only — task 06 and 07's single C cell were both single-turn,
pure-text answers). Every C-arm invocation of task 06 answered directly in one turn; every A-arm
invocation of task 06 still called `run_commands` (2 requests) despite answering identically wrong.
This suggests arm C's reasoning budget let it work through the code-tracing tasks in text more often
than arm A did, though N here is small enough that this is reported as an observation, not a claim.

---

## §5 The prefix control — not run this main run

**Arm B (`flashnext-act`) collected zero cells.** Invocation 2 (arm B, N=1, 8 planned cells) never
started, because invocation 1 exited non-zero on the request cap before invocation 1 even finished
(see §1a). This is a direct, reportable consequence of the cap-triggered early stop, not a decision
made about arm B specifically.

**Consequence for what this run can and cannot say:** the `hosted_vllm/`-vs-`openai/` prefix
confound `AB-PROTOCOL.md` §1 introduced arm B specifically to separate from the reasoning-parameter
effect is **not separated by this run's own data** — there is no B-arm evidence here to compare
against. `phase-10/REACH-PROOF.md` §5 previously found `flashnext-act` indistinguishable from
`flashnext` (delta 0, `prompt_tokens` only) at a much smaller N and a different task; that finding
is **not corroborated or contradicted here**, it is simply unavailable from this run. Any reader
using this document to judge whether the A-vs-C gap could be a prefix artifact rather than a
reasoning-parameter artifact must rely on the phase-10 finding alone, not on anything measured in
this plan.

---

## §6 The descriptive statistic

Two-sided permutation test, per-cell correctness, arm A (n=35, 30 correct) vs arm C (n=31, 26
correct), `python3` stdlib, label-shuffling, seed `20260902`, 10,000 shuffles:

```
n_a=35 n_c=31 correct_a=30 correct_c=26 observed_gap(C-A)=-4
shuffles=10000 seed=20260902 two_sided_p=0.5630
```

**p=0.563 — indistinguishable from chance.** This is **explicitly not the decision criterion**
(`AB-PROTOCOL.md` §5: "N is small and treating a p-value as the gate would over-claim precision the
design does not have"); it is reported descriptively, and it is fully consistent with §4's finding
that the two arms tie on every task except a shared floor case.

---

## §7 Void-condition check

Walking every condition `AB-PROTOCOL.md` §5 pre-registers, each stated explicitly even when not
triggered:

| condition | triggered? | evidence |
|---|---|---|
| `cline --version` change mid-batch | **NOT triggered** | `3.0.61` before, `3.0.61` after (confirmed twice: the run's own `cline-version-before/after.txt`, and the manual `postflight11` re-check run seconds after the cap-abort — see §1a) |
| >25% of either arm's cells `unparseable` | **NOT triggered** | 0 of 35 (arm A), 0 of 31 (arm C) — 0% both arms |
| any task's `prompt_tokens` > 6,525 (25% of 26,100) | **NOT triggered** | maximum observed across all 66 cells: 5,636 (task 04, arm A) — 21.6% of the trigger, well under the 25% threshold |
| runaway-agent exclusion (per-cell `requests_this_cell` > 3) | **NOT triggered** | maximum observed: 3 (`07-A-r1`, exactly at the guard's own non-triggering boundary — see §1a and §4). No task or cell was excluded from the aggregate. |

**None of the four pre-registered void conditions fired.** The run's early stop (§1a) is governed by
a **separate**, non-void mechanism (the hard request cap, hard constraint 5) that `AB-PROTOCOL.md`
§5 does not list among its void conditions — the data collected before the cap was reached remains
valid, reportable data; it is simply less of it than authorised.

---

## §8 The decision rule, applied

Quoted verbatim from `phase-11/AB-PROTOCOL.md` §5:

> **Keep** `cline-plan → flashnext-plan` only if arm C's correct-count exceeds arm A's by at least
> **4 cells out of 24** (with N=3 and 8 tasks). **Otherwise revert** `wrapper.env`'s
> `WRAPPER_PLAN_ALIAS` to `flashnext`, per USE-03's own text.
>
> [...] | 8 | 5 | 40 | **≥7** | [...]

Per this plan's own instruction and `AB-PROTOCOL.md` §4's resolution block, the applicable threshold
for the authorised 8-tasks×N=5 size is **read off the pre-computed table as ≥7, not recomputed** now
that the actual (smaller, uneven) run size is known.

**The arithmetic:**

- Arm C correct-count: **26**
- Arm A correct-count: **30**
- Gap (C − A): **26 − 30 = −4**
- Threshold to keep: **≥ +7**
- −4 does not meet ≥ +7 (it is not merely short of the threshold, it is negative — arm C's raw count
  is *lower*, not higher).

**`RULE OUTPUT: revert`**

**What would have produced the opposite output:** a gap of ≥ +7 in arm C's favour — e.g., arm C
correct-count of 37 or more against arm A's 30 (at these actual, unequal N's), or, at the fully
authorised 40-vs-40 size the threshold was computed for, arm C beating arm A by 7 or more correct
cells out of 40 each. Confirmed written before any data existed: `AB-PROTOCOL.md` was committed at
`d0521e2` (plan 11-05, Task 1), and the §4 resolution block recording the ≥7 threshold for this exact
run size was recorded after the Task 3 checkpoint, both before this run (`20260902T062649Z-ab-main`)
started.

**Read the −4 correctly — it is not evidence that arm C performs worse.** §4 already showed the
entire per-arm difference in correct-counts is explained by (a) arm A having 4 more total cells than
arm C (35 vs 31, purely because the cap-triggered stop landed after `07-C-r1`, an artifact of *when*
the run stopped, not of accuracy) and (b) both arms tying exactly (0/5 each) on the one task that
produced any incorrect answers at all. On every task both arms could be compared on equal footing —
01 through 05, and 07's single directly-comparable rep — **both arms are 100% correct.** A −4 raw
gap produced this way is not the same claim as "arm C got 4 more answers wrong than arm A"; it is
"arm C simply has 4 fewer opportunities to have been correct, and used none of the ones it did have
to fall behind." The permutation test (§6, p=0.563) is consistent with this reading. **The
mechanical rule output is still `revert`** — this document does not adjust the rule's arithmetic to
account for the N imbalance, because §5 pre-registers a raw-count comparison and this document
applies it exactly as written — but a reader should not walk away thinking this run found the
reasoning arm answers questions less accurately. It found **no measurable difference in accuracy on
the tasks both arms actually got to attempt**, at a smaller and uneven sample than authorised.

**This document does not declare the decision.** The ratified keep/revert decision and the
`DECISION:` line belong to plan 11-07, after human review — changing which alias `cline-plan`
targets changes the default behaviour of a tool the user actually runs, and (per §1c) plan 11-07
also has to weigh the now-100%-frequency `providers.json` mutation hazard, which this document's
decision rule (an answer-quality rule) cannot resolve on its own.

---

## §9 Limitations, stated plainly

- **The run did not reach its authorised size.** 66 of 88 invocations; task 08 (both
  bug-localisation tasks) and arm B were never attempted, due to the request-cap early stop
  documented in §1a. This is the single largest limitation of this dataset.
- **N is uneven between arms** (35 vs 31) and, for task 07, uneven within a task (A: N=5, C: N=1) —
  a direct consequence of the same early stop, not a design choice.
- **Resolution.** Even at the fully authorised 40-vs-40 cells this run was sized for, `AB-PROTOCOL.md`
  §5 itself states the ≥7-of-40 threshold cannot reliably distinguish smaller true effects from
  temperature-1.0 noise; at the actually-achieved 31-vs-35, the resolution is strictly worse. A true
  effect smaller than roughly one-sixth of the smaller arm's cell count would not be reliably
  detected by this design even had it run to completion.
- **The pilot's ceiling-effect risk, re-surfaced as instructed.** Plan 11-05's Task 3 checkpoint
  flagged that both piloted tasks (01, 04) graded `ceiling` (all three arms correct at N=1), and the
  reviewer authorised the full run anyway specifically to get broader-than-2-task evidence. This
  run's own data shows the **same ceiling pattern held for 5 of the 6 tasks actually completed by
  both arms** (01–05, both arms 100%) — only task 06 broke the ceiling, and it broke it identically
  for both arms (a floor, not a discriminator). The two entirely-untested bug-localisation tasks
  (07 fully tested for A only, 08 untested for either) were exactly the category the reviewer most
  wanted broader evidence on, and this run could not deliver it for 08 at all.
- **Temperature-1.0 sampling**, per the model's own `generation_config.json` — no override exists
  anywhere in the live litellm config, so every measurement here is genuinely stochastic, not merely
  nominally so.
- **A project-built task set, not an external benchmark** — `AB-TASKSET.md` §1's own reasoning for
  declining cline-bench (its two `easy` tasks already overflow the context ceiling on an unrelated
  compaction-pruning defect) still applies; this instrument answers "does `medium` reasoning change
  answer quality on bounded, single-domain tasks," not "does it help on realistic agentic workloads."
- **The shared, dynamic completion budget** (`AB-PROTOCOL.md` §3): `finish_reason=stop` on every
  cell this run, so budget starvation did not materialise here, but the budget itself still varies
  per-request with `prompt_tokens`, and is not a fixed constant either arm could be said to have
  "more" or "less" of.
- **Single model, single machine, single day.** No claim generalises past the installed
  `flashnext`/`flashnext-plan`/`flashnext-act` configuration, cline `3.0.61`, and this one session.
- **What genuinely surprised this run, beyond what the pilot predicted:** the emergent tool-calling
  behaviour (§1a) that consumed the budget faster than planned, and the fact that its effect was
  asymmetric across arms (arm A used the tool path more often than arm C — §4) rather than uniform.
  Neither was visible in, or predictable from, the pilot's 6-cell, all-single-turn dataset.
- **`providers.json`'s drift frequency is now measured at 100%** (§1c), not merely "reproducible" —
  this is a materially stronger finding than either prior single-occurrence observation and changes
  what plan 11-07 is weighing: not "this can happen" but "this happens every time."

---

## §10 The `flashnext-reach-xhigh` note

`phase-10/PHASE-10-FINDINGS.md` §5 left open whether the verification-only `flashnext-reach-xhigh`
alias should remain in the live litellm config now that Phase 10's reach questions are closed. It is
**not part of this A/B** (no arm in §1 uses it). Checked directly against the live config for this
document (`~/local-llm-settings/config/litellm-config.yaml`, read-only, not queried over the
network): **it is still present** (`model_name: flashnext-reach-xhigh`, alongside `flashnext`,
`flashnext-codex`, `flashnext-plan`, `flashnext-act`). Per `phase-10/PHASE-10-FINDINGS.md`, that
decision is handed to **Phase 12** — recorded here again so it is not silently dropped a second
time.
