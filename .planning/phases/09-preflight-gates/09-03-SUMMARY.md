---
phase: 09-preflight-gates
plan: 03
subsystem: infra
tags: [litellm, mlx-server, bash, python, probe-harness, gate-verification, reasoning_content, prompt_tokens, source-inspection]

# Dependency graph
requires:
  - phase: 09-preflight-gates (09-01)
    provides: probe_lib.sh -- preflight/postflight safety envelope, gpu-stream flake_window discriminator, four-state record_verdict machine
  - phase: 09-preflight-gates (09-02)
    provides: PRB-03-ORACLE.md's confounded multi-turn growth data and 2,497 chars of real captured xhigh reasoning traces (realtrace-t1/t2/t3.txt)
provides:
  - phase-09/probe_prb04_replay.py -- synthetic reasoning replay probe, :8011 + :4000 (flashnext), both reasoning_content/reasoning field names, 2-round anti-flake loop
  - phase-09/probe_prb04_realtrace.py -- replay comparison using 09-02's real xhigh traces (LONGEST 989 chars, CONCAT 2,497 chars)
  - phase-09/verify_reasoning_history_source.sh -- independent re-verification of shouldIncludeReasoningHistory/agentPartToContentBlock/message-builder/litellm source path, with observed line numbers
  - phase-09/PRB-04-FINDINGS.md -- both measurement matrices, quantitative reconciliation against 09-02's multi-turn numbers, the false-negative doc correction, Phase 10/12 handoffs
  - phase-09/results/20260901T021414Z-prb04/ -- run directory: prb04-synthetic.tsv (12 rows), prb04-realtrace.tsv (4 rows), source-verification.txt, 18 raw JSON bodies, verdicts.tsv (16 CONFIRMED), pre/postflight snapshots
