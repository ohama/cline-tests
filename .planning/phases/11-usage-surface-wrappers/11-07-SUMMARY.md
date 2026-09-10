---
phase: 11-usage-surface-wrappers
plan: 07
subsystem: cli-wrappers
tags: [bash, cline-cli, litellm, ab-testing, ab-results, providers-json, use-03, phase-close]

# Dependency graph
requires:
  - phase: 11-06
    provides: "phase-11/AB-RESULTS.md §1-§10 (66/88-cell A/B, RULE OUTPUT: revert, the 31/31 providers.json drift measurement) -- the measured table and mechanical rule output this plan's human checkpoint reviewed"
provides:
  - "phase-11/AB-RESULTS.md §11: the ratified DECISION line (keep cline-plan -> flashnext-plan), classified explicitly as override-with-reason (not ratify-rule-output), with the human's verbatim reply, the override reason, USE-03/criterion-3 mapping, and the no-improvement-is-valid-completion statement"
  - "phase-11/wrapper.env: an audited no-op (WRAPPER_PLAN_ALIAS unchanged at flashnext-plan, comment added citing the decision and date)"
  - "phase-11/PHASE-11-FINDINGS.md: the phase's requirement table (USE-01/02/03), ROADMAP criterion table (1/2/3), all four 11-RESEARCH.md open items with measured answers, and a disclosures section (cline-bench substitution, statistical power, budget accounting 97/112, Phase 9's session-runtime.ts-vs-main.ts scoping error, the unresolved VRF-04-vs-31/31 contradiction)"
  - "Independent re-verification, today, of the source claims underlying the keep decision: main.ts:1122/1056 (2026-09-10 tag cli-v3.0.61), paths.ts's unconditional CLINE_PROVIDER_SETTINGS_PATH honouring, and a corrected line-number citation (347-353 was the 3.0.53 location; the current 3.0.61 tree has it at 424-430 -- same function, shifted lines)"
affects: ["Phase 12 (USE-04/USE-05): receives the --thinking-status-code wording correction (400 only for openai/-prefixed aliases; hosted_vllm/-prefixed aliases 500 at the model server), the shell-function-to-script deviation, the still-open reasoning-history doc correction, and the still-open flashnext-reach-xhigh disposition"]

tech-stack:
  added: []
  patterns:
    - "A pre-registered decision rule's mechanical output can be legitimately overridden by a human, but the override must be recorded as an override next to the rule's own output, with the reason stated -- never presented as if the rule itself had produced the shipped answer"
    - "When a side-effect containment fix lands the same day it is used to justify a decision, disclose its newness explicitly (hours old, verified today, not battle-tested) rather than letting the decision read as resting on a mature, long-running mitigation"

key-files:
  created:
    - .planning/phases/11-usage-surface-wrappers/11-07-SUMMARY.md
    - phase-11/PHASE-11-FINDINGS.md
  modified:
    - phase-11/AB-RESULTS.md
    - phase-11/wrapper.env

key-decisions:
  - "Recorded the human's reply (`응, 반영해서 keep 으로 진행해줘`) as `override-with-reason`, explicitly not `ratify-rule-output` -- AB-PROTOCOL.md §5's rule outputs `revert` (arm C 26 vs arm A 30, gap -4, needed >=+7); the shipped default does not follow that output, and PHASE-11-FINDINGS.md and AB-RESULTS.md §11 both say so plainly rather than blurring the distinction"
  - "Verified, rather than assumed, every load-bearing claim in the override's stated reason before writing it down: main.ts:1122/1056 and the git diff between cli-v3.0.53 and cli-v3.0.61 (only one unrelated line changed) were read directly from the checked-out cline-src tree at tag cli-v3.0.61 (matching the installed 3.0.61 binary); resolveProviderSettingsPath()'s unconditional CLINE_PROVIDER_SETTINGS_PATH honouring was read directly; wrapper_common.sh's mktemp/trap containment was read directly; the three re-verification scripts were actually re-run today (not cited from memory) with 0 live model requests, confirmed by an unchanged flashnext.err line count (28398) across all of them"
  - "Found and reported one inaccuracy in the account handed off for this checkpoint: the cited line range for resolveProviderSettingsPath() (paths.ts:347-353) is the 3.0.53 location of that function, not the current 3.0.61 tree's location (424-430) -- same function, unconditional CLINE_PROVIDER_SETTINGS_PATH-first logic, byte-for-byte, just shifted by unrelated code added between versions. Not a functional problem (the behaviour is confirmed correct at the tag matching the installed binary), but the specific line numbers as stated do not hold at 3.0.61 and are corrected here rather than repeated uncritically into AB-RESULTS.md/PHASE-11-FINDINGS.md"
  - "Committed the decision/wrapper.env change (task 2) and the findings document (task 3) as two separate atomic commits, per the plan's own task structure -- and deliberately did not commit the re-generated verification-run artifacts (fresh mktemp-timestamped argv-test and mutant-ladder output directories) this task's own re-verification produced, since their content differs from the prior committed runs only in scratch temp-dir paths, not in any new fact, and committing them would add noise without new evidence"
  - "Did not touch .planning/STATE.md, ROADMAP.md, or REQUIREMENTS.md, per this plan's explicit instruction that the orchestrator owns those at phase close, even though the generic execute-plan workflow's state_updates step would otherwise apply here as the phase's final plan"

