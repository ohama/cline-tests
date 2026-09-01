---
phase: 09-preflight-gates
plan: 01
subsystem: infra
tags: [litellm, mlx-server, bash, probe-harness, gate-verification, reasoning_effort, enable_thinking]

# Dependency graph
requires:
  - phase: 09-preflight-gates (RESEARCH)
    provides: literal probe commands (09-RESEARCH.md sec Q2, Q1, gpu-stream flake discriminator)
provides:
  - phase-09/probe_lib.sh -- reusable preflight/postflight safety envelope + flake discriminator + four-state verdict machine, shared by 09-02/09-03
  - phase-09/probe_prb01.sh -- fresh PRB-01 reproduction with negative control
  - phase-09/probe_prb02.sh -- fresh PRB-02 reproduction with not-rejected-vs-applied positive control
  - phase-09/results/<run>/RESULT.md -- fresh measurements for both probes, no gate verdict declared
affects: [09-02-PLAN, 09-03-PLAN, 09-04-PLAN, phase-10 (CFG-12)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "preflight/postflight safety envelope: snapshot service PIDs + config hashes before a probe burst, mechanically fail (non-zero exit) if either differs after"
    - "gpu-stream flake discriminator: scan flashnext.err from a log watermark for 'no Stream(gpu, 1)' before trusting a negative sample"
    - "four-state verdict machine (CONFIRMED / DISCARDED-FLAKE / PROVISIONAL-NEGATIVE -> CONFIRMED-NEGATIVE / INDETERMINATE) so a single flaky run can never produce a confirmed negative"
    - "positive/negative control pairing: every probe that could be confounded by 'this is already the default' gets a control that differs from the default"

key-files:
  created:
    - phase-09/probe_lib.sh
    - phase-09/probe_prb01.sh
    - phase-09/probe_prb02.sh
    - phase-09/results/CURRENT_PRB01_02_RUN
    - phase-09/results/20260901T014027Z-prb01-02/ (RESULT.md, prb01.tsv, prb02.tsv, verdicts.tsv, 7 raw-*.json, pre/postflight + hash/pid snapshots)
  modified: []

key-decisions:
  - "record_verdict's four states live in probe_lib.sh as a shared library, not duplicated per probe script, so 09-02/09-03 reuse the same anti-flake logic"
  - "flake_window is called once per probe burst against a single LOG_WATERMARK set at that script's own preflight, not per-request, to keep the discriminator simple and conservative (a flake anywhere since preflight marks the whole burst DIRTY, never CLEAN when it shouldn't be)"
  - "probe_prb02.sh calls preflight() again on top of probe_prb01.sh's already-completed preflight/postflight, because each script is a separate process and LOG_WATERMARK does not survive across invocations -- this also means the run directory's pids-before.txt/hashes-before.txt reflect the state immediately before PRB-02's own burst, not the very start of the session (values are identical either way since nothing ran in between)"
  - "scripts written for bash 3.2 (macOS's shipped /bin/bash, no homebrew bash present) -- no `declare -A` associative arrays; PRB-01's 4 fixed samples are driven by explicit function calls instead of a dict-keyed loop"

patterns-established:
  - "Every Phase 9 probe script: source probe_lib.sh -> preflight -> sequential wait_idle-gated requests -> flake_window -> record_verdict per sample -> postflight, writing raw bodies verbatim (not just parsed summaries) into the run dir"

# Metrics
duration: ~15min
completed: 2026-09-01
---

# Phase 9 Plan 01: Preflight Probe Safety Envelope + Fresh PRB-01/PRB-02 Reproduction Summary

**Built the shared preflight/postflight/flake-discriminator/four-state-verdict library and used it to independently re-measure both PRB-01 and PRB-02 fresh, finding a stronger PRB-01 discriminator than the research (unspecified now confirms empty, not just non-maximal) and fixing a real parsing bug in the PRB-02 positive control along the way.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-09-01T01:33Z (baseline capture)
- **Completed:** 2026-09-01T01:45Z
- **Tasks:** 3/3
- **Files modified:** 3 scripts + 1 pointer file + 1 run directory (19 files)

## Accomplishments

- `probe_lib.sh`: mechanical stack-unchanged enforcement (PID + config-hash diff, non-zero exit on drift), the gpu-stream flake discriminator, and a four-state anti-flake verdict machine (`CONFIRMED`, `DISCARDED-FLAKE`, `PROVISIONAL-NEGATIVE` -> `CONFIRMED-NEGATIVE`, `INDETERMINATE`) that makes a single flaky run structurally incapable of producing a confirmed negative
- Both negative selftests proved `postflight` actually fails non-zero on PID mutation and on config-hash mutation (not just documented — executed)
- PRB-01 reproduced fresh with an added negative control: `medium` -> 179-char non-empty `reasoning` (both samples), unspecified -> empty `reasoning` (both samples). This is a **cleaner** result than 09-RESEARCH.md's, which only showed medium was non-empty without confirming the default was empty by contrast
- PRB-02 reproduced fresh at both `:8011` (ROADMAP wording) and `:4000` (REQUIREMENTS wording) for `enable_thinking:false`, plus the `enable_thinking:true` positive control 09-RESEARCH.md flagged as an open risk but never ran. Result: `true` produced a non-empty `reasoning_content` (30 chars) where `false` and default both show none -- evidence the parameter is **applied**, not just tolerated
- All 7 raw response bodies retained verbatim on disk; all 4 verdict states present in the library; three PIDs and two config-file hashes identical before/after; `verify_config.sh` exits 0; `cline` never invoked

## Task Commits

Each task was committed atomically:

1. **Task 1: Build the probe safety envelope and flake discriminator** - `af7186c` (feat)
2. **Task 2: Reproduce PRB-01 — negative control added** - `90c3f0a` (feat)
3. **Task 3: Reproduce PRB-02 — not-rejected-vs-applied positive control** - `046cee0` (feat)

_No TDD tasks in this plan._

## Files Created/Modified

- `phase-09/probe_lib.sh` - preflight/postflight safety envelope, flake_window discriminator, record_verdict four-state machine
- `phase-09/probe_prb01.sh` - PRB-01 reproduction: reasoning_effort medium (x2) vs unspecified negative control (x2) at `:8011`
- `phase-09/probe_prb02.sh` - PRB-02 reproduction: enable_thinking false at `:8011` and `:4000`, plus true positive control at `:4000`
- `phase-09/results/CURRENT_PRB01_02_RUN` - pointer to this plan's shared run directory
- `phase-09/results/20260901T014027Z-prb01-02/` - run directory: `RESULT.md`, `prb01.tsv`, `prb02.tsv`, `verdicts.tsv`, `preflight.txt`/`postflight.txt`, `pids-before/after.txt`, `hashes-before/after.txt`, `flake-count.txt`, and 7 `raw-*.json` bodies

## Decisions Made

- Four-state verdict logic lives entirely in `probe_lib.sh` (not duplicated in each probe script) so plans 09-02/09-03 can source it unchanged.
- `flake_window` is called once per script invocation against that invocation's own `LOG_WATERMARK`, not per individual HTTP request — simpler and strictly conservative (a flake anywhere in the burst marks the whole burst DIRTY).
- `probe_prb02.sh` re-runs `preflight()` on the shared run directory even though `probe_prb01.sh` already ran preflight/postflight, because each script is a separate bash process and the exported `LOG_WATERMARK` does not survive across invocations. The re-snapshotted PIDs/hashes are identical to the original (nothing ran in between), so no information is lost.
- Scripts target bash 3.2 (this machine's only available `/bin/bash`, no homebrew bash installed) — no `declare -A`. PRB-01's four fixed samples are driven by four explicit function calls rather than an associative-array-keyed loop.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `declare -A` associative arrays are unavailable on this machine's bash**
- **Found during:** Task 2, first execution attempt of `probe_prb01.sh`
- **Issue:** `/bin/bash --version` on this macOS host is 3.2.57 (no homebrew bash present); `declare -A` doesn't exist in bash 3.2, and even the workaround attempt (`[medium-1]=medium`) triggered `medium: unbound variable` because bash 3.2 arithmetically evaluates unquoted compound-assignment subscripts
- **Fix:** Rewrote `probe_prb01.sh` to drive its four fixed samples via explicit function calls (`run_prb01_sample "medium-1" medium nonempty`, etc.) instead of associative-array-keyed loops. `probe_lib.sh` and `probe_prb02.sh` were written without associative arrays from the start.
- **Files modified:** `phase-09/probe_prb01.sh`
- **Verification:** `bash -n` clean; live run completed all 4 samples with correct CONFIRMED verdicts
- **Committed in:** `90c3f0a` (Task 2 commit)

**2. [Rule 1 - Bug] PRB-02 parser missed litellm's actual reasoning field name**
- **Found during:** Task 3, first execution of `probe_prb02.sh` — the `enable_thinking:true` positive control returned HTTP 200 but was recorded as `reasoning_nonempty=False`, producing a `PROVISIONAL-NEGATIVE` verdict that would have wrongly suggested the parameter is not applied
- **Issue:** litellm's `openai-compatible` transform (per 09-RESEARCH.md's own source trace) surfaces the reasoning text as a top-level `reasoning_content` field on the message, with `reasoning`/`reasoning_content` also echoed inside `provider_specific_fields` — not as a bare top-level `reasoning` field, which is how the direct `:8011` model server (correctly handled by `probe_prb01.sh`) returns it. The first parser version only checked `message.reasoning` and missed it.
- **Fix:** Extended the extractor in `parse_prb02_sample` to check, in order: `message.reasoning_content`, `message.reasoning`, `provider_specific_fields.reasoning_content`, `provider_specific_fields.reasoning` — taking the first non-empty value.
- **Files modified:** `phase-09/probe_prb02.sh`
- **Verification:** Re-parsed the actual raw response (`raw-prb02-4000-true.json`, `reasoning_content: "We need to respond to user \"hi"`, 30 chars); re-ran the full burst after the fix — all three PRB-02 samples now CONFIRMED, with the `true` control correctly showing `reasoning_nonempty=True`
- **Committed in:** `046cee0` (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — bugs found and fixed during execution, not scope changes)
**Impact on plan:** Both fixes were necessary for correctness of the measurements this plan exists to produce. Bug #2 in particular would have shipped an incorrect "not applied" reading into `RESULT.md` had it not been caught before the final run — no scope creep, no architectural change.

## Issues Encountered

- First `probe_prb02.sh` invocation crashed with `LOG_WATERMARK: unbound variable` inside the `RESULT.md` heredoc, because the script (before the fix) never called `preflight()` itself and relied on an environment variable exported by `probe_prb01.sh`'s separate, already-exited process. Fixed by adding an explicit `preflight "$RUN_DIR"` call at the top of `probe_prb02.sh`; this is now the established pattern (see Decisions above). Stale artifacts from the two crashed attempts (`prb02.tsv`, `RESULT.md`, `raw-prb02-*.json`, extra `verdicts.tsv` rows) were removed from the run directory before the final, clean run that is what's committed.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `probe_lib.sh` is ready for reuse by 09-02 and 09-03 without modification.
- Fresh PRB-01 evidence in `phase-09/results/20260901T014027Z-prb01-02/RESULT.md` and `prb01.tsv`: `medium` -> non-empty reasoning (179 chars, both samples), unspecified -> empty reasoning (both samples). All four samples CONFIRMED, CLEAN flake window, no retries needed.
- Fresh PRB-02 evidence in the same `RESULT.md` and `prb02.tsv`: `false` at both `:8011` and `:4000` returns HTTP 200 with empty reasoning (not rejected, indistinguishable from default); `true` at `:4000` returns HTTP 200 with non-empty `reasoning_content` (30 chars) — evidence of **application**, not mere tolerance. `RESULT.md`'s "not-rejected vs applied" section names **CFG-12** as the Phase 10 consumer of this reading.
- No gate verdict was declared by this plan, by design — comparison of these fresh numbers against 09-RESEARCH.md's prior figures, and the actual PRB-01/PRB-04 go/no-go call for Phase 10, is plan 09-04's job.
- Stack-unchanged mechanically confirmed: `com.ohama.flashnext` (46573), `com.ohama.role-shim` (75548), `com.ohama.litellm` (48525) identical before/after; `litellm-config.yaml` and `providers.json` sha256 identical before/after; `verify_config.sh` exits 0; `cline` was never invoked (recorded explicitly in `RESULT.md`).
- No blockers for 09-02/09-03.

---
*Phase: 09-preflight-gates*
*Completed: 2026-09-01*
