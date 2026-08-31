---
phase: 01-cline-config-compaction-verification
plan: 04
subsystem: testing
tags: [bash, python3, cline, regression-harness, textwrap, compaction, tdd-adjacent]

# Dependency graph
requires:
  - phase: 01-cline-config-compaction-verification
    provides: "01-01 apply_provider_config.sh/verify_config.sh, 01-02 cline-invocation.env/check_versions.sh, 01-03 parse_result.py classifier"
provides:
  - "phase-01/filler/gen_filler.py — deterministic, seeded, textwrap-wrapped filler file generator (RESEARCH.md Pitfall 3 avoidance)"
  - "12 phase-01/filler/wrapped_NN.txt files, byte-identical across regeneration, each 9,159-9,200 bytes with no line over 100 chars"
  - "phase-01/prompts/growth_prompt.txt — the one-file-at-a-time read_file prompt with {{FILE_LIST}} substitution point"
  - "phase-01/run_regression.sh — VER-01's single re-runnable regression command: 4 preflights (config/version/budget/reachability), timestamped results dir, RUN_DRY=1 offline mode"
  - "phase-01/tests/test_harness_dryrun.sh — offline proof the whole pipeline (preflights, results layout, log slicing, classifier invocation) works without any live model call"
  - "A live-reproduced, deterministic (not rare-race) finding that check_versions.sh's own drift-check invocation always strips providers.json, requiring a heal-and-reverify preflight step"
