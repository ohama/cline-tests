---
phase: 03-sandbox-repo-whitelist
plan: 04
subsystem: infra
tags: [sandbox-exec, seatbelt, macos, cline, bun, whitelist, docs]

# Dependency graph
requires:
  - phase: 03-sandbox-repo-whitelist (plan 03-01, wave 1)
    provides: "workspace/ALLOWED_REPOS.json, gen_sandbox_profile.py, run_sandboxed.sh"
  - phase: 03-sandbox-repo-whitelist (plan 03-03, wave 2)
    provides: "phase-03/sandbox/verify_sandbox.sh — the standing gate this plan calls before and after the cline smoke test"
  - phase: 01-cline-config-compaction-verification
    provides: "phase-01/config/cline-invocation.env (reinstall-chaining pattern), verify_config.sh/apply_provider_config.sh (config guard + heal path), check_versions.sh (drift evidence)"
provides:
  - "phase-03/results/<ts>-cline-smoke/ — the one budgeted real cline invocation under the sandbox, verdict (C) BLOCKED-NEEDS-HUMAN, full evidence"
  - "docs/sandbox-whitelist.md — Phase 3's shipped-state record: architecture, scope limitation, Phase 4 interface contract, criterion mapping, cline smoke-test finding"
  - "phase-03/results/<ts>-phase-close/ — all six phase-close gates green simultaneously, service pids unchanged"
affects: [04-headless-wrapper (docs/sandbox-whitelist.md §5 is its interface contract; §7 is its open item to resolve before trusting cline under this sandbox), 05-kanban-telegram, 06-network-exposure, 07-cline-bench]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "In-whitelist temp-file output capture (workspace/scratch-repo/) instead of direct redirection to a non-punched-through path, for any sandboxed process whose own stdio fd must be a regular file — generalizes 03-03's F8 pipe-capture fix to the real cline/Bun binary"
    - "Static strings(1) inspection of the installed binary as a zero-cost diagnostic before spending an additional live invocation"

key-files:
  created:
    - docs/sandbox-whitelist.md
    - phase-03/results/20260829T202633Z-pre-cline/
    - phase-03/results/20260829T202633Z-cline-smoke/
    - phase-03/results/20260829T203455Z-phase-close/
  modified: []

key-decisions:
  - "cline smoke test verdict: (C) BLOCKED-NEEDS-HUMAN. Real cline --version under run_sandboxed.sh exits 1 with a generic, path-less Bun runtime error ('An unknown error occurred (Unexpected)'), confirmed by static strings(1) inspection to be Bun's own startup catch-all, not a message naming any specific Cline-owned directory. Since (B) requires a permission error naming a specific candidate directory and this gives none, and (A) requires exit 0/'3.0.53', the plan's own catch-all definition of (C) applies. EXTRA_ALLOW_PATHS left unchanged (still empty) — widening was deliberately NOT taken, handed to Phase 4 as a documented open item."
  - "The plan's literal invocation form (stdout/stderr redirected straight to a phase-03/results/ path) crashed with SIGABRT inside Node's own process bootstrap before any cline/Bun code ran — same root cause as 03-03's F8 finding. Classified as Rule 3 (blocking harness bug, not a sandbox/cline signal) and fixed by redirecting to an in-whitelist path (workspace/scratch-repo/) instead, then copying into the results dir afterward. This crashed attempt is NOT counted toward the phase's 'exactly one real cline invocation' budget, since no cline/Bun code executed before the crash."
  - "docs/sandbox-whitelist.md written in Korean matching docs/infra-hardening.md's house style, with the (allow default)+$HOME-scope limitation as its own numbered section (§3, not a footnote) and a copy-pasteable Phase 4 interface contract (§5: run_sandboxed.sh invocation form, verify_sandbox.sh exit contract, EXTRA_ALLOW_PATHS as the sole widening point)."

patterns-established:
  - "Phase-close re-verification pattern (all N gates in one sitting, cross-checked pids) reused unchanged from Phase 2's 02-04 precedent, this time across six gates instead of Phase 2's three."

# Metrics
duration: ~12min
completed: 2026-08-30
---

# Phase 3 Plan 04: cline Smoke Test + docs/sandbox-whitelist.md + Phase-Close Summary

**Answered 03-RESEARCH.md Open Question 1 with exactly one real `cline` invocation under the sandbox (verdict C — a generic, path-less Bun startup error, not attributable to any bounded candidate directory), wrote `docs/sandbox-whitelist.md` as Phase 3's shipped-state record, and closed the phase with all six re-verification gates green and zero service disruption.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-08-30T05:26:33+09:00 (pre-flight `verify_sandbox.sh` before the cline call)
- **Completed:** 2026-08-30T05:36:15+09:00 (last task commit `510cca2`)
- **Tasks:** 3/3
- **Files modified:** 1 doc created + 3 results directories (0 code files touched — no sandbox artifact changed)

