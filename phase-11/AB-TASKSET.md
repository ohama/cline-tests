# AB-TASKSET.md — the USE-03 instrument

**Decision date: 2026-09-02, before any USE-03 measurement exists.** This document is written and
committed before plan 11-05/11-06 issue a single live model request against either arm. Nothing
below is fit to any observed A/B result — the design constraints in §2 and the outcome-meaning
statements in §4 are pre-registered.

---

## §1 — Why not cline-bench

ROADMAP criterion 3 for Phase 11 names the same cline-bench task set Phase 07 already exercised.
This section quotes Phase 07's primary evidence directly (not `11-RESEARCH.md`'s summary of it) and
states why re-running that pool for USE-03 would not answer the question USE-03 asks.

### Primary rows, quoted from source

From `bench/runs/20260830T122809Z-phase07-fix/summary.md` (the post-fix run — the one in which the
injection mechanism is confirmed working and requests demonstrably reach this stack's `flashnext`
server), the run's own table:

```
| task                              | difficulty | verdict      | reward | wall_clock_s | model_turns | max_prompt_tokens | note |
| discord-trivia-approval-keyerror  | easy       | fail-context | 0      | 1665         | 38          | 30463             | -    |
| filmarchiver                      | medium     | fail-infra   | null   | 437          | 0           | 0                 | -    |
| telegram-plugin-refactor          | easy       | fail-context | 0      | 371          | 6           | 21036             | -    |
| v-edit-workspace-tests            | hard       | fail-context | 0      | 585          | 12          | 30696             | -    |
```

Grep confirmation that these rows are exactly what the source file contains (run against the file
itself, not retyped from memory):

```
$ grep -n "discord-trivia-approval-keyerror\|telegram-plugin-refactor" bench/runs/20260830T122809Z-phase07-fix/summary.md
22:| discord-trivia-approval-keyerror | easy | fail-context | 0 | 1665 | 38 | 30463 | - |
24:| telegram-plugin-refactor | easy | fail-context | 0 | 371 | 6 | 21036 | - |
```

Both grep lines match the quoted table verbatim. Both `easy`-difficulty tasks in the official pool
are `fail-context`, not `pass` or `fail-task`.

That table's own `max_prompt_tokens` column undercounts the fatal request, because a request the
server *rejects* never enters the accepted-request field that column reads. The corrected,
gap-closure figure — the actual prompt size at the moment of rejection — is in
`phase-07/results/20260831T010013Z-reclassify/RECLASSIFICATION.md`:

```
| task                              | max_prompt_tokens (accepted-only) | max_prompt_tokens_attempted | delta   |
| telegram-plugin-refactor          | 21036                              | 36155                        | 15,119  |
| v-edit-workspace-tests            | 30696                               | 30843                        | 147     |
| discord-trivia-approval-keyerror  | 30463                               | 31179                        | 716     |
```

`RECLASSIFICATION.md` also records, unchanged from the original classification: after auditing and
repairing the original classifier (which had both false positives and false negatives), all five
run instances were reclassified and **zero verdicts changed** — the three `fail-context` calls
above were correct the first time.

The 32K ceiling itself, and how it was hit, is detailed in
`phase-07/results/20260831T003728Z-context-forensics/CONTEXT-FORENSICS.md`: compaction fired on
schedule in both `telegram-plugin-refactor` and `v-edit-workspace-tests`, but in both cases
`messagesBefore == messagesAfter == 16` — no message was actually removed, only a summary was
prepended on top of the untouched original history. `telegram-plugin-refactor` then died in one
jump (a single `read_files` tool call added ~11,764 tokens, pushing the next request from 21,036 to
36,155 — 5,435 tokens past the 32,768 ceiling once `max_tokens:2048` is added). `v-edit-workspace-tests`
died by a slow four-turn creep after its one compaction (27,173 → 29,218 → 30,117 ×2 → 30,696 →
30,843), missing the wall by only 123 tokens. Two different failure shapes, one shared root cause:
compaction summarizes but does not prune.

### The argument, in three steps

**(a) Both `easy`-difficulty tasks in the official pool already overflow the 32K ceiling**, at
31,179 (`discord-trivia-approval-keyerror`) and 36,155 (`telegram-plugin-refactor`) attempted prompt
tokens — the cheapest, most-likely-to-fit tasks in the pool are the ones that failed.

**(b) The 8 tasks that were not run are all `medium`/`hard`** (`filmarchiver` did run but died to an
unrelated container bug, `fail-infra`, before reaching the model at all — it supplies no context
signal either way). The untried tasks are structurally larger workloads, not smaller ones, so there
is no basis internal to this evidence for expecting any of them to fit where the two `easy` tasks
did not.

