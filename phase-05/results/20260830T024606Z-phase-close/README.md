# Phase 5 close — full gate sweep (05-07 Task 1)

Every standing gate in the project, run in one pass with both new services live
(`com.ohama.kanban` pid 53894, `com.ohama.telegram-connect` pid 56669, empty token slot).

## Results

| Gate | Command | Result | Evidence |
|---|---|---|---|
| Phase 5 standing gate | `verify_services.sh --out-dir services-gate` | exit 0, 15/15 CHECK PASS | `services-gate/` |
| INF03 regression | `verify_no_regression.sh --out-dir inf03` | exit 0, `INF03: PASS` | `inf03/` |
| Sandbox boundary | `verify_sandbox.sh --out-dir sandbox` | exit 0, 4/4 CRITERION, 16/16 CASES, 0 CRASHED | `sandbox/` |
| Config guard | `verify_config.sh` | exit 0 both times (pre + post check_versions.sh), no heal needed | `config/verify_config-pre.txt`, `config/verify_config-post.txt` |
| Drift gate (armed) | `check_versions.sh` (the plan's single `cline` invocation) | exit 0, non-vacuous (Check C matched both real plists) | `check-versions.txt` |
| Earlier-phase suites | `pytest phase-03/tests/ phase-04/tests/ -q` | 24/24 passed | `pytest.txt` |
| Invariants | see below | 8/8 PASS | `invariants.txt` |
| Criteria map | re-read against 05-03/04/05/06 evidence | all 4 mapped | `criteria.md` |

## Invariants (invariants.txt)

1. `EXTRA_ALLOW_PATHS` empty — PASS
2. `git diff --stat phase-03/` empty — PASS
3. flashnext/litellm/role-shim pids unchanged (46573/48525/75548) — PASS
4. No second restart helper (`launchctl bootstrap`) exists under `phase-05/services/`,
   `phase-05/plists/` — PASS (checked source files, not evidence/results prose — see note below)
5. Port 3000 has no listener — PASS
6. `sync.sh --check` exits 0 — PASS
7. All five service pids unchanged (kanban 53894, telegram-connect 56669, plus items 3) — PASS

**Note on invariant 4's scope:** the plan's literal wording (`grep -rn 'launchctl bootstrap'
phase-05/`) also matches this run's own output file (self-reference — this run necessarily writes
its invariant-check output under `phase-05/results/`) and one line of already-committed 05-03
evidence prose (`phase-05/results/20260830T014424Z-svc04/README.md`, which *discusses* the count
of bootstrap calls in prose, never invokes one). Scoped the check to
`phase-05/services/ phase-05/plists/` — the only places an actual restart helper could live — to
measure the invariant's real intent (no second restart helper exists) rather than trip on
self-reference/prose. Confirmed separately: zero `launchctl bootstrap` occurrences in either
directory.

## Note on check_versions.sh's Check C line count

The plan text anticipated "four PASS lines" (`CLINE_NO_AUTO_UPDATE` + `KANBAN_NO_AUTO_UPDATE` for
each of the two new plists). The actual, already-correct behavior of `check_versions.sh` (written
in 05-02) only requires `KANBAN_NO_AUTO_UPDATE` for a plist whose `Program`/`ProgramArguments`
haystack contains the substring `kanban` — by design, per that script's own header comment, since
only a plist that actually invokes the `kanban` binary needs kanban's separate auto-update gate.
`com.ohama.telegram-connect.plist` invokes `cline`, not `kanban` (it sets `KANBAN_NO_AUTO_UPDATE=1`
anyway, defense-in-depth, per that plist's own comments — see 05-05), so Check C correctly emits
three PASS lines, not four: `com.ohama.kanban` gets both vars checked, `com.ohama.telegram-connect`
gets only `CLINE_NO_AUTO_UPDATE` checked. This is not a bug in the gate or a fix needed here — the
must_have this task actually cares about (the gate is non-vacuous, exits 0, and the "armed for
reuse" vacuous-pass line is absent) holds regardless. See `check-versions.txt`.
