---
phase: 01-cline-config-compaction-verification
plan: 01
subsystem: infra
tags: [cline, providers.json, litellm, openai-compatible, config-management, bash, python3]

# Dependency graph
requires: []
provides:
  - "Idempotent phase-01/config/apply_provider_config.sh that writes and asserts the flashnext openai-compatible provider config in ~/.cline/data/settings/providers.json"
  - "phase-01/config/verify_config.sh pre-run guard (used by Plan 03's regression runner) that exits 1 with a named FAIL: field on any drift"
  - "phase-01/results/config-snapshot.txt documenting that cline config --json/cline config cannot be captured headlessly in this build, plus live-reproduced Pitfall 5 durability evidence"
  - "Live confirmation that ~/.cline/data/settings/providers.json's custom models[] field is not durable across arbitrary cline invocations in 3.0.53"
affects: [01-03, 01-04, 01-05, 01-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Config-writer scripts must assert-after-write and be idempotent, not just write-and-trust"
    - "Any script touching ~/.cline must re-verify immediately before use, never assume a prior write persisted"

key-files:
  created:
    - phase-01/config/apply_provider_config.sh
    - phase-01/config/verify_config.sh
    - phase-01/results/config-snapshot.txt
    - phase-01/config/backups/providers.json.* (multiple timestamped backups)
  modified:
    - "~/.cline/data/settings/providers.json (external, not tracked in this repo)"

key-decisions:
  - "Negative test for verify_config.sh builds its tampered fixture from a self-contained payload instead of reading the live providers.json, because the live file was observed mutating mid-task (Pitfall 5 firing in real time under wave-1 parallel execution)"
  - "cline config --json / cline config are not usable as a headless evidence source in this exact build (both require a real TTY); config-snapshot.txt documents this limitation rather than fabricating a JSON capture"

patterns-established:
  - "PROVIDERS_JSON env var override pattern: both apply_provider_config.sh and verify_config.sh honor $PROVIDERS_JSON so tests never touch the real file"

# Metrics
duration: 11min
completed: 2026-08-29
---

# Phase 1 Plan 1: Flashnext Provider Config Summary

**Idempotent `apply_provider_config.sh` + `verify_config.sh` guard pair that pin Cline's `openai-compatible` provider to `flashnext`/`http://localhost:4000/v1`/`contextWindow:32768`, and live-reproduced RESEARCH.md's Pitfall 5 (config field loss) three separate times during execution — confirming the guard is load-bearing, not precautionary.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-08-29T09:00:00Z (approx, per first backup timestamp)
- **Completed:** 2026-08-29T09:11:04Z
- **Tasks:** 3/3
- **Files modified:** 4 new files (2 scripts, 1 results file) + multiple timestamped config backups

## Accomplishments
- `phase-01/config/apply_provider_config.sh`: idempotent writer that backs up the existing `providers.json`, runs `CLINE_NO_AUTO_UPDATE=1 cline auth openai-compatible -b http://localhost:4000/v1 -k dummy -m flashnext`, merges in `models: [{id: flashnext, contextWindow: 32768, maxTokens: 4096}]`, and asserts the write took effect before exiting 0. Verified idempotent across many consecutive runs during this session (used repeatedly to recover from live Pitfall 5 events).
- `phase-01/config/verify_config.sh`: pre-run guard asserting baseUrl/model/models[]/contextWindow and the absence of `flashnext-codex` anywhere under `~/.cline`. Exits 0 with `OK: ...` plus the predicted compaction trigger (26542 at contextWindow=32768), or exits 1 with a `FAIL: <field> ... <observed>` message. Verified against both the real config and a self-contained tampered fixture (`contextWindow=128000` → correctly caught).
- `phase-01/results/config-snapshot.txt`: documents that `cline config --json` and `cline config` both fail with `error: interactive mode requires a TTY` in this headless execution environment (no machine-readable Cline-side config dump was obtainable this way), records the TUI-fallback attempt's visual confirmation (Settings screen showed `Provider: OpenAI Compatible`, `Model: flashnext`), and records three live Pitfall-5 durability failures with exact before/after evidence and successful recovery via `apply_provider_config.sh`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write apply_provider_config.sh** - `ea8f0e2` (feat)
2. **Task 2: Write verify_config.sh** - `4fa5ae7` (feat)
3. **Task 3: Capture cline config snapshot + durability check** - `6e5de54` (feat)

**Plan metadata:** committed alongside this summary (docs: complete flashnext provider config plan)

## Files Created/Modified
- `phase-01/config/apply_provider_config.sh` - idempotent flashnext provider config writer + post-write assertion
- `phase-01/config/verify_config.sh` - pre-run config guard, exits 0/1 with named failing field
- `phase-01/results/config-snapshot.txt` - Cline-side config evidence + Pitfall 5 durability log
- `phase-01/config/backups/providers.json.*` - timestamped pre-write backups (one per apply run; several were consumed recovering from live Pitfall 5 events)
- `~/.cline/data/settings/providers.json` (external, real file) - currently holds:
  ```json
  {
    "version": 1,
    "lastUsedProvider": "openai-compatible",
    "providers": {
      "cline": {
        "settings": { "provider": "cline", "model": "tencent/hy4-preview" },
        "updatedAt": "2026-08-29T06:28:53.425Z",
        "tokenSource": "manual"
      },
      "openai-compatible": {
        "settings": {
          "provider": "openai-compatible",
          "apiKey": "dummy",
          "model": "flashnext",
          "baseUrl": "http://localhost:4000/v1",
          "models": [
            { "id": "flashnext", "contextWindow": 32768, "maxTokens": 4096 }
          ]
        },
        "updatedAt": "2026-08-29T09:11:04.528Z",
        "tokenSource": "manual"
      }
    }
  }
  ```

## Decisions Made
- Built the `verify_config.sh` negative-test fixture from a self-contained JSON payload instead of copying the live `providers.json`, after the live file was observed changing mid-task (avoids racing a file that other wave-1 plans and this task's own `cline` invocations were actively mutating).
- Documented rather than worked around the finding that `cline config --json`/`cline config` require a real TTY in this build — inventing a fake capture would misrepresent what CFG verification can actually observe headlessly. This is now a known constraint for Plan 04/06's harness design.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed a `set -e` early-exit bug in verify_config.sh's own draft before it ever shipped**
- **Found during:** Task 2, immediately after first draft
- **Issue:** The script's `set -euo pipefail` would have caused `verify_config.sh` to exit immediately on any Python assertion failure, before the intended `if [ "$py_status" -ne 0 ]` handling ran (dead code) — meaning the script's exit code/behavior on failure was correct by accident of `set -e`, but the following `grep -rl flashnext-codex` cross-check would never run when the JSON assertions already failed, and more importantly a genuine JSON parse error would show a raw Python traceback instead of a clean FAIL: message in some paths.
- **Fix:** Wrapped the python3 heredoc invocation in `set +e` / `set -e` so its exit code is captured deliberately in `$py_status` and handled explicitly.
- **Files modified:** phase-01/config/verify_config.sh
- **Verification:** Re-ran both the positive (real config → OK, exit 0) and negative (tampered copy → FAIL: contextWindow ..., exit 1) test cases after the fix; both passed as specified in the plan's `<verify>` block.
- **Committed in:** 4fa5ae7 (Task 2 commit)

**2. [Rule 3 - Blocking] Re-applied config three separate times after live Pitfall 5 events during Tasks 2 and 3**
- **Found during:** Task 2 (before the positive verify_config.sh test) and Task 3 (twice: before capturing the config snapshot, and after the `cline config` invocation attempts)
- **Issue:** `~/.cline/data/settings/providers.json`'s custom `models[]` array (and thus the `contextWindow: 32768` override) was silently stripped by intervening `cline` invocations — both this task's own `cline config`/`cline config --json` attempts and, separately, a concurrent wave-1 sibling plan's `cline` invocations against the shared real `~/.cline`. This is exactly RESEARCH.md Pitfall 5, now reproduced live and repeatedly rather than theorized.
- **Fix:** Re-ran `phase-01/config/apply_provider_config.sh` each time it was detected (via `verify_config.sh` failing) and re-verified before proceeding. Each occurrence and recovery is logged with exact JSON before/after in `phase-01/results/config-snapshot.txt`.
- **Files modified:** none (external `~/.cline/data/settings/providers.json` only; recorded in phase-01/results/config-snapshot.txt)
- **Verification:** `verify_config.sh` exits 0 at the end of every task and at final plan-level verification.
- **Committed in:** N/A (external file state; the recovery script itself was already committed in Task 1/ea8f0e2)

---

**Total deviations:** 2 auto-fixed (1 blocking bug in verify_config.sh, 1 recurring blocking config-durability issue handled per-plan design intent)
**Impact on plan:** No scope creep. Both are exactly the kind of fragility the plan was written to guard against (Pitfall 5) and to harden the verifier itself against (the `set -e` fix). The plan's own success criteria already anticipated needing `verify_config.sh` before every real run; this session is the first live proof that anticipation was correct.

## Issues Encountered
- Wrapping `cline config --json` in a pty (`script -q /dev/null ...`) to work around the "requires a TTY" error instead launched Cline's full interactive TUI chat session rather than dumping JSON and exiting. The spawned TUI process and its `--cline-hub-daemon` child (bound to `127.0.0.1:25463`, a local ephemeral port unrelated to any protected service) could not be terminated from this environment (process-kill actions are blocked by this session's safety policy) and was left running idle, waiting for input. It is not one of the three protected launchd services and does not touch `com.ohama.flashnext`/`com.ohama.role-shim`/`com.ohama.litellm`. Documented in `phase-01/results/config-snapshot.txt`; the user may want to close this orphaned terminal session manually.
- Executing in a shared (non-worktree) git working directory during parallel wave-1 execution caused one git-index race: a sibling plan's untracked `phase-01/config/cline-invocation.env` file was accidentally staged into this plan's first `git add`/`git commit` pair (via `git add <specific files>` followed by a plain `git commit -m`, which commits the *whole* index, not just the paths just added). Caught immediately after the commit (before any other commit built on top), fixed via `git reset --soft HEAD~1` + `git restore --staged` + a clean re-commit with an explicit pathspec. From that point on, every commit in this plan used `git commit -m "..." -- <explicit files>` to prevent recurrence. No sibling plan's work was lost or altered — the file remained on disk, untracked, exactly as before.

## User Setup Required
None - no external service configuration required. Note: an orphaned interactive `cline` TUI process (and its `--cline-hub-daemon` child on `127.0.0.1:25463`) may still be running from this session's exploration of `cline config --json`'s TTY behavior; it can be closed manually if desired (e.g., `kill` from a terminal you control), but it does not affect any of the three protected launchd services.

## Next Phase Readiness
- CFG-01/CFG-02/CFG-07 are satisfied and independently re-appliable/re-verifiable via `apply_provider_config.sh`/`verify_config.sh`.
- Plan 03's `run_regression.sh` should call `phase-01/config/verify_config.sh` immediately before every real run, exactly as designed — this session proved the durability risk is real and frequent under concurrent `cline` usage, not a theoretical edge case.
- Open question carried forward to Plan 06 unchanged: whether `contextWindow: 32768` actually reaches Cline's live compaction check (trigger ≈26,542) is still unresolved — this plan could not settle it because `cline config --json` is not capturable headlessly in this build. Plan 06's regression test (grepping the `--json` NDJSON stream for `auto-compact*` notices) remains the only way to observe this directly.
- Blocker/concern for downstream plans: `providers.json`'s custom fields are not durable across arbitrary `cline` invocations (confirmed, not just researched). Any plan that invokes `cline` for any reason (even just `cline config`) before a regression run must re-verify config state immediately beforehand.

---
*Phase: 01-cline-config-compaction-verification*
*Completed: 2026-08-29*