# Metrics
duration: ~35min
completed: 2026-09-10
---

# Phase 11 Plan 07: Keep-or-Revert Ratification and Phase Close Summary

**The human overrode the pre-registered rule's `revert` output and chose `keep` — the A/B still shows no measured accuracy improvement (both arms tie 25/30 on every equal-replication task, p=0.563), but the second ground for reverting, "the providers.json side effect is 100% certain," stopped being true today once commit `017c65e` contained it; `wrapper.env` is an audited no-op, and `PHASE-11-FINDINGS.md` closes the phase with every requirement's disposition and the disclosures a reader needs to not mistake `keep` for a positive accuracy finding.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-09-10
- **Tasks:** 3/3 (Task 1 checkpoint answered by the user before this session started; Tasks 2–3 executed autonomously)
- **Files modified:** 2 (`phase-11/AB-RESULTS.md`, `phase-11/wrapper.env`); 1 created (`phase-11/PHASE-11-FINDINGS.md`)

## What I verified independently, and what did not hold up

The user's account of the override reason was verified against source and against live re-runs
rather than taken on faith, per the task's own instruction ("verify this yourself rather than
taking my word"):

- **Confirmed exactly as stated:** `apps/cli/src/main.ts:1122` (`cline-src`, tag `cli-v3.0.61`,
  matching the installed `3.0.61` binary, clean working tree) calls
  `providerSettingsManager.saveProviderSettings({ ..., model: config.modelId, ... })` with no
  enclosing `if`; `config.modelId` at `main.ts:1056` is `args.model ?? selectedProviderSettings?.model
  ?? knownModelIds[0] ?? "anthropic/claude-sonnet-4.6"`. `git diff cli-v3.0.53 cli-v3.0.61 --
  apps/cli/src/main.ts` shows exactly one unrelated change (`filterChatModels` wrapping
  `knownModelIds`) — the `saveProviderSettings` block is byte-identical across both tags, so this
  was never version drift and is not caused by `-p`.
- **Confirmed, with one line-number correction:** `resolveProviderSettingsPath()` honours
  `CLINE_PROVIDER_SETTINGS_PATH` unconditionally, not sandbox-only — the function body matches
  exactly what was claimed. **The cited location, `paths.ts:347-353`, is the 3.0.53 location of
  this function; at the currently-checked-out `cli-v3.0.61` tag it is at `424-430`.** Confirmed by
  reading both tags directly (`git show cli-v3.0.53:...` → line 347; current working tree, which is
  at `cli-v3.0.61` — `git log -1` showed `HEAD` tagged `cli-v3.0.61` — → line 424). This is a stale
  citation, not a functional error: the behaviour is identical, only unrelated code added between
  versions shifted the line number. Recorded honestly in this summary and not silently repeated as
  `347-353` into `AB-RESULTS.md`/`PHASE-11-FINDINGS.md`, where the function is described without a
  specific line range for exactly this reason.
- **Confirmed by direct read:** `phase-11/wrapper_common.sh` (commit `017c65e`) copies the real
  `providers.json` to a per-invocation `mktemp`, exports `CLINE_PROVIDER_SETTINGS_PATH` pointing at
  the copy, traps `EXIT`/`INT`/`TERM` to remove it, and refuses with exit 3 if the copy cannot be
  made — matching the described containment exactly, including the refuse-rather-than-run-uncontained
  behaviour.
