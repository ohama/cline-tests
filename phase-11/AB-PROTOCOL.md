# AB-PROTOCOL.md — the USE-03 A/B protocol, pre-registered

**Written 2026-09-02, before any comparison data exists.** This document fixes the arms, the
fairness controls, the sizing rule, the request budget, the task-drop rule, and the keep-or-revert
decision rule — including the falsifier — before plan 11-05's Task 2 runs a single pilot cell.
`phase-11/AB-TASKSET.md` already froze the 8-task instrument and its grader; this document is
strictly about how that instrument is exercised and judged. Nothing below may be edited to fit a
result once pilot or main-run data exists — a change after that point is itself a reportable
deviation, not a protocol update.

---

## §1 Arms

Three arms, invoked at the flag-minimal shape already validated by
`phase-10/probe_vrf04_cline.sh`:

```
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m <alias> --compaction agentic --json -t 600 "<prompt>"
```

varying only `<alias>`:

- **A = `flashnext`** — the ROADMAP's and USE-03's literal control. `openai/`-prefixed at the
  gateway. No reasoning parameter of any kind is injected anywhere in this alias's litellm
  configuration.
- **C = `flashnext-plan`** — the shipped Plan alias. `hosted_vllm/`-prefixed, `enable_thinking:true`
  + `reasoning_effort:medium` injected server-side by litellm's alias config.
- **B = `flashnext-act`** — the **prefix-matched control**, run at reduced replication (N=1, never
  N-repeated like A and C). Its job is to separate "the reasoning parameter did something" from
  "the `hosted_vllm/` transformation path did something," a confound A-vs-C alone cannot separate
  because it differs in both prefix and reasoning simultaneously. `phase-10/REACH-PROOF.md` §4
  closed this confound for `prompt_tokens` only (delta 0 across three same-body pairings) — never
  for answer quality or latency. `flashnext-act` is `hosted_vllm/`-prefixed with thinking off.

## §2 The wrappers are deliberately not used for the A/B, and why

