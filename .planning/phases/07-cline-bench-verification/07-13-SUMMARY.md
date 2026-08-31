---
phase: 07-cline-bench-verification
plan: 13
subsystem: testing
tags: [cline-bench, classifier-fix, harbor, flashnext, verdict-rule, mlx_vlm]

# Dependency graph
requires:
  - phase: 07-cline-bench-verification (07-11, 07-12)
    provides: a numbered, evidence-cited defect list (CLASSIFIER-AUDIT.md section 3) for the
      `HTTP_400_SEEN`-based verdict rule, the authoritative rejection-line format
      (token-ladder.tsv), and a named max_prompt_tokens undercount handoff (15,119 tokens for
      telegram-plugin-refactor, 147 for v-edit-workspace-tests)
provides:
  - A repaired, shared verdict rule (`phase-07/bench/classify_lib.sh`) sourced by both
    `run_task.sh` (live runs) and the new `reclassify_runs.sh` (offline re-classification), so
    the two paths cannot diverge
  - A new `fail-oom` verdict class distinguishing memory/GPU exhaustion from context-ceiling
    failures, with an explicit, evidence-backed precedence rule for tasks exhibiting both
  - `max_prompt_tokens_accepted` / `max_prompt_tokens_attempted` fields making the true fatal
    prompt size visible per task, without disturbing the backward-compatible `max_prompt_tokens`
    key
  - Sidecar `meta-reclassified/` verdicts for both stored run directories (5 instances total),
    proving 0 verdicts changed under the corrected rule
  - Four negative-control fixtures proving the new detector rejects both false-positive vectors
    07-12 identified and correctly fires on both true-positive cases (context rejection, memory
    exhaustion)
  - A named, schema-verified finding for 07-14 on whether cline's auto_compaction mechanism
    prunes messages on real bench workloads at all (it does not, in the 2 stored real-bench
    completed events; it does, in all 5 synthetic completed events)
affects: [07-14 (remediation decision), 07-15 (conditional live run), any future cline-bench run
  whose fail-context/fail-oom labels get cited]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shared-rule pattern for classifiers with two call sites (live + offline
      re-derivation): factor the entire decision function into a sourced library with pure,
      side-effect-free functions (each degrading to a zero value on a missing input file rather
      than erroring), so a future fix cannot land in one call site and silently miss the other."
    - "Reclassification-as-proof pattern: before trusting a rewritten classifier, replay it over
      every stored instance and require every existing label to reproduce exactly; a changed
      label is a regression to investigate, not a success, unless independently justified."