affects: [09-04-PLAN (PRB-04 gate adjudication), phase-10 (VRF-04, CFG-16), phase-12 (USE-05 doc edits)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "anti-flake round loop for a milestone-killing gate: mandatory minimum rounds (2 for the synthetic matrix, matching the plan's 'no single reading carries a gate'), extra rounds up to ATTEMPT_MAX=3 only if a label has not yet reached a terminal verdict (CONFIRMED/CONFIRMED-NEGATIVE) in probe_lib.sh's four-state machine, INDETERMINATE recorded explicitly if still unresolved after the cap"
    - "reconciliation-by-direct-measurement: rather than estimating whether a corroborating (confounded) prior result is consistent with a new controlled result, use the controlled result's own already-measured quantity (real-trace delta=0) to explain the confounded result's residual, and record the small extra isolation probe that supports the arithmetic"
    - "read-only source-verification script pattern: PASS/FAIL/LOUD echo lines per check, sed -n captures of verbatim function bodies into an evidence file, explicit tag-drift detection with a LOUD (not silent) warning path"

key-files:
  created:
    - phase-09/probe_prb04_replay.py
    - phase-09/probe_prb04_realtrace.py
    - phase-09/verify_reasoning_history_source.sh
    - phase-09/PRB-04-FINDINGS.md
    - phase-09/results/CURRENT_PRB04_RUN
    - phase-09/results/20260901T021414Z-prb04/ (prb04-synthetic.tsv, prb04-realtrace.tsv, source-verification.txt, verdicts.tsv, 18 raw-*.json, pre/postflight + hash/pid snapshots)
  modified: []

key-decisions:
  - "Task 1's anti-flake loop treats each full 6-request round as one attempt for all 4 delta-bearing labels simultaneously (not per-label independent rounds), since one baseline call serves both field checks at an endpoint -- matches the plan's literal 6-request-matrix-per-repeat table exactly, and probe_lib.sh's record_verdict already auto-promotes PROVISIONAL-NEGATIVE to CONFIRMED-NEGATIVE across the two repeats without extra logic"
  - "Task 2 (real-trace replay) does not force a mandatory second round the way Task 1 does -- the plan only specifies a single 6-request matrix for the real traces, with the anti-flake round-extension loop reserved for the case a delta actually comes back non-zero. All 4 labels reached CONFIRMED on round 1 here, so this asymmetry was never exercised, but the code path exists"
  - "Added one small (max_tokens:4) reconciliation-only probe -- turn 3's exact user text sent alone against a fresh unspecified-arm baseline -- to make the plan's required reconciliation against 09-02's multi-turn ON-sequence growth numbers evidence-based rather than a hand-wavy assertion. Not part of either committed probe script (fires no new reasoning traces, generates no new load beyond one 4-token completion), documented directly in PRB-04-FINDINGS.md sec1c with its raw response retained on disk"
  - "verify_reasoning_history_source.sh records isCerebrasProvider's actual definition site as model-facts.ts:449 (not ai-sdk.ts, which only imports and calls it) as a LOUD but non-blocking correction to 09-RESEARCH.md's citation -- the underlying finding (our provider is non-Cerebras, so reasoning history is included) is unaffected"

patterns-established:
  - "PRB-04's decisive evidence is now a controlled, twice-reproduced, both-field-name, both-real-and-synthetic-trace measurement (this plan) with a separate corroborating-only multi-turn dataset (09-02) explicitly reconciled against it, rather than a single research run -- this two-tier evidence structure (decisive controlled + corroborating confounded, with an explicit reconciliation paragraph) is the shape 09-04 should expect for gate adjudication write-ups"

# Metrics
duration: ~15min
completed: 2026-09-01
---

# Phase 9 Plan 03: PRB-04 Controlled Replay Reproduction + Source Correction Record Summary

**Independently reproduced 09-RESEARCH.md's milestone-killing PRB-04 measurement from scratch -- synthetic AND real xhigh traces up to 2,497 chars, both field names, both stack layers, all 16 delta-bearing readings CONFIRMED at delta=0 -- and recorded (without editing) the false-negative correction that Cline's `shouldIncludeReasoningHistory`/`agentPartToContentBlock` path does architecturally re-attach reasoning history, with precise Phase 12 edit targets and a Phase 10 VRF-04 handoff.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-09-01T02:14Z (Task 1 run-dir creation + preflight)
- **Completed:** 2026-09-01T02:21Z (Task 3 commit)
- **Tasks:** 3/3
- **Files modified:** 4 scripts/docs + 1 pointer file + 1 run directory (22 files across 3 commits)

## Accomplishments

- `probe_prb04_replay.py`: reproduced 09-RESEARCH.md's literal PRB-04 replay probe from scratch as this phase's own measurement, extended to cover the `reasoning` field name (the research reasoned about it but never literally sent it as a nested message key) alongside `reasoning_content`, at both `:8011` direct and `:4000` through the existing unmodified `flashnext` alias. Two full 6-request rounds (mandatory, per "no single reading carries a gate"), a bash-3.2-compatible anti-flake round-extension loop (up to 3 rounds) wired into probe_lib.sh's four-state verdict machine. Result: **all 4 (endpoint x field) labels CONFIRMED at delta=0** both rounds, CLEAN flake window throughout -- matches the research's prior finding bit-for-bit, now independently reproduced with the second field name.
- `probe_prb04_realtrace.py`: closed 09-RESEARCH.md's Open Risk #3 (zero-cost finding used only a 1,380-char synthetic trace) using the real xhigh reasoning captured in 09-02 -- LONGEST (989 chars, the single longest real trace) and CONCAT (2,497 chars, all three real traces concatenated, nearly double the synthetic's length). Result: **all 4 (trace x endpoint) labels CONFIRMED at delta=0** on the first round -- the 2,497-char real trace shows no length-threshold effect, closing the gap with real (not synthetic) evidence.
- `verify_reasoning_history_source.sh`: independently re-verified `shouldIncludeReasoningHistory` (`ai-sdk.ts:284-289`, `return !isCerebrasProvider(...)` captured verbatim) and `agentPartToContentBlock` (`agent-message-codec.ts:231`, `case "reasoning"` at line 237 converting to a `type: "thinking"` block) at tag `cli-v3.0.53` (tree clean), plus `message-builder.ts:1213-1214`'s thinking-block budget counting and the installed litellm's `_extract_reasoning_content:1337` dual-field fallback -- all observed line numbers recorded fresh, not restated from the research. One LOUD (non-blocking) correction found: `isCerebrasProvider`'s actual definition is in `model-facts.ts:449`, not `ai-sdk.ts` as the research's citation implied.
- `PRB-04-FINDINGS.md`: both measurement matrices written up with trace lengths/deltas/flake states; the false-negative correction to `docs/plan-act-reasoning-implementation.md` (lines 96-100, 102) and `docs/plan-act-reasoning-diagrams.md` (lines 187-191) recorded with precise Phase 12 edit targets (Phase 9 does not edit these docs); the Phase 10 `VRF-04` real-Cline-on-the-wire deferral and litellm request-side-validation caveat both named explicitly; **the plan's required reconciliation against 09-02's confounded multi-turn ON-sequence growth (+58, +23) performed and found quantitatively consistent** -- a small reconciliation-only probe isolated turn 3's own user-message token cost (21 tokens vs. a 13-token fixed baseline), showing the +23 turn-3 growth is far too small to be explained by a per-character reasoning cost, fully consistent with this plan's own delta=0 measurement of that exact trace. No disagreement found; had there been one, it would have been reported as loudly as this consistency finding is.
- No gate verdict declared anywhere in this plan, by design -- PRB-04 adjudication is plan 09-04's job. Stack-unchanged mechanically confirmed across all three tasks: `com.ohama.flashnext` (46573), `com.ohama.role-shim` (75548), `com.ohama.litellm` (48525) identical throughout; config hashes identical throughout; `verify_config.sh` exits 0; `cline-src` `git status --porcelain` empty; `cline` never invoked to generate load.