`cline-plan` sets `-p`, Cline's own agent-mode flag, which restricts the tool set to
`switchToActModeTool` only (`11-RESEARCH.md` Q2; `phase-11/WRAPPER-DESIGN.md` §5). Comparing
`cline-plan` against `cline-act` would confound the reasoning-parameter effect with a
tool-availability effect. The A/B holds the mode flag constant by omitting it in every arm (no
`-p` anywhere in §1's invocation). This means the A/B measures the **alias**, which is what
USE-03's keep-or-revert decision is actually about — the wrapper-level end-to-end behaviour
(mode/alias pairing, `--thinking` leak refusal) is covered separately by USE-01/USE-02's own tests
(`phase-11/verify_wrappers.sh`, `phase-11/wrapper_argv_test.sh`), not by this instrument.

## §3 Fairness controls, each with its measurement

- **Completion budget — 🔴 2026-09-02 correction, the premise changed.** Plan 11-04 measured
  `max_tokens=20983` and an earlier draft of this plan treated that as a new *fixed* value. It is
  **not fixed**: 278 server-log samples show `cline` sizing the completion budget dynamically per
  request so that `prompt_tokens + max_tokens` lands near 26,100 (`contextWindow × 0.9`, the same
  value `verify_config.sh` prints as the compaction trigger). Observed pairs:
  `prompt=8761 → max=17716`, `prompt=9846 → max=16567`. Across the 278 samples: minimum sum 9,442,
  mean sum 25,573, maximum sum 32,013 — **zero breaches of the server's 32,768 limit.** The fixed
  `2048` belonged to cline 3.0.53 and no longer applies at the installed 3.0.61.
  This remains a **shared constraint applying equally to both arms** — for a given prompt, the
  budget is the same regardless of which alias receives it, so neither arm is given more headroom
  than the other. The basis changed from "cline ignores the configured value" to "cline hands out
  whatever context remains."
  **Fairness is actually better than assumed.** The budget-exhaustion effect Phase 9 measured at a
  fixed 300-token budget (`phase-09/PRB-03-ORACLE.md` §3: `xhigh` reasoning alone consumed the
  entire 300-token completion budget and returned **empty** content, `finish_reason: "length"`, on
  two consecutive turns) largely disappears once the effective budget is ~17,000 tokens. The
  `no-output` category is nonetheless kept in the grader (`phase-11/grade_ab.py`) and in this A/B's
  reporting — if it occurs, it is reported **in its own category and never folded into
  "incorrect,"** and this protocol's own results document (`AB-RESULTS.md`, plan 11-06) must state
  the observed `no-output` count whether it is zero or not.
- **🔴 Generation-length confound (new, 2026-09-02).** A dynamic budget means elapsed wall clock now
  mixes two different things: "thinking is slower" and "the answer/trace was longer." Every cell
  must therefore record `completion_tokens`, and `AB-RESULTS.md` must print each arm's mean
  `completion_tokens` directly beside the timing table. If the two arms' generation lengths differ
  materially, `AB-RESULTS.md` must say so explicitly and **must not** read a timing difference as
  "thinking cost" under that condition. This confound does not change §5's decision rule, which is
  accuracy-based; latency and length are reported as auxiliary information only.
- **Timeout.** `-t 600`, carried forward from VRF-04 unchanged, so a slow thinking generation is
  never truncated into what would look like a wrong answer.
- **Prompt size.** Every task's measured `prompt_tokens` must stay far below the live compaction
  trigger printed by `verify_config.sh` (currently 26,100). `AB-TASKSET.md` §2 already bounds every
  prompt to ≤1,500 bytes as a structural precaution; this protocol adds the live-measured check: the
  pilot measures real `prompt_tokens` from the server log, and **if any pilot run's `prompt_tokens`
  exceeds 25% of the trigger (6,525 tokens), the task set is judged too large and must be reduced
  before the main run.** This is an abort/reduce condition, stated before any prompt has been
  measured live.
- **Stochasticity.** The Flash-Next model's own `generation_config.json`
  (`/Users/ohama/projs/qwen38-flash-next-tests/.../generation_config.json`) declares
  `"do_sample": true, "temperature": 1.0`. No sampling override exists anywhere in the live litellm
  config. Sampling is therefore genuinely stochastic, not merely nominally so — repetitions (N) per
  cell are mandatory, not a nice-to-have.
- **Version stability.** `cline --version` is captured before and after the whole batch (pilot and,
  separately, the main run). **A mismatch is grounds to discard the run rather than report it**
  (VRF-04 precedent: a version change mid-comparison means the comparison spans two different
  binaries and is no longer a single measurement). This is a discard rule, not a warning — a
  version-mismatched run's numbers are not folded into the reported result.
- **Order.** Cells are executed in a fixed **interleaved order (task-major, arm-minor)**: for each
  task, in id order, run every arm's repetitions before moving to the next task — never all of arm
  A across every task followed by all of arm C. This spreads any time-varying condition on the
  shared single-slot model (another tenant's load, thermal state) as evenly as possible across the
  arms rather than concentrating it in one arm's block.

## §4 Sizing, and the rule that picks it — written before the pilot

**Default plan: 8 tasks × (A × N + C × N + B × 1).** With N=3 that is 8 × 7 = **56 invocations**.

**Where the two ceilings come from — stated plainly, not dressed up as a derivation.** The
72-invocation ceiling and the 90-minute wall-clock ceiling are **conservative defaults this plan
sets for itself, not measured or environmental constraints.** Nothing in the environment enforces
either number — no server-side rate limit, no imposed time budget. They were chosen before the
pilot as a self-imposed bound on how much of a single-slot (`--max-num-seqs 1`) model, shared with
Kanban and Telegram, this experiment may occupy, sized at roughly 1.3× the 56-invocation default
plan so the default sits comfortably inside them. They are **explicitly overridable at plan
11-05's Task 3 human checkpoint** — the reviewer may raise either ceiling (and thereby permit a
larger N) or lower them, and whichever is chosen is recorded verbatim in this section before plan
11-06 begins.

**The arithmetic consequence, stated so no later reader mistakes the outcome for a measurement.**
With 8 tasks, N=5 projects 8 × (5 + 5 + 1) = **88 invocations**, which exceeds the 72-invocation
ceiling on its own, before any pilot timing is even consulted. So under the default ceilings, the
sizing rule below is **guaranteed to select N=3 for 8 tasks regardless of what the pilot
measures** — the invocation ceiling decides it, not the timing data. N=5 only becomes reachable if
the reviewer raises the invocation ceiling to ≥88 at Task 3. What the pilot's measurements
genuinely decide is (a) whether even N=3 breaches the 90-minute wall-clock ceiling, and (b) whether
the task set must be reduced by the task-drop rule below. This protocol reports N=3 (under default
ceilings) as **"what the default ceiling permits," never as "what the pilot showed to be
correct."**

**The sizing rule, fixed now:**
1. Choose the largest N ∈ {5, 3} such that projected total invocations ≤ 72 **and** projected wall
   clock ≤ 90 minutes, using the pilot's measured median per-invocation seconds for the slowest arm.
   (Per the note above: with 8 tasks this resolves to N=3 unless a ceiling is raised at Task 3.)
2. If N=3 with 8 tasks exceeds either ceiling, reduce to 6 tasks using the task-drop rule below and
   re-apply step 1.
3. If N=3 with 6 tasks still exceeds either ceiling, **do not shrink further**: report that the A/B
   could not be sized affordably at a defensible N, and treat that as USE-03's answer, with its
   reasoning. This is an allowed, first-class outcome, not a failure of the plan.

**Task-drop rule — mechanically applicable from the pilot's own `ab.tsv`, no judgement.**
The pilot runs only 2 of the 8 tasks (the mechanically-selected lowest-id `word-problem` task and
lowest-id `code-trace` task — see plan 11-05 Task 2, Part B), so a criterion phrased over all eight
tasks ("drop the least informative") would demand data the pilot never produces. This rule is
written over exactly what the pilot yields: three verdicts per piloted task, plus the fixed
category structure of `phase-11/tasks/MANIFEST.tsv` (3 word-problem, 3 code-trace,
2 bug-localisation; the two piloted tasks are one word-problem and one code-trace).

Classify each **piloted** task from its three pilot rows:
- **ceiling** — all three arms graded `correct`;
- **floor** — no arm graded `correct` (any mix of `incorrect`, `no-output`, `unparseable`);
- **discriminating** — anything else.

Then drop exactly two tasks, by the first matching branch, never dropping a piloted task (its
measurements anchor the sizing arithmetic), taking siblings in **descending task id** order so the
choice is deterministic:

1. **Exactly one piloted task is ceiling-or-floor** → drop that task's two non-piloted
   category-siblings. A task set that cannot separate the arms in that category is the redundancy
   the pilot actually demonstrated. Result: 1 + 3 + 2 or 3 + 1 + 2 (six tasks total).
2. **Both piloted tasks are ceiling-or-floor** → drop the highest-id non-piloted sibling from each
   piloted task's category. Result: 2 + 2 + 2.
3. **Neither is ceiling-or-floor** → the pilot showed no redundancy, so fall back to a pure size
   cut that preserves category balance: drop the highest-id task in each of the two 3-task
   categories (word-problem and code-trace), never a piloted one. Result: 2 + 2 + 2.

Every branch is decidable from `ab.tsv` verdicts and `MANIFEST.tsv` ids alone — none of the three
branches requires knowing how an unpiloted task was answered. Every branch keeps all three
categories represented, so a reduced run is a reduced version of the same instrument, not a
different one. The pilot's `pilot-notes.md` (plan 11-05, Task 2) records the branch taken, the two
dropped ids, and the classification of each piloted task, **whether or not the reduction branch
fires.**

**Hard request cap for plan 11-06.** State this as a number once the pilot's own sizing arithmetic
(plan 11-05, Task 2) has run, in this section, before plan 11-06 begins. The cap is on **model
requests observed in the server log** (`Generation queued` lines), not on invocations attempted,
with a runaway-agent-loop guard: **abort if measured requests exceed 3× the invocation count** for
the main run — a task that has started an agent loop is no longer the single-turn instrument this
protocol describes.

> **§4 resolution — recorded after plan 11-05's Task 3 human checkpoint, before plan 11-06 begins:**
>
> **Human reply, verbatim:** `approve-as-proposed, invocation ceiling 88`
>
> **Interpretation, recorded because the reply is a phrase the checkpoint itself supplied, not one
> the reviewer coined independently.** Task 3's own resume-signal text gave, as its worked example
> of how to raise the invocation ceiling, the literal string `approve-as-proposed, invocation
> ceiling 88`, stated there as the phrase that "permits N=5 at 8 tasks." The reviewer's reply
> reproduces that example exactly. The authorisation is therefore read as: **raise the
> §4 invocation ceiling from 72 to 88, by explicit human override, not by any pilot measurement**,
> and — because `approve-as-proposed` is also present — approve the run at whatever size that
> raised ceiling makes the largest reachable rung of the sizing rule's `N ∈ {5, 3}` menu.
>
> **What this changes, worked mechanically:**
> - Invocation ceiling: **72 → 88**, by explicit override, recorded here verbatim as required by
>   this section's own pre-registered instruction. The 90-minute wall-clock ceiling was **not**
>   mentioned in the reply and is **not** overridden — it stands at 90 minutes unchanged.
> - Re-applying §4's sizing rule (step 1) with the raised ceiling: N=5 at 8 tasks projects
>   8 × (5 + 5 + 1) = **88 invocations**, which now satisfies `≤ 88` (exactly, not with margin).
>   Projected wall clock, using the pilot's slowest observed per-invocation time (17s, arms B/C,
>   applied uniformly and conservatively to every invocation including A's, per pilot-notes.md's own
>   convention): 88 × 17s = 1,496s ≈ **24.9 minutes**, which clears the unmoved 90-minute ceiling
>   with wide margin. Both ceilings satisfied → **N=5 is selected**, not N=3.
> - Step 2 (task-drop reduction) does not fire: N=5 at 8 tasks already satisfies both ceilings, so
>   the 8-task set is not reduced. (For the record, per pilot-notes.md, both piloted tasks classify
>   as `ceiling`, which would select task-drop branch 2 — dropping task 03 and task 06 — *if* a
>   reduction were ever needed; it is not needed here, so this branch is recorded but not applied,
>   exactly as it was recorded-but-not-applied at N=3 before this override.)
>
> **Authorised run for plan 11-06: 8 tasks × N=5 = 88 invocations, hard request cap 88** (runaway
> guard at 3× = 264), **projected wall clock ~25 minutes** against the unmoved 90-minute ceiling.
>
> **§5 threshold this size selects:** from the pre-computed table above, `8 tasks × N=5 = 40 cells`
> → **≥7** cells' gap in arm C's favour to keep `flashnext-plan`. This number is read off the table
> fixed at pre-registration time, not recomputed now that a size is known — per this section's own
> instruction and per §5's statement that no threshold is computed after data exists.
>
> **State plainly, so no later reader mistakes this for a measured result:** N=5 was reachable
> **only because the invocation ceiling moved.** The pilot's own timing data placed **no** obstacle
> in front of N=5 at any point — 88 invocations at the pilot's slowest observed per-invocation time
> project to ~25 minutes, comfortably under the 90-minute ceiling that was *never* touched. The
> thing that changed between "N=3 is what the default ceiling permits" (pilot-notes.md, before this
> checkpoint) and "N=5 is authorised" (here) is exclusively the reviewer's explicit override of the
> 72-invocation ceiling to 88. This is not a case of new evidence justifying a larger run; it is a
> case of the reviewer choosing to spend more of a self-imposed budget than the default reserved.
> Recording it this way is required by this section's own opening framing: "distinguishing what the
> measurements decided from what the pre-set, overridable ceilings had already fixed."
>
> **Two things the reviewer was shown at Task 3 and did not overrule — recorded here because they
> bear on how the eventual result should be read, not because either blocks the authorisation:**
>
> 1. **Both piloted tasks graded `ceiling`** — all three arms (`flashnext`, `flashnext-act`,
>    `flashnext-plan`) answered correctly at N=1 on both task 01 (word-problem) and task 04
>    (code-trace). Taken alone, this is exactly §6's "both arms at ceiling" condition and would
>    support a claim that this task set is too easy to discriminate `medium` reasoning's effect. The
>    reviewer authorised the full 8-task run anyway, with the checkpoint's own stated reasoning
>    carried forward here rather than re-argued: **6 of the 8 tasks are entirely untested by the
>    pilot, the bug-localisation category (2 of 8 tasks) is untested in its entirety, and a null
>    result measured across 8 tasks × N=5 = 40 cells is a materially stronger answer to USE-03 than
>    a null result inferred by extrapolation from two tasks observed at N=1.** This is not a claim
>    that the ceiling risk is resolved — it is not — only that the reviewer weighed it and chose to
>    spend the larger, ceiling-raised budget to get a broader-based answer rather than stop here on a
>    2-task, N=1 basis. `AB-RESULTS.md` (plan 11-06) must re-surface this risk when reporting a null
>    or near-null result rather than let a ceiling effect masquerade as "no improvement."
> 2. **The `providers.json` drift is a live, unresolved hazard, separate from this A/B decision.**
>    See the dedicated subsection immediately below. The reviewer was shown it and it did not change
>    the size or shape of the authorisation above; it is tracked as its own open finding, not folded
>    into §4's sizing arithmetic.
>
> ---
>
> ### `providers.json` model-field drift — now a reproduced, not incidental, finding
>
> **This drifted a second time, independently, during this plan's own pilot.** Plan 11-04's
> `probe_wrapper_volume.sh` (Open Item 3, `phase-11/OPEN-ITEMS.md`) already observed the shared
> provider entry's judged `model` field move from `flashnext` to `flashnext-plan` after a single
> live `phase-11/cline-plan` call (wrapper's own post-run guard caught it, exit 4). This plan's own
> pilot reproduced the same class of failure **independently**, on the pilot's `04-C-r1` cell — a
> **bare** `cline -m flashnext-plan` invocation (§2: the A/B deliberately omits `-p` and every
> wrapper layer, invoking the real binary directly), not through `phase-11/cline-plan` at all. The
> `model` field moved from `flashnext` to `flashnext-plan`; `contextWindow` again held at `29000`.
> Per this plan's own pre-registered instruction, **`providers.json` was not restored and no further
> live model request was issued** after `postflight11` surfaced the failure — that stop was correct
> and is not revisited here.
>
> **Version check, done against the primary sources rather than assumed from a paraphrase:** both
> occurrences are confirmed, from `cline-version-before.txt`/`cline-version-after.txt` in the
> respective run directories and from `phase-11/OPEN-ITEMS.md`'s own text ("Open Item 3's
> model-field corruption ... occurred at this newly-drifted 3.0.61, not the 3.0.60 version VRF-04
> tested"), to have occurred at **cline 3.0.61** in both cases — Open Item 3's occurrence in plan
> 11-04 and this plan's pilot occurrence alike. (An earlier framing of this finding described the
> two occurrences as spanning 3.0.61 and 3.0.60; that is not what the run directories or
> `OPEN-ITEMS.md` actually show, and this document records the version-checked figure instead of
> the unverified one.) What both occurrences share, and what is the actually load-bearing fact
> regardless of exact version number, is the invocation shape: **both fired the real `cline` binary
> with `-m flashnext-plan`** — one through the shipped wrapper (`-p` present), one bare (`-p`
> absent) — and both moved the same judged field the same way. Two independent occurrences, two
> different call paths, the same result, is what makes this **reproducible rather than incidental.**
>
> **The orchestrator has since restored the live file**, using the pre-existing (Phase 1)
> `phase-01/config/apply_provider_config.sh`, outside this plan's own authority and scope (this
> plan's hard constraints forbid editing `providers.json` directly). Verified at the time of writing
> this resolution: `bash phase-01/config/verify_config.sh` exits **0**, reporting
> `model=flashnext`, `contextWindow=29000`. The live stack is therefore currently in the compliant
> state again, but this restoration is a fix to the symptom for this moment, not to the mechanism.
>
> **The design consequence, stated plainly because it outlives this plan:** `phase-11/cline-plan`
> passes `-m flashnext-plan` on **every** invocation, by design (that is the whole point of the
> wrapper). Given two independent, reproduced occurrences of a bare or wrapped `-m flashnext-plan`
> call moving the shared `providers.json` entry's `model` field, **every use of `cline-plan` is now
> a live candidate for mutating the same provider entry that Kanban's and Telegram's own `cline`
> invocations read** whenever those invocations omit their own explicit `-m`. The wrapper's post-run
> guard (`WARNING[CONFIG]`, exit 4) detects this after the fact; it does not, and structurally
> cannot on its own, prevent the mutation from having already happened and having already been
> visible to any other process that read `providers.json` in between. **Plan 11-07, which owns the
> keep-or-revert ratification for the wrapper design overall, cannot ratify "keep" for `cline-plan`
> without confronting this mechanism directly** — a decision rule about answer quality (§5, this
> document) does not by itself license shipping a wrapper that is reproducibly capable of mutating a
> config file shared with two other live consumers. This is recorded here, at the point the second
> occurrence was found, rather than left to be rediscovered at 11-07.

