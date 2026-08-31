---
phase: 04-headless-cli-wrapper
plan: 01
subsystem: testing
tags: [ndjson, classifier, pytest, sandbox, bash, python]

# Dependency graph
requires:
  - phase: 01-headless-config-and-regression
    provides: "phase-01/parse_result.py's _error_event_message() flat-vs-nested tolerance pattern, plus real captured NDJSON (success and 32K-failure runs)"
  - phase: 03-sandbox-and-repo-whitelist
    provides: "phase-03/sandbox/config.env's config.env idiom, workspace/ALLOWED_REPOS.json, and phase-03/sandbox/assert_denied.sh's crash-vs-denial discriminator"
provides:
  - "phase-04/classify_run.py: pure classify() + CLI turning an NDJSON capture into a six-way outcome (success, sandbox_denied, context_overflow_terminal, tty_approval_rejected, run_aborted, crashed/other) with a documented precedence order and numeric exit-code contract"
  - "phase-04/config.env: single source of truth for phase-04 paths, deriving SANDBOX_WORKDIR from workspace/ALLOWED_REPOS.json (never hard-coded)"
  - "phase-04/fixtures/*.ndjson: five real-capture-mined NDJSON fixtures, one per outcome, frozen and read-only from here on"
  - "phase-04/tests/test_classify_run.py: pytest coverage for every false-pass confound named in the phase brief"
affects: [04-02-live-wrapper, 04-03-criterion3-verification, 04-04-phase-close]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "config.env idiom: PROJECT_ROOT derived from BASH_SOURCE, source-able from any cwd (copied from phase-03/sandbox/config.env)"
    - "Pure classify(events, ...) -> dataclass, zero file I/O / zero clock, thin CLI wrapper on top (copied from phase-01/parse_result.py)"
    - "Fixture-freeze convention: a fixtures/README.md records per-file provenance since NDJSON cannot carry comments"

key-files:
  created:
    - phase-04/config.env
    - phase-04/classify_run.py
    - phase-04/fixtures/README.md
    - phase-04/fixtures/success_no_tools.ndjson
    - phase-04/fixtures/sandbox_denied.ndjson
    - phase-04/fixtures/tty_approval_rejected.ndjson
    - phase-04/fixtures/context_overflow_32k.ndjson
    - phase-04/fixtures/crashed_truncated.ndjson
    - phase-04/tests/test_classify_run.py
  modified: []

key-decisions:
  - "sandbox_denied.ndjson deliberately carries three tool-call entries in one stream (denied read_files, denied run_commands, successful read_files on SANDBOX_INSIDE_CANARY.txt) so plan 04-03 gets both its negative and positive control from a single frozen fixture, per the plan's must-have."
  - "classify() computes every outcome's boolean signal independently (has_crash, has_denial, has_overflow, has_tty, has_aborted, has_success) and only then resolves the single primary outcome via the fixed precedence order — this guarantees 'signals' never loses information to precedence, which the deviation/verification steps explicitly required (crash-outranks-denial test)."
  - "success_no_tools.ndjson lines were surgically selected (hook_event, one usage event, one text content_end, the final run_result) from the 12-filler below_trigger run rather than copying the whole 296-line capture verbatim — keeps the fixture minimal per the task's own 'minimal clean run' instruction while every field name is still real, not invented."

# Metrics
duration: ~10min (git-log commit span; research reading time not included in this figure)
completed: 2026-08-29
---

# Phase 4 Plan 1: Headless CLI Wrapper - Offline Foundation Summary

**Six-way NDJSON outcome classifier (`phase-04/classify_run.py`) plus five real-capture-mined fixtures and 13 passing pytest discriminator tests, built with zero `cline` invocations.**

## Performance

- **Duration:** ~10 min (commit-to-commit span; excludes upfront research/context reading)
- **Started:** 2026-08-29 (session start)
- **Completed:** 2026-08-30T06:30:52+09:00 (last task commit)
- **Tasks:** 3/3
- **Files modified:** 9 created, 0 modified

