# Pilot notes — phase-11/results/20260902T054619Z-ab-pilot

Plan 11-05, Task 2, Part B. 6 cells: 2 tasks × 3 arms × 1 rep. Read from `ab.tsv`, `budget.tsv`,
`manifest.txt`, `postflight.txt`, and two raw NDJSON streams read by hand — not from exit codes.

---

## 🔴 Safety-envelope violation encountered — read this first

**`postflight11` FAILED at the end of this run.** `providers.json`'s judged `model` field moved
from `flashnext` to `flashnext-plan` (the last cell fired was `04-C-r1`, which invoked the real
`cline` binary with `-m flashnext-plan`, and — as `phase-11/OPEN-ITEMS.md`'s Open Item 3 already
observed once before at a different call — the value that call's `-m` argument used persisted into
`providers.json` after the call returned, even though the call itself never touched providers.json's
Plan-mode-specific settings by name). `contextWindow` held at `29000` (the other judged field did
**not** move). `postflight.txt`:

```
FAIL: providers.json model drifted (before='flashnext' after='flashnext-plan') -- JUDGED field
OK: providers.json contextWindow unchanged ('29000') -- JUDGED field
FAIL: verify_config.sh (providers.json section) exited non-zero
```

**Per the plan's own pre-registered instruction, `providers.json` was NOT restored and no further
live model request was issued after this was observed.** The violation was only visible in
`postflight11`, which by construction runs after the last cell — so it did not (and could not) cause
this pilot to "continue past" it: all 6 planned pilot cells had already completed before the check
ran. Two `--resume` re-invocations were made afterward purely to verify the runner's resume
behaviour (§ "Resume verification" below); both made **zero** live model requests (confirmed by an
unchanged `Generation queued` count in `flashnext.err`, 911 before and after both checks), so they
do not count as continuing past the violation either.

`bash phase-01/config/verify_config.sh` still fails as of this writing (exit 1, `model` observed as
`flashnext-plan`). This is a real, live, production-affecting condition — Kanban and Telegram share
this same provider entry and will now default to the reasoning-heavy alias for any of their own
`cline` invocations that omit an explicit `-m`. Restoring it is outside this plan's authority (hard
constraint: do not edit `providers.json`) and outside its scope; per `OPEN-ITEMS.md`'s own framing
of the same class of event, this needs a decision from the orchestrator/user, not this plan.

`cline --version` was stable at `3.0.61` across the entire pilot session (captured at the first
invocation's preflight and confirmed unchanged by every subsequent preflight/postflight in this run
directory) — the version-stability discard condition was **not** triggered.

---

## The six cells, verbatim from `ab.tsv`

| task | arm | alias | dur_s | prompt_tokens | completion_tokens | max_tokens | finish_reason | verdict | requests_this_cell | running_total |
|---|---|---|---:|---:|---:|---:|---|---|---:|---:|
| 01 | A | flashnext | 15 | 5588 | 160 | 20851 | stop | **correct** | 1 | 1 |
| 01 | B | flashnext-act | 16 | 5452 | 231 | 20851 | stop | **correct** | 1 | 2 |
| 01 | C | flashnext-plan | 17 | 5450 | 269 | 20851 | stop | **correct** | 1 | 3 |
| 04 | A | flashnext | 15 | 5636 | 195 | 20833 | stop | **correct** | 1 | 4 |
| 04 | B | flashnext-act | 18 | 5500 | 259 | 20833 | stop | **correct** | 1 | 5 |
| 04 | C | flashnext-plan | 17 | 5498 | 236 | 20833 | stop | **correct** | 1 | 6 |

**All six cells graded `correct`. Zero `no-answer`, zero `no-output`, zero `unparseable`, zero
retries.**

---

## Wall clock per arm (N=2 samples per arm — one per piloted task; not a repetition count, a
category count)

| arm | durations (s) | mean | max |
|---|---|---:|---:|
| A (flashnext) | 15, 15 | 15.0 | 15 |
| B (flashnext-act) | 16, 18 | 17.0 | 18 |
| C (flashnext-plan) | 17, 17 | 17.0 | 17 |

