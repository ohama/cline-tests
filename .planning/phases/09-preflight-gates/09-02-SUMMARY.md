---
phase: 09-preflight-gates
plan: 02
subsystem: infra
tags: [litellm, mlx-server, bash, python, probe-harness, gate-verification, reasoning_effort, enable_thinking, prompt_tokens]

# Dependency graph
requires:
  - phase: 09-preflight-gates (09-01)
    provides: probe_lib.sh -- preflight/postflight safety envelope, gpu-stream flake_window discriminator, four-state record_verdict machine
provides:
  - phase-09/probe_prb03_oracle.sh -- six-arm effort/enable_thinking sweep (unspecified/medium/low/xhigh/et-true/et-medium), run twice, watermark-attributed prompt_tokens per request
  - phase-09/probe_multiturn_growth.py -- two >=3-turn sequences (xhigh thinking-on w/ reasoning feedback, thinking-off), watermark-attributed per-turn prompt_tokens growth, real xhigh trace capture
  - phase-09/PRB-03-ORACLE.md -- three-way absolute/delta comparison (VALIDATED.md / 09-RESEARCH.md / fresh), multi-turn growth table with confound stated, Phase 10 reach-probe oracle declaration
  - phase-09/results/20260901T015706Z-prb03/ -- run directory: prb03.tsv, multiturn.tsv, realtrace-t1..3.txt (2,497 real xhigh reasoning chars), realtrace-capture.tsv, 12+12 raw JSON bodies, sweep-lines.txt, verdicts.tsv, pre/postflight snapshots
