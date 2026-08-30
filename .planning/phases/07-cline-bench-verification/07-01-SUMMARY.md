---
phase: 07-cline-bench-verification
plan: 01
subsystem: testing
tags: [harbor, cline-bench, docker, colima, uv, litellm, benchmark]

# Dependency graph
requires:
  - phase: 06-network-exposure
    provides: verify_network.sh standing gate (CASES 24/24 baseline), docs/network-exposure.md handoff notes
  - phase: 05-kanban-telegram-services
    provides: verify_services.sh standing gate, six live launchd/proxy services
  - phase: 03-sandbox-repo-whitelist
    provides: verify_sandbox.sh standing gate, workspace/ALLOWED_REPOS.json, bench/runs/CANARY.txt (SBX-04)
  - phase: 02-infra-hardening
    provides: verify_no_regression.sh (INF-03) standing gate
  - phase: 01-config-pins
    provides: verify_config.sh standing gate, openai-compatible/flashnext provider pin
provides:
  - phase-07/bench/config.env (single source of truth for harbor/cline-bench spec)
  - phase-07/bench/preflight.sh (11-check standing Phase 7 gate)
  - phase-07/bench/install_bench.sh (idempotent harbor + cline-bench installer)
  - Live cline-bench checkout @ d1085569fb0ae3f9613957e6fc2706c6e2f7da9b (12 tasks)
  - harbor 0.22.0 installed at ~/.local/bin/harbor
  - Measured task inventory (phase-07/results/*-inventory/tasks.tsv, candidates.txt)
  - Reproduced container->litellm reachability proof
affects: [07-02, 07-03, 07-04, 07-05]

# Tech tracking
tech-stack:
  added: [harbor (harbor-framework/harbor, PyPI, 0.22.0), cline-bench (git checkout, not a dependency)]
  patterns: ["standing-gate composition (preflight.sh wraps five prior phases' own gates)", "wording-collision-trap resolution by relocating prose to a sibling file rather than the mechanically-checked one"]

key-files:
  created:
    - phase-07/bench/config.env
    - phase-07/bench/preflight.sh
    - phase-07/bench/install_bench.sh
    - phase-07/results/20260830T084629Z-preflight/ (incl. negative-control/)
    - phase-07/results/20260830T085155Z-install/
    - phase-07/results/20260830T085301Z-inventory/
  modified:
    - .gitignore (bench/cline-bench/ excluded; bench/runs/ stays tracked)

key-decisions:
  - "P11's ALLOWED_REPOS.json check parses the repos[] JSON array via python3/tomllib-adjacent json, not a naive whole-file grep for 'bench' -- the file's own Phase-3-authored _comment field legitimately contains the word 'bench' while explaining SBX-04, which would make a bare grep a permanent false positive."
  - "The excluded task's exclusion reason (terraform-azurerm-deployment-stacks, memory_mb=8192) is recorded in README.md, not candidates.txt -- this plan's own <action> text and <verify> block for Task 3 are mutually exclusive for that one file (see Deviations)."
  - "P5 of preflight.sh passes --out-dir explicitly to verify_network.sh to prevent this process's exported RESULTS_ROOT from leaking into a child gate script and silently redirecting its evidence into phase-07/results/ instead of phase-06/results/."

patterns-established:
  - "A phase's own preflight.sh composing five prior phases' standing gates plus phase-specific checks (disk/colima/docker/sandbox-exclusion), all under one CHECK:/CASES contract, with an explicit negative control proving the composite gate can fail."

# Metrics
duration: ~20min
completed: 2026-08-30
---

# Phase 7 Plan 1: Preflight + Install + Inventory Summary

**harbor 0.22.0 + cline-bench@d108556 installed idempotently after an 11-check preflight sweep (with a working negative control), and the live task pool measured at 12 tasks (not the 14 research assumed, and far from the old ~89 figure) with a container->litellm reachability proof reproduced live.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-08-30T08:38:00Z (approx.)
- **Completed:** 2026-08-30T08:58:00Z
- **Tasks:** 3/3
- **Files modified:** 4 script/config files + 3 timestamped evidence directories (82+6+5 files)

## Accomplishments
- All five inherited standing gates (phase-05 services, phase-02 INF-03, phase-06 network CASES 24/24, phase-03 sandbox SBX-04, phase-01 provider config) plus six Phase-7-specific checks (pids+cmd substring, port 3000, disk floor, colima, docker, ALLOWED_REPOS.json exclusion) proven green in one composite gate, twice, with a negative control proving it can actually fail.
- harbor and cline-bench installed idempotently with a written, literal removal recipe (`uv tool uninstall harbor` + `rm -rf bench/cline-bench`), proven idempotent by a second run into a scratch dir.
- Live task inventory measured directly (tomllib, not regex): 12 tasks, correcting 07-RESEARCH.md's own 14 (itself already a correction from an older ~89 figure) -- the pool shrank by two directories between yesterday's research and today's clone.
- Container-to-litellm reachability re-proven live: `docker run --rm alpine ... curl http://host.docker.internal:4000/v1/models` returns HTTP 200 with the real flashnext model list, wildcard-bind count and the `:4000` 127.0.0.1-only bind both unchanged before/after -- no Phase 2 posture change.

## Task Commits

Each task was committed atomically:

1. **Task 1: config.env + read-only preflight sweep** - `f669831` (feat)
2. **Task 2: Idempotent install of cline-bench + harbor** - `47a8b0a` (feat)
3. **Task 3: Live task inventory + reachability probe** - `f8e9d04` (docs)

_No separate plan-metadata commit yet -- this SUMMARY.md + STATE.md update is the final commit for this plan._

## Files Created/Modified
- `phase-07/bench/config.env` - single source of truth: harbor/cline-bench spec, live-pid table (three parallel arrays incl. expected cmd substrings), candidate task suffixes, MIN_FREE_GIB
- `phase-07/bench/preflight.sh` - 11-check read-only standing gate (P1-P11), `--out`/`--baseline` flags, 0/1/2 exit contract
- `phase-07/bench/install_bench.sh` - idempotent installer: clone (never pull), pinned `uv venv --python 3.13`, `uv tool install harbor`, README.md manifest with REMOVAL recipe
- `.gitignore` - added `bench/cline-bench/`
- `phase-07/results/20260830T084629Z-preflight/` - two clean runs' worth of evidence + `negative-control/negative-control.txt`
- `phase-07/results/20260830T085155Z-install/` - install manifest, commit SHA, commands run
- `phase-07/results/20260830T085301Z-inventory/` - `tasks.tsv`, `candidates.txt`, `docker-reachability.txt`, `resources.txt`, `README.md`

## Decisions Made
- P11 (ALLOWED_REPOS.json exclusion check) parses the JSON `repos[]` array specifically via `python3`, rather than a naive whole-file `grep -c bench` -- the file's own Phase-3 `_comment` field (commit `df088e2`, predates this phase) legitimately explains SBX-04 in prose containing the word "bench", which would make a literal whole-file grep a permanent false positive unrelated to the actual SBX-01/SBX-04 invariant (the `repos[]` array itself, which correctly excludes both `bench/` and the repo root).
- P5 of `preflight.sh` passes `--out-dir` explicitly to `phase-06/net/verify_network.sh` rather than relying on that script's own `RESULTS_ROOT`-derived default -- caught live during authoring: without it, this process's exported `RESULTS_ROOT` (from `phase-07/bench/config.env`) leaked into the child process and silently redirected phase-06's gate evidence into `phase-07/results/` instead of `phase-06/results/`.
- The `terraform-azurerm-deployment-stacks` exclusion (measured `memory_mb=8192` exceeding colima's whole 4 GiB VM) is recorded in the inventory `README.md`, not `candidates.txt` -- see Deviations below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] P5's child-gate output redirected to the wrong phase's results dir**
- **Found during:** Task 1 (writing/testing `preflight.sh`)
- **Issue:** `preflight.sh` exports `RESULTS_ROOT=phase-07/results` (from `config.env`). Calling `phase-06/net/verify_network.sh --baseline <path>` without an explicit `--out-dir` let the child process inherit that exported value via its own `${RESULTS_ROOT:-default}` override idiom, so its own evidence directory landed under `phase-07/results/<UTC>-net-gate/` instead of `phase-06/results/<UTC>-net-gate/` -- confirmed live (ran once, saw the misplaced directory, then fixed).
- **Fix:** P5 now passes `--out-dir "$OUT_DIR/p5-network"` explicitly, matching what P3/P4/P6 already did for the same reason.
- **Files modified:** `phase-07/bench/preflight.sh`
- **Verification:** Re-ran preflight.sh twice after the fix; both runs' P5 evidence landed correctly under `$OUT_DIR/p5-network/`, no stray directories appeared under `phase-06/results/` or `phase-07/results/`.
- **Committed in:** `f669831` (Task 1 commit)

**2. [Rule 4-adjacent, reported not improvised — wording-collision plan defect] Task 3's own `<action>` and `<verify>` for `candidates.txt` are mutually exclusive**
- **Found during:** Task 3 (writing `candidates.txt`)
- **Issue:** The plan's `<action>` text for Task 3, taken literally, instructs writing every excluded task's name (with its measured reason) into `candidates.txt`'s own "왜 이 목록인가" header -- including `terraform-azurerm-deployment-stacks`. The same task's `<verify>` block asserts `grep terraform .../candidates.txt` finds nothing. Both cannot be simultaneously true for the same file; this is house rule 9's WORDING-COLLISION TRAP, encountered live in the plan's own authored text rather than in pre-existing prose.
- **Resolution:** Per the executor's own instructions ("if you hit a `<verify>` step you cannot satisfy from the `<action>` text, treat that as a plan defect worth reporting, not something to improvise around"), the literal, mechanically-checked `<verify>` grep was satisfied: `candidates.txt`'s header lists only the three genuinely `not-shortlisted` tasks (no "terraform" substring anywhere in the file). The excluded task's confirmation (present in `tasks.tsv`, absent from the candidate list) and its `memory_mb=8192` reason are instead recorded in `README.md`, a sibling file in the same `phase-07/results/<UTC>-inventory/` directory -- the substance the `<action>` text asked for is preserved, just relocated one file over, rather than silently dropped or silently violating the `<verify>` grep.
- **Files affected:** `phase-07/results/20260830T085301Z-inventory/candidates.txt`, `.../README.md`
- **Verification:** `grep terraform .../candidates.txt` exits 1 (no match, confirmed); `.../README.md` contains the full exclusion confirmation with `memory_mb=8192` reason, cross-referenced from `candidates.txt`'s own header note.
- **Committed in:** `f8e9d04` (Task 3 commit)

**3. [Rule 1 - pre-existing false positive, documented not fixed] The overall plan's own `<verification>` line `grep -c bench workspace/ALLOWED_REPOS.json` is 0 is not satisfiable without editing a Phase-3-owned file outside this plan's declared scope**
- **Found during:** Final plan-level verification sweep
- **Issue:** `workspace/ALLOWED_REPOS.json`'s own `_comment` field (written in commit `df088e2`, Phase 3, `feat(03-01): scaffold whitelist, workspace, bench tree, and config.env` -- predates this plan entirely) legitimately explains SBX-04 in prose that contains the word "bench" ("...because bench/ lives under it and SBX-04 (criterion 4) requires bench/ to be unreachable..."). `grep -c bench workspace/ALLOWED_REPOS.json` therefore reads `1`, not `0`, and always has since Phase 3 -- no task in this plan touches this file (correctly: it is not in any task's declared `<files>` list, and it is Phase 3's own canonical SBX-01 source, not this phase's to edit).
- **Resolution:** Not fixed -- editing a Phase-3-owned file's explanatory prose is out of this plan's scope. The check that actually matters (does `ALLOWED_REPOS.json`'s `repos[]` array include `bench` or the repo root?) is implemented correctly and passes as `preflight.sh`'s own P11 check (`entries=1 ['/Users/ohama/projs/cline-tests/workspace/scratch-repo']`). Documented here per the executor's instruction to report, not improvise around, an unsatisfiable `<verify>` line.
- **Files affected:** none (no file was edited to work around this)
- **Verification:** `grep -c bench workspace/ALLOWED_REPOS.json` reads `1` (confirmed, pre-existing since Phase 3); `preflight.sh`'s P11 check (the semantically correct check) reads `PASS entries=1 [...]`.
- **Committed in:** n/a (documentation-only finding, no code change)

---

**Total deviations:** 3 (1 auto-fixed bug, 1 reported-not-improvised plan-wording-collision, 1 documented pre-existing false positive)
**Impact on plan:** All three preserve or improve correctness; none touched a live service, host posture, or a file outside this plan's declared scope. No scope creep.

## Issues Encountered
- The live cline-bench task count changed between 07-RESEARCH.md's clone (2026-08-30, research pass) and this plan's clone (2026-08-30, a few hours later, same day): 14 -> 12. Two task directories present at research time are gone from the live repo as of this install. Documented in `phase-07/results/*-inventory/README.md` as the new, current denominator (12) -- not silently reconciled against the stale 14.
- `CANDIDATE_SUFFIXES`' `orpc-client-workspace` entry does not resolve against the live inventory (the real, live suffix is `orpc-client-migration`) -- resolved per plan as `UNRESOLVED orpc-client-workspace`, simply dropped from the candidate pool. `07-03`'s decision plan can still reach the equivalent task (`orpc-client-migration`) as a `not-shortlisted`/`custom` pick if desired, per its own honest labelling in `candidates.txt`.

## User Setup Required
None - no external service configuration required. harbor and cline-bench were installed entirely by `install_bench.sh`; no manual dashboard/env steps.

## Next Phase Readiness
- `phase-07/bench/{config.env,preflight.sh,install_bench.sh}` are ready for reuse by later plans in this phase (07-02 onward): `preflight.sh` should be re-run before any `harbor run` invocation, per its own standing-gate role.
- `bench/cline-bench/tasks/` (12 tasks) and `phase-07/results/*-inventory/candidates.txt` give 07-02/07-03 a measured, resolved candidate pool to select the smoke task and the 5-8-task run from -- `SMOKE_SUFFIX` (`discord-trivia-approval-keyerror`) is confirmed resolvable and should be the first real `harbor run`.
- No blockers. The one open, disclosed risk carried forward from 07-RESEARCH.md (container-side Cline's unconfigured 128k contextWindow fallback likely reproducing this project's own known bug against this stack's 32K ceiling) has not yet been tested -- that is 07-02's smoke-run's job, not this plan's.
- Six live pids (46573/75548/48525/53894/99162/19669) and port 3000 (unbound) were unchanged across all three tasks and at the final plan-level verification sweep.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-30*
