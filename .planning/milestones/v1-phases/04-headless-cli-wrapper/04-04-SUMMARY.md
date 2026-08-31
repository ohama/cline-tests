---
phase: 04-headless-cli-wrapper
plan: 04
subsystem: cli
tags: [bash, cline, sandbox, ndjson, seatbelt, headless, criterion-3, phase-close]

# Dependency graph
requires:
  - phase: 04-headless-cli-wrapper
    plan: "04-01"
    provides: "phase-04/classify_run.py's classify()/CLI contract and the frozen phase-04/fixtures/"
  - phase: 04-headless-cli-wrapper
    plan: "04-02"
    provides: "phase-04/run_headless.sh, the shipped wrapper, and its live-confirmed cwd fix for the inherited Phase 3 blocker"
  - phase: 04-headless-cli-wrapper
    plan: "04-03"
    provides: "phase-04/verify_sandbox_via_cline.sh's 8-rung verdict ladder, offline-proven against all 7 required NDJSON rows"
  - phase: 03-sandbox-and-repo-whitelist
    provides: "phase-03/sandbox/run_sandboxed.sh, verify_sandbox.sh, and docs/sandbox-whitelist.md's §7 open item this plan resolves"
provides:
  - "Criterion 3 (HLS-03) proven live: phase-04/results/20260829T215236Z-verify-cline-criterion3/ — VERDICT: DENIED, a real kernel EPERM on an out-of-whitelist read plus a successful in-whitelist canary read in the same run"
  - "docs/headless-wrapper.md: the Korean operator document (8 sections, house style), §4 stating the --auto-approve false safe-but-inert limitation as its own section with an explicit Phase 5 escalation requirement"
  - "docs/sandbox-whitelist.md §7 resolved: a 해결됨 (Phase 4) note naming docs/headless-wrapper.md and the real root cause (process cwd, not a missing punch-through), original narrative preserved"
  - "phase-04/results/20260829T215715Z-phase-close/: the phase-close gate sweep, all 8 items PASS, EXTRA_ALLOW_PATHS empty, service pids unchanged"
affects: [05-kanban-telegram-surfaces]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "In-whitelist scratch-file stdio capture, then copy-out-and-delete, for ANY script that wraps a sandboxed cline invocation — this plan found the same SIGABRT-on-unpunched-redirect bug (03-03 F8 / 03-04 / 04-02's already-known class) present in verify_sandbox_via_cline.sh itself, which had never been exercised against a real live invocation before this plan"
    - "A crash whose native stack trace shows only Node's own bootstrap frames (no cline/Bun frame) does not count toward an invocation budget, since no cline/Bun code executed — reused the 03-04/04-02 precedent a third time"

key-files:
  created:
    - docs/headless-wrapper.md
    - phase-04/results/20260829T215236Z-verify-cline-criterion3/ (criterion-3 live evidence, incl. README.md)
    - phase-04/results/20260829T215123Z-verify-cline-CRASHED-stdio-redirect/ (preserved crashed-attempt evidence, not counted toward the invocation budget)
    - phase-04/results/20260829T215715Z-phase-close/ (phase-close gate sweep, incl. README.md)
  modified:
    - phase-04/verify_sandbox_via_cline.sh (bug fix: stderr capture routed through an in-whitelist scratch file)
    - docs/sandbox-whitelist.md (§7 appended with 해결됨 (Phase 4) resolution note)

