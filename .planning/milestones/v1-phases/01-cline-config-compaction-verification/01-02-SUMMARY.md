---
phase: 01-cline-config-compaction-verification
plan: 02
subsystem: infra
tags: [cline, kanban, launchd, versioning, compaction, cli-flags]

# Dependency graph
requires: []
provides:
  - "phase-01/config/cline-invocation.env — canonical env file every other Phase 1 script and every Phase 5 launchd plist sources"
  - "phase-01/config/check_versions.sh — drift assertion (cline 3.0.53, kanban 0.1.70) + plist EnvironmentVariables scanner"
  - "docs/cline-config-pins.md — durable record of CFG-04/05/06 pins with cline --help evidence"
affects: [01-03, 01-04, 01-05, 01-06, phase-05-services]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single canonical .env file sourced by every headless cline/kanban invocation; no script hardcodes flags/versions directly"
    - "Drift-check script re-verifies version pins after an intervening real CLI invocation, not just once at the top"
    - "Plist compliance scanner (plutil -convert json | python3) designed to pass vacuously today and arm itself the moment matching plists exist"

key-files:
  created:
    - phase-01/config/cline-invocation.env
    - phase-01/config/check_versions.sh
    - docs/cline-config-pins.md
  modified: []

key-decisions:
  - "CFG-04 redefined: 'Compact Prompt' does not exist in the cline CLI (confirmed by exhaustive strings search of the installed binary + TUI menu inspection). Satisfied instead by pinning --compaction agentic explicitly."
  - "CLINE_COMPACTION_TRIGGER_RATIO=0.81 and CLINE_PREDICTED_TRIGGER_TOKENS=26542 documented as cross-check-only defaults; downstream plans must re-derive the trigger from the live contextWindow, not reuse the literal."
  - "Config isolation flags (--config, --data-dir) deliberately never passed in Phase 1 invocations, since the phase's claim is that the real ~/.cline/data/settings/providers.json takes effect."

patterns-established:
  - "Every cline/kanban invocation in phase-01/ sources cline-invocation.env and builds its flag string from CLINE_COMMON_FLAGS rather than repeating flags ad hoc."

# Metrics
duration: ~5min (task work; overlapped with parallel wave 1 plans 01-01/01-03 in the same repo)
completed: 2026-08-29
---

# Phase 1 Plan 02: Cline/Kanban Version and Invocation Pins Summary

**Pinned cline@3.0.53 and kanban@0.1.70 with a drift-reassertion script and a canonical env file that forces `CLINE_NO_AUTO_UPDATE=1` and explicit `--compaction agentic` into every invocation.**

## Performance

- **Duration:** ~5 min of active task work (concurrent wave-1 execution with plans 01-01 and 01-03 in the same working tree)
- **Started:** 2026-08-29T18:02 KST
- **Completed:** 2026-08-29T18:06 KST
- **Tasks:** 3/3
- **Files modified:** 3 created, 0 modified

## Accomplishments

- `phase-01/config/cline-invocation.env` created as the single sourceable definition of `CLINE_NO_AUTO_UPDATE=1`, the version pins, the provider/model pin, and `CLINE_COMPACTION_MODE=agentic` bundled into `CLINE_COMMON_FLAGS`.
- `phase-01/config/check_versions.sh` created and verified: confirms `cline --version`/`kanban --version` match pins both against the binary and the npm `package.json` manifest, re-confirms after an intervening real `cline config --json` invocation (the actual CFG-05 no-drift claim), and scans `~/Library/LaunchAgents/*.plist` for `cline`/`kanban` entries missing `CLINE_NO_AUTO_UPDATE=1` (vacuous pass today — verified against the real directory, which has zero matching plists; also verified against both a failing and a passing fixture plist via a `LAUNCHAGENTS_DIR` override).
- `docs/cline-config-pins.md` created recording all four pins, the real captured `cline --help` flag surface for 3.0.53, the CFG-04 redefinition (no "Compact Prompt" in the CLI) with decompiled-parser evidence, the copy-pasteable `EnvironmentVariables` plist fragment for Phase 5, and the real `check_versions.sh` output.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the canonical invocation env file** - `8a426e9` (feat) — see Deviations below for why this commit came after Task 2's in final history
2. **Task 2: Write check_versions.sh (drift assertion + plist scanner)** - `3d23861` (feat)
3. **Task 3: Record the pins and the Phase 5 plist snippet in docs/cline-config-pins.md** - `bbf888c` (docs)

No separate plan-metadata commit was made beyond this SUMMARY/STATE update commit (see final_commit step).

## Files Created/Modified

- `phase-01/config/cline-invocation.env` - Canonical env file: `CLINE_NO_AUTO_UPDATE=1`, `CLINE_PINNED_VERSION=3.0.53`, `KANBAN_PINNED_VERSION=0.1.70`, `CLINE_PROVIDER=openai-compatible`, `CLINE_MODEL=flashnext`, `CLINE_COMPACTION_MODE=agentic`, `CLINE_COMPACTION_TRIGGER_RATIO=0.81`, `CLINE_PREDICTED_TRIGGER_TOKENS=26542` (cross-check only), `CLINE_COMMON_FLAGS`.
- `phase-01/config/check_versions.sh` - Executable `set -euo pipefail` script; three checks (version pins, no-drift-across-invocations, plist scan); prints `OK:`/`FAIL:` lines and a final `check_versions: PASS`/`FAIL (<n>)` summary; supports `LAUNCHAGENTS_DIR` override for testing.
- `docs/cline-config-pins.md` - Korean-language record of the four pins, verified CLI flag surface, CFG-04 redefinition rationale, Phase 5 plist snippet, drift-invalidation note, and real `check_versions.sh` output.

