---
phase: 11-usage-surface-wrappers
plan: 05
subsystem: cli-wrappers
tags: [bash, cline-cli, litellm, ab-testing, pre-registration, providers-json, use-03]

# Dependency graph
requires:
  - phase: 11-02
    provides: "phase-11/AB-TASKSET.md (frozen 8-task instrument, MANIFEST.tsv categories) and phase-11/grade_ab.py"
  - phase: 11-04
    provides: "phase-11/probe_lib11.sh (safety envelope, idleness gate, code-enforced request counter), the re-measured dynamic max_tokens figure, phase-11/OPEN-ITEMS.md's Open Item 3 (first providers.json model-field drift observation)"
provides:
  - "phase-11/AB-PROTOCOL.md: the pre-registered USE-03 A/B protocol (arms, fairness controls, sizing rule, task-drop rule, DECISION RULE with falsifier) plus, added after the Task 3 checkpoint, the §4 resolution recording the human's ceiling override verbatim and its arithmetic consequences"
  - "phase-11/run_ab.sh: resumable, budget-capped, watermark-attributing A/B runner"
  - "A 6-cell pilot (phase-11/results/20260902T054619Z-ab-pilot/) with pilot-notes.md's full measurement record, manually stream-verified"
  - "A human-authorised main-run size for plan 11-06: 8 tasks x N=5 = 88 invocations, cap 88, threshold >=7"
  - "A confirmed-reproducible finding that phase-11/cline-plan's -m flashnext-plan invocation shape mutates the shared providers.json model field, now observed twice independently"
affects: ["11-06 (spends the 88-invocation authorised budget against this protocol's DECISION RULE)", "11-07 (wrapper keep-or-revert ratification cannot pass over the providers.json mutation hazard this plan reproduced)"]

tech-stack:
  added: []
  patterns:
    - "Pre-registration with self-imposed, explicitly overridable ceilings: state which ceiling would need to move for a larger result, name it as a conservative default rather than a derivation, and give the reviewer the exact override phrase at the checkpoint rather than making them invent one"
    - "Record a human authorisation by quoting the reply verbatim, then separately showing the worked arithmetic consequence of that reply, so a later reader can tell the override apart from anything the pilot's own measurements determined"
    - "A safety-envelope violation found mid-plan is left unrestored per the plan's own pre-registered stop rule even when a later, out-of-band actor (the orchestrator) subsequently fixes it -- the plan's own record states what it observed and did, not what happened after its authority ended"

key-files:
  created:
    - phase-11/run_ab.sh
    - phase-11/results/20260902T054619Z-ab-pilot/ (ab.tsv, budget.tsv, manifest.txt, pilot-notes.md, preflight.txt, postflight.txt, streams/)
    - phase-11/results/CURRENT_AB_PILOT_RUN
  modified:
    - phase-11/AB-PROTOCOL.md

key-decisions:
  - "The human's Task 3 reply, 'approve-as-proposed, invocation ceiling 88', is read as raising the §4 invocation ceiling from 72 to 88 by explicit override (not by pilot measurement) and, combined with approve-as-proposed, as selecting the largest sizing-rule rung the raised ceiling reaches -- N=5 at 8 tasks (88 invocations), leaving the unmentioned 90-minute wall-clock ceiling untouched"
  - "N=5 was reachable only because the invocation ceiling moved -- the pilot's own timings (17s slowest observed per-invocation) projected N=5 at ~25 minutes, comfortably inside the unmoved 90-minute ceiling, at every point before this override; the record states this plainly so the larger run is never mistaken for something the pilot's measurements newly justified"
  - "The §5 threshold for the authorised size (8 tasks x N=5 = 40 cells) is read off the pre-computed table in AB-PROTOCOL.md as >=7, not recomputed now that a size is known, per the table's own no-post-hoc-arithmetic rule"
  - "The reviewer was shown, and did not overrule, that both piloted tasks graded 'ceiling' (all three arms correct at N=1) -- the full 8-task x N=5 run was authorised anyway on the stated reasoning that 6 of 8 tasks (and the entire bug-localisation category) are untested by the pilot, and a null result across 40 cells is stronger evidence for USE-03 than one inferred from 2 tasks at N=1; AB-RESULTS.md (plan 11-06) must re-surface this ceiling risk if the main run also comes back null"
  - "The providers.json model-field drift is recorded as reproducible, not incidental: two independent occurrences (11-04's Open Item 3 through the wrapper, this plan's pilot through a bare -m flashnext-plan call) both moved the same judged field at cline 3.0.61 -- version-checked against both run directories' before/after captures rather than assumed from a paraphrase. Because phase-11/cline-plan passes -m flashnext-plan on every call by design, this is now recorded as a live hazard that plan 11-07 must confront directly before ratifying 'keep', not something this plan's own DECISION RULE (which is about answer quality, not config-file safety) can resolve"
  - "The pilot's own providers.json violation (surfaced by postflight11 after the last cell, 04-C-r1) was correctly left unrestored per this plan's pre-registered stop rule; the orchestrator has since restored it out-of-band via the pre-existing phase-01/config/apply_provider_config.sh, verified here as bash phase-01/config/verify_config.sh now exiting 0 with model=flashnext, contextWindow=29000 -- recorded as a fact about the live file's current state, not as this plan's own fix"