## Task Commits

Each task was committed atomically:

1. **Task 1: Re-run the synthetic replay probe at both layers, with both field names** - `44436b6` (feat)
2. **Task 2: Re-run the replay with the real xhigh traces captured in 09-02** - `701ce80` (feat)
3. **Task 3: Re-verify the reasoning-history source path and write PRB-04-FINDINGS.md** - `ceba3c9` (feat)

_No TDD tasks in this plan._

## Files Created/Modified

- `phase-09/probe_prb04_replay.py` - synthetic reasoning replay probe: 2 endpoints x 3 field states x 2 rounds, anti-flake round-extension loop
- `phase-09/probe_prb04_realtrace.py` - real xhigh trace replay: LONGEST/CONCAT x 2 endpoints, reuses 09-02's captured traces (no new load)
- `phase-09/verify_reasoning_history_source.sh` - read-only re-verification of the Cline + litellm reasoning-history source path, PASS/FAIL/LOUD per check
- `phase-09/PRB-04-FINDINGS.md` - both measurement matrices, reconciliation, false-negative correction, Phase 10/12 handoffs, requirement mapping
- `phase-09/results/CURRENT_PRB04_RUN` - pointer to this plan's shared run directory
- `phase-09/results/20260901T021414Z-prb04/` - run directory: `prb04-synthetic.tsv` (12 rows), `prb04-realtrace.tsv` (4 rows), `source-verification.txt`, `verdicts.tsv` (16 CONFIRMED entries across both tasks), 18 `raw-prb04-*.json` (including one reconciliation-only probe body), pre/postflight + hash/pid snapshots

## Decisions Made