Slowest arm by mean: **B and C tie at 17.0s**; A is fastest at 15.0s. For sizing projection below,
the slowest observed per-invocation time (**17s**, from arms B/C) is used conservatively for every
invocation, including A's.

## `completion_tokens` beside the timing table — the generation-length confound, checked

| arm | completion_tokens | mean |
|---|---|---:|
| A (flashnext, no thinking) | 160, 195 | 177.5 |
| B (flashnext-act, no thinking) | 231, 259 | 245.0 |
| C (flashnext-plan, thinking=medium) | 269, 236 | 252.5 |

C's mean completion length (252.5) is materially higher than A's (177.5) — consistent with C
producing a visible reasoning trace in addition to the answer (confirmed by the manual read below:
`04-C-r1`'s raw stream contains an explicit `"contentType": "reasoning"` block). **Per
`AB-PROTOCOL.md` §3, this pilot's small C-vs-A timing gap (17s vs 15s mean) is not read as "thinking
cost"** — it is at least partly a generation-length effect, and the sample here (N=2 per arm) is far
too small to separate the two contributions with any confidence regardless. Interestingly, B (no
thinking, same `hosted_vllm/` prefix as C) also generated substantially more than A (245.0 vs 177.5)
despite having no reasoning trace — suggesting some of the length difference may be attributable to
the `hosted_vllm/` transformation path itself, not reasoning, which is exactly the confound arm B
exists to help separate. This pilot's N is too small to say more than "noted, watch it in the main
run."

## `prompt_tokens` vs the live compaction trigger (26,100; abort condition is >25% = 6,525)

| task | arm | prompt_tokens | % of trigger |
|---|---|---:|---:|
| 01 | A | 5588 | 21.41% |
| 01 | B | 5452 | 20.89% |
| 01 | C | 5450 | 20.88% |
| 04 | A | 5636 | 21.59% |
| 04 | B | 5500 | 21.07% |
| 04 | C | 5498 | 21.07% |

**Maximum observed: 21.59%, well under the 25% abort threshold.** No task in this pilot approaches
the live compaction trigger. (The fixed system prompt and turn scaffolding account for most of these
~5,450–5,640 tokens against a ≤586-byte task prompt — this is expected and was not itself part of
what §3's 25% check screens for; the check is about headroom under the trigger, which is ample here.)

## Completion-budget starvation check

`finish_reason=stop` on all six cells — no `length` truncations anywhere, including on the thinking
arm (C). `max_tokens` was 20,851 (task 01) / 20,833 (task 04) for **every** arm on a given task —
confirming AB-PROTOCOL.md §3's claim that the dynamic budget is prompt-driven, not arm-driven (same
prompt → same budget, regardless of which alias received it). **Zero `no-output` verdicts observed.**
No sign of budget starvation under `medium` thinking through Cline at this prompt size — consistent
with AB-PROTOCOL.md §3's prediction that the effect Phase 9 measured at a 300-token budget "largely
disappears" once the effective budget is ~17,000+ tokens (here, ~20,800).

---

## Manual read of raw streams (grader-trust check — not optional)

**Read directly, not inferred from the grader's own report:**

- `streams/01-A-r1.ndjson` (167 lines): the model's final `text` field (via the `"type":"done"`
  event) ends literally with `...**Total time:** 2 + 6 = **8 hours**.\n\nANSWER: 8`. Expected value
  for task 01 is `8`. **The grader's `correct` verdict for this cell is confirmed by eye** — the
  visible text really does contain a well-formed `ANSWER: 8` line and the arithmetic shown in the
  model's own working (2h combined + 6h more from B alone = 8h) is the same derivation
  `01-pipe-rate.expected`'s own `notes` field records.