affects: [09-03-PLAN, 09-04-PLAN, phase-10 (VRF-01, VRF-02, CFG-11, CFG-16)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "log-watermark request attribution: wc -l immediately before firing, read only lines appended since, require exactly one 'Prefill started' match before trusting its prompt_tokens -- replaces 09-RESEARCH.md's tail -N ordering inference, which a concurrent Kanban/Telegram request could silently corrupt"
    - "Python probe scripts source probe_lib.sh's shared functions via `bash -c 'source probe_lib.sh; <func>'` subprocess calls rather than reimplementing preflight/postflight/flake_window/record_verdict in Python"
    - "multi-task runs share one LOG_WATERMARK across process boundaries by reading it back out of preflight.txt (written by an earlier task's own preflight() call), rather than re-running preflight per task -- keeps the flake window scoped to the whole run, not just one task's own burst"
    - "check both reasoning_content and reasoning field names on every response parse (wave 1's false-negative bug, restated here as a standing rule for this phase's remaining scripts)"

key-files:
  created:
    - phase-09/probe_prb03_oracle.sh
    - phase-09/probe_multiturn_growth.py
    - phase-09/PRB-03-ORACLE.md
    - phase-09/results/CURRENT_PRB03_RUN
    - phase-09/results/20260901T015706Z-prb03/ (prb03.tsv, multiturn.tsv, realtrace-capture.tsv, realtrace-t1..3.txt, sweep-lines.txt, sweep-ab-compare.txt, verdicts.tsv, 12 raw-prb03-*.json, 6 raw-multiturn-*.json, 6 msgs-*.json, pre/postflight + hash/pid snapshots)
  modified: []

key-decisions:
  - "Sweep A and sweep B ran back-to-back with an explicit agreement check (sweep-ab-compare.txt); since they agreed on all 6 arms with zero variance, the plan's conditional third sweep was never triggered -- the script supports it (would run sweep C and report all three) but this run didn't need it"
  - "Task 1's postflight() call was deliberately deferred to Task 2, since both tasks share one run directory and one continuous burst; Task 2 reads LOG_WATERMARK back out of Task 1's preflight.txt instead of calling preflight() a second time, so the flake window covers the entire 18-request run, not just Task 2's own 6"
  - "probe_multiturn_growth.py always attaches a reasoning_content key to the ON sequence's assistant messages, even on the (non-occurring, in this run) case of an empty trace -- matching Cline's literal wire shape rather than conditionally omitting the key"
  - "et-medium's -2 margin is reported as a token-margin fact only; whether enable_thinking is actually doing anything once reasoning_effort is already explicit is explicitly left to CFG-16 (Phase 10), not adjudicated here"

patterns-established:
  - "Six-arm effort sweep (not four) is now the Phase 9/10 standard shape, covering the 2026-09-01 alias design change (enable_thinking:true + reasoning_effort:medium shipped together, CFG-11)"

# Metrics
duration: ~25min
completed: 2026-09-01
---

# Phase 9 Plan 02: PRB-03 Oracle Re-measurement + Multi-turn Growth Summary

**Independently re-measured the six-arm prompt_tokens oracle (unspecified=13/medium=11/low=41/xhigh=53/et-true=53/et-medium=11) with per-request log-watermark attribution, found the shipped enable_thinking:true+medium combination inherits medium's fragile -2 margin unchanged rather than rescuing it, and ran two real >=3-turn thinking-on/off sequences that captured 2,497 characters of genuine xhigh reasoning traces for plan 09-03.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-09-01T01:57Z (Task 1 preflight)
- **Completed:** 2026-09-01T02:02Z (Task 2 postflight) + ORACLE.md write-up
- **Tasks:** 3/3
- **Files modified:** 2 scripts + 1 doc + 1 pointer file + 1 run directory (43 files total across 3 commits)

## Accomplishments

- `probe_prb03_oracle.sh`: six-arm sweep (`unspecified`, `medium`, `low`, `xhigh`, `et-true`, `et-medium`) run twice back-to-back at `:8011` direct, 12 requests total, each attributed to its own `Prefill started` log line by an explicit watermark (not `tail -N` ordering inference) -- the two bugs wave 1 hit (bash 3.2 no `declare -A`, litellm's `reasoning_content` field name) were both designed around from the start rather than rediscovered
- Sweep A and sweep B agreed bit-for-bit on all six arms with zero variance -- no third sweep needed, but the script supports one and would run it on any disagreement rather than silently picking a winner
- Fresh absolutes (13/11/41/53) match `09-RESEARCH.md`'s numbers exactly, and fresh deltas from `unspecified` (medium -2, low +28, xhigh +40) match both `09-RESEARCH.md` and the original `VALIDATED.md` bit-for-bit -- no divergence found, despite this plan not requiring one
- New finding (not in `09-RESEARCH.md`, since these arms didn't exist there): `et-true` (`enable_thinking:true` alone) reproduces `xhigh`'s absolute value and delta exactly, confirming VALIDATED.md sec4's claim; `et-medium` (the shipped combination) reproduces `medium`'s value and delta exactly, meaning `enable_thinking:true` added on top of an already-explicit `reasoning_effort:medium` changed nothing measurable -- **it does not rescue `medium`'s unusably tight margin**
- `probe_multiturn_growth.py`: two real 3-turn sequences at `:8011` (`xhigh` thinking-on with `reasoning_content` fed back every turn, thinking-off with nothing fed back), each turn attributed by the same watermark technique, reusing Task 1's `LOG_WATERMARK` (read back from `preflight.txt`) so the flake window spans the whole 18-request run
- ON sequence prompt_tokens grew 69->127->150 (+58, +23) while feeding back 591/917/989-char real `xhigh` reasoning traces each turn; OFF grew 29->360->681 (+331, +321) with long plain replies and no reasoning fed back. ON's smaller growth is directionally consistent with `09-RESEARCH.md`'s zero-cost replay finding, but **explicitly confounded**: ON's turns 2-3 came back with literally empty `content` (the 300-token completion budget was entirely consumed by `xhigh` reasoning, `finish_reason: length`), so ON's replies were far shorter than OFF's -- the growth gap mixes a reasoning-replay effect with a reply-length effect, and `PRB-03-ORACLE.md` states this loudly rather than presenting the numbers as a clean controlled experiment
- 2,497 characters of real `xhigh` reasoning captured to `realtrace-t1.txt`/`t2.txt`/`t3.txt`, closing `09-RESEARCH.md` open item #1 (its zero-cost finding used a ~1,380-char synthetic trace) -- available for plan 09-03's controlled replay probe
- `PRB-03-ORACLE.md` written self-contained for Phase 10: three-way absolute/delta comparison, the `et-medium`/`et-true` sec2b table, the multi-turn table with the confound stated explicitly, and an oracle declaration naming `low`/`xhigh` as the usable VRF-01 reach probes while ruling out both `medium` and `et-medium` with their stated -2 margin
- Stack unchanged throughout: three `com.ohama.*` PIDs (46573/75548/48525) and both config file hashes identical before/after across the whole 18-request run; `verify_config.sh` exits 0; `flake-count.txt` = 0 (CLEAN) the entire time; `cline` never invoked

## Task Commits

Each task was committed atomically:

1. **Task 1: Sweep six effort/enable_thinking arms with watermark-attributed prompt_tokens** - `3aad850` (feat)
2. **Task 2: Run two >=3-turn sequences (thinking on/off), capture real xhigh traces** - `8e2477b` (feat)
3. **Task 3: Write PRB-03-ORACLE.md** - `5b62f5c` (docs)

_No TDD tasks in this plan._

## Files Created/Modified

- `phase-09/probe_prb03_oracle.sh` - six-arm effort sweep (2x, A/B), watermark-per-request attribution, conditional third-sweep-on-mismatch logic (unused this run)
- `phase-09/probe_multiturn_growth.py` - two 3-turn sequences (ON xhigh w/ reasoning feedback, OFF), watermark attribution reusing Task 1's LOG_WATERMARK via bash-sourced probe_lib.sh functions, real trace capture
- `phase-09/PRB-03-ORACLE.md` - three-way comparison, sec2b shipped-combination table, multi-turn growth table + confound statement, sec4 oracle declaration, sec5 unexplained observations
- `phase-09/results/CURRENT_PRB03_RUN` - pointer to this plan's shared run directory
- `phase-09/results/20260901T015706Z-prb03/` - run directory: `prb03.tsv` (12 rows), `multiturn.tsv` (6 rows), `realtrace-capture.tsv` + 3 trace files, `sweep-lines.txt`, `sweep-ab-compare.txt`, `verdicts.tsv` (18 CONFIRMED, 0 flakes), 12 `raw-prb03-*.json`, 6 `raw-multiturn-*.json`, 6 `msgs-*.json`, pre/postflight snapshots

## Decisions Made

- Deferred `postflight()` from Task 1 to Task 2 since both tasks operate on one continuous run/burst; Task 2 reads `LOG_WATERMARK` back out of Task 1's `preflight.txt` rather than calling `preflight()` a second time, so the gpu-stream flake window covers the entire 18-request run rather than resetting mid-run.
- `probe_multiturn_growth.py` sources `probe_lib.sh`'s shared functions (`flake_window`, `record_verdict`, `postflight`) via `bash -c 'source probe_lib.sh; ...'` subprocess calls rather than reimplementing any safety-envelope logic in Python -- satisfies "do not reimplement" while still being a Python script.
- The sweep-A/sweep-B agreement check and conditional third sweep were implemented as specified even though they were not exercised (both sweeps agreed on all six arms) -- the plan explicitly required this path to exist for the case where they disagree, not just for the case observed.
- `et-medium`'s margin finding is reported strictly as a token-count fact in `PRB-03-ORACLE.md` sec2b; whether `enable_thinking` is actually being applied once `reasoning_effort` is already explicit is left entirely to CFG-16 (Phase 10, measured via the `reasoning` field through `:8011`/`:4000`), not inferred from token count here.

## Deviations from Plan

None — plan executed exactly as written. The plan's own 2026-09-01 patch (six arms instead of four, to cover the shipped `enable_thinking` combination) had already been applied to `09-02-PLAN.md` before this execution began (visible in the commit history as `ac6301e`, a prior plan-authoring commit); this execution followed the patched plan as given.

## Issues Encountered

None. Every request across both tasks succeeded on its first attempt (all 18 samples CONFIRMED, no `DISCARDED-FLAKE`/`PROVISIONAL-NEGATIVE`/`INDETERMINATE` verdicts, no retries consumed). The one genuinely surprising observation -- ON sequence turns 2-3 returning empty `content` because `xhigh` reasoning consumed the entire `max_tokens: 300` completion budget (`finish_reason: length`) -- was verified against the raw response bodies before being written into `PRB-03-ORACLE.md` sec3 as an explicit confound, not treated as a bug.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `PRB-03-ORACLE.md` names `low` (+28) and `xhigh` (+40) as the usable Phase 10 VRF-01 reach probes and rules out both `medium` and the shipped `et-medium` combination with their identical, stated -2 margin. Phase 10 should prove reach with `low`/`xhigh` (or `et-true`, which reproduces `xhigh`'s margin) and then deploy the alias at `medium`/`et-medium`.
- Real `xhigh` reasoning traces (2,497 chars total, `realtrace-t1.txt`/`t2.txt`/`t3.txt` in `phase-09/results/20260901T015706Z-prb03/`) are on disk and ready for plan 09-03's controlled single-shot replay probe, which is the decisive PRB-04 measurement (this plan's multi-turn numbers are corroborating only, explicitly confounded by reply-length differences).
- `et-medium`'s token-margin finding (identical to `medium` alone) is a fact Phase 10's CFG-16 measurement should be aware of going in: it means the token-count evidence alone cannot distinguish "enable_thinking is redundant once effort is explicit" from "enable_thinking is silently no-op'd" -- CFG-16's direct `reasoning`-field check is what will actually resolve that, not this document.
- No gate verdict was declared here, by design. PRB-03 is not a gate; the multi-turn growth numbers and the sec2b margin finding are hand-off inputs to plan 09-04's PRB-04 adjudication.
- Stack-unchanged mechanically confirmed across the whole 18-request run: `com.ohama.flashnext` (46573), `com.ohama.role-shim` (75548), `com.ohama.litellm` (48525) identical before/after; `litellm-config.yaml` and `providers.json` sha256 identical before/after; `verify_config.sh` exits 0; `cline` was never invoked.
- No blockers for 09-03/09-04.

---
*Phase: 09-preflight-gates*
*Completed: 2026-09-01*
