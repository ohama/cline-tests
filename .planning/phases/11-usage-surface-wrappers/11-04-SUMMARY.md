---
phase: 11-usage-surface-wrappers
plan: 04
subsystem: cli-wrappers
tags: [bash, cline-cli, litellm, providers-json, live-probe, budget-enforcement, cfg-05]

# Dependency graph
requires:
  - phase: 11-01
    provides: "phase-11/cline-plan / cline-act deny-by-default wrappers, phase-11/wrapper.env, phase-11/testing/stub-cline"
  - phase: 11-03
    provides: "phase-11/verify_wrappers.sh, phase-01/config/verify_config.sh's wrapper section (exit 3), WRAPPER_CHECK_ALIAS_LIVE=1 opt-in live check"
provides:
  - "phase-11/probe_lib11.sh: Phase 11 safety envelope judging providers.json on model/contextWindow (delegated to verify_config.sh), never sha256; hard litellm-pid check with no restart_expected escape hatch; a code-enforced 14-request budget cap shared across every probe script this plan runs"
  - "phase-11/selftest_probe_lib11.sh: proves the corrected invariant discriminates (4 mutants + 1 clean control, offline)"
  - "phase-11/probe_open_items.sh: live observation of reasoning_effort:high through both alias prefixes plus the real cline --thinking high surface, and a re-measured per-turn max_tokens figure"
  - "phase-11/probe_wrapper_volume.sh: live wrapper-invocation volume probe that caught a real providers.json model-field corruption on its very first call"
  - "phase-11/OPEN-ITEMS.md: disposition of all four 11-RESEARCH.md open items, three resolved here, one deferred to 11-05"
affects: ["11-05 (USE-03 A/B harness -- must use the newly re-measured max_tokens=20983, not the stale 2048 figure; must account for providers.json's model field currently reading flashnext-plan, not flashnext)", "phase-12 (USE-04/USE-05 docs; the CFG-05 auto-update-breaks-the-binary finding and the -m persistence regression both belong in the phase findings)"]

tech-stack:
  added: []
  patterns:
    - "Corrected providers.json invariant: judge on model/contextWindow via the script that owns that check (verify_config.sh), record sha256/updatedAt as observations only, never as pass/fail -- proven, not assumed, via 4 seeded mutants plus a clean control"
    - "Code-enforced, plan-wide (not per-script) live-request budget: a single persistent watermark file shared across every probe script in the plan, checked before every request (assert_budget) and logged after every request (log_budget_row), cross-verified via a second, independent counting arithmetic in each script"
    - "Replay, not interception, of a suppressed internal guard call one is forbidden from instrumenting directly: when a shipped script (owned by an earlier plan) discards its own sub-process's stdout on success, run the identical command adjacent in time against the same state and label it explicitly as a replay"
    - "Pre-registered stop condition executed literally: 'if a judged field moves, stop, do not restore, record' was written into the plan before any live call, and was exercised for real on the very first wrapper invocation"

key-files:
  created:
    - phase-11/probe_lib11.sh
    - phase-11/selftest_probe_lib11.sh
    - phase-11/probe_open_items.sh
    - phase-11/probe_wrapper_volume.sh
    - phase-11/OPEN-ITEMS.md
    - phase-11/results/20260902T045646Z-selftest/
    - phase-11/results/20260902T045814Z-openitems/
    - phase-11/results/20260902T050726Z-volume/
    - phase-11/results/CURRENT_OPENITEMS_RUN
    - phase-11/results/CURRENT_VOLUME_RUN
  modified: []

key-decisions:
  - "count_requests_since/assert_budget/log_budget_row count only Generation queued lines in flashnext.err (requests that reached the model's generation queue), not every HTTP/cline invocation attempted -- a request rejected by litellm's own param validation or the model server's own pre-queue value check costs zero against the cap, by design, matching the plan's own stated definition of the budget"
  - "The wrapper's own internal (VERIFY_CONFIG_NO_WRAPPER_CHECK=1-suppressed) guard call's stdout cannot be observed from outside without editing wrapper_common.sh (forbidden, owned by 11-01) because it is discarded on success -- probe_wrapper_volume.sh replays the identical command adjacent in time instead, and documents this as a replay, never claiming literal interception"
  - "When providers.json's model field was found to have moved after a single live wrapper call, the probe stopped immediately and did NOT attempt to restore the file or continue the loop, per the plan's own pre-registered instruction -- this is recorded as the plan's single most significant finding, not smoothed over to make the six-row table look complete"
  - "cline was reinstalled via `npm install -g cline@3.0.60` (pinned explicitly, not `latest`) after its npm package was found entirely removed mid-plan, to keep the plan's own measurements on a version consistent with what preflight11 had already recorded rather than accepting an undocumented further drift on top of an already-disrupted session"

patterns-established:
  - "A live-request budget across MULTIPLE probe scripts in the same plan needs one persistent, shared watermark, not a per-script one that resets and silently under-counts the true plan-wide total"
  - "An operational-failure retry (binary missing, connection refused) must be distinguished in code from a content-based retry (wrong answer, unexpected status) -- only the former is ever retried, and the distinguishing grep pattern (ENOENT / command not found / No such file) should be written into the script, not left to the operator's judgment at the time"