key-files:
  created:
    - phase-07/bench/classify_lib.sh
    - phase-07/bench/reclassify_runs.sh
    - bench/runs/20260830T122809Z-phase07-fix/meta-reclassified/*.json (4 files)
    - bench/runs/20260830T093657Z-phase07/meta-reclassified/discord-trivia-approval-keyerror.json
    - phase-07/results/20260831T010013Z-reclassify/README.md
    - phase-07/results/20260831T010013Z-reclassify/RECLASSIFICATION.md
    - phase-07/results/20260831T010013Z-reclassify/negative-controls.txt
    - phase-07/results/20260831T010013Z-reclassify/fixtures/*.txt (4 files)
  modified:
    - phase-07/bench/run_task.sh
    - phase-07/bench/verify_bench.sh

key-decisions:
  - "max_prompt_tokens (the pre-existing meta.json key) keeps its exact pre-07-13 value and
    computation (accepted-only peak) for backward compatibility with make_summary.sh and
    historical ledger comparisons in 07-11's CONTEXT-FORENSICS.md. The true fatal-request peak
    (including rejected requests) lives in a new key, max_prompt_tokens_attempted, so the two are
    never conflated again -- exactly as 07-13-PLAN.md's Task 1 action item specified."
  - "The old rule's second OR-term (max_prompt_tokens >= 32768 against the accepted-only figure)
    is REMOVED outright, not kept as a redundant fallback: 07-12 defect 4 proved it structurally
    could never fire (a rejected request is never queued, so its prompt count never reaches the
    accepted-only grep target), and it would now be fully subsumed by the authoritative-phrase
    match in every case where it could theoretically matter."
  - "fail-context takes precedence over the new fail-oom verdict whenever both signals are
    present, because 07-12's audit confirmed the MAX_KV_SIZE rejection is the TERMINAL event in
    the one stored task showing both (discord-trivia-approval-keyerror: 6 recovered OOM events,
    then 1 terminal rejection). The oom_failures counter is still recorded in the meta record
    precisely so this is never a *silent* pure-context report."
  - "classify_lib.sh is a new file, not listed in 07-13-PLAN.md's files_modified. Added under
    deviation Rule 2 (missing critical correctness gap): the plan's own key_links section
    requires run_task.sh and reclassify_runs.sh to 'derive the verdict from one shared rule ...
    so live runs and re-classification cannot diverge' -- a sourced helper file is the plan's own
    suggested mechanism for this ('a sourced helper file, or have reclassify_runs.sh source the
    function out of run_task.sh')."
  - "reclassify_runs.sh independently re-derives model_turns and reward from stored evidence
    (server-log grep, verifier/reward.txt) rather than trusting the values already recorded in
    meta/*.json, per the plan's 'derive from stored evidence' framing -- even though the values
    are identical either way for all 5 stored instances."

patterns-established:
  - "When two scripts must share a classification rule, express it as small pure functions in a
    sourced .sh library (count_X, max_Y, classify_verdict), each independently testable against a
    synthetic fixture file by direct function call, rather than only testable by running the full
    pipeline against real data."

# Metrics
duration: 12min
completed: 2026-08-31
---

# Phase 07 Plan 13: Classifier Fix (Gap Closure) Summary

**Replaced the bare-`\b400\b` context-rejection detector with a shared `classify_lib.sh` that
matches the authoritative `MAX_KV_SIZE` rejection phrase, added a distinct `fail-oom` verdict, and
proved via offline re-classification that all 5 stored run instances reproduce their exact
original labels under the corrected rule.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-08-31T00:51:50Z (safety snapshot)
- **Completed:** 2026-08-31T01:02:54Z (last task commit)
- **Tasks:** 3/3 completed
- **Files modified:** 2 modified (`run_task.sh`, `verify_bench.sh`), 12 created (1 shared lib, 1
  offline script, 5 meta-reclassified sidecars, 1 README, 1 RECLASSIFICATION.md, 4 fixture files
  + negative-controls.txt)

## Accomplishments

- Repaired `run_task.sh`'s verdict rule: replaced the bare-`400` substring test (07-12 defects 1+2)
  with a match on the authoritative rejection phrase (`Request needs <T> context tokens (<P>
  prompt + <G> max generation), but MAX_KV_SIZE is <K>`), verified byte-for-byte against the real
  rejection lines in all 3 stored `fail-context` tasks' server logs and transcripts.
- Factored the entire verdict rule into `phase-07/bench/classify_lib.sh`, sourced by both
  `run_task.sh` and the new `reclassify_runs.sh`, so live runs and offline re-classification
  cannot diverge (07-13-PLAN.md's explicit `key_links` requirement).
- Added `max_prompt_tokens_accepted` / `max_prompt_tokens_attempted` fields (the latter recovering
  07-11's named undercount: 36155 vs 21036 for `telegram-plugin-refactor`, 30843 vs 30696 for
  `v-edit-workspace-tests`) while keeping the pre-existing `max_prompt_tokens` key
  byte-for-byte unchanged in value and computation.
- Added a distinct `fail-oom` verdict class for GPU/host memory exhaustion, with an explicit,
  evidence-backed precedence rule (`fail-context` wins when both signals are present) documented
  in both `classify_lib.sh`'s function body and `run_task.sh`'s comment block.
- Built `reclassify_runs.sh`, ran it against both stored run directories (5 task instances total),
  and confirmed `meta/` stayed byte-identical, the script is idempotent, and **0 of 5 verdicts
  changed** — the corrected classifier reproduces every existing label exactly.
- Proved the fix against 4 synthetic negative/positive controls: decode telemetry and the
  benchmark repo's own HTTP-status source literals do NOT trigger `fail-context`; the real
  rejection phrase DOES trigger it with the correct attempted-prompt figure; a bare OOM event
  triggers the new `fail-oom`, not `fail-context`.
- Checked the orchestrator's pruning-observation lead cheaply: confirmed the phase-01 synthetic
  run and the real bench `.compaction.json` notices share the identical `auto_compaction` schema
  (same field names, same producer), then compared every `completed` event on both sides — 5/5
  synthetic events pruned messages and shrank tokens; 2/2 real-bench events pruned zero messages
  and grew tokens. Recorded as a named, scoped finding for 07-14 rather than acted on.

## Task Commits

Each task was committed atomically:

1. **Task 1: Repair the verdict rule in run_task.sh** - `52a27f5` (fix)
2. **Task 2: Build reclassify_runs.sh and admit the new verdict class in verify_bench.sh** - `282b560` (feat)
3. **Task 3: Prove the new detector with negative controls and write RECLASSIFICATION.md** - `1714181` (docs)

**Plan metadata:** commit created below (docs: complete plan)

## Files Created/Modified

- `phase-07/bench/classify_lib.sh` - shared verdict-rule library: `count_maxkv_rejections`,
  `count_oom_failures`, `max_prompt_tokens_accepted`, `max_rejected_prompt_tokens`,
  `max_prompt_tokens_attempted`, `count_model_turns`, `read_reward`, `classify_verdict`
- `phase-07/bench/run_task.sh` - classification/meta-emit region (section 8/9) rewritten to
  source `classify_lib.sh`; new meta fields `max_prompt_tokens_accepted`,
  `max_prompt_tokens_attempted`, `maxkv_rejections_serverlog`, `maxkv_rejections_transcript`,
  `oom_failures`; `http_400_seen` key kept (semantics changed, documented in-line)
- `phase-07/bench/verify_bench.sh` - B2's allowed-verdict set now admits `fail-oom`
- `phase-07/bench/reclassify_runs.sh` - offline re-classification of a stored run directory from
  preserved evidence, writing `<run-dir>/meta-reclassified/<task>.json` sidecars, with a hard
  assertion refusing any output path resolving inside `meta/`
- `bench/runs/20260830T122809Z-phase07-fix/meta-reclassified/{discord-trivia-approval-keyerror,
  filmarchiver,telegram-plugin-refactor,v-edit-workspace-tests}.json` - sidecar verdicts (0
  changed vs originals)
- `bench/runs/20260830T093657Z-phase07/meta-reclassified/discord-trivia-approval-keyerror.json` -
  sidecar verdict for the pre-fix run instance (0 changed)
- `phase-07/results/20260831T010013Z-reclassify/README.md` - directory index + safety snapshot
- `phase-07/results/20260831T010013Z-reclassify/RECLASSIFICATION.md` - old-vs-new table for all 5
  stored instances, restated corrected counts (N=4/M=3/P=0, unchanged), and the pruning-lead
  finding for 07-14
- `phase-07/results/20260831T010013Z-reclassify/negative-controls.txt` - 4/4 controls MATCH
- `phase-07/results/20260831T010013Z-reclassify/fixtures/*.txt` - the 4 synthetic fixture files

## Decisions Made

See `key-decisions` in frontmatter. In short: `max_prompt_tokens` stays accepted-only for
backward compatibility (new field for the true fatal peak); the numeric OR-term is removed
outright, not kept as a fallback; `fail-context` wins precedence over `fail-oom`; `classify_lib.sh`
is a deliberate, plan-sanctioned addition to satisfy the shared-rule requirement; and
`reclassify_runs.sh` re-derives everything from raw evidence rather than trusting the original
meta.json fields.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added `phase-07/bench/classify_lib.sh` as a new shared file**
- **Found during:** Task 1 (Repair the verdict rule in run_task.sh)
- **Issue:** 07-13-PLAN.md's `key_links` section requires `run_task.sh` and `reclassify_runs.sh`
  to derive the verdict from one shared rule, but the plan's `files_modified` frontmatter only
  listed `run_task.sh`, `verify_bench.sh`, and `reclassify_runs.sh` -- no shared-library file.
  Duplicating the classification logic by copy-paste between the two scripts would have violated
  the plan's own explicit anti-drift requirement.
- **Fix:** Created `phase-07/bench/classify_lib.sh` containing every count/verdict function, sourced
  by both `run_task.sh` and `reclassify_runs.sh`. This is exactly the mechanism the plan's own
  Task 2 action text names as acceptable ("a sourced helper file, or have reclassify_runs.sh
  source the function out of run_task.sh").
- **Files modified:** `phase-07/bench/classify_lib.sh` (new), `phase-07/bench/run_task.sh`,
  `phase-07/bench/reclassify_runs.sh`
- **Verification:** Both scripts pass `bash -n`; `run_task.sh`'s diff still touches only the
  classification/meta-emit region (git diff hunks confined to lines ~460-620); reclassification
  reproduces all 5 stored verdicts exactly using the same shared functions.
- **Committed in:** `52a27f5` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical, required by the plan's own key_links
constraint).
**Impact on plan:** Necessary to satisfy the plan's explicit anti-drift requirement; no scope
creep beyond what Task 1's own action text anticipated as an acceptable implementation choice.

## Issues Encountered

None. The authoritative rejection phrase matched verbatim, byte-for-byte, in both the raw
server-log and the litellm-relayed transcript for all 3 `fail-context` tasks on the first attempt
(spot-checked directly against the stored files before writing any code), so no iteration was
needed to find the right regex.

## User Setup Required

None - no external service configuration required. This plan is read-only with respect to all
live services and configuration; the only writes were to `phase-07/bench/*.sh`, a new
`classify_lib.sh`, and sidecar/results files.

## Next Phase Readiness

- 07-14 (remediation decision) has a corrected instrument to build on: `fail-context` and
  `fail-oom` verdicts are now independently trustworthy in mechanism, not just coincidentally
  correct, and `max_prompt_tokens_attempted` gives 07-14 the true fatal-request size per task
  without needing to re-derive it forensically.
- 07-14 also has a named, schema-verified finding worth weighing explicitly: on the 2 real
  `fail-context` compaction events captured so far, cline's `auto_compaction` mechanism completed
  without pruning any messages (messagesBefore==messagesAfter==16, tokens grew rather than
  shrank), while all 5 completed events in the phase-01 synthetic run (same notice schema) did
  prune and did shrink. If this generalizes, lowering `contextWindow` alone would not fix the
  observed failures -- but this remains a 2-data-point real-world observation, not a
  remediation recommendation, and a third example (07-15's conditional live run) is the specific
  gap that would firm it up.
- No blockers. All hard safety constraints held throughout: `bench/runs/*/meta/` byte-unchanged
  (`git status --short bench/runs/*/meta/` empty, checked before and after `reclassify_runs.sh`
  ran and again at the end of this plan); pids 46573/75548/48525 unchanged (all six live-service
  pids present, confirmed by ps); `providers.json` sha256
  `534151965f81089b11d96d4af0b8a115b558f38efd42e82a9edd2a76f44fc214` unchanged; colima still
  stopped (`colima status` -> "colima is not running"); `lsof -i :3000` empty; no `harbor`/`cline`
  process invoked; zero live bench runs; zero model calls.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-31*