## Accomplishments
- `phase-04/classify_run.py`: a pure `classify()` function that turns a parsed NDJSON event list into one of six primary outcomes (`success`, `sandbox_denied`, `context_overflow_terminal`, `tty_approval_rejected`, `run_aborted`, `crashed`, or `other`), with a documented precedence order (`crashed > sandbox_denied > context_overflow_terminal > tty_approval_rejected > run_aborted > success > other`) and a numeric CLI exit-code contract (0/2/3/4/5/6/7/1).
- Reused `phase-01/parse_result.py`'s `_error_event_message()` flat-vs-nested tolerance verbatim in logic, so the classifier catches the real, live-observed nested `event.error.message` shape, not just the hand-written flat shape.
- Five NDJSON fixtures under `phase-04/fixtures/`, every event shape mined from a real capture (`04-RESEARCH.md`'s live-reproduced Pitfall 2/3 transcripts, `phase-01/results/2026-08-29T094459Z-42449/ndjson.log`, `phase-01/tests/fixtures/outcome2_server400_nested_real.ndjson`) — none invented from scratch except the authored `crashed_truncated.ndjson` (which is explicitly meant to be synthetic: a truncated trailing line simulating a kill) and the `SANDBOX_INSIDE_CANARY.txt` positive-control payload.
- `phase-04/config.env` derives `SANDBOX_WORKDIR` from `workspace/ALLOWED_REPOS.json`'s first `repos[]` entry via `python3 -c` (no `jq` dependency), documents the Pitfall 1 cwd rule and the do-not-widen-the-sandbox rule in its header.
- 13 pytest tests in `phase-04/tests/test_classify_run.py` cover every false-pass confound the phase brief names: nested-vs-flat error shape, crash-outranks-denial (with denial signal surviving in `signals`), denial-vs-TTY-rejection non-cross-contamination, model-refusal-is-not-a-denial, mixed-stream non-suppression, `allowed_prefixes` → `denied_inside_allowlist`, and `run_result`-absence-alone → `crashed`.
- **Zero `cline` invocations made** — every fixture was mined from existing captures on disk; no live model call, no CLI reinstall, no `providers.json` drift risk.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create phase-04/config.env and the outcome fixtures** - `1fcf819` (feat)
2. **Task 2: Write phase-04/classify_run.py** - `16ebdf7` (feat)
3. **Task 3: pytest coverage for the classifier's discriminators** - `11e6d43` (test)

**Plan metadata:** (this commit, created after this summary)

## Files Created/Modified
- `phase-04/config.env` - Derives `PROJECT_ROOT`/`RESULTS_ROOT`/`SANDBOX_WORKDIR` (from `ALLOWED_REPOS.json`, never hard-coded); documents the Pitfall 1 cwd rule and the do-not-widen rule.
- `phase-04/classify_run.py` - Pure `classify()` + CLI; six-outcome precedence classifier; reuses Phase 1's nested-error tolerance; writes `outcome.json`/`outcome.md`.
- `phase-04/fixtures/README.md` - Per-fixture provenance (exact source file or `04-RESEARCH.md` section) and the frozen/read-only rule for wave 2.
- `phase-04/fixtures/success_no_tools.ndjson` - Minimal clean run mined from the real `finishReason:"completed"` capture.
- `phase-04/fixtures/sandbox_denied.ndjson` - Denied `$HOME/.zshrc` `read_files`/`run_commands` entries (verbatim from research) plus a successful `SANDBOX_INSIDE_CANARY.txt` positive control — the exact fixture plan 04-03 will consume read-only.
- `phase-04/fixtures/tty_approval_rejected.ndjson` - The object-shaped `output":{"error":"...requires approval in a TTY session"}` sequence ending in `run_aborted`/`finishReason:"aborted"`.
- `phase-04/fixtures/context_overflow_32k.ndjson` - Byte-for-byte copy of `phase-01/tests/fixtures/outcome2_server400_nested_real.ndjson` (real, live-captured nested `MAX_KV_SIZE` error).
- `phase-04/fixtures/crashed_truncated.ndjson` - Two valid lines then a truncated trailing line, no `run_result`.
- `phase-04/tests/test_classify_run.py` - 13 pytest tests covering every outcome plus all named discriminators.

## Decisions Made
- `sandbox_denied.ndjson` deliberately carries three tool-call entries in one stream (two denied, one successful canary read) so plan 04-03 gets both its negative and positive control from a single frozen fixture — matches the plan's explicit must-have and avoids any wave-2 write to `phase-04/fixtures/`.
- `classify()` computes every outcome's boolean signal independently, then resolves the single primary outcome via the fixed precedence order, so `signals` never loses information to precedence ordering (verified directly by the crash-outranks-denial test).
- `success_no_tools.ndjson` surgically selects four real lines from the 296-line below-trigger capture rather than copying the whole file, keeping the fixture "minimal" per the task instruction while every field name stays real.

## Deviations from Plan

None - plan executed exactly as written. All fixture sourcing rules (correct source file for `success_no_tools.ndjson`, verbatim research payload plus authored canary for `sandbox_denied.ndjson`) were followed as specified; no bugs found requiring auto-fix, no missing critical functionality discovered, no blockers hit, and no architectural changes needed.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `phase-04/fixtures/` is now frozen and read-only: plans 04-02 and 04-03 (wave 2) can both consume `sandbox_denied.ndjson` and the other fixtures without racing each other or needing to write to this directory.
- `phase-04/classify_run.py`'s `classify()` signature (`classify(events, cline_exit_code=None, stderr_text="", allowed_prefixes=None) -> Outcome`) is a stable contract wave-2 scripts can import directly (`sys.path.insert` + `import classify_run`, per `phase-04/tests/test_classify_run.py`'s own pattern).
- `phase-04/config.env` is ready to be sourced by both wave-2 scripts for a whitelist-derived `SANDBOX_WORKDIR` — no hard-coded path anywhere.
- No blockers. Zero `cline` invocations spent from the phase's 2-invocation budget; both remain available for plans 04-02/04-03.

---
*Phase: 04-headless-cli-wrapper*
*Completed: 2026-08-29*