- `streams/04-C-r1.ndjson` (243 lines): contains an explicit reasoning block
  (`{"type":"content_end","contentType":"reasoning","reasoning":"The function sums elements at
  indices 1 to n-2 (excluding both ends). For [10,20,30,40,50], that's n=5, and range(1,4) gives
  indices 1,2,3 → 20+30+40 = 90.\n"}`) followed by a final `text` ending
  `...it returns total, which is 90.\n\nANSWER: 90`. Expected value for task 04 is `90`. **Confirmed
  correct by eye**, and this stream additionally confirms `flashnext-plan`'s reasoning parameter is
  genuinely producing a visible, on-topic reasoning trace through the real `cline` client (not just
  at the raw litellm/curl level `phase-11/OPEN-ITEMS.md` Open Item 1 already checked) — the trace's
  own arithmetic (20+30+40=90) matches the visible answer and the task's own truth-derivation.

Two of six streams read by hand; both verdicts match the visible text exactly. No sign the grader is
agreeing with itself.

---

## §4 sizing arithmetic, applied to these measurements

**Default plan:** 8 tasks × (A×N + C×N + B×1). With N=3: 8×7 = **56 invocations**.

**Step 1 — largest N ∈ {5,3} within both ceilings.**
- N=5, 8 tasks → 8×(5+5+1) = **88 invocations > 72** — fails the invocation ceiling **on its own**,
  before any pilot timing is consulted at all. This is exactly AB-PROTOCOL.md §4's own pre-stated
  arithmetic consequence, not a new finding.
- N=3, 8 tasks → 56 invocations ≤ 72 ✓. Projected wall clock, using this pilot's slowest observed
  per-invocation time (17s, arms B/C) applied uniformly: 56 × 17s = 952s ≈ **15.9 minutes** ≤ 90 min
  ✓. **N=3 with 8 tasks passes both ceilings.**

**Step 2 does not fire.** N=3 with 8 tasks does not exceed either ceiling, so the task-drop rule is
**not applied** to the main run — the proposal is the full 8-task set at N=3, 56 invocations,
~16 minutes projected.

