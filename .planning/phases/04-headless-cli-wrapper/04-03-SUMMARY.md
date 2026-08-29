---
phase: 04-headless-cli-wrapper
plan: 03
subsystem: testing
tags: [sandbox, seatbelt, cline, bash, python, ndjson, verdict-ladder]

# Dependency graph
requires:
  - phase: 04-headless-cli-wrapper
    plan: "04-01"
    provides: "phase-04/classify_run.py's classify()/CLI contract, phase-04/config.env's SANDBOX_WORKDIR derivation, and the frozen phase-04/fixtures/ (sandbox_denied.ndjson carrying both the denial pair and the SANDBOX_INSIDE_CANARY.txt positive control)"
  - phase: 03-sandbox-and-repo-whitelist
    provides: "phase-03/sandbox/run_sandboxed.sh's documented interface contract (docs/sandbox-whitelist.md §5), phase-03/sandbox/verify_sandbox.sh's standing gate, and assert_denied.sh's crash-vs-denial discriminator this plan's verdict ladder mirrors"
provides:
  - "phase-04/verify_sandbox_via_cline.sh: the criterion-3 (HLS-03) proof gate -- a TEST-ONLY, --auto-approve true, separate invocation from the shipped run_headless.sh, with an 8-rung verdict ladder computed entirely from classify_run.py's outcome.json"
  - "VERIFY_DRY_NDJSON=<path> offline self-test hook, proven against all seven required rows without spending any cline invocation"
affects: [04-04-phase-close]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "8-rung verdict ladder (crashed > 32K terminal > TTY-rejected > model-never-attempted-target > fail-open > control-read-missing > DENIED > other), each rung a distinct non-conflatable verdict, evaluated in a single ordered python3 block reading only outcome.json + the raw ndjson.log -- never a bare exit code"
    - "VERIFY_DRY_NDJSON env hook: swaps the live cline invocation for a canned NDJSON file, letting the verdict ladder be proven fully offline (mirrors phase-03's --negative-control pattern for self-testing a verifier)"
    - "Preflight A (config guard) is skipped entirely when VERIFY_DRY_NDJSON is set, because its heal path (apply_provider_config.sh) itself invokes a real `cline auth` call -- an offline self-test must not trigger a hidden live invocation via its own safety plumbing"

key-files:
  created:
    - phase-04/verify_sandbox_via_cline.sh
  modified: []

key-decisions:
  - "Preflight A/Step 8 (config guard verify->heal->re-verify) is gated on DRY_RUN, not just SKIP_SANDBOX_GATE, because apply_provider_config.sh's heal path runs `cline auth ...` -- a live cline call. Skipping this preflight in dry-run mode is what makes 'ZERO cline invocations' actually true for this plan's offline self-test, not just true by luck (the config happened to already be valid)."
  - "Rule (e) of the verdict ladder cross-checks the raw ndjson.log for the target file's own real first line (read directly by this unsandboxed script, since the verifier itself is not running under the sandbox) as an additional fail-open trip-wire, independent of the success:true field classify_run.py already tracks -- defense in depth against a denial verdict that a leaked-content stream would otherwise contradict."
  - "Row 7 (a completed run with zero tool attempts / model refusal) needed no new fixture: 04-01's success_no_tools.ndjson already is exactly that case (finishReason:completed, zero tool_attempts) and was consumed read-only, unmodified, straight from phase-04/fixtures/."

# Metrics
duration: ~15min
completed: 2026-08-30
---

# Phase 4 Plan 3: Headless CLI Wrapper - Criterion-3 Verification Gate Summary

**`phase-04/verify_sandbox_via_cline.sh`, a TEST-ONLY `--auto-approve true` criterion-3 proof gate whose 8-rung verdict ladder was proven correct over all seven required NDJSON rows entirely offline, with zero `cline` invocations spent.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-30 (session start)
- **Completed:** 2026-08-30T06:43:02+09:00 (Task 1 commit; Task 2 produced no file diff)
- **Tasks:** 2/2
- **Files modified:** 1 created, 0 modified