- **Confirmed by live re-run, 0 model requests:** `bash phase-01/config/verify_config.sh` → exit 0,
  `OK[WRAPPER]: WRAPPER_PLAN_ALIAS='flashnext-plan' is a known-good plan alias`;
  `bash phase-11/wrapper_argv_test.sh` → exit 0, 13/13 PASS, both `MUTANT-LEAKY`/`MUTANT-SWAP`
  CAUGHT, P1's captured argv shows `-m flashnext-plan`; `bash phase-11/verify_wrappers.sh` → exit 0;
  `bash phase-11/selftest_verify_wrappers.sh` → 9/9 mutants correct (M1–M7 `CAUGHT`, M8/M9 `PASS`).
  `~/llm-system/services/logs/flashnext.err` line count: 28398 before and after all four runs.
- **`wrapper.env`'s current value, checked rather than assumed:** `WRAPPER_PLAN_ALIAS="flashnext-plan"`
  — confirmed before making any edit, matching the account given.
- **The A/B's equal-N figures**, re-derived from `AB-RESULTS.md` §3/§4 directly rather than trusted
  from the account: tasks 01–06 at equal N=5 give arm A 25/30 correct, arm C 25/30 correct
  (25 = 5×5 correct on tasks 01–05, +0/5 on task 06 for both) — matches the account exactly.
- **Not independently re-derivable within this task's scope, so not re-verified from scratch:**
  the 31/31 providers.json drift measurement and the sha `588bd7cc5e15977a...` before/after
  isolation figure are cited from `phase-11/AB-RESULTS.md` §1c and the commit `017c65e` message
  respectively; re-running the isolation measurement would require a live `cline` invocation, which
  this task's own constraint (zero live model requests) forecloses, so it was checked for internal
  consistency (the sha matches the live `providers.json`'s current sha, confirming the file is not
  presently drifted) rather than re-measured end-to-end.
- **PID/config invariants, all confirmed unchanged throughout:** `com.ohama.flashnext` (46573),
  `com.ohama.role-shim` (75548), and `com.ohama.litellm` (68670) all still running, never restarted;
  `/Users/ohama/agent-stack/litellm/config.yaml` and its mirror both unchanged at sha256
  `d7278a9ff52ee996b3a6fd5af2eb41fee66249407ba37b396aa45d632fe2e18e`; `providers.json` holds
  `model=flashnext`, `contextWindow=29000` (unmutated by this task).

## The final shipped state

```
DECISION: keep cline-plan -> flashnext-plan
```

- **Classification:** `override-with-reason`. `AB-PROTOCOL.md` §5's rule mechanically outputs
  `revert` (arm C 26 vs arm A 30 correct, gap −4, needed ≥+7 to keep). The human overrode this.
- **The override reason, as recorded in `AB-RESULTS.md` §11:** of `revert`'s two grounds — (1) no
  accuracy improvement, (2) the providers.json side effect is 100% certain — ground 1 is unchanged
  and alone would still select revert (25/30 vs 25/30 on every equal-N task, p=0.563 — this is not
  presented as evidence thinking helps, because it is not). Ground 2 changed today: the side effect
  is now contained (commit `017c65e`), not merely detected, which removes the strongest reason to
  revert without supplying any new reason to believe reasoning improves accuracy.
- **`phase-11/wrapper.env`:** unchanged value (`WRAPPER_PLAN_ALIAS="flashnext-plan"`), with a 5-line
  comment added above it recording the affirmation, date, and citation to `AB-RESULTS.md` §11 —
  `git diff` shows only comment lines added, the value line itself untouched.
- **The litellm config and its mirror:** untouched. All five aliases (`flashnext`,
  `flashnext-plan`, `flashnext-act`, `flashnext-codex`, `flashnext-reach-xhigh`) remain live.
- **`phase-11/PHASE-11-FINDINGS.md`:** created, §1–§6 complete — requirement table (USE-01 Met,
  USE-02 Met, USE-03 Met via override), ROADMAP criterion table (1/2/3), all four open research
  items with measured answers, and disclosures covering the cline-bench substitution, statistical
  power, the shared completion budget, the inherited Phase-10-§4.1 weak-proof note, CFG-05 and
  cline's mid-plan self-removal (11-04), a full budget accounting (97 actual requests against a
  112-request stated cap across plans 11-04/05/06, no overage), an instrument self-check
  (`run_ab.sh`'s postflight-skip on the cap-abort path), Phase 9's `session-runtime.ts`-read-path-vs-`main.ts`-write-path
  scoping error, and the unresolved contradiction between Phase 10's single clean VRF-04 observation
  and Phase 11's 31/31 measured drift (named as an open contradiction, with Phase 10's single
  observation identified as the more likely outlier — no mechanism invented to explain it away).