# Metrics
duration: ~16min (Tasks 1-2, measured from commit timestamps d0521e2 14:40:58 -> e1f083c 14:54:09) + Task 3 checkpoint pause + this continuation's documentation-only work
completed: 2026-09-02
---

# Phase 11 Plan 05: USE-03 A/B Protocol, Runner, Pilot, and Human-Authorised Main-Run Size Summary

**Pre-registered the USE-03 A/B protocol before any data existed, built and piloted a resumable/budget-capped runner (6/6 cells correct, 6 of a 10-request cap spent), and recorded a human override that raises the main run from the default-permitted N=3/56 invocations to a ceiling-raised N=5/88 invocations — while flagging, unresolved and unoverruled, both a ceiling-effect risk in the pilot's own two tasks and a second, now-reproducible providers.json mutation hazard that plan 11-07 must address.**

## Performance

- **Duration:** Tasks 1-2 ~16 min (commit-to-commit); Task 3 was a blocking human checkpoint (not
  counted as execution time); this continuation performed documentation-only recording work with
  zero model requests.
- **Started:** 2026-09-02T14:40:58+09:00 (first task commit)
- **Completed:** 2026-09-02 (this continuation)
- **Tasks:** 3/3 (Task 1 auto, Task 2 auto, Task 3 checkpoint — answered)
- **Files modified:** 2 (phase-11/AB-PROTOCOL.md across two commits; phase-11/run_ab.sh created)

## Accomplishments

- `phase-11/AB-PROTOCOL.md` written and committed (`d0521e2`) before any pilot cell ran: three arms
  (A=`flashnext` control, C=`flashnext-plan`, B=`flashnext-act` prefix-matched control at reduced
  replication), the corrected dynamic (not fixed-2048) completion-budget fairness control, a
  mechanically-decidable task-drop rule, and a pre-registered DECISION RULE with its falsifier and
  void conditions stated in advance.
- `phase-11/run_ab.sh` built and piloted (`e1f083c`): task-major/arm-minor cell ordering,
  idleness-gated + budget-asserted requests, byte-watermarked server-log attribution (never
  `tail -N`), incremental `ab.tsv` writes, operational-failure-only single retry, a runaway guard,
  and verified `--resume` behaviour (zero new rows, zero new requests on re-invocation).
- Six-cell pilot (2 tasks x 3 arms x 1 rep): **all six graded `correct`**, zero `no-output`/
  `unparseable`, zero retries. Two raw streams read by hand and confirmed against the grader's own
  verdict. `prompt_tokens` measured at 20.88%-21.59% of the live compaction trigger (26,100) — well
  under the 25% abort threshold. `finish_reason=stop` on every cell; no thinking-arm budget
  starvation observed.
- Task 3 checkpoint answered by the human (`approve-as-proposed, invocation ceiling 88`); this
  continuation recorded the resulting authorisation, its arithmetic, and two unoverruled risk items
  in `AB-PROTOCOL.md` §4, with zero model requests spent.