# Metrics
duration: ~28min
completed: 2026-09-02
---

# Phase 11 Plan 04: Model-Touching Safety Envelope + Three Open-Item Live Probes Summary

**Built the corrected (model/contextWindow-only) providers.json safety envelope and a code-enforced 14-request budget, then used them to observe `reasoning_effort:"high"`'s real failure mode through both alias prefixes, re-measure cline's per-turn `max_tokens` (2048 → 20983, a ~10× move), and catch — on the very first live wrapper invocation, not after a planned six — providers.json's pinned `model` field actually moving from `flashnext` to `flashnext-plan`, live, in production, contradicting Phase 10's own N=1 clean observation.**

## Performance

- **Duration:** ~28 min (baseline capture 04:45:11Z → final commit 05:13:07Z)
- **Tasks:** 3/3 completed (all three produced live, non-trivial findings)
- **Files created:** 5 scripts/docs + 3 timestamped results directories
- **Live model requests:** 3 of a stated 14-request cap (see Budget section below) — 8 total request *attempts* were made (including 2 operational-failure retries), but only 3 actually reached the model's generation queue

## Accomplishments

- `phase-11/probe_lib11.sh` encodes the corrected providers.json invariant (model/contextWindow via `verify_config.sh`, sha256/updatedAt recorded but never judged) and a code-enforced, plan-wide 14-request budget cap — proven, not assumed, by `selftest_probe_lib11.sh`'s 4 mutants + 1 clean control (all 5 PASS/FAIL exactly as required) and by `assert_budget` actually aborting under a forced zero-cap test.
- Open Item 1 (11-RESEARCH.md Q4) resolved end-to-end: `reasoning_effort:"high"` produces HTTP 500 from the model server through `flashnext-plan` (`hosted_vllm/`), HTTP 400 from litellm itself through `flashnext` (`openai/`), and the real `cline --thinking high` CLI surfaces the identical model-side 500 message and exits 1 — plus a healthy-path control (HTTP 200) proving the alias itself was never the problem.
- Open Item 2 (11-RESEARCH.md Q6.2) resolved, with a surprising answer: cline's per-turn `max_tokens` is no longer the fixed `2048` measured at 3.0.53 — it is now `20983` at the installed 3.0.60/3.0.61, a roughly 10× increase for an essentially identical prompt. This directly invalidates the "fixed shared completion budget" assumption plan 11-05's A/B design was going to rely on.
- Open Item 3 (11-RESEARCH.md Q5) superseded by a more severe finding: the very first of six planned live wrapper invocations already moved providers.json's pinned `model` field (`flashnext` → `flashnext-plan`), contradicting Phase 10's own N=1 observation. The wrapper's own post-run guard caught this correctly and exited 4, exactly per its documented contract. Per the plan's own explicit instruction, the probe stopped immediately and did not restore the file or continue the loop — `providers.json` is currently left in this corrupted state, a real, live, production-affecting condition that needs a human decision (see Next Phase Readiness).
- `phase-11/OPEN-ITEMS.md` records the disposition of all four `11-RESEARCH.md` open items (three resolved here, one explicitly deferred to 11-05), the Part A0 live gateway-check result, and a full, honest budget accounting.

## Task Commits

1. **Task 1: probe_lib11.sh safety envelope + providers.json mutant selftest** — `eca6188` (test)
2. **Task 2: open items 1 & 2 — reasoning_effort failure modes, max_tokens re-measurement** — `2a50af9` (feat)
3. **Task 3: wrapper volume probe — live -m call moves providers.json model field** — `50dd653` (feat)
4. **OPEN-ITEMS.md — disposition of all four open items** — `e45267a` (docs)

_This document + the STATE.md update are the orchestrator's standard closing step, per workflow — not committed as part of this plan's own task sequence._

## Files Created/Modified

- `phase-11/probe_lib11.sh` — Phase 11 preflight11/postflight11, providers_fields, wait_idle11, count_requests_since/assert_budget/log_budget_row
- `phase-11/selftest_probe_lib11.sh` — 4-mutant + clean-control proof that the corrected invariant discriminates, offline
- `phase-11/probe_open_items.sh` — Open Items 1 & 2 live probes, with operational-failure-only retry logic
- `phase-11/probe_wrapper_volume.sh` — Open Item 3's live wrapper-volume probe, Part A0 (opt-in live gateway alias check) + Part A (6 planned wrapper invocations, stopped at 1)
- `phase-11/OPEN-ITEMS.md` — full disposition of all four research open items
- `phase-11/results/20260902T045646Z-selftest/`, `.../20260902T045814Z-openitems/`, `.../20260902T050726Z-volume/` — the three evidence run directories
- `phase-11/results/CURRENT_OPENITEMS_RUN`, `.../CURRENT_VOLUME_RUN` — pointers to the above

## Decisions Made