## Decisions Made

- CFG-04 is satisfied by explicit `--compaction agentic` pinning rather than a "Compact Prompt" toggle, because the latter does not exist anywhere in the installed CLI binary (confirmed by exhaustive `strings` search plus TUI settings menu inspection during Phase 1 research — see `01-RESEARCH.md` Pitfall 6). This is a redefinition, not a workaround: CFG-04's underlying intent (compaction is armed and its mode is not left to an implicit default) is fully met.
- `CLINE_PREDICTED_TRIGGER_TOKENS=26542` is documented explicitly as a cross-check-only value, not the authority, because Plan 05's Branch B2 may change `contextWindow`, which would silently invalidate a hardcoded literal. Downstream scripts must derive the trigger as `int(contextWindow * CLINE_COMPACTION_TRIGGER_RATIO)`.
- `--config`/`--data-dir` are named in the env file's comments as flags Phase 1 deliberately never passes, since isolating config would defeat the phase's purpose of verifying the real `~/.cline` state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Git race with concurrent wave-1 agent swept Task 1's file into a different plan's commit**
- **Found during:** Task 1 (Create the canonical invocation env file), immediately after staging
- **Issue:** This plan runs in Wave 1 in parallel with 01-01 and 01-03 against the same working tree. Between `git add phase-01/config/cline-invocation.env` and the intended `git commit`, the concurrently running 01-01 agent executed its own `git commit`, which (due to `cline-invocation.env` already being staged in the shared index) swept the file into commit `7e1a202` ("feat(01-01): write idempotent flashnext provider config applier") instead of a 01-02 commit. That commit was later superseded (rebased/amended by 01-01's own subsequent work) and `cline-invocation.env` reverted to untracked, with its content on disk unchanged and verified byte-identical throughout.
- **Fix:** Did not rewrite any git history (forbidden — destructive, and risky against a concurrently-running agent's in-progress commits). Instead, once the file was confirmed untracked again with correct, verified content, staged and committed it cleanly under this plan as `8a426e9` ("feat(01-02): create canonical cline/kanban invocation env file"). For Tasks 2 and 3, minimized the add-then-commit window to avoid recurrence; no further collisions occurred.
- **Files modified:** `phase-01/config/cline-invocation.env` (content unchanged from original Task 1 write throughout)
- **Verification:** `git show HEAD:phase-01/config/cline-invocation.env | diff - phase-01/config/cline-invocation.env` confirmed byte-identical before the corrective commit; `sh -n`/`bash -n` and the full sourcing verification (Task 1's `<verify>` block) passed against the final committed version.
- **Committed in:** `8a426e9`

**2. [Rule 1 - Bug] Python f-string in plist scanner used an invalid backslash-in-expression construct**
- **Found during:** Task 2 (Write check_versions.sh), first verification run
- **Issue:** The embedded `python3 -c` snippet used `f"{label}\t{\"PASS\" if ok else \"FAIL\"}\t{val!r}"`, which is a `SyntaxError` under the Python version installed on this host (`\"` inside an f-string expression is not permitted pre-3.12-style f-strings). Every plist in the real (populated) `~/Library/LaunchAgents/` triggered this error, which was silently swallowed by the `|| true` guard and produced no scan output for any plist — Check C's plist detection logic was effectively dead code, masked by the vacuous-pass fallback.
- **Fix:** Rewrote the print statement using plain string concatenation (`label + "\t" + status + "\t" + repr(val)`) instead of an f-string with embedded quotes.
- **Files modified:** `phase-01/config/check_versions.sh`
- **Verification:** Re-ran against the real `~/Library/LaunchAgents/` (no syntax errors, correct vacuous-pass line since no cline/kanban plist exists there) and against two fixture plists in the scratchpad directory — one missing `CLINE_NO_AUTO_UPDATE` (FAIL, exit 1) and one carrying it (PASS, exit 0).
- **Committed in:** `3d23861` (fixed before the task commit was made; not a separate commit)

---

**Total deviations:** 2 auto-fixed (1 blocking/git-race, 1 bug)
**Impact on plan:** Both fixes were necessary for correctness (Check C would otherwise have been silently non-functional against the real LaunchAgents directory) and for proper commit attribution. No scope creep — final file contents match the plan's `<action>` specifications exactly.

## Issues Encountered

- The real `~/Library/LaunchAgents/` directory contains multiple existing plists unrelated to this project (other `com.ohama.*` and system plists); none reference `cline` or `kanban`, so Check C's real-directory run is a genuine vacuous pass, not an untested code path — confirmed via the separate fixture-plist tests described above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `phase-01/config/cline-invocation.env` is ready for every other Phase 1 script (`apply_provider_config.sh` from 01-01, the regression harness from 01-04, the observed-config work in 01-05, the verdict classifier in 01-03/01-06) to source instead of hardcoding flags.
- `phase-01/config/check_versions.sh` is ready to be invoked as a pre-flight guard before the regression test in 01-04/01-06 runs, to catch any auto-update drift before trusting the compaction verdict.
- `docs/cline-config-pins.md` gives Phase 5 the exact `EnvironmentVariables` plist fragment to copy when the Kanban/Telegram/headless launchd services are built.
- No blockers for downstream Phase 1 plans. One note: `check_versions.sh`'s Check C is currently a vacuous pass in this environment (no cline/kanban plist exists yet) — this is expected and by design, not a gap; it is exercised end-to-end via the fixture-plist tests documented above, and will start asserting for real once Phase 5 creates launchd plists.

---
*Phase: 01-cline-config-compaction-verification*
*Completed: 2026-08-29*