- A `providers.json` model-field drift was caught by `postflight11` after the pilot's last cell
  (`04-C-r1`) and correctly left unrestored per the plan's own pre-registered stop rule — this is
  the **second** independent occurrence of the same class of failure `phase-11/OPEN-ITEMS.md`'s Open
  Item 3 first observed in plan 11-04, now confirmed reproducible rather than incidental.

## Task Commits

1. **Task 1: AB-PROTOCOL.md — arms, fairness controls, sizing rule, decision rule** - `d0521e2` (docs)
2. **Task 2: run_ab.sh and the pilot** - `e1f083c` (feat) — includes an in-flight fix (Rule 1) for a
   `manifest.txt` truncating-append bug found during the pilot's own `--resume` verification
3. **Task 3: Authorise the main A/B run's budget** - checkpoint, answered by the human as
   `approve-as-proposed, invocation ceiling 88`; the resulting record is committed by this
   continuation (see below)

**This continuation's commit:** records the Task 3 authorisation, its worked arithmetic, and the
two unoverruled risk items in `phase-11/AB-PROTOCOL.md` §4, plus this SUMMARY.

_Note: no model/live requests were made in this continuation — the remaining work was reading
already-committed evidence and recording it._

## Files Created/Modified

- `phase-11/AB-PROTOCOL.md` — §1-§6 pre-registered protocol (Task 1); §4 resolution block filled in
  with the human's verbatim Task 3 reply, its arithmetic consequence, the two unoverruled risk items,
  and the providers.json reproducibility finding (this continuation)
- `phase-11/run_ab.sh` — the resumable, budget-capped, watermark-attributing A/B runner (Task 2)
- `phase-11/results/20260902T054619Z-ab-pilot/` — pilot run directory: `ab.tsv` (6 rows), `budget.tsv`,
  `manifest.txt`, `pilot-notes.md`, `preflight.txt`/`postflight.txt`, `providers-before.txt`/
  `providers-after.txt`, `cline-version-before.txt`/`cline-version-after.txt`, `streams/` (6 raw
  NDJSON captures)
- `phase-11/results/CURRENT_AB_PILOT_RUN` — pointer to the pilot run directory

## The pilot, verbatim from `ab.tsv`

| task | arm | alias | dur_s | prompt_tokens | completion_tokens | max_tokens | finish_reason | verdict |
|---|---|---|---:|---:|---:|---:|---|---|
| 01 | A | flashnext | 15 | 5588 | 160 | 20851 | stop | correct |
| 01 | B | flashnext-act | 16 | 5452 | 231 | 20851 | stop | correct |
| 01 | C | flashnext-plan | 17 | 5450 | 269 | 20851 | stop | correct |
| 04 | A | flashnext | 15 | 5636 | 195 | 20833 | stop | correct |
| 04 | B | flashnext-act | 18 | 5500 | 259 | 20833 | stop | correct |
| 04 | C | flashnext-plan | 17 | 5498 | 236 | 20833 | stop | correct |

All six cells correct. Slowest arm by mean: B and C tie at 17.0s; A fastest at 15.0s. Both piloted
tasks (01 = pipe-rate/word-problem, 04 = loop-sum/code-trace) classify as **ceiling** under §4's
task-drop rule (all three arms correct) — branch 2 would drop tasks 03 and 06 if a reduction were
ever triggered; recorded, not applied, at either N=3 (pilot's own arithmetic) or N=5 (this
continuation's arithmetic).

**Budget:** 6 of the pilot's 10-request cap spent (`Generation queued` and `Prefill started` line
counts in `flashnext.err` agree exactly at 6). 4 of 10 never spent.

**`cline --version`:** `3.0.61` before, `3.0.61` after — stable across the entire pilot session;
the version-stability discard condition was not triggered.

## Sizing rule's output — before and after Task 3

**Pilot-time arithmetic (before the checkpoint, default ceilings in force):** N=5 at 8 tasks
projects 88 invocations, which exceeds the un-raised 72-invocation ceiling on its own — this is
exactly `AB-PROTOCOL.md` §4's own pre-stated arithmetic consequence, not a new finding. N=3 at 8
tasks (56 invocations) satisfies both ceilings; projected wall clock at the pilot's slowest observed
per-invocation time (17s) is ~15.9 minutes. Task-drop step 2 does not fire. Proposed at pilot time:
8 tasks, N=3, 56 invocations, cap 56, threshold >=4 (24 cells).