- Task 1's anti-flake loop operates at the granularity of a full 6-request round (all 4 delta-bearing labels at once), not per-label independent retries, since one baseline call serves both field checks at each endpoint -- matches the plan's literal request table and lets `probe_lib.sh`'s existing PROVISIONAL-NEGATIVE -> CONFIRMED-NEGATIVE promotion logic (across the two mandatory repeats) do the anti-flake work without extra bookkeeping.
- Task 2 does not force a mandatory second round the way Task 1 does, since the plan specifies a single 6-request matrix for the real traces; the round-extension loop exists and would fire on any non-zero delta, but was never exercised (all 4 labels CONFIRMED on round 1).
- Added a single small (`max_tokens:4`) reconciliation-only probe, isolating turn 3's exact user text against a fresh baseline, to make the plan's required reconciliation paragraph in `PRB-04-FINDINGS.md` evidence-based. This fires no new reasoning trace and generates no meaningful additional model load; its raw response is retained on disk but it is not part of either committed probe script.
- `verify_reasoning_history_source.sh` records `isCerebrasProvider`'s actual definition site (`model-facts.ts:449`) as a LOUD, non-blocking correction to 09-RESEARCH.md's citation, which implied it was local to `ai-sdk.ts` -- the underlying finding is unaffected.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added a small reconciliation-support probe not listed as a task**
- **Found during:** Task 3, while writing `PRB-04-FINDINGS.md`'s required reconciliation paragraph against 09-02's multi-turn ON-sequence growth numbers (+58, +23)
- **Issue:** The plan explicitly requires stating "whether your controlled result is quantitatively consistent with those multi-turn numbers, and if it is not, say so loudly." A purely qualitative assertion of consistency, without checking the arithmetic, would be exactly the kind of unverified claim the project's recurring failure mode warns against ("설정했다" vs "작동한다").
- **Fix:** Fired one additional `max_tokens:4` request -- turn 3's exact user text alone, against a fresh `unspecified`-arm baseline -- to get an isolated content-token estimate (21 tokens vs. a 13-token fixed baseline = ~8 tokens of isolated content), then reasoned explicitly in `PRB-04-FINDINGS.md` sec1c about why the residual between that estimate and the observed +23 growth is attributable to turn-boundary/chat-template overhead rather than to the 917-char reasoning trace (which this plan's own sec1b measurement already shows costs exactly 0 tokens when replayed directly).
- **Files modified:** `phase-09/PRB-04-FINDINGS.md` (reconciliation paragraph); `phase-09/results/20260901T021414Z-prb04/raw-prb04-reconcile-turn3solo.json` (raw evidence, retained on disk)
- **Verification:** Request returned HTTP 200, single unambiguous `Prefill started` log match, `prompt_tokens=21` read directly from the log line, `wait_idle()` confirmed before firing
- **Committed in:** `ceba3c9` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 -- missing critical correctness support for a required claim)
**Impact on plan:** The fix strengthens the plan's own required reconciliation statement with actual evidence rather than assertion; it used the existing safety-envelope idle-check discipline, cost one extra 4-token completion, and did not add scope beyond what Task 3 already required writing.

## Issues Encountered

None beyond the one deviation above. Every request across both probe scripts succeeded on its first attribution attempt (all `attr_attempts=1` in stderr logs); no `DISCARDED-FLAKE`, no unresolved `PROVISIONAL-NEGATIVE`, no `INDETERMINATE` verdicts anywhere in this run's `verdicts.tsv` -- 16 CONFIRMED entries total (12 from Task 1, 4 from Task 2), zero flakes.

## User Setup Required

None -- no external service configuration required.

## Next Phase Readiness

- `PRB-04-FINDINGS.md` gives plan 09-04 a complete, twice-reproduced, both-layer, both-field-name, both-synthetic-and-real-trace evidence base for PRB-04 adjudication, plus an explicit reconciliation showing 09-02's corroborating multi-turn numbers do not contradict this plan's controlled zero-cost result.
- The false-negative correction to `docs/plan-act-reasoning-implementation.md` (lines 96-100, 102) and `docs/plan-act-reasoning-diagrams.md` (lines 187-191) is recorded with precise line-level edit targets for Phase 12 (USE-05) -- Phase 9 did not edit either document, by design; `git -C /Users/ohama/projs/cline-src status --porcelain` confirms `cline-src` itself was never modified either.
- Phase 10's `VRF-04` (real-Cline-on-the-wire confirmation, already present in `.planning/REQUIREMENTS.md`) is named explicitly as the consumer of Phase 9's "source-verified only, MEDIUM confidence" architectural finding -- this deferral is not newly invented here, but this plan is the first to tie it explicitly to the specific PRB-04 evidence gap it closes.
- No gate verdict was declared by this plan, by design. Comparison of these fresh numbers against 09-RESEARCH.md's prior figures and the actual PRB-04 go/no-go call is plan 09-04's job -- the milestone's continuation into Phase 10 depends entirely on that adjudication.
- Stack-unchanged mechanically confirmed across all three tasks: `com.ohama.flashnext` (46573), `com.ohama.role-shim` (75548), `com.ohama.litellm` (48525) identical before/after every preflight/postflight pair; `litellm-config.yaml` and `providers.json` sha256 identical throughout; `verify_config.sh` exits 0; `cline-src` untouched; `cline` was never invoked to generate model load.
- No blockers for 09-04.

---
*Phase: 09-preflight-gates*
*Completed: 2026-09-01*
