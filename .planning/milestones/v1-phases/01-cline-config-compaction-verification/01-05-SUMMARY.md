---
phase: 01-cline-config-compaction-verification
plan: 05
subsystem: infra
tags: [cline, max_tokens, litellm, flashnext, budget-verification, compaction, CFG-03]

# Dependency graph
requires:
  - phase: 01-cline-config-compaction-verification (Plan 01)
    provides: "apply_provider_config.sh / verify_config.sh (Pitfall 5 guard pair)"
  - phase: 01-cline-config-compaction-verification (Plan 02)
    provides: "phase-01/config/cline-invocation.env canonical invocation, CLINE_COMPACTION_TRIGGER_RATIO=0.81"
provides:
  - "phase-01/config/observed.env publishing CLINE_OBSERVED_MAX_TOKENS=2048 (measured, not assumed) for run_regression.sh's budget preflight"
  - "Live proof that predicted_trigger(26542) + observed_max_tokens(2048) = 28590 < 32768, so the compaction trigger gets a real chance to fire before the server's accept-time wall"
  - "docs/cline-max-tokens-findings.md: CFG-03 investigation record with verbatim server log evidence"
  - "Confirmation that providers.json's maxTokens field is not honored by cline@3.0.53 (root cause still unknown), reproducing 01-RESEARCH.md"