key-decisions:
  - "phase-04/verify_sandbox_via_cline.sh's live-run stderr redirect (`2>\"$OUT_DIR/stderr.log\"`) was a real, previously-latent bug: $OUT_DIR is outside SANDBOX_WORKDIR, so the sandboxed process's stderr fd pointed at an unpunched path and Node's own bootstrap SIGABRTed before any cline/Bun code ran. This script was authored and self-tested entirely offline in 04-03 (VERIFY_DRY_NDJSON never exercises this code path), so the bug survived until this plan's first live invocation. Fixed by reusing the exact validated pattern from run_headless.sh/03-04 rather than re-deriving a new one."
  - "The crashed first attempt (exit 134, no cline/Bun frame in the native stack trace, empty ndjson.log) does not count toward the plan's one-invocation budget, per the same precedent 03-04 and 04-02 already established for the identical failure class -- the corrected retry is the one counted, keeping the phase total at exactly 2 real cline invocations against a hard cap of 4."
  - "The criterion-3 evidence directory was renamed post-hoc from the script's default *-verify-cline naming to *-verify-cline-criterion3 so it matches the plan's own <verification> glob (phase-04/results/*-criterion3/verdict.txt) without requiring a second live invocation to get the naming right."

# Metrics
duration: ~9min (commit span, 818b4d7 to aa17e3d; excludes upfront context reading)
completed: 2026-08-30
---

# Phase 4 Plan 4: Criterion-3 Live Run, Operator Docs, Phase Close Summary

**Criterion 3 (HLS-03) proven with a real live `cline` run under the Seatbelt sandbox — VERDICT: DENIED, a kernel `EPERM` on `/Users/ohama/.zshrc` alongside a successful in-whitelist canary read in the same tool-call batch — closing Phase 4 with `docs/headless-wrapper.md` written and every standing gate green.**

## Performance

- **Duration:** ~9 min (commit-to-commit span, `818b4d7`→`aa17e3d`; excludes upfront research/context reading)
- **Started:** 2026-08-30T06:54:54+09:00 (Task 1 commit)
- **Completed:** 2026-08-30T06:58:41+09:00 (Task 3 commit)
- **Tasks:** 3/3
- **Files modified:** 1 script fixed (`phase-04/verify_sandbox_via_cline.sh`), 1 doc created (`docs/headless-wrapper.md`), 1 doc updated (`docs/sandbox-whitelist.md`), 3 evidence directories created under `phase-04/results/`

## Accomplishments
- **Criterion 3 proven live.** `bash phase-04/verify_sandbox_via_cline.sh --timeout 180` → exit 0, `VERDICT: DENIED`. The counted run's tool-call batch carries both signals in one `content_end` event: `{"query":"/Users/ohama/.zshrc","error":"Error reading file: EPERM: operation not permitted, stat '/Users/ohama/.zshrc'","success":false}` and `{"query":"./SANDBOX_INSIDE_CANARY.txt","result":"1 | INSIDE-SANDBOX-READABLE-OK","success":true}`. `outcome.json`'s primary outcome is `sandbox_denied`; the verdict ladder fired rung (g), the decisive positive. Evidence: `phase-04/results/20260829T215236Z-verify-cline-criterion3/` (README.md documents the exact rung, verbatim NDJSON, config-guard heal transcript, sandbox-gate PASS, and an explicit `EXTRA_ALLOW_PATHS`-untouched statement).
- **Found and fixed a real bug in the criterion-3 script itself before the counted run.** The first invocation crashed with `Abort trap: 6` (exit 134, native stack trace showing only `node::InitializeOncePerProcessInternal`/`node::Start`, `ndjson.log` empty) — `verify_sandbox_via_cline.sh` (authored offline in 04-03) redirected the sandboxed process's stderr straight to `$OUT_DIR/stderr.log`, a path outside `SANDBOX_WORKDIR`, the same SIGABRT-on-unpunched-redirect class already hit in 03-03 F8, 03-04, and 04-02. Fixed by reusing the validated in-whitelist-scratch-file-then-copy-out pattern verbatim. Per the established precedent, this crashed attempt (no cline/Bun code executed) does not count toward the invocation budget — the phase spent exactly 2 real `cline` invocations total (04-02: 1, 04-04: 1) against a hard cap of 4.
- **`docs/headless-wrapper.md` written** (Korean, house style matching `docs/infra-hardening.md`/`docs/sandbox-whitelist.md`, 8 numbered sections, 200 lines). §4 is its own heading stating the shipped wrapper is intentionally "안전하지만 무력(inert)" for tool-using prompts under `--auto-approve false` in 3.0.53, quotes the exact `Tool "<name>" requires approval in a TTY session` rejection, explains `--hook-command` exists only on `cline connect <channel>`, and hands Phase 5 an explicit escalation (accept `--auto-approve true` with the sandbox as sole boundary, or wait on an upstream feature — never a silent flip). §3's `context_overflow_terminal` operational rule is restated verbatim from `docs/32k-compaction-policy.md`, not re-derived. §5 quotes Task 1's live evidence directly. §6 documents the real root cause of the inherited Phase 3 blocker (process cwd, not a missing punch-through).
- **`docs/sandbox-whitelist.md` §7 resolved.** Appended (not replacing) a `해결됨 (Phase 4)` note naming `docs/headless-wrapper.md` and the real root cause; the original 미해결 narrative is left in place as history.
- **Phase-close gate sweep, all 8 items PASS.** `verify_sandbox.sh` (4/4 CRITERION, 16/16 CASES, CRASHED 0), `verify_no_regression.sh` (INF03:PASS), `verify_config.sh` (PASS, no heal needed this time), `pytest phase-04/tests/` (13/13), boundary assertion (`EXTRA_ALLOW_PATHS` empty, `git diff --stat phase-03/ phase-02/` empty, no stray `EXTRA_ALLOW_PATHS=` assignment anywhere in `phase-04/`), all 3 ROADMAP Phase 4 criteria re-asserted from on-disk evidence with zero new `cline` invocations, service pids unchanged (flashnext=46573, role-shim=75548, litellm=48525), `git status --porcelain` clean apart from two pre-existing untracked files unrelated to this plan. Evidence: `phase-04/results/20260829T215715Z-phase-close/README.md`.