## Accomplishments
- Ran the phase's single budgeted `cline` invocation under `run_sandboxed.sh`: reinstall-then-launch chained, `cline --version` exits 1 with a generic Bun runtime error (`error: An unknown error occurred (Unexpected)`), confirmed via zero-cost `strings -a` inspection of the installed `.cline` binary to be Bun's own startup catch-all, not a path-naming permission error — classified (C) per the plan's own catch-all rule, no `EXTRA_ALLOW_PATHS` change made
- Diagnosed and fixed (Rule 3) a harness plumbing crash on the first attempt: the plan's literal output-redirection form crashed Node's own process bootstrap with SIGABRT before any cline/Bun code ran — same root cause 03-03 already found for plain `node`; fixed by capturing sandboxed output to an in-whitelist path instead of a phase-03/results/ path, and the crashed attempt is not counted toward the phase's invocation budget
- `phase-01/config/verify_config.sh` left verified-correct (PASS) after two heal cycles (the smoke test itself, and `check_versions.sh`'s own internal `cline config --json` call, each independently stripped `providers.json`'s `models[]`/`contextWindow` exactly as Phase 1's decision log predicted — both healed via `apply_provider_config.sh` and re-verified)
- `docs/sandbox-whitelist.md` written (8 sections, Korean, house style matched to `docs/infra-hardening.md`): architecture flow, why Cline's own permission/sandbox env vars are dead code in this build, the `(allow default)`+`$HOME`-scoped deny limitation as its own prominent section, how to add a repo, the Phase 4 interface contract, the criterion-to-case mapping (verified to match `verify_sandbox.sh`'s actual criterion-1 ancestor-check direction), the cline smoke-test (C) result as a documented Phase 4 open item, and what was deferred to Phase 5
- Phase-close: all six gates (`verify_sandbox.sh`, `pytest phase-03/tests/`, `verify_config.sh`, `phase-02/infra/verify_no_regression.sh`, launchctl pids, `git status`) green in one sitting; flashnext/litellm/role-shim pids unchanged from the values recorded at the very start of this plan and throughout Phase 3 (46573/48525/75548)

## Task Commits

Each task was committed atomically:

1. **Task 1: The single budgeted cline smoke test under the sandbox** - `946bb30` (feat)
2. **Task 2: docs/sandbox-whitelist.md — shipped state, stated limitation, Phase 4 interface** - `a77e2fb` (docs)
3. **Task 3: Phase-close re-verification** - `510cca2` (docs)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified
- `docs/sandbox-whitelist.md` - Phase 3's shipped-state record (8 sections: architecture, why not Cline-native, the scope-limitation section, how to add a repo, Phase 4 interface contract, verification evidence + criterion mapping, cline smoke-test result, deferred work)
- `phase-03/results/20260829T202633Z-pre-cline/` - pre-flight `verify_sandbox.sh` run (PASS) + `providers.json.snapshot` taken before the cline call
- `phase-03/results/20260829T202633Z-cline-smoke/` - `verdict.txt`, `README.md`, the crashed first attempt's transcript (`attempt1-crashed.*`), the real second attempt's transcript (`version.*`), static `strings` evidence (`bun-error-strings-evidence.txt`), and the full config-guard heal-cycle transcripts (`verify_config-*.txt`, `apply_provider_config*.txt`, `check_versions.txt`, `verify_sandbox-post.txt`)
- `phase-03/results/20260829T203455Z-phase-close/` - all six phase-close gate transcripts plus a `README.md` verdict table