## The three re-verification results (Part C, today, 0 live model requests)

| Check | Result | Alias reported |
|---|---|---|
| `bash phase-01/config/verify_config.sh` | exit 0 | `WRAPPER_PLAN_ALIAS ('flashnext-plan')` |
| `bash phase-11/wrapper_argv_test.sh` | exit 0, 13/13 PASS, both mutants CAUGHT | P1 argv: `-m flashnext-plan` |
| `bash phase-11/verify_wrappers.sh` | exit 0 | `WRAPPER_PLAN_ALIAS='flashnext-plan'` |

`flashnext.err` line count: 28398 → 28398 across all checks (plus the `selftest_verify_wrappers.sh`
9-mutant ladder re-run, also included in this task's verification though not required by the plan's
own verify block).

## The phase's total measured request spend against stated caps

| Plan | Stated cap | Actual measured requests |
|---|---:|---:|
| 11-04 | 14 | 3 |
| 11-05 | 10 | 6 |
| 11-06 | 88 | 88 (cap reached — 66/88 authorised invocations completed) |
| **Total** | **112** | **97** |

This task itself: 0 live model requests (three re-verification scripts run exclusively against
`phase-11/testing/stub-cline`, plus static file inspection).

## Task Commits

1. **Task 1: Ratify the keep-or-revert decision** — checkpoint answered by the user prior to this
   session (`응, 반영해서 keep 으로 진행해줘`); no commit of its own, recorded as part of Task 2's
   commit.
2. **Task 2: Apply the decision and re-prove the wrappers** — `1054249` (docs)
3. **Task 3: PHASE-11-FINDINGS.md** — `a487b04` (docs)

**Plan metadata commit:** none separate — per this plan's explicit instruction not to touch
`STATE.md`, this plan does not create the usual orchestrator-facing metadata commit; the two task
commits above are the complete record.

## Files Created/Modified

- `phase-11/AB-RESULTS.md` — added §11: the ratified `DECISION:` line, the human's verbatim reply,
  its classification as an override (not a ratification), the stated reason with both grounds
  addressed, the USE-03/criterion-3 mapping, the no-improvement-is-valid-completion statement, and
  Part C's re-verification results
- `phase-11/wrapper.env` — unchanged value, one 5-line comment block added recording the
  affirmation
- `phase-11/PHASE-11-FINDINGS.md` — created: phase-closing account (§1 what changed, §2 requirement
  table, §3 criterion table, §4 open items, §5 disclosures, §6 Phase 12 handoff)

## Decisions Made

See `key-decisions` in the frontmatter above for the full list, including the one inaccuracy found
during independent verification (the `paths.ts:347-353` citation is the 3.0.53 location; the current
3.0.61 tree has the same function at `424-430`) and how it was handled (corrected in this summary,
not repeated uncritically into the phase's permanent documents).

## Deviations from Plan

**None requiring auto-fix under the deviation rules (Rules 1–3).** One informational correction
found during verification and reported rather than silently absorbed: the source line-number
citation for `resolveProviderSettingsPath()` in the account handed to this task (`paths.ts:347-353`)
does not match the current `cli-v3.0.61` checkout (`424-430`) — same function, unrelated code shift.
This did not affect the decision, the wrapper's behaviour, or any verification outcome, since the
function's logic was independently confirmed correct at both tags; it only affects a citation, which
is why neither `AB-RESULTS.md` §11 nor `PHASE-11-FINDINGS.md` repeats a specific line range for this
function.

## Next Phase Readiness

Phase 11 is closed. `PHASE-11-FINDINGS.md` §6 hands Phase 12 (USE-04/USE-05): the wrappers'
invocation path, exit-code table, and refusal messages for the manual; the corrected
`--thinking`-status-code finding (400 only for `openai/`-prefixed aliases; `hosted_vllm/`-prefixed
aliases 500 at the model server, never a 400 a user would see) for `docs/cline-config-pins.md`; the
shell-function-to-script deviation and the A/B's override-not-improvement outcome for the design
docs' status badge; Phase 9's still-unaddressed reasoning-history documentation correction; and the
still-open `flashnext-reach-xhigh` disposition, now handed forward a second time.

Per this plan's explicit instruction, `.planning/STATE.md`, `ROADMAP.md`, and `REQUIREMENTS.md` were
not touched — the orchestrator owns updating those at phase close.