## Task Commits

Each task was committed atomically:

1. **Task 1: One live criterion-3 run** - `818b4d7` (feat) — includes the stdio-redirect bugfix to `phase-04/verify_sandbox_via_cline.sh`
2. **Task 2: Write docs/headless-wrapper.md** - `d91733a` (docs)
3. **Task 3: Phase-close gate sweep** - `aa17e3d` (test)

_No separate plan-metadata commit was required beyond this SUMMARY/STATE update._

## Files Created/Modified
- `docs/headless-wrapper.md` - The Phase 4 Korean operator document: interface, 6-outcome table + operational rules, the inertness limitation as its own section, criterion-3 evidence, cwd-rule root cause, invocation-budget/config-drift protocol, Phase 5 handoff.
- `docs/sandbox-whitelist.md` - §7 appended with a `해결됨 (Phase 4)` resolution note pointing at `docs/headless-wrapper.md`.
- `phase-04/verify_sandbox_via_cline.sh` - Fixed the sandboxed process's stderr capture to route through an in-whitelist scratch file (was: direct redirect to an unpunched `$OUT_DIR` path, causing a Node bootstrap SIGABRT).
- `phase-04/results/20260829T215123Z-verify-cline-CRASHED-stdio-redirect/` - Preserved crashed-attempt evidence, excluded from the invocation budget.
- `phase-04/results/20260829T215236Z-verify-cline-criterion3/` - Criterion-3 live evidence (README.md, ndjson.log, outcome.json, verdict.txt, config guard transcripts, sandbox-gate transcript).
- `phase-04/results/20260829T215715Z-phase-close/` - Phase-close gate sweep transcripts and README.md.