## Decisions Made
- **Verdict (C) BLOCKED-NEEDS-HUMAN, no sandbox change.** See key-decisions above and `verdict.txt` for the full reasoning chain; the short version: the only real error message the sandboxed `cline` binary produced is Bun's generic "An unknown error occurred (Unexpected)" catch-all, which names no path — the plan's (B) bounded-fix path requires a permission error naming one of four specific pre-declared Cline-owned directories, and this evidence does not provide that, so per the plan's explicit instruction the only correct classification is (C): make no profile change and hand it to Phase 4 as a documented open item.
- **The first (crashed) attempt does not count toward "exactly one real cline invocation."** It crashed inside Node's own C++ process bootstrap before a single line of cline's/Bun's own code executed (confirmed by the native stack trace showing only `node::InitializeOncePerProcessInternal`/`node::Start`), and the cause was this executor's own output-redirection choice (a plumbing detail), not a signal from the sandbox about `cline` or a real `cline` invocation attempt. The corrected second attempt — which did reach and run the real `.cline` Bun binary and produce a genuine application-level (if unspecific) error — is the one counted.
- Attempted one additional zero-cost diagnostic beyond what the plan required (`log show --last 10m --predicate 'eventMessage contains "deny("'`) to try to recover the specific denied path/errno from macOS's unified log; it returned no data under this session's privilege level. This did not consume any additional `cline` invocation and is documented in `verdict.txt` as an exhausted avenue, not a new finding.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The plan's literal cline-smoke-test invocation form crashed the sandboxed process with SIGABRT before any cline/Bun code ran**
- **Found during:** Task 1, first live attempt at the smoke test
- **Issue:** The plan's literal command form (`bash -c '...' > phase-03/results/<ts>-cline-smoke/version.out 2> ...version.err`) redirects the outer chained command's stdout/stderr — which the sandboxed `cline` process inherits unchanged across `exec` — directly to a regular file under `phase-03/results/`, a path the generated profile does NOT punch through. This is the exact same root cause plan 03-03 already found and fixed for its F8 case (plain `node` invocation): Node's own process bootstrap (`node::InitializeOncePerProcessInternal`) crashes with SIGABRT and no application-level diagnostic when one of its inherited stdio fds is a regular file under a denied path. Since `cline`'s launcher is itself a `#!/usr/bin/env node` shebang script, it hit the identical crash before ever spawning the real `.cline` Bun binary. Exit code 134, stderr contained only a native C++ stack trace, no cline/sandbox-specific information — indistinguishable from a denial by exit code alone.
- **Fix:** Redirected the outer chained command's stdout/stderr to files inside the whitelist (`workspace/scratch-repo/.cline-smoke-version.{out,err}`, an `ALLOWED_REPOS.json` entry) instead of directly to `phase-03/results/`, then copied the captured files into the results directory from the unsandboxed parent shell afterward and deleted the scratch copies. This does not touch `EXTRA_ALLOW_PATHS`, `config.env`, or any security boundary — it is a pure output-capture plumbing fix, the same class of fix 03-03 already applied and documented for F8.
- **Files modified:** None (shell-level invocation adjustment only, no script/config file changed)
- **Verification:** The corrected invocation no longer crashes (no SIGABRT, no native stack trace); it proceeds to run the real `.cline` Bun binary and produces a genuine application-level error instead. The crashed first attempt's full transcript is preserved (`attempt1-crashed.{out,err,exitcode}`) for the record, and `verdict.txt`/`README.md` explain why it is not counted toward the phase's invocation budget.
- **Committed in:** `946bb30` (Task 1 commit — found and fixed before that commit)

---

**Total deviations:** 1 auto-fixed (1 blocking harness bug, same root cause class as 03-03's F8 finding, generalized here to the real cline binary)
**Impact on plan:** Required to get any real evidence about the actual `cline` binary's behavior at all (the plan's literal command would have produced only an uninformative crash trace). No sandbox boundary was touched by this fix; the resulting classification (C) and the "make no profile change" outcome are unaffected by it.

## Issues Encountered
- `check_versions.sh`'s own internal `cline config --json` invocation (part of its "Check B: no drift across invocations") re-stripped `providers.json`'s `models[]`/`contextWindow` a second time within this single plan's execution, exactly as the 01-04 decision log predicted would happen with any real `cline` call. Not a new finding; healed with a second `apply_provider_config.sh` run and re-verified PASS, matching the plan's explicit instruction that this drift is "expected and recoverable, not a failure."
- Attempted `log show` as a zero-cost diagnostic to recover the specific denied path behind the generic Bun error; returned no data under this session's unprivileged access. Did not pursue `dtruss`/`fs_usage` (require `sudo`, explicitly out of scope for an unattended plan) — documented as an exhausted avenue in `verdict.txt` rather than silently omitted.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 4 has a single document to read (`docs/sandbox-whitelist.md`) and a single script to call (`phase-03/sandbox/run_sandboxed.sh`) to start building the headless wrapper, per the plan's own success criteria.
- Phase 4's one open item, explicitly documented rather than hidden: running the real `cline` binary under this sandbox as shipped produces a generic Bun runtime error of unspecific cause. Phase 4 should budget time to reproduce with elevated diagnostic tooling (`dtruss`/`fs_usage` under `sudo`, or any Bun verbose/debug flags) before deciding whether — and how narrowly, within the four pre-declared candidates — to widen `EXTRA_ALLOW_PATHS`. This is not a blocker for Phase 4 to begin: ROADMAP criteria 2/3 are already proven at the kernel level using `/bin/cat`/`/bin/sh`/`node`, which share `cline`'s fs/exec syscall surface.
- All four ROADMAP Phase 3 success criteria (SBX-01..04) are simultaneously PASS at phase close, and the standing gate (`verify_sandbox.sh`) plus Phase 2's standing gate (`verify_no_regression.sh`) both re-confirmed PASS with zero service disruption (flashnext/litellm/role-shim pids unchanged throughout the entire phase: 46573/48525/75548).
- No blockers for Phase 4. **Phase 3 (샌드박스 + 저장소 화이트리스트) is closed.**

---
*Phase: 03-sandbox-repo-whitelist*
*Completed: 2026-08-30*
