---
phase: 07-cline-bench-verification
plan: 02
subsystem: testing
tags: [harbor, cline-bench, docker-compose, providers-json, bash, evidence-capture]

# Dependency graph
requires:
  - phase: 07-01
    provides: harbor 0.22.0 + cline-bench@d108556 installed, preflight.sh (11-check standing gate), measured 12-task live pool, config.env single-source-of-truth
provides:
  - phase-07/results/20260830T091118Z-ctxwindow/FINDING.md (INJECTABLE contextWindow verdict, sourced from the installed adapter + installed cline binary)
  - phase-07/bench/cline-cw-overlay.yaml + cline-cw-providers.json (the injection mechanism's two supporting assets)
  - phase-07/bench/config.env additions (CW_INJECTION=applied, HARBOR_EXTRA_ARGS=--extra-docker-compose ...)
  - phase-07/bench/run_task.sh (one-task runner: guards, harbor invocation, prompt capture, server-log slice, meta record, config.json)
  - phase-07/bench/make_summary.sh (BCH-03 table generator)
  - phase-07/bench/verify_bench.sh (10-check BCH-01/02/03 + SBX-04 standing gate, with a proven negative control)
affects: [07-03, 07-04, 07-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "docker-compose overlay (--extra-docker-compose) + a compose-service-level env var (CLINE_PROVIDER_SETTINGS_PATH) as a generic, harbor-native way to inject container-only config without editing a task file or patching harbor"
    - "verdict-classification-as-a-script-comment (run_task.sh's pass/fail-task/fail-context/fail-infra rule is written as an auditable comment directly above the code that implements it)"
    - "escape-valve-that-announces-itself (verify_bench.sh's B3 prints '(N excused as fail-infra)' whenever the valve fires, so an exemption is never silent)"

key-files:
  created:
    - phase-07/results/20260830T091118Z-ctxwindow/FINDING.md
    - phase-07/bench/cline-cw-overlay.yaml
    - phase-07/bench/cline-cw-providers.json
    - phase-07/bench/run_task.sh
    - phase-07/bench/make_summary.sh
    - phase-07/bench/verify_bench.sh
  modified:
    - phase-07/bench/config.env (CW_INJECTION, HARBOR_EXTRA_ARGS)

key-decisions:
  - "contextWindow VERDICT is INJECTABLE, not the NOT-INJECTABLE the phase's own framing leaned toward -- avenue E (--extra-docker-compose, a real harbor CLI flag) bind-mounts a project-authored providers.json and redirects the container's cline to it via CLINE_PROVIDER_SETTINGS_PATH, chained through three independently-sourced points in the installed cline 3.0.53 binary. Not live-verified (this plan's cline/harbor budget is 0); 07-03's smoke run is the first live check, and its contingency is unchanged either way -- if the mechanism doesn't take effect live, the resulting failure is still a disclosable fail-context row, not a broken harness."
  - "B5's wording collision (make_summary.sh's own <action> requires a not-run row for every unattempted live task -- 'no task is ever omitted' -- while B5's <verify> requires the table's data-row count to equal the meta record count) resolved by defining B5's counted 'data rows' as attempted-task rows only, excluding not-run rows from that one count while keeping them in the table. Reported in verify_bench.sh's own B5 comment, matching 07-01 Task 3's precedent for the same house-rule-9 trap."
  - "run_task.sh writes a run-level config.json (harbor version, cline-bench SHA, model spec, BASE_URL) that no <action> text in this plan explicitly instructed -- added because verify_bench.sh's own B1 check (also this plan's own Task 3) needs it and could never pass without it. A Rule 2 gap-fill, not a scope expansion: the artifact is exactly what B1's own wording already implied must exist."

patterns-established:
  - "A phase's contextWindow-injection question is answered from the INSTALLED adapter's own source (not a GitHub clone) plus direct strings/regex reads of the installed compiled binary -- never invoking the tool itself when the plan's own budget for it is 0."

# Metrics
duration: ~20min
completed: 2026-08-30
---

# Phase 7 Plan 2: contextWindow Verdict + Bench Scripts Summary

**The container's Cline CAN be told this stack's 29000-token contextWindow -- via `harbor run --extra-docker-compose`, a bind-mounted project-authored providers.json, and `CLINE_PROVIDER_SETTINGS_PATH`, sourced from three chained points in the installed cline 3.0.53 binary -- and the three evidence-capture scripts (`run_task.sh`/`make_summary.sh`/`verify_bench.sh`) that turn a `harbor run` into a committed, re-verifiable BCH-01/02/03 bundle are written, syntax-checked, and exercised against synthetic run directories, with zero model spend.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-08-30T09:11:00Z (approx.)
- **Completed:** 2026-08-30T09:30:00Z
- **Tasks:** 3/3
- **Files modified:** 6 new files + 1 modified config file + 2 timestamped evidence directories

## Accomplishments

- Read the INSTALLED harbor 0.22.0 adapter source (`~/.local/share/uv/tools/harbor/.../agents/installed/cline/cline.py`, `docker.py`, `cli/jobs.py`, `utils/env.py`) and the INSTALLED cline 3.0.53 compiled binary directly on this machine (not remote copies), worked all five avenues the plan specified, and landed a single grep-checkable `VERDICT: INJECTABLE` line, backed by verbatim source quotes for every avenue.
- Discovered, chained, and documented the actual mechanism: `--extra-docker-compose` (a real, documented, generic harbor CLI flag -- confirmed wired end-to-end through `cli/jobs.py` -> `models/trial/config.py` -> `environments/docker/docker.py`) bind-mounts a from-scratch `providers.json` and sets `CLINE_PROVIDER_SETTINGS_PATH` at the compose-service level; `docker compose exec -e` is additive (confirmed from source, never clears the container's own env); the installed cline binary's settings-path resolver (`sC()`) honors that env var verbatim; and cline's own `--json`/non-interactive single-shot bootstrap calls `getProviderConfig()` for the exact invocation shape harbor's adapter uses.
- Bonus finding folded into the same FINDING.md (avenue C, as the plan itself asked to check): `BASE_URL` is never forwarded by the adapter's fixed 5-key exec-env dict, and the compiled cline binary never reads it in the core invocation path (only in unrelated `connect <platform>` subcommands) -- for `openai-compatible` specifically, `baseUrl` is sourced exclusively from `providers.json`, so this same injection mechanism incidentally also supplies the base URL a fresh container-side cline would otherwise lack entirely.
- `run_task.sh` (505 lines): resolves a task by full name or suffix, keeps every task in one run directory (resumable via skip-if-done), five pre-guards that abort before anything mutates, prompt capture before the run so it survives a harbor crash, the exact plan-specified harbor invocation (unquoted so `--dry-run` output is directly grep-checkable), post-guards that record rather than silently absorb a regression, harbor's own `jobs/` output collected verbatim with `agent-command.txt`/`system-prompt-probe.txt` extraction and `CAPTURE-GAPS.txt` for anything missing, a byte-offset server-log slice, and an auditable `pass`/`fail-task`/`fail-context`/`fail-infra` verdict rule written as a script comment.
- `make_summary.sh` (203 lines) and `verify_bench.sh` (438 lines): the former builds the BCH-03 table (every attempted task plus a `not-run` row for every unattempted live-pool task, a totals line, and a mandatory 한계 section) purely from `verifier/reward.txt`-derived meta records; the latter is a 10-check (B1-B10) read-only standing gate with a proven negative control (`--run-dir /nonexistent` -> exit 1, `CHECK: FAIL B1`) and a B3 escape valve scoped exactly to `fail-infra` that announces itself when used and never accepts `agent/cline.txt` as a substitute for `agent-command.txt`.
- Both scripts exercised against three synthetic run directories (constructed under the session scratchpad, never touching `bench/runs/`): a positive two-task case reaching `CASES 10/10`, a `fail-infra` case proving the B3 valve fires and announces itself, and a `fail-task` case proving the same valve correctly refuses to fire.

## Task Commits

Each task was committed atomically:

1. **Task 1: contextWindow injectability verdict — INJECTABLE** - `c4a660c` (feat)
2. **Task 2: run_task.sh — one task in, one evidence bundle out** - `c4eec49` (feat)
3. **Task 3: make_summary.sh (BCH-03 table) + verify_bench.sh (gate)** - `f115ffe` (feat)

## Files Created/Modified

- `phase-07/results/20260830T091118Z-ctxwindow/FINDING.md` — the five-avenue investigation and VERDICT, plus two preflight re-runs' evidence captured alongside it (`preflight-check/`, `preflight-check2/`)
- `phase-07/bench/cline-cw-overlay.yaml` — docker-compose overlay for the `main` service: read-only bind mount + `CLINE_PROVIDER_SETTINGS_PATH`
- `phase-07/bench/cline-cw-providers.json` — from-scratch, container-only providers.json (top-level `settings.contextWindow=29000`, matching `docs/32k-compaction-policy.md`'s already-proven schema), never a copy of or write to the host's real file
- `phase-07/bench/config.env` — added `CW_INJECTION=applied`, `HARBOR_EXTRA_ARGS=--extra-docker-compose $PROJECT_ROOT/phase-07/bench/cline-cw-overlay.yaml`
- `phase-07/bench/run_task.sh` — the one-task runner (also gained a small `config.json` writer during Task 3, see Deviations)
- `phase-07/bench/make_summary.sh` — BCH-03 table generator
- `phase-07/bench/verify_bench.sh` — 10-check standing gate

## Decisions Made

- **contextWindow VERDICT: INJECTABLE**, not the NOT-INJECTABLE outcome the phase's own framing text leaned toward. The mechanism (`--extra-docker-compose` + `CLINE_PROVIDER_SETTINGS_PATH`) is sourced with high confidence from four independent, directly-quoted points in the installed adapter and the installed cline binary, but is explicitly flagged as NOT live-verified (this plan's `cline`/`harbor` budget is 0) -- 07-03's smoke run is the first live check, and either outcome (mechanism works, or doesn't) leaves 07-03's own contingency intact: an unconfigured/misconfigured context window still produces a disclosable `fail-context` row, never a broken harness.
- **House rule 6 compliance is structural, not incidental**: the injection mechanism never targets `~/.cline/data/settings/providers.json` (host or container) at all -- it deliberately routes around that literal path via `CLINE_PROVIDER_SETTINGS_PATH`, and `cline-cw-providers.json` is an entirely new file, never a copy of the host's real config.
- **B5's wording collision** (make_summary.sh's own `<action>` requires "no task is ever omitted from the table" including `not-run` rows, while B5's `<verify>` requires the table's data-row count to equal the meta record count -- literally incompatible whenever any task is not-run) resolved by defining B5's counted "data rows" as attempted-task rows only. Reported and resolved in `verify_bench.sh`'s own B5 comment, matching 07-01 Task 3's precedent for the same class of trap.
- **`config.json` gap-fill in `run_task.sh`**: no `<action>` text anywhere in this plan instructed creating a run-level `config.json`, yet Task 3's own B1 check requires one (naming harbor version, cline-bench SHA, model spec, BASE_URL) and could never pass without it. Added as a small, idempotent addition to `run_task.sh`'s run-directory step (Rule 2 -- missing critical functionality, not a scope expansion, since the artifact is exactly what B1's own wording already implied).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — missing critical functionality] `run_task.sh` needed a run-level `config.json` that no `<action>` instructed building**
- **Found during:** Task 3 (writing `verify_bench.sh`'s B1 check)
- **Issue:** B1 requires "the run directory exists and `config.json` in it names harbor version, cline-bench SHA, model spec and BASE_URL." Task 2's own 10-step `<action>` list for `run_task.sh` never mentions creating `config.json` anywhere.
- **Fix:** Added a small, idempotent block to `run_task.sh`'s run-directory-resolution step (before the skip-if-done check) that writes `<RUN>/config.json` once per run directory, if absent.
- **Files modified:** `phase-07/bench/run_task.sh`
- **Verification:** `verify_bench.sh`'s B1 check passes against a synthetic run directory with this `config.json` present; `--dry-run` mode (which returns before this code path) still creates no run directory at all, confirmed unchanged.
- **Committed in:** `f115ffe` (Task 3 commit — the fix landed alongside the check that needed it, both touching the bench-scripts surface together)

**2. [Rule 1 — bug, bash 3.2 compatibility] Empty-array iteration crashed under `set -u`**
- **Found during:** Task 3 (testing `verify_bench.sh`'s negative control)
- **Issue:** `for f in "${META_FILES[@]}"; do ...` raised `unbound variable` when `META_FILES` was a truly empty array — a known bash 3.2 (macOS `/bin/bash`) quirk, distinct from `${#META_FILES[@]}` (always safe). First hit while running the `--run-dir /nonexistent` negative control.
- **Fix:** Wrapped every such loop (B3, B4, B6) with an explicit `[ "$META_COUNT" -gt 0 ]` guard before iterating; B2's loop was already inside an equivalent guard.
- **Files modified:** `phase-07/bench/verify_bench.sh`
- **Verification:** Negative control re-run cleanly to completion (`CASES 4/10`, `CHECK: FAIL B1`, exit 1) instead of crashing mid-script.
- **Committed in:** `f115ffe` (Task 3 commit)

### Reported, Not Improvised

**3. [House rule 9 — wording-collision trap] B5's "data-row count equals meta record count" contradicts make_summary.sh's own "no task ever omitted" requirement**
- **Found during:** Task 3 (implementing B5)
- **Issue:** make_summary.sh's `<action>` text requires a `not-run` row for every live-pool task not attempted in the run directory ("No task is ever omitted from the table"). B5's `<verify>` text requires the resulting table's "data-row count" to equal the meta record count (the count of tasks actually attempted). Whenever any task is not-run — true for any partial run of the 12-task live pool, which every plan in this phase describes — a table satisfying the first requirement literally cannot satisfy the second as a whole-table row count.
- **Resolution:** Per the executor's own instructions and 07-01 Task 3's own precedent for the identical class of trap, the substance was preserved and the literal check was made satisfiable by definition: `verify_bench.sh`'s B5 counts only the rows for tasks that were actually attempted (`verdict != not-run`) as "data rows," excluding `not-run` rows from that count while keeping every one of them present in the table. Documented in a block comment directly above B5's implementation.
- **Files affected:** `phase-07/bench/verify_bench.sh` (comment + implementation), no change to `make_summary.sh`'s own behavior
- **Verification:** Tested against a synthetic 2-attempted/10-not-run run directory (matching the live 12-task pool): `CASES 10/10`, B5 reads `attempted-rows=2 meta-count=2`.
- **Committed in:** `f115ffe` (Task 3 commit)

---

**Total deviations:** 3 (1 Rule-2 gap-fill, 1 Rule-1 bash-compat bug fix, 1 reported-not-improvised wording-collision)
**Impact on plan:** All three preserve or improve correctness; none touched a live service, host posture, or spent any model/`cline`/`harbor` budget. No scope creep — the `config.json` gap-fill only supplies what B1 (this same plan's own Task 3) already required.

## Issues Encountered

- The contextWindow VERDICT required substantially deeper source tracing than the plan's five-avenue outline implies on its own — confirming `BASE_URL` propagation, the compose-service-level env-var inheritance behavior of `docker compose exec`, and the CLI single-shot bootstrap's `getProviderConfig()` call all required reading beyond `cline.py` alone (into `docker.py`, `cli/jobs.py`, `models/trial/config.py`, and multiple independent regions of the compiled cline binary). None of this exceeded the plan's stated scope (all of it lives inside avenues A-E), but it took materially longer than a single-file read.
- No live `harbor run` exists yet to confirm the INJECTABLE mechanism actually takes effect end-to-end — by design (this plan's budget for both `cline` and `harbor run` is 0). FINDING.md's own closing section names exactly what 07-03 must check first.

## User Setup Required

None — no external service configuration required. Every artifact in this plan is either read-only source investigation or a new file under `phase-07/`.

## Next Phase Readiness

- `phase-07/bench/{run_task.sh,make_summary.sh,verify_bench.sh}` are ready for 07-03's first real `harbor run` — `run_task.sh <task> ` (no `--dry-run`) is the exact command to invoke, and its `--dry-run` mode remains available for re-confirming the resolved command line before spending any model time.
- `phase-07/bench/config.env`'s `HARBOR_EXTRA_ARGS` already carries the contextWindow-injection flag; 07-03 does not need to add anything to the invocation itself.
- **The one thing 07-03 must do first, before treating any smoke-run result as meaningful**: confirm the `--extra-docker-compose` overlay actually took effect (FINDING.md's "What 07-03 must confirm first" section gives three concrete checks — `docker compose config` showing the merged mount/env, `docker compose exec main cat /opt/harbor-cline-cw/providers.json`, and the first few turns of `agent/cline.txt` not showing an immediate provider-not-configured error). If it did not take effect, the correct response is not to fix it live but to record the resulting failures as `fail-context` rows with their `max_prompt_tokens`, exactly as `run_task.sh`'s verdict rule and `make_summary.sh`'s 한계 section already anticipate.
- Six live pids (46573/75548/48525/53894/99162/19669) and port 3000 (unbound) were unchanged across all three tasks and at the final plan-level verification sweep; `docker ps -a -q --filter status=exited` count (5) is unchanged and confirmed to consist entirely of pre-existing containers from 2026-07-07/08-21/08-22 — none created by this plan.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-30*