See `key-decisions` in the frontmatter above; the most consequential one in practice: **the probe stopped and did not attempt to restore `providers.json`** once its `model` field was observed to have moved, exactly as the plan pre-registered, rather than treating a "clean" six-row table as more important than reporting what was actually observed.

## Deviations from Plan

### Auto-fixed Issues (Rule 3 — blocking issue, fixed to unblock)

**1. cline npm package found entirely removed mid-plan, blocking Open Items 1c/2**
- **Found during:** Task 2, `probe_open_items.sh`'s first live `cline` invocation (case 1c)
- **Issue:** `/opt/homebrew/bin/cline: No such file or directory`; `/opt/homebrew/lib/node_modules/cline/` did not exist; `npm ls -g` showed no `cline` package at all. A still-running, unrelated hub-daemon process held an open handle to the now-unlinked binary, consistent with an in-progress/interrupted self-update (CFG-05) rather than any action by this plan.
- **Fix:** `npm install -g cline@3.0.60` (version pinned explicitly to match what `preflight11` had already recorded, not `latest`). Cases 1c and Open Item 2 were then retried exactly once each, per this plan's own outcome-neutral operational-failure-retry rule; cases 1a/1b/1d were NOT re-run since they had already succeeded with real content.
- **Files modified:** none (environmental repair only, no plan-owned file touched)
- **Verification:** `cline --version` returned `3.0.60` immediately after reinstall; both retried cases completed and produced real observations (see Open Items 1 and 2 above)
- **Committed in:** `2a50af9` (evidence of both the failure and the successful retry preserved verbatim in the run directory)

**Total deviations:** 1 auto-fixed (Rule 3 — blocking, environmental, fixed to unblock; not a plan-file change). **No Rule 4 (architectural) deviation was triggered** — the providers.json model-field corruption in Task 3, while highly significant, was a scenario the plan itself had already pre-authorized a specific response to (stop, do not restore, record), so no user check-in was required to know how to handle it; the significance is instead flagged prominently for the orchestrator's own attention in this document and in `OPEN-ITEMS.md`.

## Issues Encountered

**The plan's overall `<verification>` checklist item 5 ("providers.json: model is flashnext, contextWindow is 29000, verify_config.sh exits 0") is currently FALSE, by design, not by failure.** As of this plan's completion, the live `providers.json` reads `settings.model="flashnext-plan"` (contextWindow is still correctly `29000`) because of the Task 3 finding above, and `bash phase-01/config/verify_config.sh` exits 1. This is not glossed over: Task 3's own `<verify>` block explicitly anticipates and accepts "the run stopped at that row" as a valid outcome, and the plan's hard constraints forbid editing `providers.json` — so this document reports the literal top-level verification bullet as **NOT MET, by the plan's own design**, rather than silently claiming a clean pass. See "Next Phase Readiness" below for what this means operationally.

**cline drifted TWICE during this plan's live execution** (3.0.60 → [briefly missing entirely] → 3.0.60 (reinstalled) → 3.0.61), both loudly recorded by `preflight11`/`postflight11`'s own version-drift check, never silently absorbed.

## User Setup Required

None — no external service configuration required. However, see the urgent operational note below.

## Next Phase Readiness

- **🔴 Urgent, needs a human decision, outside this plan's authority:** the live `providers.json`'s `settings.model` currently reads `"flashnext-plan"`, not `"flashnext"`. Kanban and Telegram share this same provider entry; any of their own `cline` invocations that do not pass an explicit `-m` override will now default to the reasoning-heavy alias instead of the plain one. This plan's hard constraints forbid editing `providers.json` and its own explicit instruction forbids attempting to restore it — whether to run `phase-01/config/apply_provider_config.sh` (the tool that owns restoring this file) is a decision for the orchestrator/user, not something this plan executed.
- **Plan 11-05 (USE-03 A/B) must use `max_tokens=20983` as the current re-measured completion-budget constraint, not the stale `2048` figure from 3.0.53** — `docs/cline-max-tokens-findings.md` §6's own recheck recipe should be re-run again immediately before 11-05 executes, since the binary may have drifted further by then (it has already moved twice in the course of this single plan).
- **`phase-11/OPEN-ITEMS.md` is the authoritative source for all four `11-RESEARCH.md` open items** — three resolved with observed evidence, one (A/B sizing) explicitly deferred to 11-05, not silently dropped.
- **CFG-05 (cline's un-blocked auto-update) has now been observed to (a) completely remove the CLI's own invocability mid-session, not just silently drift version/flags, and (b) plausibly cause the `-m` persistence regression this plan's own Task 3 caught.** This connects two previously-separate risk categories and is worth a prominent mention in Phase 11/12's own findings document, beyond what this plan alone owns to write.
- Three `com.ohama.*` service pids (litellm 68670, flashnext 46573, role-shim 75548) unchanged throughout; port 3000 free; the live litellm config and its `~/local-llm-settings` mirror remain byte-identical; no service was ever restarted.

---
*Phase: 11-usage-surface-wrappers*
*Plan: 04*
*Completed: 2026-09-02*