## §5 DECISION RULE — pre-registered

> **Keep** `cline-plan → flashnext-plan` only if arm C's correct-count exceeds arm A's by at least
> **4 cells out of 24** (with N=3 and 8 tasks). **Otherwise revert** `wrapper.env`'s
> `WRAPPER_PLAN_ALIAS` to `flashnext`, per USE-03's own text.
>
> Scaling, pre-computed now so no arithmetic judgement is made after data exists. Threshold =
> `ceil(cells / 6)` where `cells = tasks × N`. Enumerated over every reachable (tasks × N) size:
>
> | tasks | N | cells | threshold (`ceil(cells/6)`) |
> |---|---|---|---|
> | 8 | 3 | 24 | **≥4** |
> | 6 | 3 | 18 | **≥3** |
> | 8 | 5 | 40 | **≥7** |
> | 6 | 5 | 30 | **≥5** |
>
> Once §4's sizing is fixed (post-pilot, post-checkpoint), the single applicable number from this
> table is restated on its own line in §4's resolution block above, so a later reader never has to
> recompute it.
>
> The threshold is set at roughly one-sixth of the cells because per-cell N=3 against a
> temperature-1.0 sampler cannot reliably distinguish a smaller gap from noise; a smaller observed
> gap is therefore reported as **"no measurable improvement,"** which USE-03 accepts as a valid,
> complete disposition — not as "no gap exists."
>
> **What would produce the opposite decision:** a gap of ≥4 cells (at 8 tasks × N=3; see the table
> above for other sizes) in arm C's favour would flip the decision from revert to keep.
>
> **What would make the comparison void rather than negative** (i.e., "we cannot say" rather than
> "no improvement"): a `cline --version` change mid-batch (§3's discard rule); more than 25% of
> either arm's cells grading `unparseable`; or any task whose `prompt_tokens` exceeded §3's 25%
> abort threshold (6,525 tokens).
>
> **Latency is reported but does not enter the decision rule.** It is recorded as median and p90
> wall clock per arm and discussed in the findings, because a "keep" decision that doubles every
> call's latency is information the reader needs, even though USE-03's own text conditions the
> revert on improvement, not on speed.
>
> **The statistic reported alongside, descriptive only:** a two-sided permutation test over
> per-cell correctness (`python3` stdlib, ≥10,000 shuffles). This is **explicitly not the decision
> criterion** — N is small and treating a p-value as the gate would over-claim precision the design
> does not have.

## §6 What the pilot could reveal that would stop the main run

Written in advance, each a legitimate stopping point reported as USE-03's answer with its own
evidence, not a failure of this plan:

- **Both arms at ceiling** on the piloted tasks — the set (or at least this slice of it) cannot
  discriminate the arms; a ceiling result answers nothing about whether `medium` reasoning helps.
- **Both arms at floor** — the set is too hard for both arms, or the harness itself is broken (a
  grader bug, a malformed prompt, a wrapper defect). This must be caught by the pilot's own manual
  stream read (plan 11-05, Task 2, Part B) before the main run is spent, not discovered after.
- **Per-invocation cost making a defensible N unaffordable** — §4 step 3's outcome.
- **A grader that mis-verdicts real output** — caught by the pilot's manual read of at least two raw
  streams against `grade_ab.py`'s own verdict for those same streams.

Any of these, if triggered, is written as the conclusion and carried into plan 11-05's Task 3
checkpoint as the recommended option (`abort-report-undiscriminating`) — the design is not adjusted
to get past it.