affects: [01-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "OBSERVED_ENV_PATH indirection: a script that must read another wave-2 plan's shared, in-progress output file takes the path as an overridable env var (default = the real shared path) rather than ever stubbing/restoring the real file, eliminating a TOCTOU race between concurrent plans"
    - "RESULTS_ROOT indirection: same pattern applied to the harness's own output location, so its offline test can contain throwaway results under an already-gitignored subdirectory instead of the real results tree"
    - "Heal-known-self-inflicted-drift preflight: when a script's OWN required preflight sequence deterministically causes a known, previously-diagnosed side effect (not an external/unexplained one), auto-heal via the existing idempotent writer and re-verify, rather than hard-abort every single run"
    - "bash 3.2 compatibility (macOS default /bin/bash ships no associative arrays) — parallel indexed arrays used instead of declare -A anywhere in this project's shell scripts"

key-files:
  created:
    - phase-01/filler/gen_filler.py
    - phase-01/filler/wrapped_01.txt … wrapped_12.txt
    - phase-01/prompts/growth_prompt.txt
    - phase-01/run_regression.sh
    - phase-01/tests/test_harness_dryrun.sh
  modified: []

key-decisions:
  - "EFFECTIVE_TRIGGER is always derived live from providers.json's contextWindow (int(cw*0.9*0.9)), never the 26542 literal — CLINE_PREDICTED_TRIGGER_TOKENS from cline-invocation.env/observed.env is a cross-check only; a NOTICE is printed if they disagree, and the derived value always wins"
  - "run_regression.sh never writes/creates/deletes phase-01/config/observed.env — read-only through OBSERVED_ENV_PATH, verified by both static grep and a live before/after shasum comparison in the dry-run test"
  - "-c is documented and used as cline's WORKING-DIRECTORY flag (verified from cline --help on 3.0.53), pointed at phase-01/filler/ for run-to-run determinism — NOT a config-isolation flag; --config/--data-dir are deliberately never passed since the whole phase's claim is that the real ~/.cline config takes effect"
  - "A non-zero cline exit from the real invocation is captured as data (cline_exit.txt) and the script continues to classification rather than treating it as a script failure, since a crash/timeout is itself one of the three possible verdicts"

patterns-established:
  - "Every headless script in phase-01/ sources cline-invocation.env and never hardcodes flags/versions/the compaction trigger"
  - "A dry-run/offline mode (RUN_DRY=1 + DRY_FIXTURE) is built into the real runner itself, not as a separate mock harness, so the exact preflight and results-layout code path that will run live is what gets proven offline"

# Metrics
duration: ~35min
completed: 2026-08-29
---

# Phase 1 Plan 04: Regression Harness (Filler Generator, Growth Prompt, Runner, Offline Test) Summary

**`run_regression.sh` — a single, re-runnable VER-01 command with four preflights (config guard, version guard, a live-`contextWindow`-derived max_tokens budget gate, and server reachability) that drives Cline's own `read_file` tool loop through 12 deterministic ~9KB filler files and hands both oracles to `parse_result.py`; proven end-to-end offline via `RUN_DRY=1` against all three classifier fixtures (exit 0/2/3) without a single live model call.**

## Performance

- **Duration:** ~35 min active work
- **Started:** 2026-08-29T18:15 (approx, first file write)
- **Completed:** 2026-08-29T18:30
- **Tasks:** 3/3
- **Files modified:** 16 created (2 scripts, 12 filler files, 1 prompt, 1 test script), 0 modified outside this plan's own files

## Accomplishments

- `phase-01/filler/gen_filler.py`: seeded (`random.Random(f"{seed}-{num}")`), stdlib-only generator that grows a word count until `textwrap.fill(width=100)` output lands in the 8,500-9,200 byte target band. Verified: 12 files, all 9,159-9,200 bytes, zero lines over 100 chars (well under the 120-char hard limit that trips Cline's tool-output truncator), byte-identical across repeated regeneration with the same seed, each self-naming its own filename+seed on line 1.
- `phase-01/prompts/growth_prompt.txt`: the verified RESEARCH.md Pattern 1 prompt — one-at-a-time `read_file` calls, one-word `"ok"` acknowledgements, a final `DONE`, and a `{{FILE_LIST}}` substitution placeholder.
- `phase-01/run_regression.sh`: the VER-01 deliverable. Preflight A (`verify_config.sh`) → Preflight B (`check_versions.sh`) → **Preflight A2** (new, see Deviations) → Preflight C (max_tokens budget, derived trigger) → Preflight D (server reachability) → timestamped results dir → prompt rendering → real/dry cline invocation → log slicing → post-run config re-check → classification via `parse_result.py --predicted-trigger "$EFFECTIVE_TRIGGER"`. Supports `RUN_DRY=1`, `DRY_FIXTURE`, `FILLER_COUNT`, `RUN_TIMEOUT`, `RESULTS_ROOT`, `OBSERVED_ENV_PATH`.
- `phase-01/tests/test_harness_dryrun.sh`: drove all three `parse_result.py` fixtures through the real runner (`RUN_DRY=1`), asserting exit codes 0/2/3, the full 8-artifact results-dir contract, a rendered prompt with exactly 12 absolute filler paths and no leftover placeholder, correct rejection of an over-budget `CLINE_OBSERVED_MAX_TOKENS` (computed from the live `contextWindow`, not a hardcoded number) printing all four relevant numbers, the exact required abort message when `OBSERVED_ENV_PATH` points at nothing, an `EFFECTIVE_TRIGGER` in `env.txt` matching an independently-computed `int(contextWindow*0.9*0.9)`, that `flashnext.err` was never opened for writing and never shrank, and that `phase-01/config/observed.env` (Plan 05's file) is byte-identical before and after the entire test run.

## Task Commits

Each task was committed atomically:

1. **Task 1: Generate deterministic, properly wrapped filler files** - `6721705` (feat)
2. **Task 2: Write run_regression.sh (preflight, capture, classify)** - `a1d4394` (feat)
3. **Task 3: Write the offline dry-run harness test** - `c529d9b` (test)

**Plan metadata:** committed alongside this summary (docs: complete regression harness plan)

## Files Created/Modified

- `phase-01/filler/gen_filler.py` - deterministic filler generator; `--count`/`--outdir`/`--seed` CLI, per-file byte/line/max-len/est-token summary table, raises if any line exceeds the 120-char hard limit
- `phase-01/filler/wrapped_01.txt` … `wrapped_12.txt` - 12 generated filler files, 9,159-9,200 bytes each, self-naming header line
- `phase-01/prompts/growth_prompt.txt` - one-at-a-time read_file prompt template with `{{FILE_LIST}}` placeholder
- `phase-01/run_regression.sh` - the regression runner (executable, `set -euo pipefail`)
- `phase-01/tests/test_harness_dryrun.sh` - the offline proof harness (executable)

## The Real cline Command Line the Runner Builds

```sh
CLINE_NO_AUTO_UPDATE=1 "$CLINE_BIN" -P openai-compatible -m flashnext --compaction agentic \
  --json --auto-approve true \
  -c "<repo_root>/phase-01/filler" -t "${RUN_TIMEOUT:-1800}" "$(cat "$RESULTS_DIR/prompt.txt")" \
  2>"$RESULTS_DIR/stderr.log" | tee "$RESULTS_DIR/ndjson.log"
```
`-c` is cline's **working-directory** flag (confirmed via `cline --help` on 3.0.53), deliberately pointed at `phase-01/filler/` so the run's workspace is a fixed, deterministic 12-file set instead of the whole (growing) repo — this is what makes VER-01 "re-runnable" rather than merely "runnable once." It is **not** a config-isolation flag; `--config`/`--data-dir` are deliberately never passed anywhere in Phase 1, since the phase's whole claim is that the real `~/.cline/data/settings/providers.json` takes effect.

## Results-Directory Contract

`phase-01/results/<UTC-timestamp>-<pid>/` always contains, whether real or `RUN_DRY=1`:
`prompt.txt`, `ndjson.log`, `flashnext_window.log`, `versions.txt`, `env.txt`, `providers.json`, `config_post_run.txt`, `cline_exit.txt`, `log_offset.txt`, `verdict.md` (written by `parse_result.py`), plus `stderr.log` on real runs only.

## Knobs Plan 06 Will Use

| Knob | Default | Purpose |
|---|---|---|
| `RUN_DRY` | (unset = real run) | `1` skips Preflight D and the real cline call, copying `DRY_FIXTURE` into `ndjson.log` instead |
| `DRY_FIXTURE` | `phase-01/tests/fixtures/outcome3_below_trigger.ndjson` | which classifier fixture to use under `RUN_DRY=1` |
| `FILLER_COUNT` | `12` | how many `wrapped_NN.txt` files to list in the rendered prompt |
| `RUN_TIMEOUT` | `1800` | seconds passed to cline's `-t` |
| `RESULTS_ROOT` | `phase-01/results` | parent dir for the timestamped results dir; tests point this at `phase-01/results/dryrun/` |
| `OBSERVED_ENV_PATH` | `phase-01/config/observed.env` | where `CLINE_OBSERVED_MAX_TOKENS` is sourced from (Plan 05's file); **read-only, never write here** |

## Derived-Trigger Rule

`EFFECTIVE_TRIGGER = int(contextWindow * 0.9 * 0.9)`, read live from `~/.cline/data/settings/providers.json` (or `$PROVIDERS_JSON` override) at the start of every run — never the `26542` literal baked into `cline-invocation.env`/`observed.env`, which are cross-check-only defaults for `contextWindow=32768`. If Plan 05's Branch B2 had lowered `contextWindow`, this derivation (not the literal) is what `parse_result.py --predicted-trigger` receives, and what Preflight C's budget arithmetic uses.

## Decisions Made

- `-c` is the working-directory flag, not a config flag — documented explicitly in the script and here to prevent a future reader from assuming it isolates config (it doesn't; `--config`/`--data-dir` do, and Phase 1 deliberately never passes them).
- `run_regression.sh` only ever reads `phase-01/config/observed.env` through the `OBSERVED_ENV_PATH` indirection; every test that needs to exercise Preflight C points that variable at a scratch file under `phase-01/tests/tmp/` instead, eliminating any stub/restore race with Plan 05 (confirmed running concurrently in this same wave, and confirmed to have published its real `observed.env` mid-session).
- The dry-run test's own "never write phase-01/config/observed.env" property is verified externally (via the plan's own `<verify>` grep) rather than as an internal self-check inside the script, because a self-referential grep for that exact literal pattern would always match the line performing the check (see Deviations).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] cline had auto-updated to 3.0.60 despite `CLINE_NO_AUTO_UPDATE=1`, blocking every preflight from passing**
- **Found during:** Task 2, first dry-run test attempt
- **Issue:** `check_versions.sh` correctly failed with `cline --version reports '3.0.60', expected '3.0.53'`. The installed npm package (`/opt/homebrew/lib/node_modules/cline/package.json`, symlink timestamp matching this session) had drifted from the pinned 3.0.53, exactly the class of drift `cline-invocation.env`'s own comments and `STATE.md`'s accumulated decisions warn about ("3.0.53 -> 3.0.60 drift was reproduced twice during Phase 1 research"). No `cline`/`kanban` processes were running at the time (confirmed via `ps aux`), so it was safe to act.
- **Fix:** `npm install -g cline@3.0.53`, confirmed no protected launchd services or active cline/kanban processes were touched (`com.ohama.flashnext`/`role-shim`/`litellm` PIDs unchanged throughout). Re-ran `check_versions.sh` - PASS.
- **Files modified:** none in this repo (global npm package only); no config/code change
- **Verification:** `check_versions.sh` PASS immediately after; re-confirmed multiple times over the rest of the session (versions never drifted again for the remainder of this plan)
- **Committed in:** N/A (external system state, not a repo file)

**2. [Rule 1 - Bug / Rule 2 - Missing Critical] `check_versions.sh`'s own drift-check probe deterministically strips `providers.json`, invalidating Preflight A's earlier pass before the real run ever happens**
- **Found during:** Task 2, dry-run testing immediately after the version fix above
- **Issue:** `check_versions.sh`'s "Check B: no drift across invocations" (Plan 02, by design) makes a real `CLINE_NO_AUTO_UPDATE=1 cline config --json` call to prove version pins survive an intervening invocation. Live-testing proved this call **deterministically** (confirmed via 3 repeated isolated trials, not a rare concurrency race) strips `providers.json`'s `models[]`/`contextWindow` override — RESEARCH.md Pitfall 5, now shown to be triggered by the harness's *own required preflight sequence*, not only by sibling-plan concurrency as Plan 01 had observed. Since the plan's original ordering was Preflight A (config verify) then Preflight B (version check) with nothing after, a real run would proceed against a silently-reverted 128k-fallback config immediately after Preflight B — exactly the false-verdict scenario Preflight A exists to prevent.
- **Fix:** Added **Preflight A2**: immediately after Preflight B, re-run `verify_config.sh`; if it fails, heal by calling the existing idempotent `apply_provider_config.sh` (Plan 01), then re-verify once more, aborting only if the config is still bad after healing (which would indicate something beyond this specific known pattern). This is intentionally narrower than "auto-fix any config problem silently" — it only heals the specific, previously-diagnosed, self-inflicted drift this script's own preflight sequence causes, and still hard-aborts on anything else.
- **Files modified:** `phase-01/run_regression.sh`
- **Verification:** Re-ran the full dry-run test suite repeatedly after the fix (`phase-01/tests/test_harness_dryrun.sh`, multiple full passes); `phase-01/config/verify_config.sh` passes at the point the real cline invocation would occur in every trial.
- **Committed in:** `a1d4394` (Task 2 commit)

**3. [Rule 2 - Missing Critical] `run_regression.sh` had no way to keep dry-run test output out of the real results tree**
- **Found during:** Task 3, writing the dry-run test's cleanup requirement ("write them under `phase-01/results/dryrun/`")
- **Issue:** `run_regression.sh`'s `RESULTS_DIR` was hardcoded under `phase-01/results/`, with no override — the dry-run test's own spec required its throwaway results to live under the already-gitignored `phase-01/results/dryrun/` instead.
- **Fix:** Added a `RESULTS_ROOT` env var (default `phase-01/results`, backward compatible) that the dry-run test sets to `phase-01/results/dryrun/`.
- **Files modified:** `phase-01/run_regression.sh`
- **Verification:** `test_harness_dryrun.sh`'s results all land under `phase-01/results/dryrun/`, confirmed empty (fully cleaned up) after the test exits.
- **Committed in:** `c529d9b` (Task 3 commit, bundled with the file that needed it)

**4. [Rule 1 - Bug] bash 3.2 (macOS default `/bin/bash`) has no associative arrays**
- **Found during:** Task 3, first dry-run test execution attempt
- **Issue:** `declare -A FIXTURE_EXPECTED_EXIT=(["path/with/slashes.ndjson"]=0 ...)` produced a cryptic `line 65: phase: unbound variable` error — bash 3.2 (this host's `/bin/bash`, confirmed via `bash --version`) does not support `declare -A` at all and mis-parses the associative-array literal syntax.
- **Fix:** Replaced with two parallel indexed arrays (`FIXTURES=(...)` / `EXPECTED_EXITS=(...)`), iterating by numeric index — a pattern already implicitly required by this project's other bash 3.2-compatible scripts.
- **Files modified:** `phase-01/tests/test_harness_dryrun.sh`
- **Verification:** Full test suite passes.
- **Committed in:** `c529d9b` (Task 3 commit)

**5. [Rule 1 - Bug] Self-referential false positives in two "must not reference this literal path" checks**
- **Found during:** Task 3, first two full test runs
- **Issue:** (a) An internal self-check grepping `test_harness_dryrun.sh`'s own source for the write/delete-against-`observed.env` pattern always matched the line performing the check itself (the check's own source contains both the forbidden keywords and the literal path in the same line). (b) A documentation comment reading "Never touches `phase-01/config/observed.env`" was itself caught by the same grep pattern, since `touch` is a substring of `touches`.
- **Fix:** (a) Removed the internal self-check entirely — that property is verified externally, by the plan's own `<verify>` block grepping the finished file, which cannot produce this self-referential false positive. (b) Reworded the comment to "Never modifies phase-01/config/observed.env".
- **Files modified:** `phase-01/tests/test_harness_dryrun.sh`
- **Verification:** `grep -cE '(rm|mv|cp|touch|>|>>)[^\n]*phase-01/config/observed\.env' phase-01/tests/test_harness_dryrun.sh` now returns `0`, matching the plan's required `<verify>` output; full test suite still PASS.
- **Committed in:** `c529d9b` (Task 3 commit)

---

**Total deviations:** 5 auto-fixed (1 blocking environment-state fix, 2 correctness bugs discovered by the harness's own offline testing, 1 missing test-isolation feature, 1 shell-portability bug + 2 self-referential grep false positives bundled together). No scope creep: every fix either restores a pinned invariant this whole phase depends on, closes a genuine false-verdict risk this plan's own tasks exist to prevent, or fixes the harness's own test tooling. The two most significant findings (auto-update drift, and check_versions.sh's own drift-inducing call) are exactly the kind of live-reproduced evidence RESEARCH.md's Pitfall 5 predicted and Plan 01 had already flagged as "not theoretical" — this plan reproduced it a fourth and fifth time, this time from the harness's own required preflight sequence rather than sibling-plan concurrency, and hardened against it structurally (heal-and-reverify) rather than just detecting it.

## Issues Encountered

- `phase-01/config/observed.env` did not exist yet when Task 2 testing began (Plan 05 was still running concurrently in this same wave) and appeared partway through this plan's execution with `CLINE_OBSERVED_MAX_TOKENS=2048`, `CLINE_MAX_TOKENS_BRANCH=A`. This plan never read from or depended on its exact contents beyond exercising the absent/present code paths against scratch stubs — confirmed byte-identical (via `shasum`) at the start and end of every test run in this plan, including the final full verification pass.
- `phase-01/results/max-tokens-probe/` (Plan 05's own results artifact) was visible throughout this plan's execution as evidence of Plan 05's concurrent activity; never read, modified, or referenced by any file in this plan.

## User Setup Required

None - no external service configuration required. The npm package downgrade (`cline@3.0.60` → `3.0.53`) was performed as an in-session auto-fix per Rule 3, not a manual step for the user.

## Next Phase Readiness

- **Plan 06 can run `bash phase-01/run_regression.sh` directly, unmodified**, with no env vars needed for a real run (all defaults are the real paths/values). It will: heal a `providers.json` drift caused by its own version-check preflight if one occurs (now expected, not exceptional), abort cleanly if `phase-01/config/observed.env` is ever missing/stale or the budget is blown, and produce a fully self-contained, timestamped evidence directory including the exact rendered prompt.
- **Before the live run**, Plan 06 should note: `check_versions.sh`'s Check B *will* strip `providers.json` on every single invocation in this environment (not a maybe) — this is now handled transparently by Preflight A2's heal-and-reverify step, but it means every real run does one extra `apply_provider_config.sh` write cycle mid-preflight. This is expected, logged as a `NOTICE`, and does not require any Plan 06 action.
- **Version drift risk remains live**: this plan found and fixed a real 3.0.53→3.0.60 auto-update in the shared environment mid-session, unrelated to any code this plan wrote. Plan 06 should run `bash phase-01/config/check_versions.sh` as its own first sanity step before the real regression run, exactly as `run_regression.sh` already does internally — if it has drifted again, `npm install -g cline@3.0.53` is the confirmed, safe recovery (no live cline/kanban process was ever found running when this fix was applied in this session; Plan 06 should re-confirm that with `ps aux` before repeating it).
- No blockers. The harness is outcome-neutral by design and construction (verified against all three `parse_result.py` fixture outcomes) and ready for the single live invocation Plan 06 is scoped to spend.

---
*Phase: 01-cline-config-compaction-verification*
*Completed: 2026-08-29*