**Post-checkpoint arithmetic (this continuation, ceiling raised to 88 per the human's reply):**
re-applying the same rule with the raised ceiling, N=5 at 8 tasks (88 invocations) now satisfies
`<=88`; projected wall clock at the same 17s/invocation figure is 88 x 17 = 1,496s ~= **24.9
minutes**, comfortably inside the **unmoved** 90-minute ceiling. Both ceilings satisfied -> N=5 is
selected. Task-drop step 2 still does not fire (both ceilings satisfied without reduction).

**Authorised for plan 11-06: 8 tasks x N=5 = 88 invocations, hard request cap 88** (runaway guard
at 3x = 264), **projected wall clock ~25 minutes**. **§5 threshold: >=7** (read off the
pre-computed `8 tasks x N=5 = 40 cells -> >=7` row in `AB-PROTOCOL.md` §5's table, not recomputed).

**What the record states plainly:** N=5 became reachable exclusively because the reviewer raised the
invocation ceiling from 72 to 88. The pilot's own timing data never stood in the way of N=5 — at
17s/invocation, 88 invocations was always going to finish in ~25 of the 90 minutes the wall-clock
ceiling allows. The default ceilings, not the measurements, were the only thing that had capped the
proposal at N=3 before this checkpoint.

## Decisions Made

- **Task 3 authorisation, verbatim:** `approve-as-proposed, invocation ceiling 88`. Read as raising
  the §4 invocation ceiling 72 -> 88 by explicit override and, via `approve-as-proposed`, selecting
  the largest sizing-rule rung the raised ceiling reaches (N=5, 8 tasks, 88 invocations). The
  90-minute wall-clock ceiling was not mentioned and remains unraised at 90 minutes; ~25 projected
  minutes clears it with wide margin. Full worked arithmetic recorded in `AB-PROTOCOL.md` §4's
  resolution block.
- **Two items shown to the reviewer and not overruled, recorded because they bear on how plan
  11-06's result should be read:**
  1. Both piloted tasks graded `ceiling` (3/3 arms correct at N=1 on tasks 01 and 04) — a possible
     sign the task set is too easy to discriminate `medium` reasoning's effect. Authorised anyway,
     per the checkpoint's own stated reasoning: 6 of 8 tasks (and the entire bug-localisation
     category) are untested by the pilot, and a null result across 8 tasks x N=5 = 40 cells is
     materially stronger evidence for USE-03 than one inferred from two tasks at N=1. `AB-RESULTS.md`
     (plan 11-06) must re-surface this risk if the main run also returns a null result.
  2. `providers.json`'s model-field drift is a live, unresolved hazard, tracked separately from the
     A/B sizing decision (see below) — it did not change the size or shape of the authorisation.
- **providers.json is now reproducibly, not incidentally, drift-prone under `-m flashnext-plan`.**
  This plan's pilot moved the same judged field (`model: flashnext -> flashnext-plan`) that plan
  11-04's Open Item 3 first observed — this time via a bare `cline -m flashnext-plan` call (no
  wrapper, no `-p`, per §2's deliberate omission of the wrapper layer in the A/B), rather than
  through `phase-11/cline-plan`. Both occurrences are confirmed at **cline 3.0.61** by direct
  inspection of each run directory's `cline-version-before.txt`/`cline-version-after.txt` and
  `phase-11/OPEN-ITEMS.md`'s own text — not assumed from a paraphrase, and this record corrects an
  earlier framing that attributed the two occurrences to different cline versions (3.0.61 and
  3.0.60), which the primary sources do not support. What both occurrences do share, and what is
  load-bearing regardless of the exact version, is the invocation shape: **any call passing
  `-m flashnext-plan` to the real `cline` binary**, wrapped or bare. Because `phase-11/cline-plan`
  passes exactly that flag on every call by design, this is recorded as a hazard that **plan 11-07
  cannot ratify "keep" past without confronting directly** — a keep-or-revert decision about answer
  quality (this plan's §5 DECISION RULE) does not by itself license shipping a wrapper reproducibly
  capable of mutating a `providers.json` entry that Kanban's and Telegram's own `cline` invocations
  also read.
- **The pilot's own providers.json violation was correctly left unrestored**, per this plan's own
  pre-registered stop rule (do not restore, do not continue past it, record it). **The orchestrator
  has since restored it out-of-band**, via the pre-existing (Phase 1, not this plan's own)
  `phase-01/config/apply_provider_config.sh`. Verified at the time of writing this summary:
  `bash phase-01/config/verify_config.sh` exits **0**, reporting `model=flashnext`,
  `contextWindow=29000`. This is recorded as a fact about the live file's current state, not as
  work this plan performed — the plan itself made no repair.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `run_ab.sh`'s `manifest.txt` used a truncating append on every invocation**
- **Found during:** Task 2's own `--resume` verification check
- **Issue:** `manifest.txt` was written with a truncating `>` redirect on both its opening and
  closing blocks on every invocation, including a `--resume` re-invocation that fires zero live
  requests — the first `--resume` check silently overwrote the original pilot invocation's real
  `cells_this_invocation=6` and its correctly-captured `live_compaction_trigger` line with the
  resume invocation's own near-empty values.
- **Fix:** Made `manifest.txt` append-only across invocations (each gets its own timestamped block)
  and had the closing block read the real post-postflight `cline-version-after.txt` rather than a
  placeholder string.
- **Files modified:** `phase-11/run_ab.sh`
- **Verification:** A third invocation (also `--resume`, zero live requests) correctly appended a
  new block without disturbing prior ones; the final block shows the real
  `cline_version_after=3.0.61`. No data in `ab.tsv` or `budget.tsv` was ever affected (both are
  append-only by construction). The original invocation's lost `manifest.txt` text is not
  recoverable, but every fact it would have recorded is independently present in `ab.tsv`,
  `budget.tsv`, and `pilot-notes.md`.
- **Committed in:** `e1f083c` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug).
**Impact on plan:** Necessary for `--resume`'s correctness claim to hold across invocations. No
scope creep; no other files touched.

## Authentication Gates

None — no authentication was required for this plan's work.

## Issues Encountered

- `postflight11` failed at the end of the pilot: `providers.json`'s `model` field drifted
  `flashnext -> flashnext-plan` after the pilot's last cell (`04-C-r1`, `-m flashnext-plan`).
  Resolved per the plan's own pre-registered instruction: not restored, no further live request
  issued, recorded as the pilot's own headline finding in `pilot-notes.md` and carried into the
  Task 3 checkpoint. The orchestrator subsequently restored the live file out-of-band (see Decisions
  Made, above) — `verify_config.sh` now exits 0 as of this summary's writing. The underlying
  reproducibility hazard (documented above) remains open and is explicitly handed to plan 11-07,
  not resolved by this plan.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `phase-11/AB-PROTOCOL.md` is fully pre-registered, including the §4 resolution recording the
  human's authorised main-run size (8 tasks x N=5 = 88 invocations, cap 88, threshold >=7) — plan
  11-06 can proceed directly against this without re-deriving anything.
- **Two open risks are explicitly handed forward, not resolved here:** (1) the pilot's own two
  tasks graded `ceiling`, a possible sign the instrument is too easy in those categories —
  `AB-RESULTS.md` (11-06) must re-surface this if the main run also returns null; (2) the
  `providers.json` model-field mutation under `-m flashnext-plan` is now reproducible (two
  independent occurrences, both cline 3.0.61) and must be confronted by plan 11-07 before any
  "keep" ratification for `cline-plan`.
- The orchestrator's own fix for the providers.json drift (via `phase-01/config/apply_provider_config.sh`)
  has already landed and is verified live as of this summary; plan 11-06 starts from a compliant
  stack (`verify_config.sh` exit 0, `model=flashnext`, `contextWindow=29000`).
- Per this continuation's own instructions, the main A/B run itself (plan 11-06's own spend against
  the 88-invocation budget authorised here) was **not** started by this continuation.

---
*Phase: 11-usage-surface-wrappers*
*Completed: 2026-09-02*