**(c) The reasoning-effort parameter this A/B varies cannot close a gap of this size.** `medium`
reasoning's only measured effect on `prompt_tokens` is **−2** relative to unspecified
(`phase-09/PRB-03-ORACLE.md` §2b: "Delta from `unspecified`... medium | −2 | −2 | **−2**" across
three independent measurement sessions weeks apart, bit-for-bit identical), corroborated at the
actual shipped alias in `phase-10/REACH-PROOF.md` §3b ("`B` (`flashnext`, unspecified) vs `D`
(`flashnext-plan`, et-medium injected): prompt_tokens 13 vs 11, **delta = −2**, exactly matching the
oracle's et-medium delta"). Separately, reasoning-history replay costs **0** additional prompt
tokens even for a 2,497-character real trace (`phase-09/PRB-04-FINDINGS.md`: "16/16 `delta=0`,
CLEAN" across two endpoints, two field names, synthetic and real traces). A −2-token effect, or a
0-token replay cost, cannot rescue a task overflowing its budget by 5,000–15,000 tokens.

**Therefore:** running `flashnext` vs `flashnext-plan` on the official cline-bench pool would very
likely reproduce 0/N vs 0/N — a null result that measures the compaction-pruning defect this
project already carries as an open, accepted v1 blocker (`.planning/STATE.md` Blockers/Concerns:
"실제 부하에서 압축이 프루닝하지 않는다. cline-bench 통과 0개"), not whether `medium` reasoning
changes answer quality. That is not what USE-03 asks.

### The declined fallback

A technically valid alternative was considered and declined, so this decision does not read as
avoiding the official benchmark by omission: **run the two already-`fail-context` `easy` tasks
(`discord-trivia-approval-keyerror`, `telegram-plugin-refactor`) under both arms and report the
expected 0/2-vs-0/2 result as USE-03's answer.** USE-03's own text accepts "no improvement" as a
valid, complete disposition, so this would technically satisfy the letter of the requirement.

It is declined for two reasons: (1) it spends the shared single-concurrency model's queue — the
same queue Kanban and Telegram share — on a run whose outcome is already known from Phase 07's own
evidence above, buying no new information; (2) "both arms hit an unrelated 32K ceiling before
producing an answer" answers a different question than "does `medium` reasoning improve answer
quality" — it is a null result about compaction, not about reasoning effort, and reporting it as a
USE-03 finding would misattribute the cause.

### The reversal condition

**What would put cline-bench back in scope:** a future phase (this project's own open v1 blocker,
not scoped to v1.1) fixing the compaction-pruning defect described in
`phase-07/results/20260831T003728Z-context-forensics/CONTEXT-FORENSICS.md` — i.e., compaction
actually shortens the persisted message array (`messagesAfter < messagesBefore`) rather than only
prepending a summary on top of the untouched original — such that at least one `easy`-difficulty
cline-bench task completes (any verdict other than `fail-context`/`fail-infra`) under either arm.
At that point, the official pool would no longer be structurally guaranteed to return 0/N regardless
of reasoning effort, and the A/B should be re-run on it, and this decision revisited.

This decision was made **before any USE-03 measurement existed** — no A/B has been run under either
arm, on any task set, as of this writing (2026-09-02).

---

## §2 — Design constraints for the replacement set

- **Bounded turns (1–3).** Every prompt is answerable without tool use — no task should require a
  file read or an editing/execution tool call. Two reasons: (1) it removes turn count as a source
  of prompt growth entirely (the very failure mode §1 documents — a single tool call added ~11,764
  tokens in one turn in `telegram-plugin-refactor`); (2) `docs/headless-wrapper.md` §4 records that
  `--auto-approve false` headless mode rejects every tool call outright
  (`Tool "<name>" requires approval in a TTY session`, followed by self-abort) — keeping tools out
  of the prompt design removes that whole axis from the A/B comparison rather than confounding
  "does thinking help" with "did a tool call get rejected".

- **Prompt size ≪ trigger.** `phase-01/config/verify_config.sh` prints the live compaction trigger:
  `trigger = maxInputTokens x 0.9 = 26100`. Each task's prompt is capped at 1,500 bytes; the measured
  byte size of every prompt is recorded in `MANIFEST.tsv`'s `prompt_bytes` column (§5 below). A
  1,500-byte prompt is on the order of a few hundred tokens at most — nowhere near the 26,100-token
  trigger even before the fixed system prompt and any turn history are added. This plan does not
  measure the real tokenized `prompt_tokens` (that is a live-request measurement, owned by 11-05's
  pilot); this constraint only has to make overflow structurally implausible for a 1–3 turn run,
  which a byte cap this far under trigger achieves without needing a live call.

- **Answer budget ≪ completion cap.** Cline sends a fixed per-turn completion budget (measured 2048
  at 3.0.53, `docs/cline-max-tokens-findings.md`; **not yet re-verified at 3.0.60 — open item owned
  by plan 11-04**, since the host `cline` binary has drifted from 3.0.53 to 3.0.60 mid-project,
  `phase-10/VRF-04-OBSERVATION.md` §1). Whatever that budget turns out to be, a thinking arm shares
  it between the reasoning trace and the visible answer: `phase-09/PRB-03-ORACLE.md` §3 measured
  `xhigh` reasoning alone consuming an entire 300-token completion budget and returning **empty**
  final content, `finish_reason: "length"`, on two consecutive turns ("ON's turns 2 and 3 came back
  with **empty** content entirely, because `xhigh` reasoning alone consumed the full 300-token
  completion budget before any answer text could be produced"). Every task in this set is designed
  so its expected answer is a handful of tokens (a number, a single character, a short line-number),
  so that if a run is graded `no-answer` or `no-output`, that is a signal about budget starvation
  under `medium` thinking through Cline, not an artifact of the task demanding a long answer.

- **Objectively gradable.** No LLM judge and no human judgement anywhere in the loop: every task has
  a single fixed expected value and a mechanical (string/numeric) comparison, implemented in
  `grade_ab.py` (Task 3).

- **Plausibly reasoning-sensitive.** `phase-10/VRF-04-OBSERVATION.md` §3 reports its own single
  arithmetic-word-problem prompt was too easy to separate the arms on its own. This set therefore
  uses multi-step word problems (3+ arithmetic steps, not single-step trivia), code-tracing
  questions requiring a full trace of a 12–20 line function (including at least one with a
  loop-boundary or mutation-aliasing subtlety), and single-defect bug-localisation snippets — tasks
  chosen to have enough intermediate reasoning surface that a difference between arms, if one
  exists, has room to show up, while still being answerable within the bounded-turn/bounded-answer
  constraints above.

- **Numeric-match observation (from Task 3's fixture work).** `ANSWER: 84.0` graded against
  `expected: 84` under `match: numeric` returns `correct` (both sides parsed as floats: 84.0 ==
  84.0). The same pair graded under `match: exact_normalized` returns **`incorrect`** — normalization
  strips whitespace and a trailing period but does not fold `84.0` and `84` to the same string, so a
  purely formatting difference reads as a wrong answer. This is exactly why every task whose answer
  is a number uses `match: numeric` in `MANIFEST.tsv`/the `.expected` files, never
  `exact_normalized` — grading noise from decimal-point formatting would otherwise be
  indistinguishable from a real arm difference. (Verified directly in Task 3's fixture run; see
  `phase-11/fixtures/selftest.tsv` row `f8-numeric-vs-exact`.)

---

## §3 — Answer protocol

Every prompt in this set ends with the identical sentence, verbatim, so the answer-format
instruction is never a variable across arms or tasks:

```
Respond with exactly one line at the end of your reply, in exactly this form and nothing else on that line: ANSWER: <value>
```

This sentence is the only place the literal string `ANSWER:` may appear in any `.prompt` file — no
task's prompt body contains a worked example or restated instance of the format, so the model is
never shown a second occurrence that could leak per-task formatting quirks into its output.

---

## §4 — What each possible aggregate outcome would mean (written before any data exists)

- **(a) Both arms near 100%.** The set is too easy to discriminate the arms; that is what gets
  reported, not a claim that thinking "works" — a ceiling result answers nothing about whether
  `medium` helps, only that this task set cannot tell.
- **(b) Both arms near 0%.** The set is too hard, or the harness itself is broken (a bad grader, a
  malformed prompt, a wrapper defect). The pilot (11-05) must catch this **before** the main run is
  spent; a 0%-vs-0% main-run result without a pilot check first would be indistinguishable from a
  broken instrument, not evidence about reasoning effort.
- **(c) The arms differ.** The measured gap between `flashnext` and `flashnext-plan` on this task
  set is the finding, reported as-is, in whichever direction it points — USE-03 does not presuppose
  the direction.
- **(d) The thinking arm (`flashnext-plan`) shows many `no-answer` verdicts relative to the baseline
  arm.** This is not noise to be corrected away — per §2's `xhigh`/300-token precedent, it would be
  a real, reportable finding: deploying `medium` thinking through Cline's fixed completion budget
  starves the visible answer more often than not thinking at all. That is itself a valid answer to
  "does turning on `medium` reasoning through this wrapper help" — the answer would be "no, and here
  is the specific mechanism."

None of (a)–(d) is presumed. §5 (the task table) and the grader (Task 3) are built to be able to
produce and distinguish all four before any arm has been run.

---

## §5 — Task table

(Filled by Task 2. Row count: 8. Answer keys are not reproduced here — they live in
`phase-11/tasks/*.expected`, one file per task, so this table describes the set's shape without
itself becoming the answer sheet.)

| id | category | description | prompt_bytes | match_mode |
|----|----------|-------------|-------------:|------------|
| 01 | word-problem | two-pipe combined-then-solo fill-time problem | 427 | numeric |
| 02 | word-problem | saline-solution dilution-to-target-concentration problem | 361 | numeric |
| 03 | word-problem | two-stage simple-interest reinvestment problem | 437 | numeric |
| 04 | code-trace | trace a sum-of-interior-elements loop over a fixed list | 466 | numeric |
| 05 | code-trace | trace list aliasing vs `.copy()`, then a length check on the original | 461 | numeric |
| 06 | code-trace | trace a most-frequent-letter counter over a fixed string | 553 | exact_normalized |
| 07 | bug-localisation | locate a wrong-index off-by-one defect (IndexError) by line number | 510 | numeric |
| 08 | bug-localisation | locate an unguarded-division defect (ZeroDivisionError) by line number | 586 | numeric |

See `phase-11/tasks/MANIFEST.tsv` for exact prompt-byte counts, match modes, and each answer's
derivation method.