**What the measurements actually drove vs. what the default ceilings had already fixed, stated
plainly:** the ceiling (72 invocations) alone rules out N=5 regardless of any timing — 88 > 72 is
true before a single pilot cell runs. What the pilot's own timing *did* determine is that N=3 at 8
tasks does not merely satisfy the invocation ceiling, it also comfortably clears the 90-minute
wall-clock ceiling (~16 of 90 minutes) — and, as a side observation worth surfacing to the reviewer,
**N=5 at 8 tasks (88 invocations, ~25 minutes at this pilot's timings) would also have comfortably
cleared the 90-minute ceiling on its own** — it is purely the 72-invocation ceiling, not the
90-minute one, that would need to be raised (to ≥88) at Task 3 for N=5 to become reachable.

**Proposed for plan 11-06 (pending Task 3 authorisation):**
- Tasks: 8 (all of them — no reduction needed under default ceilings)
- N: 3
- Total invocations: 56
- Projected wall clock: ~16 minutes (conservative, using the slowest arm's mean; likely somewhat
  less in practice since arm A ran faster in this pilot)
- Hard request cap for plan 11-06: **56** (1:1 with invocations under non-runaway conditions),
  runaway-agent-loop abort guard at **168** (3× invocations)
- §5 threshold this size selects (pre-computed, `AB-PROTOCOL.md` §5 table): 8 tasks × N=3 = 24
  cells → **≥4** cells' gap in arm C's favour to keep `flashnext-plan`.

---

## §4 task-drop classification of both piloted tasks — recorded regardless of whether the reduction
branch fires (it does not, per the arithmetic above)

- **Task 01 (pipe-rate, word-problem):** all three arms graded `correct` → **ceiling**.
- **Task 04 (loop-sum, code-trace):** all three arms graded `correct` → **ceiling**.

**Both piloted tasks are ceiling** → task-drop rule **branch 2** would select: drop the
highest-id non-piloted sibling from each piloted task's category — **task 03
(reinvested-interest, word-problem)** and **task 06 (mode-char, code-trace)** — yielding a 2+2+2
six-task set (01,02 word-problem / 04,05 code-trace / 07,08 bug-localisation) **if and only if** the
sizing rule's step 2 ever required a reduction. It does not, per the arithmetic above, so **this
branch is recorded but not applied**: the main run proceeds with all 8 tasks.

---

## §6 stopping conditions — checked, one is worth flagging even though it does not itself trigger a
hard stop

- Both arms at floor: **not observed** (0/6 cells incorrect/no-output/unparseable).
- Per-invocation cost making a defensible N unaffordable: **not observed** — the proposed main run
  (56 invocations, ~16 min) is comfortably affordable within both self-imposed ceilings.
- A grader mis-verdicting real output: **not observed** — both manually-read streams confirm the
  grader's verdict against the actual visible text.
- **Both arms at ceiling — observed, on this 2-task slice.** All six pilot cells graded `correct`.
  This is exactly §6's "both arms near 100%" condition, on the two tasks piloted. It does **not**
  mechanically trigger a stop or a reduction under the sizing rule (which only responds to the
  invocation/wall-clock ceilings, not to correctness), and it is only 2 of 8 tasks at N=1 each — a
  very small basis for a conclusion about the whole set. But it is a real, honestly-reported signal
  that this task set's word-problem and code-trace categories may be too easy for this model at
  `--max-num-seqs 1` (i.e., no real generation constraint) to discriminate `medium` reasoning's
  effect, and it is the same signal the task-drop rule's own "ceiling" classification is built to
  detect and respond to by trimming redundant same-category tasks. The two untested categories from
  this pilot (the third word-problem/code-trace task and both bug-localisation tasks) are the ones
  most likely to still discriminate, if anything in this 8-task set does — this is exactly why the
  task-drop rule, when it does fire, never drops a piloted task itself. **This is carried into the
  Task 3 checkpoint as a named risk, not smoothed over**, per this plan's outcome-neutrality
  requirement.

---

## Budget accounting

**Cap for this pilot invocation: 10.** **Measured: 6** `Generation queued` lines in `flashnext.err`
since this run's watermark (line 23798), cross-checked independently against `Prefill started` lines
over the same window (also **6** — the two counters agree exactly, as `probe_lib11.sh`'s own header
comment documents they should). **No overage; 4 of the 10-request cap were never spent.**

## Resume verification

Re-invoking `run_ab.sh` with identical arguments plus `--resume` twice (once before, once after
fixing the manifest.txt append bug below) both added **zero** new rows to `ab.tsv` (7 lines — 1
header + 6 data — unchanged across both checks) and issued **zero** new live requests (`Generation
queued` count in `flashnext.err`: 911 before and after both checks). `postflight11` correctly still
reports the same `providers.json` `model` failure on every re-invocation, since that condition is a
persistent fact about the live file, not something a read-only resume check could or should clear.

---

## A bug found and fixed during this pilot (Rule 1)

`run_ab.sh`'s `manifest.txt` was originally written with a truncating `>` redirect at both its
opening and closing blocks, on every invocation — including a `--resume` re-invocation that fires no
live requests. The first `--resume` verification check (run before this was noticed) silently
overwrote the original run's `manifest.txt`, replacing its real `cells_this_invocation=6` and its
correctly-captured `live_compaction_trigger` line with a resume invocation's own (0 cells,
already-failing-so-empty trigger line, since `verify_config.sh` no longer prints the trigger line
once its providers.json section has already failed). **No data in `ab.tsv` or `budget.tsv` was ever
affected** — both are append-only by construction and were not touched by this bug. Fixed by making
`manifest.txt` append-only across invocations (each invocation gets its own timestamped block) and
by having the closing block read the real post-postflight `cline-version-after.txt` instead of a
placeholder string. Verified fixed: a third invocation (also `--resume`, also zero live requests)
correctly appended a new block without disturbing the prior ones, and `manifest.txt`'s final block
now shows the real `cline_version_after=3.0.61` rather than a placeholder. The original invocation's
lost manifest text is not recoverable, but every fact it would have recorded is independently present
and unambiguous in `ab.tsv`, `budget.tsv`, and this document.