## Decisions Made
- The crashed first `verify_sandbox_via_cline.sh` attempt does not count toward the invocation budget (no cline/Bun code executed) — third confirmation of the 03-04/04-02 precedent.
- Renamed the criterion-3 evidence directory post-hoc (`*-verify-cline` → `*-verify-cline-criterion3`) rather than spending a second live invocation to get the directory name to match the plan's `*-criterion3` glob.
- Fixed the newly-discovered stdio-redirect bug in `verify_sandbox_via_cline.sh` directly (Rule 1, auto-fix) rather than working around it, since the fix is a one-line-class change with an already-validated pattern and blocks the plan's sole purpose (the live criterion-3 run) if left unfixed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `phase-04/verify_sandbox_via_cline.sh`'s live-run stderr redirect crashed the sandboxed process before any cline/Bun code ran**
- **Found during:** Task 1 (first live invocation attempt)
- **Issue:** The script's live-run branch redirected the sandboxed `cline` process's stderr directly to `"$OUT_DIR/stderr.log"` — a path outside `$SANDBOX_WORKDIR`/`~/.cline`, i.e. outside the sandbox whitelist. The sandboxed process inherits that fd across `exec`, and Node's own bootstrap (`node::InitializeOncePerProcessInternal`) SIGABRTs (exit 134) the moment it touches the denied fd, before a single line of cline/Bun code runs. This is the exact, previously-documented failure class from 03-03 (F8), 03-04, and 04-02 — but this script itself, authored and self-tested entirely offline in 04-03, had never been exercised against a real live invocation and still carried the bug.
- **Fix:** Capture stderr to a scratch file inside `$SANDBOX_WORKDIR` (`.verify-cline-stderr-$$.log`), then copy the captured content into `$OUT_DIR/stderr.log` and delete the scratch copy — the exact pattern already validated in `phase-04/run_headless.sh` (04-02) and `phase-03`'s cline smoke test (03-04), reused verbatim rather than re-derived.
- **Files modified:** `phase-04/verify_sandbox_via_cline.sh`
- **Verification:** `bash -n` passes; the corrected retry produced a clean, non-crashed `DENIED` verdict (see Accomplishments above); TEST-ONLY invariants (`TEST-ONLY` present, `--auto-approve true` present x4, `--auto-approve false` absent) re-asserted after the amendment, both immediately after Task 1 and again at phase close (Task 3).
- **Committed in:** `818b4d7` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug)
**Impact on plan:** Necessary for correctness — without the fix, the plan's sole purpose (a live criterion-3 proof) was unreachable. No sandbox widening, no scope creep beyond the one script this plan's own action explicitly authorized amending ("this plan may amend `phase-04/verify_sandbox_via_cline.sh`").

## Issues Encountered
None beyond the bug documented above. The counted live run required exactly one config-guard heal cycle post-run (expected Pitfall 5 `providers.json` drift, healed by `apply_provider_config.sh`, re-verified PASS) — this is normal operating behavior per `docs/32k-compaction-policy.md`'s and `04-RESEARCH.md`'s own documented pattern, not treated as an issue.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- **Phase 4 is closed.** All three ROADMAP Phase 4 success criteria (HLS-01/02/03) are simultaneously true and evidenced on disk. `EXTRA_ALLOW_PATHS` is empty, `phase-03/`/`phase-02/` are byte-unchanged, and all inherited standing gates (Phase 1 config guard, Phase 2 no-regression, Phase 3 sandbox) still pass.
- **Phase 5 inherits an explicit, documented limitation, not a silent gap:** the shipped headless wrapper cannot perform tool-using work under `--auto-approve false` in cline 3.0.53. `docs/headless-wrapper.md` §4/§8 states this plainly and requires the decision (accept `--auto-approve true` with the sandbox as sole boundary, or await an upstream programmatic-approval feature) be escalated to a human before Phase 5 builds any surface that depends on unattended tool use.
- **Phase 5's launchd plists must set an explicit `WorkingDirectory`** inside `ALLOWED_REPOS.json` — `docs/headless-wrapper.md` §6 warns that omitting it will resurrect the exact Bun-bootstrap crash this phase diagnosed and fixed, and it will superficially resemble a sandbox tightening rather than a missing cwd.
- Two open research questions carried forward, non-blocking: the exact self-abort trigger threshold under `--auto-approve false`, and whether `run_start`'s absence from the NDJSON stream's first line is version-specific or environment-specific (`docs/headless-wrapper.md` §8, `04-RESEARCH.md` Open Questions 1/2).

---
*Phase: 04-headless-cli-wrapper*
*Completed: 2026-08-30*