affects: [01-04, 01-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Server-side log slicing (byte offset before invocation, tail -c +N after) as the token oracle instead of trusting the client-reported NDJSON usage stream"
    - "Budget arithmetic (trigger + max_tokens < MAX_KV_SIZE) always recomputed from the live providers.json contextWindow, never reused as a literal"

key-files:
  created:
    - phase-01/config/observed.env
    - phase-01/results/max-tokens-probe/ (prompt.txt, ndjson.log, stderr.log, flashnext_window.log, observed_lines.txt, observed.txt)
    - docs/cline-max-tokens-findings.md
  modified: []

key-decisions:
  - "Branch A taken: OBSERVED_MAX=2048 < 6226 threshold, no mitigation needed, providers.json/apply_provider_config.sh/verify_config.sh left unmodified, REQUIREMENTS.md/ROADMAP.md left untouched (Branch B2 obligations do not apply)"
  - "This environment's Bash tool shell is zsh, not bash: unquoted $CLINE_COMMON_FLAGS does not word-split under zsh (unlike bash), collapsing into a single malformed -P argument on the first probe attempt. Fixed by wrapping the actual cline invocation in `bash -c '...'` to match the bash semantics the env file's own comments assume. No source file changed; this is an execution-environment note, not a script bug."

patterns-established:
  - "Any interactive step of this plan that invokes cline/env-file semantics from the orchestrating shell must be wrapped in `bash -c` when run under a zsh-based shell tool, to get bash word-splitting for space-separated flag variables like CLINE_COMMON_FLAGS."

# Metrics
duration: ~6min
completed: 2026-08-29
---

# Phase 1 Plan 05: Cline max_tokens Observation Summary

**Measured Cline's real wire `max_tokens` at 2048 (not the configured 4096) via a single minimal probe and flashnext.err's own "Generation queued" log line; the budget arithmetic 26542+2048=28590 < 32768 passes, so Branch A (no mitigation) was taken and no config/requirements/roadmap files needed to change.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-08-29T09:15:30Z (approx, first STATE.md read)
- **Completed:** 2026-08-29T09:20:20Z
- **Tasks:** 3/3
- **Files modified:** 3 created (observed.env, docs/cline-max-tokens-findings.md, phase-01/results/max-tokens-probe/ with 6 files inside)

## Accomplishments

- **Task 1:** Ran ONE minimal probe (`cline -P openai-compatible -m flashnext --compaction agentic --json -t 600 "Reply with exactly one word: OK"`) against the real, unisolated `~/.cline/data/settings/providers.json`, sliced `flashnext.err` from a pre-recorded byte offset, and extracted the verbatim server-side evidence line: `Generation queued: request=82eb9186e0 prompt_tokens=5495 max_tokens=2048 ...`. `OBSERVED_MAX=2048`.
- **Task 2:** Did the arithmetic from the live `contextWindow` (32768 → trigger 26542), confirmed `OBSERVED_MAX(2048) < 6226` (the threshold), took **Branch A** (no mitigation), and published `phase-01/config/observed.env` exporting `CLINE_OBSERVED_MAX_TOKENS=2048`, `CLINE_MAX_TOKENS_BRANCH=A`, `CLINE_CONFIGURED_CONTEXT_WINDOW=32768`, `CLINE_PREDICTED_TRIGGER_TOKENS=26542`, `CLINE_MAX_TOKENS_OBSERVED_AT=2026-08-29T09:17:58Z`. Verified the arithmetic (`26542+2048=28590 < 32768 → True`) and the trigger-matches-live-contextWindow cross-check (both print `True`).
- **Task 3:** Wrote `docs/cline-max-tokens-findings.md` (Korean prose, English commands/log lines) covering the problem statement, the observed value with pasted evidence, the `providers.json.maxTokens` non-enforcement finding, the Branch A decision, the budget table, and the exact re-probe command/trigger conditions.

## Task Commits

Each task was committed atomically:

1. **Task 1: Probe the wire value of max_tokens from the server's own log** - `de9c647` (feat)
2. **Task 2: Decide the mitigation, apply it, and publish observed.env** - `50b7d90` (feat)
3. **Task 3: Write docs/cline-max-tokens-findings.md** - `61659ac` (docs)

**Plan metadata:** committed alongside this summary (docs: complete max_tokens observation plan)

## Files Created/Modified

- `phase-01/config/observed.env` - Publishes `CLINE_OBSERVED_MAX_TOKENS=2048`, `CLINE_MAX_TOKENS_BRANCH=A`, `CLINE_CONFIGURED_CONTEXT_WINDOW=32768`, `CLINE_PREDICTED_TRIGGER_TOKENS=26542`, `CLINE_MAX_TOKENS_OBSERVED_AT`. Sole writer is this plan; written once, atomically (`> tmp && mv`).
- `phase-01/results/max-tokens-probe/{prompt.txt,ndjson.log,stderr.log,flashnext_window.log,observed_lines.txt,observed.txt}` - Raw probe evidence: the exact prompt sent, the full NDJSON stream, the sliced server log window, the extracted `Generation queued` line(s), and a plain-text summary of the observation.
- `docs/cline-max-tokens-findings.md` - CFG-03 investigation record: why the budget matters, the observed value with verbatim evidence, the `maxTokens` non-enforcement finding, the Branch A decision, the budget table, and re-probe conditions/command.
- `phase-01/config/apply_provider_config.sh`, `phase-01/config/verify_config.sh` - **Not modified.** Branch A does not require config or script changes; both were only re-run (not edited) as the standard post-cline-invocation durability guard.
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` - **Not modified**, confirmed by `git status --short` before final commit. Branch A does not trigger the B2 amendment obligation.

## Decisions Made

- **Branch A taken.** `OBSERVED_MAX=2048` is well under the `6226` threshold (`predicted_trigger 26542 + max_tokens < 32768`), so Cline's own internal `max_tokens` cap already leaves headroom for the compaction trigger to fire before the server's `MAX_KV_SIZE` wall. No mitigation was applied; `providers.json`, `apply_provider_config.sh`, and `verify_config.sh` are unchanged from Plan 01's state.
- **Did not chase the `providers.json.maxTokens` non-enforcement further.** The plan explicitly permits this under Branch A ("it is not blocking anything"). Configured value was `4096`; observed wire value was `2048` — confirms, does not newly discover, the 01-RESEARCH.md finding. Root cause remains unknown and is documented as such, not guessed at.
- **Residual risk recorded:** `2048` looks like a Cline-internal default tied to the installed binary version, not to `providers.json`. `check_versions.sh` (Plan 02, CFG-05/06) already guards against version drift, so a re-probe is only needed if that guard trips, if `providers.json` is re-applied, or if a live `MAX_KV_SIZE` 400 is observed — all three conditions are spelled out in the findings doc with the exact re-probe command.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] zsh word-splitting broke the first probe invocation**
- **Found during:** Task 1, first invocation attempt
- **Issue:** This session's Bash tool runs zsh, not bash. Under zsh, unquoted `$CLINE_COMMON_FLAGS` (a space-separated string: `-P openai-compatible -m flashnext --compaction agentic`) does NOT undergo word-splitting the way it does in bash — the entire string collapsed into a single argument to `-P`, producing `Unknown or disabled provider "openai-compatible -m flashnext --compaction agentic"` and an immediate `finishReason: "error"` with zero server-side evidence.
- **Fix:** Wrapped the actual `cline` invocation (offset capture + `cline` call) in `bash -c '...'`, matching the bash semantics that `cline-invocation.env`'s own comments and Plan 01/02's scripts already assume (`#!/usr/bin/env bash` shebangs). No source file was changed — this is purely an execution-shell adaptation for this session.
- **Files modified:** none (execution-only fix; no repo file changed)
- **Verification:** Re-run under `bash -c` produced a clean `exit=0`, a real 5495-token prompt, and the expected `Generation queued: ... max_tokens=2048` server log line.
- **Committed in:** de9c647 (Task 1 commit; noted in the commit message body)

**2. [Rule 3 - Blocking] Pitfall 5 (providers.json field loss) fired live again during Task 2's plan-level verification**
- **Found during:** Task 2, when re-running the overall plan `<verification>` block after Task 3's doc write
- **Issue:** `bash phase-01/config/verify_config.sh` failed with `FAIL: models[] expected length 1, observed None` — the custom `models[]` array (and thus `contextWindow: 32768`) had been silently stripped from `~/.cline/data/settings/providers.json` by an intervening `cline` invocation (consistent with Plan 01's live-reproduced Pitfall 5, occurring here almost certainly from Plan 04's concurrent wave-2 `cline` usage against the same shared `~/.cline`).
- **Fix:** Re-ran `phase-01/config/apply_provider_config.sh` (unmodified script; idempotent as designed), then re-ran `verify_config.sh`, which passed (`exit=0`) with `models[]`/`contextWindow` restored.
- **Files modified:** none in this repo (external `~/.cline/data/settings/providers.json` only, restored to the CFG-01/02/07 state established by Plan 01)
- **Verification:** `verify_config.sh` exits 0 immediately after the fix and again at final plan-level verification; no orphaned `cline` process remained after the `cline auth` call inside `apply_provider_config.sh` (`ps aux | grep -i cline` empty).
- **Committed in:** N/A (external file state only; the recovery scripts themselves were already committed by Plan 01)

---

**Total deviations:** 2 auto-fixed (both Rule 3 - blocking, both matching failure classes already documented by Plan 01/02: shell word-splitting and Pitfall 5 config-field loss)
**Impact on plan:** No scope creep. Both fixes were needed purely to get a valid measurement and to leave `providers.json` in the state this plan's own `verify_config.sh` and Plan 04's regression runner require. No plan file, script, or doc content changed as a result beyond what Task 1-3 already specified.

## Issues Encountered

- One orphaned `cline --cline-hub-daemon` process (pid 29476, bound to `127.0.0.1:25463`) was left running after Task 1's probe invocation exited. It was not one of the three protected launchd services (`com.ohama.flashnext`/`role-shim`/`litellm`), matched this session's `cwd`/start time exactly, and was killed cleanly (`kill 29476`) with no observable side effects. `ps aux | grep -i cline` was empty immediately after and again at the end of the plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `phase-01/config/observed.env` is ready for Plan 04's `run_regression.sh` to source (via its `OBSERVED_ENV_PATH` indirection) for preflight C's budget assertion. `CLINE_OBSERVED_MAX_TOKENS=2048` and `CLINE_PREDICTED_TRIGGER_TOKENS=26542` are both concrete, measured/derived, and cross-checked against the live `providers.json`.
- Branch A means Plan 06's regression test can proceed against the unmodified `contextWindow=32768` / trigger `26542` — no downstream gate needs to pick up a recomputed value, since none was recomputed.
- `providers.json`'s live state is confirmed correct at end-of-plan (`verify_config.sh` exit 0): `baseUrl=http://localhost:4000/v1`, `model=flashnext`, `contextWindow=32768`, no `flashnext-codex` alias anywhere under `~/.cline`.
- Open risk carried forward (documented, not resolved): `providers.json`'s `maxTokens` field is still not honored by cline@3.0.53 for reasons unknown. This is explicitly non-blocking under Branch A, but if a future plan needs to *raise* the effective output cap (e.g., for a task that legitimately needs long completions), this non-enforcement means `providers.json` cannot be used to do it — a different lever would be needed.
- No blockers for Plan 06. The one operational note to carry forward: Pitfall 5 (config field loss) fired live again during this plan's own execution, reinforcing Plan 01's guidance that `verify_config.sh` must be called immediately before every real regression run, not just once at setup time.

---
*Phase: 01-cline-config-compaction-verification*
*Completed: 2026-08-29*