## Accomplishments
- `phase-04/verify_sandbox_via_cline.sh`: a re-runnable criterion-3 gate, banner-labeled `TEST-ONLY`, whose header explains why `--auto-approve true` is deliberate and non-default (mirrors `docs/sandbox-whitelist.md` §5's own worked example) and explicitly points back at `phase-04/run_headless.sh` as the shipped path it is not — without ever spelling out the literal `--auto-approve false` string itself, so a grep for that pin only ever matches the real wrapper.
- Asserts `EXTRA_ALLOW_PATHS` is empty (via `phase-03/sandbox/config.env`) before trusting anything else, and never sets it — the sandbox boundary is provably untouched by this plan.
- Preflight A (config guard) + Preflight B (`phase-03/sandbox/verify_sandbox.sh`, honoring `SKIP_SANDBOX_GATE=1`), a `--target`-outside-whitelist assertion, an in-sandbox positive-control write, and a real `cd` into `SANDBOX_WORKDIR` with a post-cd whitelist assertion (04-RESEARCH.md Pitfall 1's cwd fix, same discipline as the wrapper).
- An 8-rung verdict ladder implemented as a single ordered python3 block, reading only `classify_run.py`'s `outcome.json` plus the raw NDJSON text — never a bare exit code — that distinguishes: crashed, 32K terminal death, TTY-approval-gate rejection, the model never having attempted the target (refusal), a fail-open sandbox (target succeeded, or its real content leaked into the stream even if marked denied), a missing/failed in-whitelist control read, the decisive `DENIED` positive, and a residual `other` catch-all.
- **Offline self-test: all seven required rows produced the exact expected `VERDICT`/exit code**, using `VERIFY_DRY_NDJSON` plus `SKIP_SANDBOX_GATE=1` and read-only consumption of `phase-04/fixtures/`:

  | Row | Fixture | Verdict | Exit |
  |---|---|---|---|
  | 1 | `sandbox_denied.ndjson` (unmodified) | `DENIED` | 0 |
  | 2 | same, canary entry removed (`/tmp` copy) | `INCONCLUSIVE` | 2 |
  | 3 | same, target `read_files` entry's `success` flipped `true` (`/tmp` copy) | `NOT_DENIED` | 1 |
  | 4 | `tty_approval_rejected.ndjson` (unmodified) | `NOT_DENIED` | 1 |
  | 5 | `context_overflow_32k.ndjson` (unmodified) | `INCONCLUSIVE` | 2 |
  | 6 | `crashed_truncated.ndjson` (unmodified) | `INCONCLUSIVE` | 2 |
  | 7 | `success_no_tools.ndjson` (unmodified — already the zero-tool-attempts/model-refusal case) | `INCONCLUSIVE` | 2 |

  No row required amending the script — the verdict ladder was correct on first execution.
- **Zero `cline` invocations made.** All seven rows ran with `VERIFY_DRY_NDJSON` set; `SKIP_SANDBOX_GATE=1` skipped Preflight B; Preflight A's config guard (whose heal path is itself a real `cline auth` call) was structurally skipped in dry-run mode, so no code path in this plan's execution could reach a live `cline` call.
- `phase-04/fixtures/` left provably byte-unchanged: `git status --porcelain phase-04/fixtures/` and `git diff --stat phase-04/fixtures/` both empty after every row ran. The two negated variants (row 2, row 3) were built by `grep -v`/python-edit into a `mktemp -d "${TMPDIR:-/tmp}/..."` directory, never by editing the fixture in place, and were not committed.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write phase-04/verify_sandbox_via_cline.sh** - `ad8f100` (feat)
2. **Task 2: Offline self-test of the verdict logic against fixtures** - no commit (verification-only; all seven rows passed without amending the script, so no file changed — the transcript above and the checks below constitute this task's evidence)

**Plan metadata:** (this commit, created after this summary)

## Files Created/Modified
- `phase-04/verify_sandbox_via_cline.sh` - The criterion-3 proof gate: TEST-ONLY banner, `--auto-approve true` explained and justified, `EXTRA_ALLOW_PATHS`-empty assertion, cwd fix, `VERIFY_DRY_NDJSON` offline hook, 8-rung verdict ladder routed entirely through `classify_run.py`'s structured `outcome.json`.

## Decisions Made
- Preflight A (config guard) is skipped entirely in dry-run mode because its heal path calls real `cline auth` — see key-decisions above for the full rationale. This is the mechanism that makes "zero cline invocations" true by construction, not by coincidence of the environment's current config state.
- Rule (e) of the verdict ladder also greps the raw NDJSON text for the target file's own real first line (read directly by this unsandboxed verifier process) as an extra fail-open trip-wire, independent of `classify_run.py`'s `success` field.
- Row 7 of the offline self-test reused `phase-04/fixtures/success_no_tools.ndjson` unmodified rather than authoring a new `/tmp` variant, since it already is exactly the "completed run, zero tool attempts" case the row calls for.

## Deviations from Plan

None - plan executed exactly as written. Two issues were found and fixed during authoring itself (before Task 1's verification checks were run, so before any deviation classification applied — these are ordinary authoring bugs caught by the plan's own `<verify>` step, not post-hoc deviations):

- A literal `--auto-approve false` string appeared twice in the header's explanatory prose, which would have failed the plan's own `grep -c -- '--auto-approve false' ... == 0` verification requirement. Reworded to describe the shipped wrapper's pin without spelling out the flag+value pair literally, preserving the explanation's meaning.
- A single unescaped apostrophe inside a `#`-comment line within the verdict-ladder's heredoc body (`<<'PYEOF'`) caused `bash -n` to report a spurious unterminated-quote error, even though the heredoc's own delimiter is quoted. Confirmed via isolated reproduction that bash's parser scans heredoc body lines for quote characters even when the body itself is not expanded — a bare apostrophe on a comment line (not wrapped in a Python string) breaks this scan, while one embedded inside a Python double-quoted string does not. Reworded the one offending comment to avoid the apostrophe; no logic changed.

Both fixes are wording-only, made before the Task 1 commit, and required no fixture edits, no sandbox widening, and no `cline` invocation.

## Issues Encountered
None beyond the two authoring-time syntax/grep issues documented above, both resolved before committing Task 1.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `phase-04/verify_sandbox_via_cline.sh` is ready for plan 04-04 to invoke for real, exactly once, against the live sandbox — its verdict ladder has already been proven correct over every named confound (crash, 32K death, TTY rejection, model refusal, fail-open) offline, so the one live invocation only needs to answer "which rung does the real run land on," not "does the classifier work."
- `phase-04/fixtures/` remains frozen and provably untouched by this plan (git status/diff both empty) — plan 04-04 can continue to treat it as read-only evidence if needed.
- This plan's wave-2 sibling, `phase-04/run_headless.sh` (04-02), was observed running live and writing to `phase-04/results/` concurrently while this plan executed (e.g. `phase-04/results/20260829T214124Z-89595-headless/`) — confirming the two plans' file-ownership boundary (this plan owns only `verify_sandbox_via_cline.sh`; 04-02 owns `run_headless.sh` and `phase-04/results/`) held with no collision.
- No blockers. `cline` invocation budget for this plan: 0/0 spent (this plan was allotted zero by design) — the phase's real invocation(s) remain 04-02's and 04-04's to spend.

---
*Phase: 04-headless-cli-wrapper*
*Completed: 2026-08-30*
